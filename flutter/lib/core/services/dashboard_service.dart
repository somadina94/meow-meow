import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dashboard Service Provider
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});

/// Online Woman Model (for men's dashboard)
class OnlineWoman {
  final String userId;
  final String fullName;
  final String? photoUrl;
  final String? country;
  final String? primaryLanguage;
  final int? age;
  final String motherTongue;
  final bool isEarningEligible;
  final bool isAvailable;
  final int currentChatCount;
  final int maxConcurrentChats;
  final DateTime? lastSeen;

  OnlineWoman({
    required this.userId,
    required this.fullName,
    this.photoUrl,
    this.country,
    this.primaryLanguage,
    this.age,
    required this.motherTongue,
    this.isEarningEligible = false,
    this.isAvailable = true,
    this.currentChatCount = 0,
    this.maxConcurrentChats = 3,
    this.lastSeen,
  });

  factory OnlineWoman.fromJson(Map<String, dynamic> json) {
    return OnlineWoman(
      userId: json['user_id'],
      fullName: json['full_name'] ?? 'Anonymous',
      photoUrl: json['photo_url'],
      country: json['country'],
      primaryLanguage: json['primary_language'],
      age: json['age'],
      motherTongue: json['mother_tongue'] ?? json['primary_language'] ?? 'Unknown',
      isEarningEligible: json['is_earning_eligible'] ?? false,
      isAvailable: json['is_available'] ?? true,
      currentChatCount: json['current_chat_count'] ?? 0,
      maxConcurrentChats: json['max_concurrent_chats'] ?? 3,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }

  bool get isBusy => currentChatCount >= maxConcurrentChats;
}

/// Online Man Model (for women's dashboard)
class OnlineMan {
  final String userId;
  final String fullName;
  final String? photoUrl;
  final String? country;
  final String? state;
  final String? preferredLanguage;
  final String? primaryLanguage;
  final int? age;
  final String motherTongue;
  final double walletBalance;
  final bool hasRecharged;
  final DateTime? lastSeen;
  final int activeChatCount;
  final bool isSameLanguage;

  OnlineMan({
    required this.userId,
    required this.fullName,
    this.photoUrl,
    this.country,
    this.state,
    this.preferredLanguage,
    this.primaryLanguage,
    this.age,
    required this.motherTongue,
    this.walletBalance = 0,
    this.hasRecharged = false,
    this.lastSeen,
    this.activeChatCount = 0,
    this.isSameLanguage = false,
  });

  factory OnlineMan.fromJson(Map<String, dynamic> json, {String? womanLanguage}) {
    final manLanguage = json['mother_tongue'] ?? json['primary_language'] ?? json['preferred_language'] ?? 'Unknown';
    final balance = (json['wallet_balance'] as num?)?.toDouble() ?? 0;
    return OnlineMan(
      userId: json['user_id'],
      fullName: json['full_name'] ?? 'Anonymous',
      photoUrl: json['photo_url'],
      country: json['country'],
      state: json['state'],
      preferredLanguage: json['preferred_language'],
      primaryLanguage: json['primary_language'],
      age: json['age'],
      motherTongue: manLanguage,
      walletBalance: balance,
      hasRecharged: balance > 10,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      activeChatCount: json['active_chat_count'] ?? 0,
      isSameLanguage: womanLanguage != null && 
          manLanguage.toLowerCase() == womanLanguage.toLowerCase(),
    );
  }

  bool get isPremium => walletBalance > 10;
}

/// Dashboard Stats
class DashboardStats {
  final String gender;
  final int onlineCount;
  final int matchCount;
  final int unreadNotifications;
  final double walletBalance;
  final double todayEarnings;
  final int activeChats;

  DashboardStats({
    required this.gender,
    this.onlineCount = 0,
    this.matchCount = 0,
    this.unreadNotifications = 0,
    this.walletBalance = 0,
    this.todayEarnings = 0,
    this.activeChats = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      gender: json['gender'] ?? '',
      onlineCount: json['online_count'] ?? 0,
      matchCount: json['match_count'] ?? 0,
      unreadNotifications: json['unread_notifications'] ?? 0,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
      todayEarnings: (json['today_earnings'] as num?)?.toDouble() ?? 0,
      activeChats: json['active_chats'] ?? 0,
    );
  }
}

/// Top Earner Model
class TopEarner {
  final String name;
  final double amount;
  final String? photoUrl;

