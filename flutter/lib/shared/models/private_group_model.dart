/// Private Group Model - Synced with private_groups table
class PrivateGroupModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? ownerLanguage;
  final String accessType;
  final bool isActive;
  final bool isLive;
  final String? streamId;
  final String? currentHostId;
  final String? currentHostName;
  final int participantCount;
  final double minGiftAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PrivateGroupModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.ownerLanguage,
    this.accessType = 'gift',
    this.isActive = true,
    this.isLive = false,
    this.streamId,
    this.currentHostId,
    this.currentHostName,
    this.participantCount = 0,
    this.minGiftAmount = 50,
    this.createdAt,
    this.updatedAt,
  });

  factory PrivateGroupModel.fromJson(Map<String, dynamic> json) {
    return PrivateGroupModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String? ?? 'Unnamed Group',
      description: json['description'] as String?,
      ownerLanguage: json['owner_language'] as String?,
      accessType: json['access_type'] as String? ?? 'gift',
      isActive: json['is_active'] as bool? ?? true,
      isLive: json['is_live'] as bool? ?? false,
      streamId: json['stream_id'] as String?,
      currentHostId: json['current_host_id'] as String?,
      currentHostName: json['current_host_name'] as String?,
      participantCount: json['participant_count'] as int? ?? 0,
      minGiftAmount: (json['min_gift_amount'] as num?)?.toDouble() ?? 50,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}

/// Group Membership Model
class GroupMembershipModel {
  final String id;
  final String groupId;
  final String userId;
  final double giftAmountPaid;
  final bool hasAccess;
  final DateTime? joinedAt;

  const GroupMembershipModel({
    required this.id,
    required this.groupId,
    required this.userId,
    this.giftAmountPaid = 0,
    this.hasAccess = true,
    this.joinedAt,
  });

  factory GroupMembershipModel.fromJson(Map<String, dynamic> json) {
    return GroupMembershipModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      giftAmountPaid: (json['gift_amount_paid'] as num?)?.toDouble() ?? 0,
      hasAccess: json['has_access'] as bool? ?? true,
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
    );
  }
}
