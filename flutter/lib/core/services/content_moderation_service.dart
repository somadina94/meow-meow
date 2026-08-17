import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Content Moderation Service Provider
final contentModerationServiceProvider = Provider<ContentModerationService>((ref) {
  return ContentModerationService();
});

/// Content Moderation Result
class ModerationResult {
  final bool isAllowed;
  final bool isFlagged;
  final String? reason;
  final String? category;

  const ModerationResult({
    required this.isAllowed,
    this.isFlagged = false,
    this.reason,
    this.category,
  });
}

/// Content Moderation Service
///
/// Synced with React content-moderation.ts
/// Handles client-side content filtering and server-side moderation via edge functions.
class ContentModerationService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Blocked word patterns (basic client-side check)
  static final List<RegExp> _blockedPatterns = [
    RegExp(r'\b(sex|porn|nude|naked|xxx)\b', caseSensitive: false),
    RegExp(r'\b(kill|murder|suicide|bomb|terror)\b', caseSensitive: false),
    RegExp(r'\b(drug|cocaine|heroin|meth)\b', caseSensitive: false),
    RegExp(r'(\+?\d{10,})', caseSensitive: false), // Phone numbers
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', caseSensitive: false), // Emails
    RegExp(r'(https?://|www\.)\S+', caseSensitive: false), // URLs
    RegExp(r'(@[a-zA-Z0-9_]+)', caseSensitive: false), // Social media handles
  ];

  /// Quick client-side content check
  ModerationResult checkContent(String text) {
    if (text.trim().isEmpty) {
      return const ModerationResult(isAllowed: true);
    }

    for (final pattern in _blockedPatterns) {
      if (pattern.hasMatch(text)) {
        return ModerationResult(
          isAllowed: false,
          isFlagged: true,
          reason: 'Message contains prohibited content',
          category: 'blocked_content',
        );
      }
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Server-side content moderation via edge function
  Future<ModerationResult> moderateContent({
    required String text,
    required String userId,
    String? chatId,
    String contentType = 'message',
  }) async {
    // Quick client-side check first
    final clientCheck = checkContent(text);
    if (!clientCheck.isAllowed) return clientCheck;

    try {
      final response = await _client.functions.invoke(
        'content-moderation',
        body: {
          'text': text,
          'userId': userId,
          'chatId': chatId,
          'contentType': contentType,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return const ModerationResult(isAllowed: true);
      }

      return ModerationResult(
        isAllowed: data['allowed'] as bool? ?? true,
        isFlagged: data['flagged'] as bool? ?? false,
        reason: data['reason'] as String?,
        category: data['category'] as String?,
      );
    } catch (e) {
      // Allow on error to avoid blocking legitimate messages
      return const ModerationResult(isAllowed: true);
    }
  }

  /// Flag a message
  Future<bool> flagMessage({
    required String messageId,
    required String flaggedBy,
    required String reason,
  }) async {
    try {
      await _client.from('chat_messages').update({
        'flagged': true,
        'flagged_by': flaggedBy,
        'flag_reason': reason,
        'flagged_at': DateTime.now().toIso8601String(),
        'moderation_status': 'flagged',
      }).eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Report user
  Future<bool> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      await _client.from('community_disputes').insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'title': reason,
        'description': details,
        'dispute_type': 'user_report',
        'language_code': 'en',
        'status': 'pending',
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