  TopEarner({required this.name, required this.amount, this.photoUrl});
}

/// Notification Model
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Matched User Model (for men's dashboard matches section)
class MatchedUser {
  final String matchId;
  final String userId;
  final String fullName;
  final String? photoUrl;
  final int? age;
  final String? country;
  final String? primaryLanguage;
  final bool isOnline;
  final String? matchedAt;

  MatchedUser({
    required this.matchId,
    required this.userId,
    required this.fullName,
    this.photoUrl,
    this.age,
    this.country,
    this.primaryLanguage,
    this.isOnline = false,
    this.matchedAt,
  });
}

/// Men's Free Minutes Model
class MenFreeMinutes {
  final int freeMinutesTotal;
  final int freeMinutesUsed;
  final int freeMinutesRemaining;
  final DateTime? nextResetAt;
  final bool hasFreeMinutes;

  MenFreeMinutes({
    this.freeMinutesTotal = 10,
    this.freeMinutesUsed = 0,
    this.nextResetAt,
  }) : freeMinutesRemaining = freeMinutesTotal - freeMinutesUsed,
       hasFreeMinutes = freeMinutesUsed < freeMinutesTotal;

  factory MenFreeMinutes.fromJson(Map<String, dynamic> json) {
    return MenFreeMinutes(
      freeMinutesTotal: json['free_minutes_total'] ?? 10,
      freeMinutesUsed: json['free_minutes_used'] ?? 0,
      nextResetAt: json['next_reset_at'] != null ? DateTime.parse(json['next_reset_at']) : null,
    );
  }
}

/// Dashboard Service
/// 
/// Handles all data fetching for men's and women's dashboards.
/// Synced with React DashboardScreen and WomenDashboardScreen.
class DashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get dashboard stats via RPC
  Future<DashboardStats> getDashboardStats(String userId) async {
    try {
      final response = await _client.rpc('get_dashboard_stats', params: {
        'p_user_id': userId,
      });
      if (response is Map<String, dynamic>) {
        return DashboardStats.fromJson(response);
      }
      return DashboardStats(gender: '');
    } catch (e) {
      return DashboardStats(gender: '');
    }
  }

  /// Fetch online women for men's dashboard.
  /// No `get_online_women_dashboard` RPC exists — falls back to a direct query
  /// joining user_status (online), profiles (gender=female, AI-verified visibility
  /// is enforced by RLS), and women_availability for chat-slot info.
  Future<List<OnlineWoman>> getOnlineWomen() async {
    try {
      final statuses = await _client
          .from('user_status')
          .select('user_id, last_seen')
          .eq('is_online', true)
          .limit(200);

      final ids = (statuses as List)
          .map((s) => s['user_id'] as String)
          .toList();
      if (ids.isEmpty) return [];

      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name, photo_url, country, primary_language, age, gender')
          .inFilter('user_id', ids)
          .eq('gender', 'female');

      final availability = await _client
          .from('women_availability')
          .select('user_id, is_available, current_chat_count, max_concurrent_chats, is_earning_eligible')
          .inFilter('user_id', ids);

      final availMap = {
        for (final a in (availability as List)) a['user_id']: a
      };
      final lastSeenMap = {
        for (final s in statuses) s['user_id']: s['last_seen']
      };

      return (profiles as List).map((p) {
        final a = availMap[p['user_id']] as Map<String, dynamic>?;
        return OnlineWoman.fromJson({
          'user_id': p['user_id'],
          'full_name': p['full_name'],
          'photo_url': p['photo_url'],
          'country': p['country'],
          'primary_language': p['primary_language'],
          'age': p['age'],
          'mother_tongue': p['primary_language'],
          'is_earning_eligible': a?['is_earning_eligible'] ?? false,
          'is_available': a?['is_available'] ?? true,
          'current_chat_count': a?['current_chat_count'] ?? 0,
          'max_concurrent_chats': a?['max_concurrent_chats'] ?? 3,
          'last_seen': lastSeenMap[p['user_id']],
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch online men for women's dashboard via RPC
  Future<List<OnlineMan>> getOnlineMen({String? womanLanguage}) async {
    try {
      final response = await _client.rpc('get_online_men_dashboard');
      if (response is List) {
        return response.map((json) => OnlineMan.fromJson(
          json as Map<String, dynamic>,
          womanLanguage: womanLanguage,
        )).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch matched women for men's dashboard
  Future<List<MatchedUser>> getMatchedWomen(String userId) async {
    try {
      final matches = await _client
          .from('matches')
          .select('id, matched_user_id, user_id, matched_at, status')
          .or('user_id.eq.$userId,matched_user_id.eq.$userId')
          .order('matched_at', ascending: false)
          .limit(50);

      if (matches == null || (matches as List).isEmpty) return [];

      final otherUserIds = (matches as List).map((m) {
        return m['user_id'] == userId ? m['matched_user_id'] : m['user_id'];
      }).toList();

      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name, photo_url, age, country, primary_language, gender')
          .inFilter('user_id', otherUserIds);

      final statuses = await _client
          .from('user_status')
          .select('user_id, is_online')
          .inFilter('user_id', otherUserIds);

      final statusMap = {for (var s in (statuses as List)) s['user_id']: s['is_online'] ?? false};
      final profileMap = {for (var p in (profiles as List)) p['user_id']: p};

      final result = <MatchedUser>[];
      for (final m in matches) {
        final otherId = m['user_id'] == userId ? m['matched_user_id'] : m['user_id'];
        final profile = profileMap[otherId];
        if (profile == null || (profile['gender'] ?? '').toString().toLowerCase() != 'female') continue;
        result.add(MatchedUser(
          matchId: m['id'],
          userId: otherId,
          fullName: profile['full_name'] ?? 'Anonymous',
          photoUrl: profile['photo_url'],
          age: profile['age'],
          country: profile['country'],
          primaryLanguage: profile['primary_language'],
          isOnline: statusMap[otherId] ?? false,
          matchedAt: m['matched_at'],
        ));
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  /// Fetch notifications
  Future<List<AppNotification>> getNotifications(String userId, {int limit = 5}) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get today's top earner via RPC
  Future<TopEarner?> getTopEarnerToday() async {
    try {
      final response = await _client.rpc('get_top_earner_today');
      if (response is List && response.isNotEmpty) {
        final data = response[0];
        return TopEarner(
          name: data['full_name'] ?? 'Top Earner',
          amount: (data['total_amount'] as num?)?.toDouble() ?? 0,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get today's earnings for a woman via canonical RPC
  /// (`get_women_wallet_balance` returns both balance and today_earnings).
  Future<double> getTodayEarnings(String userId) async {
    try {
      final response = await _client.rpc('get_women_wallet_balance', params: {
        'p_user_id': userId,
      });
      if (response is Map) {
        return (response['today_earnings'] as num?)?.toDouble() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get women's wallet balance via canonical RPC.
  /// Single source of truth: get_women_wallet_balance over wallet_transactions.
  Future<double> getWomenWalletBalance(String userId) async {
    try {
      final response = await _client.rpc('get_women_wallet_balance', params: {
        'p_user_id': userId,
      });
      if (response is Map) {
        return (response['available_balance'] as num?)?.toDouble() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get men's wallet balance via canonical RPC (mirrors React loadWalletBalance).
  Future<double> getMenWalletBalance(String userId) async {
    try {
      final response = await _client.rpc('get_men_wallet_balance', params: {
        'p_user_id': userId,
      });
      if (response is Map) {
        return (response['balance'] as num?)?.toDouble() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get men's free chat usage (real table: free_chat_usage with total_seconds_used per pair)
  Future<MenFreeMinutes> getMenFreeMinutes(String userId) async {
    try {
      final response = await _client
          .from('free_chat_usage')
          .select('total_seconds_used')
          .eq('man_user_id', userId);
      final rows = List<Map<String, dynamic>>.from(response);
      final totalSec = rows.fold<num>(0, (s, r) => s + ((r['total_seconds_used'] as num?) ?? 0));
      final totalMinutesUsed = (totalSec / 60).floor();
      return MenFreeMinutes.fromJson({'free_minutes_used': totalMinutesUsed});
    } catch (_) {
      return MenFreeMinutes();
    }
  }

  /// Get active chat count
  Future<int> getActiveChatCount(String userId, {required bool isMale}) async {
    try {
      final column = isMale ? 'man_user_id' : 'woman_user_id';
      final response = await _client
          .from('active_chat_sessions')
          .select('id')
          .eq(column, userId)
          .eq('status', 'active');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Check golden badge status
  Future<({bool hasGoldenBadge, String? expiresAt})> checkGoldenBadge(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('has_golden_badge, golden_badge_expires_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return (hasGoldenBadge: false, expiresAt: null);

      final hasIt = response['has_golden_badge'] == true &&
          response['golden_badge_expires_at'] != null &&
          DateTime.parse(response['golden_badge_expires_at']).isAfter(DateTime.now());

      return (
        hasGoldenBadge: hasIt,
        expiresAt: response['golden_badge_expires_at'],
      );
    } catch (e) {
      return (hasGoldenBadge: false, expiresAt: null);
    }
  }

  /// Purchase golden badge.
  /// No `purchase_golden_badge` RPC exists yet — delegate to the
  /// `golden-badge` edge function (matches React parity expectation).
  /// Returns success=false if the function isn't deployed.
  Future<Map<String, dynamic>> purchaseGoldenBadge(String userId) async {
    try {
      final response = await _client.functions.invoke(
        'golden-badge',
        body: {'action': 'purchase', 'user_id': userId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'error': 'Unexpected response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update user online status
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client.from('user_status').upsert({
        'user_id': userId,
        'is_online': isOnline,
        'last_seen': now,
        'updated_at': now,
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  /// Start chat session (men only)
  /// Routes through chat-manager edge function for security
  /// (wallet checks, block list, parallel limits enforced server-side)
  /// Synced with React DashboardScreen.handleStartChatWithWoman
  Future<({bool success, String? chatId, String? error})> startChatSession({
    required String manUserId,
    required String womanUserId,
    bool goldenBadgeOverride = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'chat-manager',
        body: {
          'action': 'start_chat',
          'man_user_id': manUserId,
          'woman_user_id': womanUserId,
          'golden_badge_override': goldenBadgeOverride,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return (success: false, chatId: null, error: 'No response from server');
      }

      if (data['error'] != null) {
        return (success: false, chatId: null, error: data['error'] as String);
      }

      final chatId = data['chat_id'] as String?;
      if (chatId != null) {
        // Send initial greeting message (same as React frontend)
        await _client.from('chat_messages').insert({
          'chat_id': chatId,
          'sender_id': manUserId,
          'receiver_id': womanUserId,
          'message': '👋 Hi!',
        });
      }

      return (success: true, chatId: chatId, error: null);
    } catch (e) {
      return (success: false, chatId: null, error: e.toString());
    }
  }

  /// Get chat pricing from admin settings
  Future<({double ratePerMinute, double videoRatePerMinute, double womenEarningRate})> getChatPricing() async {
    try {
      final response = await _client
          .from('chat_pricing')
          .select()
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        return (
          ratePerMinute: (response['rate_per_minute'] as num?)?.toDouble() ?? 4,
          videoRatePerMinute: (response['video_rate_per_minute'] as num?)?.toDouble() ?? 8,
          womenEarningRate: (response['women_earning_rate'] as num?)?.toDouble() ?? 2,
        );
      }
      return (ratePerMinute: 4, videoRatePerMinute: 8, womenEarningRate: 2);
    } catch (e) {
      return (ratePerMinute: 4, videoRatePerMinute: 8, womenEarningRate: 2);
    }
  }

  /// Process recharge via canonical SoT RPC `ledger_recharge`
  /// (writes a single wallet_transactions row with idempotency_key).
  Future<({bool success, double? newBalance, String? error})> processRecharge({
    required String userId,
    required double amount,
    required String gatewayName,
  }) async {
    try {
      final referenceId =
          '${gatewayName.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';
      final response = await _client.rpc('ledger_recharge', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_reference_id': referenceId,
        'p_gateway': gatewayName,
      });

      if (response is Map) {
        return (
          success: response['success'] == true,
          newBalance: (response['new_balance'] as num?)?.toDouble(),
          error: response['error'] as String?,
        );
      }
      return (success: false, newBalance: null, error: 'Unexpected response');
    } catch (e) {
      return (success: false, newBalance: null, error: e.toString());
    }
  }

  /// Subscribe to dashboard realtime updates
  RealtimeChannel subscribeToDashboardUpdates({
    required String userId,
    required bool isMale,
    required void Function() onUserStatusChange,
    required void Function() onChatSessionChange,
    required void Function() onWalletChange,
    void Function()? onEarningsChange,
    void Function()? onAvailabilityChange,
    void Function()? onNotificationChange,
  }) {
    var channel = _client.channel('dashboard-updates-$userId');

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_status',
      callback: (_) => onUserStatusChange(),
    );

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'active_chat_sessions',
      callback: (_) => onChatSessionChange(),
    );

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'wallets',
      callback: (_) => onWalletChange(),
    );

    // Wallet balance changes are driven by wallet_transactions inserts
    // (canonical SoT). Mirror the React subscription which listens to
    // wallet_transactions filtered by user_id.

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'wallet_transactions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) {
        onWalletChange();
        if (!isMale && onEarningsChange != null) onEarningsChange();
      },
    );

    if (isMale && onAvailabilityChange != null) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'women_availability',
        callback: (_) => onAvailabilityChange(),
      );
    }

    if (onNotificationChange != null) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => onNotificationChange(),
      );
    }

    return channel.subscribe();
  }
}
