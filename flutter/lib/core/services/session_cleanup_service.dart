import 'package:supabase_flutter/supabase_flutter.dart';

/// Session Cleanup Service
/// 
/// Centralized cleanup for all active sessions when a user logs out.
/// Synced with React src/services/session-cleanup.service.ts
/// Handles: active chats, video calls, private group calls, user status.
class SessionCleanupService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Clean up all active sessions for a user on logout
  static Future<void> cleanupAllUserSessions(String userId) async {
    final now = DateTime.now().toIso8601String();

    try {
      await Future.wait([
        // 1. End all active chat sessions
        _client
            .from('active_chat_sessions')
            .update({
              'status': 'ended',
              'ended_at': now,
              'end_reason': 'user_logout',
            })
            .or('man_user_id.eq.$userId,woman_user_id.eq.$userId')
            .eq('status', 'active'),

        // 2. End all paused chat sessions
        _client
            .from('active_chat_sessions')
            .update({
              'status': 'ended',
              'ended_at': now,
              'end_reason': 'user_logout',
            })
            .or('man_user_id.eq.$userId,woman_user_id.eq.$userId')
            .inFilter('status', ['paused', 'billing_paused']),

        // 3. End all active video call sessions
        _client
            .from('video_call_sessions')
            .update({
              'status': 'ended',
              'ended_at': now,
              'end_reason': 'user_logout',
            })
            .or('man_user_id.eq.$userId,woman_user_id.eq.$userId')
            .eq('status', 'active'),

        // 4. Stop any private groups where user is the host
        _client
            .from('private_groups')
            .update({
              'is_live': false,
              'stream_id': null,
              'current_host_id': null,
              'current_host_name': null,
              'participant_count': 0,
            })
            .eq('current_host_id', userId)
            .eq('is_live', true),

        // 5. Remove user from any group memberships (as participant)
        _client
            .from('group_memberships')
            .delete()
            .eq('user_id', userId),

        // 6. Set user offline
        _client
            .from('user_status')
            .update({
              'is_online': false,
              'status_text': 'offline',
              'last_seen': now,
            })
            .eq('user_id', userId),

        // 7. Set women availability to unavailable
        _client
            .from('women_availability')
            .update({
              'is_available': false,
              'is_available_for_calls': false,
            })
            .eq('user_id', userId),
      ]);

      // ignore: avoid_print
      print('[SessionCleanup] All sessions cleaned up for user $userId');
    } catch (e) {
      // Don't throw - logout should still proceed even if cleanup partially fails
      // ignore: avoid_print
      print('[SessionCleanup] Error during cleanup: $e');
    }
  }
}
