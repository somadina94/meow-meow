import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the existing `verify-photo` edge function for AI gender + face
/// verification. Threshold (0.55) and rejection are decided server-side.
///
/// Returns null on transport failure; otherwise the parsed result.
final photoVerificationServiceProvider =
    Provider<PhotoVerificationService>((ref) => PhotoVerificationService());

class PhotoVerificationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<PhotoVerificationResult?> verify({
    required String userId,
    required String photoUrl,
    required String declaredGender,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-photo',
        body: {
          'user_id': userId,
          'photo_url': photoUrl,
          'declared_gender': declaredGender,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      return PhotoVerificationResult(
        approved: data['approved'] as bool? ?? false,
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
        detectedGender: data['detected_gender'] as String?,
        reason: data['reason'] as String?,
      );
    } catch (e) {
      debugPrint('[PhotoVerify] failed: $e');
      return null;
    }
  }
}

class PhotoVerificationResult {
  final bool approved;
  final double confidence;
  final String? detectedGender;
  final String? reason;
  const PhotoVerificationResult({
    required this.approved,
    required this.confidence,
    this.detectedGender,
    this.reason,
  });
}
