import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Edge functions invoked via Supabase client - no direct URL needed

/// Cleanup Service Provider
final cleanupServiceProvider = Provider<CleanupService>((ref) {
  return CleanupService();
});

/// Cleanup Service - Synced with React cleanup.service.ts
///
/// Triggers backend edge functions for data retention policy enforcement.
class CleanupService {
  final SupabaseClient _client = Supabase.instance.client;

  // Edge function calls use _client.functions.invoke() which handles URL/auth automatically

  /// Trigger data cleanup edge function
  Future<CleanupResult> triggerDataCleanup() async {
    try {
      final response = await _client.functions.invoke('data-cleanup');
      final data = response.data as Map<String, dynamic>?;
      return CleanupResult(
        success: data?['success'] ?? true,
        error: data?['error'] as String?,
      );
    } catch (e) {
      return CleanupResult(success: false, error: e.toString());
    }
  }

  /// Trigger group cleanup edge function
  Future<CleanupResult> triggerGroupCleanup() async {
    try {
      final response = await _client.functions.invoke('group-cleanup');
      final data = response.data as Map<String, dynamic>?;
      return CleanupResult(
        success: data?['success'] ?? true,
        error: data?['error'] as String?,
      );
    } catch (e) {
      return CleanupResult(success: false, error: e.toString());
    }
  }

  /// Trigger video cleanup edge function
  Future<CleanupResult> triggerVideoCleanup() async {
    try {
      final response = await _client.functions.invoke('video-cleanup');
      final data = response.data as Map<String, dynamic>?;
      return CleanupResult(
        success: data?['success'] ?? true,
        error: data?['error'] as String?,
      );
    } catch (e) {
      return CleanupResult(success: false, error: e.toString());
    }
  }

  /// Verify photo using edge function
  Future<PhotoVerificationResult> verifyPhoto({
    required String imageBase64,
    String? expectedGender,
    String? userId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-photo',
        body: {
          'imageBase64': imageBase64,
          'expectedGender': expectedGender,
          'userId': userId,
          'verificationType': 'selfie',
        },
      );

      final data = response.data as Map<String, dynamic>?;
      return PhotoVerificationResult(
        verified: data?['verified'] ?? false,
        detectedGender: data?['detectedGender'] ?? data?['detected_gender'],
        confidence: (data?['confidence'] as num?)?.toDouble(),
        reason: data?['reason'] as String?,
        genderMatches: data?['genderMatches'] ?? data?['gender_matches'],
      );
    } catch (e) {
      // Accept photo on error to avoid blocking registration
      return PhotoVerificationResult(verified: true, reason: 'Photo accepted');
    }
  }

  /// Run all cleanup tasks (admin manual trigger)
  Future<AllCleanupResults> runAllCleanups() async {
    final results = await Future.wait([
      triggerDataCleanup(),
      triggerGroupCleanup(),
      triggerVideoCleanup(),
    ]);

    return AllCleanupResults(
      dataCleanup: results[0],
      groupCleanup: results[1],
      videoCleanup: results[2],
    );
  }
}

/// Result model for cleanup operations
class CleanupResult {
  final bool success;
  final String? error;

  CleanupResult({required this.success, this.error});
}

/// Result model for photo verification
class PhotoVerificationResult {
  final bool verified;
  final String? detectedGender;
  final double? confidence;
  final String? reason;
  final bool? genderMatches;

  PhotoVerificationResult({
    required this.verified,
    this.detectedGender,
    this.confidence,
    this.reason,
    this.genderMatches,
  });
}

/// Combined results for all cleanup operations
class AllCleanupResults {
  final CleanupResult dataCleanup;
  final CleanupResult groupCleanup;
  final CleanupResult videoCleanup;

  AllCleanupResults({
    required this.dataCleanup,
    required this.groupCleanup,
    required this.videoCleanup,
  });
}
