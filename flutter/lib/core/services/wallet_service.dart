import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/wallet_model.dart';
import '../../shared/models/gift_model.dart';

/// Wallet Service Provider
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

/// Wallet Service
///
/// Handles all wallet, transaction, session, and pricing operations.
/// Synced with React TransactionHistoryScreen data fetching.
class WalletService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get user's wallet
  Future<WalletModel?> getWallet(String userId) async {
    try {
      final response = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return WalletModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get men's wallet balance via server-side RPC
  Future<double> getMenWalletBalance(String userId) async {
    try {
      final response = await _client.rpc('get_men_wallet_balance', params: {
        'p_user_id': userId,
      });
      final data = response as Map<String, dynamic>?;
      return (data?['balance'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get women's wallet balance via server-side RPC
  Future<double> getWomenWalletBalance(String userId) async {
    try {
      final response = await _client.rpc('get_women_wallet_balance', params: {
        'p_user_id': userId,
      });
      final data = response as Map<String, dynamic>?;
      return (data?['available_balance'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get wallet transactions (all, no limit for statement)
  Future<List<WalletTransactionModel>> getTransactions(String userId, {int limit = 50}) async {
    try {
      // First get wallet id
      final wallet = await _client
          .from('wallets')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) return [];

      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', wallet['id'])
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => WalletTransactionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get ALL wallet transactions (no limit, for statement computation)
  Future<List<WalletTransactionModel>> getAllTransactions(String userId) async {
    try {
      final wallet = await _client
          .from('wallets')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) return [];

      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', wallet['id'])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WalletTransactionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get chat pricing config
  Future<ChatPricingModel> getChatPricing() async {
    try {
      final response = await _client
          .from('chat_pricing')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return const ChatPricingModel();
      return ChatPricingModel.fromJson(response);
    } catch (e) {
      return const ChatPricingModel();
    }
  }

  /// Get chat sessions for user
  Future<List<ChatSessionModel>> getChatSessions(String userId, String gender) async {
    try {
      final field = gender == 'male' ? 'man_user_id' : 'woman_user_id';
      final partnerField = gender == 'male' ? 'woman_user_id' : 'man_user_id';

      final response = await _client
          .from('active_chat_sessions')
          .select()
          .eq(field, userId)
          .order('started_at', ascending: false)
          .limit(100);

      final sessions = (response as List)
          .map((json) => ChatSessionModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Enrich with partner names
      if (sessions.isNotEmpty) {
        final partnerIds = sessions.map((s) => gender == 'male' ? s.womanUserId : s.manUserId).toSet().toList();
        final profiles = await _client
            .from('profiles')
            .select('user_id, full_name, photo_url')
            .inFilter('user_id', partnerIds);

        final profileMap = <String, Map<String, dynamic>>{};
        for (final p in profiles) {
          profileMap[p['user_id'] as String] = p;
        }

        for (final s in sessions) {
          final partnerId = gender == 'male' ? s.womanUserId : s.manUserId;
          s.partnerName = profileMap[partnerId]?['full_name'] as String? ?? 'Anonymous';
          s.partnerPhoto = profileMap[partnerId]?['photo_url'] as String?;
        }
      }

      return sessions;
    } catch (e) {
      return [];
    }
  }

  /// Get video call sessions for user
  Future<List<VideoCallSessionModel>> getVideoCallSessions(String userId, String gender) async {
    try {
      final field = gender == 'male' ? 'man_user_id' : 'woman_user_id';

      final response = await _client
          .from('video_call_sessions')
          .select()
          .eq(field, userId)
          .order('created_at', ascending: false)
          .limit(100);

      final sessions = (response as List)
          .map((json) => VideoCallSessionModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Enrich with partner names
      if (sessions.isNotEmpty) {
        final partnerIds = sessions.map((s) => gender == 'male' ? s.womanUserId : s.manUserId).toSet().toList();
        final profiles = await _client
            .from('profiles')
            .select('user_id, full_name, photo_url')
            .inFilter('user_id', partnerIds);

        final profileMap = <String, Map<String, dynamic>>{};
        for (final p in profiles) {
          profileMap[p['user_id'] as String] = p;
        }

        for (final s in sessions) {
          final partnerId = gender == 'male' ? s.womanUserId : s.manUserId;
          s.partnerName = profileMap[partnerId]?['full_name'] as String? ?? 'Anonymous';
          s.partnerPhoto = profileMap[partnerId]?['photo_url'] as String?;
        }
      }

      return sessions;
    } catch (e) {
      return [];
    }
  }

  /// Get women's earnings — derived from canonical wallet_transactions
  /// (credit rows where transaction_type marks an earning).
  Future<List<WomenEarningsModel>> getWomenEarnings(String userId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'credit')
          .inFilter('transaction_type', ['session_earning', 'gift_earning'])
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) =>
              WomenEarningsModel.fromWalletTransaction(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get ALL women's earnings (no limit) — derived from wallet_transactions.
  Future<List<WomenEarningsModel>> getAllWomenEarnings(String userId) async {
    try {
      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'credit')
          .inFilter('transaction_type', ['session_earning', 'gift_earning'])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) =>
              WomenEarningsModel.fromWalletTransaction(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get gift transactions
  Future<List<GiftTransactionModel>> getGiftTransactions(String userId) async {
    try {
      final response = await _client
          .from('gift_transactions')
          .select()
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(100);

      final gifts = (response as List)
          .map((json) => GiftTransactionModel.fromJson(json as Map<String, dynamic>))
          .toList();

      if (gifts.isNotEmpty) {
        // Get gift details
        final giftIds = gifts.map((g) => g.giftId).toSet().toList();
        final giftDetails = await _client
            .from('gifts')
            .select('id, name, emoji')
            .inFilter('id', giftIds);

        final giftMap = <String, Map<String, dynamic>>{};
        for (final g in giftDetails) {
          giftMap[g['id'] as String] = g;
        }

        // Get partner profiles
        final partnerIds = gifts
            .map((g) => g.senderId == userId ? g.receiverId : g.senderId)
            .toSet()
            .toList();
        final profiles = await _client
            .from('profiles')
            .select('user_id, full_name')
            .inFilter('user_id', partnerIds);

        final profileMap = <String, String>{};
        for (final p in profiles) {
          profileMap[p['user_id'] as String] = p['full_name'] as String? ?? 'Anonymous';
        }

        for (final g in gifts) {
          g.giftName = giftMap[g.giftId]?['name'] as String? ?? 'Gift';
          g.giftEmoji = giftMap[g.giftId]?['emoji'] as String? ?? '🎁';
          g.isSender = g.senderId == userId;
          final partnerId = g.isSender ? g.receiverId : g.senderId;
          g.partnerName = profileMap[partnerId] ?? 'Anonymous';
        }
      }

      return gifts;
    } catch (e) {
      return [];
    }
  }

  /// Get withdrawal requests
  Future<List<WithdrawalRequestModel>> getWithdrawalRequests(String userId) async {
    try {
      final response = await _client
          .from('withdrawal_requests')
          .select('id, amount, status, payment_method, created_at, processed_at, rejection_reason')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WithdrawalRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// `process_wallet_transaction` does NOT exist as a public RPC — direct
  /// wallet writes are blocked by the wallet-balance-protection trigger.
  /// Use the canonical type-specific paths instead:
  ///   • Recharge   → `ledger_recharge`         (see DashboardService.processRecharge)
  ///   • Withdrawal → `ledger_withdrawal`        (see requestWithdrawal below)
  ///   • Gift / tip → `bill_gift_or_tip`         (see sendGift below)
  ///   • Sessions   → server-managed heartbeats (chat / video / group)
  /// Kept for backwards compatibility — always returns failure.
  Future<TransactionResult> processTransaction({
    required String userId,
    required double amount,
    required String type,
    String? description,
  }) async {
    return TransactionResult(
      success: false,
      error: 'Use canonical RPCs (ledger_recharge / ledger_withdrawal / '
          'bill_gift_or_tip). Direct wallet writes are not permitted.',
    );
  }

  /// Process transfer between users
  Future<TransactionResult> processTransfer({
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? description,
  }) async {
    try {
      final response = await _client.rpc('process_atomic_transfer', params: {
        'p_from_user_id': fromUserId,
        'p_to_user_id': toUserId,
        'p_amount': amount,
        'p_description': description,
      });

      final data = response as Map<String, dynamic>;
      return TransactionResult(
        success: data['success'] ?? false,
        transactionId: data['from_transaction_id'],
        previousBalance: (data['from_previous_balance'] as num?)?.toDouble(),
        newBalance: (data['from_new_balance'] as num?)?.toDouble(),
        error: data['error'],
      );
    } catch (e) {
      return TransactionResult(success: false, error: e.toString());
    }
  }

  /// Get available gifts
  Future<List<GiftModel>> getGifts() async {
    try {
      final response = await _client
          .from('gifts')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((json) => GiftModel(
                id: json['id'],
                name: json['name'],
                emoji: json['emoji'] ?? '🎁',
                price: (json['price'] as num?)?.toDouble() ?? 0,
                currency: json['currency'] ?? 'INR',
                category: json['category'] ?? 'general',
                description: json['description'],
                isActive: json['is_active'] ?? true,
                sortOrder: json['sort_order'] ?? 0,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Send gift via canonical SoT RPC `bill_gift_or_tip`.
  /// (Mirrors React `sendGift` in services/billing.service.ts.)
  /// Looks up gift price from the `gifts` table since the canonical RPC
  /// expects an amount, not a gift_id.
  Future<TransactionResult> sendGift({
    required String senderId,
    required String receiverId,
    required String giftId,
    String? message,
  }) async {
    try {
      final gift = await _client
          .from('gifts')
          .select('price, name, emoji')
          .eq('id', giftId)
          .maybeSingle();
      if (gift == null) {
        return TransactionResult(success: false, error: 'Gift not found');
      }
      final price = (gift['price'] as num?)?.toDouble() ?? 0;
      final desc = message ??
          'Gift: ${gift['emoji'] ?? ''} ${gift['name'] ?? ''}'.trim();

      final response = await _client.rpc('bill_gift_or_tip', params: {
        'p_man_id': senderId,
        'p_woman_id': receiverId,
        'p_amount': price,
        'p_type': 'gift',
        'p_description': desc,
        'p_reference_id': giftId,
      });

      final data = response is Map<String, dynamic>
          ? response
          : <String, dynamic>{};
      return TransactionResult(
        success: data['success'] ?? false,
        transactionId: data['transaction_id'] ?? data['gift_transaction_id'],
        previousBalance: (data['previous_balance'] as num?)?.toDouble(),
        newBalance: (data['new_balance'] as num?)?.toDouble(),
        error: data['error'],
      );
    } catch (e) {
      return TransactionResult(success: false, error: e.toString());
    }
  }

  /// Request withdrawal via canonical SoT RPC `ledger_withdrawal`.
  /// Mirrors React billing.service.ts withdrawal flow.
  Future<TransactionResult> requestWithdrawal({
    required String userId,
    required double amount,
    String? paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final response = await _client.rpc('ledger_withdrawal', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_payment_method': paymentMethod ?? 'upi',
        'p_payment_details': paymentDetails,
      });

      final data = response is Map<String, dynamic>
          ? response
          : <String, dynamic>{};
      return TransactionResult(
        success: data['success'] ?? false,
        transactionId: data['withdrawal_id'] ?? data['transaction_id'],
        previousBalance: (data['previous_balance'] as num?)?.toDouble(),
        newBalance: (data['new_balance'] as num?)?.toDouble(),
        error: data['error'],
      );
    } catch (e) {
      return TransactionResult(success: false, error: e.toString());
    }
  }
  RealtimeChannel subscribeToWallet(
    String userId,
    void Function(WalletModel wallet) onUpdate,
  ) {
    return _client.channel('wallet:$userId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'wallets',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final json = payload.newRecord;
        onUpdate(WalletModel(
          id: json['id'],
          userId: json['user_id'],
          balance: (json['balance'] as num).toDouble(),
          currency: json['currency'] ?? 'INR',
        ));
      },
    ).subscribe();
  }
}
