import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/video_call_model.dart';

/// Video Call Service Provider
final videoCallServiceProvider = Provider<VideoCallService>((ref) {
  return VideoCallService();
});

/// Video Call Service
///
/// Handles video call session management via Supabase.
/// Synced with React DirectVideoCallButton, VideoCallMiniButton, IncomingVideoCallWindow.
/// DB columns: call_id, man_user_id, woman_user_id, status, rate_per_minute,
///   started_at, ended_at, end_reason, total_earned, total_minutes
class VideoCallService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Initiate a video call via edge function
  Future<VideoCallResult> initiateCall({
    required String callerId,
    required String receiverId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'video-call-server',
        body: {
          'action': 'initiate',
          'callerId': callerId,
          'receiverId': receiverId,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return const VideoCallResult(success: false, error: 'No response from server');
      }

      return VideoCallResult(
        success: data['success'] as bool? ?? false,
        sessionId: data['sessionId'] as String?,
        callId: data['call_id'] as String?,
        error: data['error'] as String?,
      );
    } catch (e) {
      return VideoCallResult(success: false, error: e.toString());
    }
  }

  /// Accept incoming call
  Future<bool> acceptCall(String callId) async {
    try {
      await _client.from('video_call_sessions').update({
        'status': 'active',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('call_id', callId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reject/decline incoming call
  Future<bool> rejectCall(String callId) async {
    try {
      await _client.from('video_call_sessions').update({
        'status': 'declined',
        'ended_at': DateTime.now().toIso8601String(),
        'end_reason': 'declined',
      }).eq('call_id', callId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// End active call
  Future<bool> endCall(String callId) async {
    try {
      await _client.from('video_call_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
        'end_reason': 'user_ended',
      }).eq('call_id', callId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get call session details by call_id
  Future<VideoCallSessionModel?> getSession(String callId) async {
    try {
      final response = await _client
          .from('video_call_sessions')
          .select()
          .eq('call_id', callId)
          .maybeSingle();

      if (response == null) return null;
      return VideoCallSessionModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get call history
  Future<List<VideoCallSessionModel>> getCallHistory(String userId, {int limit = 20}) async {
    try {
      final response = await _client
          .from('video_call_sessions')
          .select()
          .or('man_user_id.eq.$userId,woman_user_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => VideoCallSessionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Subscribe to incoming calls
  /// Men receive calls on man_user_id, women on woman_user_id
  RealtimeChannel subscribeToIncomingCalls(
    String userId,
    String userGender,
    void Function(VideoCallSessionModel session) onIncomingCall,
  ) {
    final filterColumn = userGender == 'male' ? 'man_user_id' : 'woman_user_id';

    return _client.channel('video_calls:$userId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'video_call_sessions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: filterColumn,
        value: userId,
      ),
      callback: (payload) {
        final session = VideoCallSessionModel.fromJson(payload.newRecord);
        if (session.status == 'ringing') {
          onIncomingCall(session);
        }
      },
    ).subscribe();
  }

  /// Video call billing is **server-managed** via the canonical heartbeat
  /// pipeline (`bill_session_minute` / `bill_session_partial_minute`)
  /// triggered by edge functions on session events. The client must NOT
  /// call any per-minute billing RPC directly. Kept for API compatibility.
  Future<Map<String, dynamic>> processCallBilling(
    String sessionId, double minutes,
  ) async {
    return {
      'success': true,
      'note': 'Video call billing is handled server-side via heartbeats.',
    };
  }
}
