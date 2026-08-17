/// Optimized Supabase service with caching and batching
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';
import '../utils/performance_utils.dart';

/// Provider for optimized Supabase service
final optimizedSupabaseProvider = Provider<OptimizedSupabaseService>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return OptimizedSupabaseService(cacheService);
});

/// Optimized Supabase service with caching
class OptimizedSupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final CacheService _cache;
  
  // Request debouncer for rapid requests
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 50));

  OptimizedSupabaseService(this._cache);

  /// Get profile with caching
  Future<Map<String, dynamic>?> getProfile(String userId, {bool forceRefresh = false}) async {
    return _cache.getOrFetch(
      CacheKeys.profile(userId),
      () async {
        final response = await _client
            .from('profiles')
            .select('id, user_id, full_name, age, gender, country, state, bio, photo_url, interests, occupation, is_verified, account_status, approval_status')
            .eq('user_id', userId)
            .single();
        return response;
      },
      ttl: CacheTTL.long,
      forceRefresh: forceRefresh,
    );
  }

  /// Get wallet balance with short cache
  Future<Map<String, dynamic>?> getWalletBalance(String userId, {bool forceRefresh = false}) async {
    return _cache.getOrFetch(
      CacheKeys.walletBalance(userId),
      () async {
        final response = await _client
            .from('wallets')
            .select('balance, currency')
            .eq('user_id', userId)
            .single();
        return response;
      },
      ttl: CacheTTL.veryShort, // Balance changes frequently
      forceRefresh: forceRefresh,
    );
  }

  /// Get transactions with pagination
  Future<List<Map<String, dynamic>>> getTransactions(
    String userId, {
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final result = await _cache.getOrFetch(
      '${CacheKeys.transactions(userId)}_$limit',
      () async {
        final response = await _client
            .from('wallet_transactions')
            .select('id, type, amount, description, status, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);
        return response as List<dynamic>;
      },
      ttl: CacheTTL.short,
      forceRefresh: forceRefresh,
    );
    return (result).cast<Map<String, dynamic>>();
  }

  /// Get earnings with aggregation
  Future<Map<String, dynamic>> getEarnings(String userId, {bool forceRefresh = false}) async {
    return _cache.getOrFetch(
      CacheKeys.earnings(userId),
      () async {
        // Earnings come from canonical wallet_transactions credits with
        // an earning transaction_type (legacy `women_earnings` table removed).
        final response = await _client
            .from('wallet_transactions')
            .select('id, amount, description, transaction_type, created_at')
            .eq('user_id', userId)
            .eq('type', 'credit')
            .inFilter('transaction_type', ['session_earning', 'gift_earning'])
            .order('created_at', ascending: false)
            .limit(50);
        
        final earnings = response as List<dynamic>;
        final total = earnings.fold<double>(0, (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble());
        
        return {
          'total': total,
          'earnings': earnings,
        };
      },
      ttl: CacheTTL.short,
      forceRefresh: forceRefresh,
    );
  }

  /// Get online users with caching
  Future<List<Map<String, dynamic>>> getOnlineUsers({
    String? gender,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final result = await _cache.getOrFetch(
      CacheKeys.onlineUsers(gender),
      () async {
        var query = _client
            .from('user_status')
            .select('''
              user_id,
              is_online,
              last_seen,
              profiles!inner (
                full_name,
                age,
                gender,
                country,
                photo_url,
                is_verified
              )
            ''')
            .eq('is_online', true)
            .order('last_seen', ascending: false)
            .limit(limit);
        
        // Note: Can't filter joined table directly, filter in memory
        final response = await query;
        
        if (gender != null) {
          return (response as List<dynamic>).where((item) {
            final profiles = item['profiles'];
            return profiles != null && profiles['gender'] == gender;
          }).toList();
        }
        
        return response as List<dynamic>;
      },
      ttl: CacheTTL.veryShort,
      forceRefresh: forceRefresh,
    );
    return (result).cast<Map<String, dynamic>>();
  }

  /// Get chat messages
  Future<List<Map<String, dynamic>>> getChatMessages(
    String chatId, {
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final result = await _cache.getOrFetch(
      CacheKeys.chatMessages(chatId),
      () async {
        final response = await _client
            .from('chat_messages')
            .select('id, message, sender_id, receiver_id, created_at, is_read, translated_message, is_translated')
            .eq('chat_id', chatId)
            .order('created_at', ascending: false)
            .limit(limit);
        return (response as List<dynamic>).reversed.toList();
      },
      ttl: const Duration(seconds: 0), // Don't cache chat messages
      forceRefresh: true, // Always fetch fresh
    );
    return (result).cast<Map<String, dynamic>>();
  }

  /// Get active gifts with long cache
  Future<List<Map<String, dynamic>>> getGifts({bool forceRefresh = false}) async {
    final result = await _cache.getOrFetch(
      CacheKeys.gifts,
      () async {
        final response = await _client
            .from('gifts')
            .select('id, name, emoji, price, currency, category, description')
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        return response as List<dynamic>;
      },
      ttl: CacheTTL.veryLong, // Gifts rarely change
      forceRefresh: forceRefresh,
    );
    return (result).cast<Map<String, dynamic>>();
  }

  /// Get chat pricing with long cache
  Future<Map<String, dynamic>?> getChatPricing({bool forceRefresh = false}) async {
    return _cache.getOrFetch(
      CacheKeys.chatPricing,
      () async {
        final response = await _client
            .from('chat_pricing')
            .select('rate_per_minute, video_rate_per_minute, women_earning_rate, video_women_earning_rate, currency')
            .eq('is_active', true)
            .single();
        return response;
      },
      ttl: CacheTTL.hour, // Pricing rarely changes
      forceRefresh: forceRefresh,
    );
  }

  /// Invalidate specific cache
  void invalidateProfile(String userId) {
    _cache.remove(CacheKeys.profile(userId));
  }

  void invalidateWallet(String userId) {
    _cache.remove(CacheKeys.walletBalance(userId));
    _cache.remove(CacheKeys.transactions(userId));
  }

  void invalidateEarnings(String userId) {
    _cache.remove(CacheKeys.earnings(userId));
  }

  void invalidateChats(String chatId) {
    _cache.remove(CacheKeys.chatMessages(chatId));
  }

  /// Clear all cache
  void clearCache() {
    _cache.clear();
  }

  /// Prefetch common data on login
  Future<void> prefetchUserData(String userId) async {
    await Future.wait([
      getProfile(userId),
      getWalletBalance(userId),
      getGifts(),
      getChatPricing(),
    ]);
  }

  void dispose() {
    _debouncer.dispose();
  }
}
