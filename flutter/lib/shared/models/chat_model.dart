/// Chat Message Model
class ChatMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String message;
  final String? translatedMessage;
  final bool isTranslated;
  final bool isRead;
  final bool flagged;
  final String? flagReason;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.translatedMessage,
    this.isTranslated = false,
    this.isRead = false,
    this.flagged = false,
    this.flagReason,
    this.createdAt,
  });
}

/// Chat Session Model
class ChatSessionModel {
  final String id;
  final String chatId;
  final String manUserId;
  final String womanUserId;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double totalMinutes;
  final double totalEarned;
  final double ratePerMinute;
  final String? endReason;
  final DateTime? lastActivityAt;

  const ChatSessionModel({
    required this.id,
    required this.chatId,
    required this.manUserId,
    required this.womanUserId,
    this.status = 'active',
    this.startedAt,
    this.endedAt,
    this.totalMinutes = 0,
    this.totalEarned = 0,
    this.ratePerMinute = 4.0,
    this.endReason,
    this.lastActivityAt,
  });
}

/// Chat Pricing Model
/// Note: Indian women earn womenEarningRate, non-Indian women earn ₹0/min
/// Eligibility checked via is_earning_eligible flag in female_profiles
class ChatPricingModel {
  final double ratePerMinute;
  final double womenEarningRate;
  final double videoRatePerMinute;
  final double videoWomenEarningRate;
  final double minWithdrawalBalance;
  final String currency;

  const ChatPricingModel({
    this.ratePerMinute = 4.0,
    this.womenEarningRate = 2.0,
    this.videoRatePerMinute = 8.0,
    this.videoWomenEarningRate = 4.0,
    this.minWithdrawalBalance = 5000.0, // Synced with React DEFAULT_PRICING
    this.currency = 'INR',
  });
}

/// Chat Partner Info (for display)
class ChatPartnerInfo {
  final String userId;
  final String name;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  const ChatPartnerInfo({
    required this.userId,
    required this.name,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
  });
}
