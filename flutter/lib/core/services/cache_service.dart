/// Caching service for Flutter app
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/performance_utils.dart';

/// Provider for cache service
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

/// Cache entry with TTL
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.ttl,
  }) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

/// In-memory and persistent cache service
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final LRUCache<String, CacheEntry<dynamic>> _memoryCache = LRUCache(maxSize: 200);
  SharedPreferences? _prefs;

  /// Initialize persistent storage
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get from memory cache
  T? get<T>(String key) {
    final entry = _memoryCache.get(key);
    if (entry != null && !entry.isExpired) {
      return entry.data as T?;
    }
    if (entry?.isExpired ?? false) {
      _memoryCache.remove(key);
    }
    return null;
  }

  /// Set in memory cache
  void set<T>(String key, T data, {Duration ttl = const Duration(minutes: 5)}) {
    _memoryCache.set(key, CacheEntry(data: data, ttl: ttl));
  }

  /// Remove from cache
  void remove(String key) {
    _memoryCache.remove(key);
    _prefs?.remove(key);
  }

  /// Clear all cache
  void clear() {
    _memoryCache.clear();
  }

  /// Get with fetch fallback
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetch, {
    Duration ttl = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = get<T>(key);
      if (cached != null) return cached;
    }

    final data = await fetch();
    set(key, data, ttl: ttl);
    return data;
  }

  /// Persist string data
  Future<void> persistString(String key, String value) async {
    await init();
    await _prefs?.setString(key, value);
  }

  /// Get persisted string
  Future<String?> getPersistedString(String key) async {
    await init();
    return _prefs?.getString(key);
  }

  /// Persist JSON data
  Future<void> persistJson(String key, Map<String, dynamic> data) async {
    await init();
    await _prefs?.setString(key, jsonEncode(data));
  }

  /// Get persisted JSON
  Future<Map<String, dynamic>?> getPersistedJson(String key) async {
    await init();
    final value = _prefs?.getString(key);
    if (value != null) {
      return jsonDecode(value) as Map<String, dynamic>;
    }
    return null;
  }

  /// Invalidate cache entries matching pattern
  void invalidate(String pattern) {
    // Note: LRUCache doesn't support pattern matching
    // For now, clear all - in production, implement proper pattern matching
    if (pattern == '*') {
      clear();
    }
  }
}

/// Cache keys constants
class CacheKeys {
  static String profile(String userId) => 'profile_$userId';
  static String wallet(String userId) => 'wallet_$userId';
  static String walletBalance(String userId) => 'wallet_balance_$userId';
  static String transactions(String userId) => 'transactions_$userId';
  static String earnings(String userId) => 'earnings_$userId';
  static String chatMessages(String chatId) => 'chat_messages_$chatId';
  static String activeChats(String userId) => 'active_chats_$userId';
  static String onlineUsers(String? gender) => 'online_users_${gender ?? "all"}';
  static String matches(String userId) => 'matches_$userId';
  static const String gifts = 'gifts';
  static const String chatPricing = 'chat_pricing';
  static String femaleProfile(String userId) => 'female_profile_$userId';
  static String userLanguages(String userId) => 'user_languages_$userId';
  static String userPhotos(String userId) => 'user_photos_$userId';
}

/// Cache TTL constants
class CacheTTL {
  static const Duration veryShort = Duration(seconds: 30);
  static const Duration short = Duration(minutes: 1);
  static const Duration medium = Duration(minutes: 5);
  static const Duration long = Duration(minutes: 15);
  static const Duration veryLong = Duration(minutes: 30);
  static const Duration hour = Duration(hours: 1);
}
