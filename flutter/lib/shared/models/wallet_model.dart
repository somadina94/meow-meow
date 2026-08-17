/// Wallet Model - Synced with wallets table
class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    this.balance = 0,
    this.currency = 'INR',
    this.createdAt,
    this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}

/// Wallet Transaction Model - Synced with wallet_transactions table
class WalletTransactionModel {
  final String id;
  final String walletId;
  final String userId;
  final String type; // 'credit' or 'debit'
  final double amount;
  final String? description;
  final String? referenceId;
  final String status;
  final DateTime? createdAt;
  double? balanceAfter; // Computed client-side for running balance

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.referenceId,
    this.status = 'completed',
    this.createdAt,
    this.balanceAfter,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String? ?? '',
      userId: json['user_id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// Women Earnings Model - Derived view over `wallet_transactions`
/// (legacy `women_earnings` table is removed; SoT is wallet_transactions).
class WomenEarningsModel {
  final String id;
  final String userId;
  final double amount;
  final String earningType; // 'chat' | 'video_call' | 'gift' | 'group'
  final String? chatSessionId;
  final String? description;
  final DateTime? createdAt;
  String? partnerName;

  WomenEarningsModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.earningType,
    this.chatSessionId,
    this.description,
    this.createdAt,
    this.partnerName,
  });

  /// Build from a `wallet_transactions` row (credit + earning transaction_type).
  factory WomenEarningsModel.fromWalletTransaction(Map<String, dynamic> json) {
    final txType = (json['transaction_type'] as String? ?? '').toLowerCase();
    final desc = (json['description'] as String? ?? '').toLowerCase();
    String earningType = 'chat';
    if (txType.contains('gift')) {
      earningType = 'gift';
    } else if (desc.contains('video')) {
      earningType = 'video_call';
    } else if (desc.contains('group') || desc.contains('private')) {
      earningType = 'group';
    } else if (desc.contains('chat')) {
      earningType = 'chat';
    }
    return WomenEarningsModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      earningType: earningType,
      chatSessionId: json['session_id']?.toString(),
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// Withdrawal Request Model - Synced with withdrawal_requests table
class WithdrawalRequestModel {
  final String id;
  final String userId;
  final double amount;
  final String? paymentMethod;
  final Map<String, dynamic>? paymentDetails;
  final String status;
  final String? processedBy;
  final DateTime? processedAt;
  final String? rejectionReason;
  final String? notes;
  final DateTime? createdAt;

  const WithdrawalRequestModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.paymentMethod,
    this.paymentDetails,
    this.status = 'pending',
    this.processedBy,
    this.processedAt,
    this.rejectionReason,
    this.notes,
    this.createdAt,
  });

