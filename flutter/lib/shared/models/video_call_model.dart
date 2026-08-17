/// Video Call Session Model - Synced with video_call_sessions table
class VideoCallSessionModel {
  final String id;
  final String callId;
  final String manUserId;
  final String womanUserId;
  final String status; // 'ringing', 'active', 'ended', 'declined', 'missed', 'timeout_cleanup'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final double totalMinutes;
  final double totalEarned;
  final double ratePerMinute;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VideoCallSessionModel({
    required this.id,
    required this.callId,
    required this.manUserId,
    required this.womanUserId,
    this.status = 'ringing',
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.totalMinutes = 0,
    this.totalEarned = 0,
    this.ratePerMinute = 8.0,
    this.createdAt,
    this.updatedAt,
  });

  factory VideoCallSessionModel.fromJson(Map<String, dynamic> json) {
    return VideoCallSessionModel(
      id: json['id'] as String,
      callId: json['call_id'] as String,
      manUserId: json['man_user_id'] as String,
      womanUserId: json['woman_user_id'] as String,
      status: json['status'] as String? ?? 'ringing',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      endReason: json['end_reason'] as String?,
      totalMinutes: (json['total_minutes'] as num?)?.toDouble() ?? 0,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0,
      ratePerMinute: (json['rate_per_minute'] as num?)?.toDouble() ?? 8.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}

/// Video Call Result - Response from video-call-server edge function
class VideoCallResult {
  final bool success;
  final String? sessionId;
  final String? callId;
  final String? error;

  const VideoCallResult({
    required this.success,
    this.sessionId,
    this.callId,
    this.error,
  });
}
