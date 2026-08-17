/// Gift Model - Synced with gifts table
class GiftModel {
  final String id;
  final String name;
  final String emoji;
  final double price;
  final String currency;
  final String category;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GiftModel({
    required this.id,
    required this.name,
    this.emoji = '🎁',
    this.price = 0,
    this.currency = 'INR',
    this.category = 'general',
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🎁',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
  final String? message;
  final String status;
  final DateTime? createdAt;

  const GiftTransactionModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.giftId,
    required this.pricePaid,
    this.currency = 'INR',
    this.message,
    this.status = 'completed',
    this.createdAt,
  });

  factory GiftTransactionModel.fromJson(Map<String, dynamic> json) {
    return GiftTransactionModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      giftId: json['gift_id'] as String,
      pricePaid: (json['price_paid'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// Gift with Sender Info (for display)
class ReceivedGift {
  final GiftModel gift;
  final String senderName;
  final String? senderPhotoUrl;
  final String? message;
  final DateTime? receivedAt;

  const ReceivedGift({
    required this.gift,
    required this.senderName,
    this.senderPhotoUrl,
    this.message,
    this.receivedAt,
  });
}