  factory WithdrawalRequestModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      paymentDetails: json['payment_details'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'pending',
      processedBy: json['processed_by'] as String?,
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
      rejectionReason: json['rejection_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// Chat Session Model - Synced with active_chat_sessions table
class ChatSessionModel {
  final String id;
  final String chatId;
  final String manUserId;
  final String womanUserId;
  final double totalEarned;
  final double totalMinutes;
  final double ratePerMinute;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  String? partnerName;
  String? partnerPhoto;

  ChatSessionModel({
    required this.id,
    required this.chatId,
    required this.manUserId,
    required this.womanUserId,
    this.totalEarned = 0,
    this.totalMinutes = 0,
    this.ratePerMinute = 4,
    this.status = 'active',
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.partnerName,
    this.partnerPhoto,
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      manUserId: json['man_user_id'] as String,
      womanUserId: json['woman_user_id'] as String,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toDouble() ?? 0,
      ratePerMinute: (json['rate_per_minute'] as num?)?.toDouble() ?? 4,
      status: json['status'] as String? ?? 'active',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      endReason: json['end_reason'] as String?,
    );
  }
}

/// Video Call Session Model - Synced with video_call_sessions table
class VideoCallSessionModel {
  final String id;
  final String callId;
  final String manUserId;
  final String womanUserId;
  final double totalEarned;
  final double totalMinutes;
  final double ratePerMinute;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final DateTime? createdAt;
  String? partnerName;
  String? partnerPhoto;

  VideoCallSessionModel({
    required this.id,
    required this.callId,
    required this.manUserId,
    required this.womanUserId,
    this.totalEarned = 0,
    this.totalMinutes = 0,
    this.ratePerMinute = 8,
    this.status = 'active',
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.createdAt,
    this.partnerName,
    this.partnerPhoto,
  });

  factory VideoCallSessionModel.fromJson(Map<String, dynamic> json) {
    return VideoCallSessionModel(
      id: json['id'] as String,
      callId: json['call_id'] as String? ?? '',
      manUserId: json['man_user_id'] as String,
      womanUserId: json['woman_user_id'] as String,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toDouble() ?? 0,
      ratePerMinute: (json['rate_per_minute'] as num?)?.toDouble() ?? 8,
      status: json['status'] as String? ?? 'active',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      endReason: json['end_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// Chat Pricing Model - Synced with chat_pricing table
class ChatPricingModel {
  final double ratePerMinute;
  final double videoRatePerMinute;
  final double womenEarningRate;
  final double videoWomenEarningRate;
  final double minWithdrawalBalance;

  const ChatPricingModel({
    this.ratePerMinute = 4,
    this.videoRatePerMinute = 8,
    this.womenEarningRate = 2,
    this.videoWomenEarningRate = 4,
    this.minWithdrawalBalance = 5000,
  });

  factory ChatPricingModel.fromJson(Map<String, dynamic> json) {
    return ChatPricingModel(
      ratePerMinute: (json['rate_per_minute'] as num?)?.toDouble() ?? 4,
      videoRatePerMinute: (json['video_rate_per_minute'] as num?)?.toDouble() ?? 8,
      womenEarningRate: (json['women_earning_rate'] as num?)?.toDouble() ?? 2,
      videoWomenEarningRate: (json['video_women_earning_rate'] as num?)?.toDouble() ?? 4,
      minWithdrawalBalance: (json['min_withdrawal_balance'] as num?)?.toDouble() ?? 5000,
    );
  }
}

/// Gift Transaction Model - Synced with gift_transactions table
class GiftTransactionModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String giftId;
  final double pricePaid;
  final String currency;
  final String status;
  final String? message;
  final DateTime? createdAt;
  String? giftName;
  String? giftEmoji;
  String? partnerName;
  bool isSender;

  GiftTransactionModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.giftId,
    this.pricePaid = 0,
    this.currency = 'INR',
    this.status = 'completed',
    this.message,
    this.createdAt,
    this.giftName,
    this.giftEmoji,
    this.partnerName,
    this.isSender = false,
  });

  factory GiftTransactionModel.fromJson(Map<String, dynamic> json) {
    return GiftTransactionModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      giftId: json['gift_id'] as String,
      pricePaid: (json['price_paid'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'completed',
      message: json['message'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// Unified Transaction - for statement view
class UnifiedTransaction {
  final String id;
  final String type; // 'recharge', 'chat', 'video', 'gift', 'withdrawal', 'other'
  final double amount;
  final String description;
  final DateTime createdAt;
  final String status;
  final bool isCredit;
  final String icon; // 'wallet', 'chat', 'video', 'gift', 'arrow'
  double? balanceAfter;

  UnifiedTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.status,
    required this.isCredit,
    required this.icon,
    this.balanceAfter,
  });
}

/// Transaction Result
class TransactionResult {
  final bool success;
  final String? transactionId;
  final double? previousBalance;
  final double? newBalance;
  final String? error;

  const TransactionResult({
    required this.success,
    this.transactionId,
    this.previousBalance,
    this.newBalance,
    this.error,
  });
}
