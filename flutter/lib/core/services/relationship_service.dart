import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for RelationshipService
final relationshipServiceProvider = Provider<RelationshipService>((ref) {
  return RelationshipService();
});

/// Blocked users state provider
final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((ref) async {
  final service = ref.watch(relationshipServiceProvider);
  return service.getBlockedUsers();
});

/// Friends state provider
final friendsProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  final service = ref.watch(relationshipServiceProvider);
  return service.getFriends();
});

/// Pending friend requests provider
final pendingRequestsProvider = FutureProvider.autoDispose<List<FriendRequest>>((ref) async {
  final service = ref.watch(relationshipServiceProvider);
  return service.getPendingRequests();
});

/// Model for blocked user
class BlockedUser {
  final String id;
  final String blockedUserId;
  final String? blockedName;
  final String? blockedPhoto;
  final DateTime blockedAt;

  BlockedUser({
    required this.id,
    required this.blockedUserId,
    this.blockedName,
    this.blockedPhoto,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json, Map<String, dynamic>? profile) {
    return BlockedUser(
      id: json['id'] as String,
      blockedUserId: json['blocked_user_id'] as String,
      blockedName: profile?['full_name'] as String?,
      blockedPhoto: profile?['photo_url'] as String?,
      blockedAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Model for friend
class Friend {
  final String id;
  final String friendId;
  final String? friendName;
  final String? friendPhoto;
  final String status;
  final bool isOnline;
  final DateTime addedAt;

  Friend({
    required this.id,
    required this.friendId,
    this.friendName,
    this.friendPhoto,
    required this.status,
    required this.isOnline,
    required this.addedAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json, String currentUserId, Map<String, dynamic>? profile, bool isOnline) {
    final friendId = json['user_id'] == currentUserId ? json['friend_id'] : json['user_id'];
    return Friend(
      id: json['id'] as String,
      friendId: friendId as String,
      friendName: profile?['full_name'] as String?,
      friendPhoto: profile?['photo_url'] as String?,
      status: json['status'] as String,
      isOnline: isOnline,
      addedAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Model for friend request
class FriendRequest {
  final String id;
  final String fromUserId;
  final String? fromUserName;
  final String? fromUserPhoto;
  final DateTime requestedAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    this.fromUserName,
    this.fromUserPhoto,
    required this.requestedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json, Map<String, dynamic>? profile) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['user_id'] as String,
      fromUserName: profile?['full_name'] as String?,
      fromUserPhoto: profile?['photo_url'] as String?,
      requestedAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service for managing user relationships (blocks and friends)
class RelationshipService {
  final _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ============ BLOCK FUNCTIONS ============

  /// Get list of blocked users
  Future<List<BlockedUser>> getBlockedUsers() async {
    if (_currentUserId == null) return [];

    final response = await _supabase
        .from('user_blocks')
        .select('id, blocked_user_id, created_at')
        .eq('blocked_by', _currentUserId!);

    if (response.isEmpty) return [];

    final blockedIds = (response as List).map((b) => b['blocked_user_id'] as String).toList();

    final profiles = await _supabase
        .from('profiles')
        .select('user_id, full_name, photo_url')
        .inFilter('user_id', blockedIds);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final p in profiles) {
      profileMap[p['user_id'] as String] = p;
    }

    return response.map((block) => BlockedUser.fromJson(
      block,
      profileMap[block['blocked_user_id']],
    )).toList();
  }

  /// Block a user
  Future<bool> blockUser(String targetUserId, {String? reason}) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase.from('user_blocks').insert({
        'blocked_by': _currentUserId,
        'blocked_user_id': targetUserId,
        'reason': reason,
      });
      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String targetUserId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocked_by', _currentUserId!)
          .eq('blocked_user_id', targetUserId);
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String targetUserId) async {
    if (_currentUserId == null) return false;

    final response = await _supabase
        .from('user_blocks')
        .select('id')
        .eq('blocked_by', _currentUserId!)
        .eq('blocked_user_id', targetUserId)
        .maybeSingle();

    return response != null;
  }

  // ============ FRIEND FUNCTIONS ============

  /// Get list of friends
  Future<List<Friend>> getFriends() async {
    if (_currentUserId == null) return [];

    final response = await _supabase
        .from('user_friends')
        .select('id, user_id, friend_id, status, created_at')
        .or('user_id.eq.$_currentUserId,friend_id.eq.$_currentUserId')
        .eq('status', 'accepted');

    if (response.isEmpty) return [];

    final friendIds = (response as List).map((f) {
      return f['user_id'] == _currentUserId ? f['friend_id'] : f['user_id'];
    }).toList();

    final profiles = await _supabase
        .from('profiles')
        .select('user_id, full_name, photo_url')
        .inFilter('user_id', friendIds);

    final onlineStatus = await _supabase
        .from('user_status')
        .select('user_id, is_online')
        .inFilter('user_id', friendIds);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final p in profiles) {
      profileMap[p['user_id'] as String] = p;
    }

    final onlineMap = <String, bool>{};
    for (final s in onlineStatus) {
      onlineMap[s['user_id'] as String] = s['is_online'] as bool;
    }

    return response.map((friend) {
      final friendId = friend['user_id'] == _currentUserId ? friend['friend_id'] : friend['user_id'];
      return Friend.fromJson(
        friend,
        _currentUserId!,
        profileMap[friendId],
        onlineMap[friendId] ?? false,
      );
    }).toList();
  }

  /// Get pending friend requests (received)
  Future<List<FriendRequest>> getPendingRequests() async {
    if (_currentUserId == null) return [];

    final response = await _supabase
        .from('user_friends')
        .select('id, user_id, created_at')
        .eq('friend_id', _currentUserId!)
        .eq('status', 'pending');

    if (response.isEmpty) return [];

    final requesterIds = (response as List).map((r) => r['user_id'] as String).toList();

    final profiles = await _supabase
        .from('profiles')
        .select('user_id, full_name, photo_url')
        .inFilter('user_id', requesterIds);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final p in profiles) {
      profileMap[p['user_id'] as String] = p;
    }

    return response.map((req) => FriendRequest.fromJson(
      req,
      profileMap[req['user_id']],
    )).toList();
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String targetUserId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase.from('user_friends').insert({
        'user_id': _currentUserId,
        'friend_id': targetUserId,
        'status': 'pending',
        'created_by': _currentUserId,
      });
      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String fromUserId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase
          .from('user_friends')
          .update({'status': 'accepted'})
          .eq('user_id', fromUserId)
          .eq('friend_id', _currentUserId!);
      return true;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String fromUserId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase
          .from('user_friends')
          .delete()
          .eq('user_id', fromUserId)
          .eq('friend_id', _currentUserId!);
      return true;
    } catch (e) {
      print('Error rejecting friend request: $e');
      return false;
    }
  }

  /// Cancel sent friend request
  Future<bool> cancelFriendRequest(String targetUserId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase
          .from('user_friends')
          .delete()
          .eq('user_id', _currentUserId!)
          .eq('friend_id', targetUserId);
      return true;
    } catch (e) {
      print('Error canceling friend request: $e');
      return false;
    }
  }

  /// Unfriend a user
  Future<bool> unfriend(String targetUserId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase
          .from('user_friends')
          .delete()
          .or('and(user_id.eq.$_currentUserId,friend_id.eq.$targetUserId),and(user_id.eq.$targetUserId,friend_id.eq.$_currentUserId)');
      return true;
    } catch (e) {
      print('Error unfriending user: $e');
      return false;
    }
  }

  /// Check friendship status
  Future<FriendshipStatus> getFriendshipStatus(String targetUserId) async {
    if (_currentUserId == null) {
      return FriendshipStatus(isFriend: false, isPending: false, isRequested: false);
    }

    final response = await _supabase
        .from('user_friends')
        .select('id, status, user_id')
        .or('and(user_id.eq.$_currentUserId,friend_id.eq.$targetUserId),and(user_id.eq.$targetUserId,friend_id.eq.$_currentUserId)')
        .maybeSingle();

    if (response == null) {
      return FriendshipStatus(isFriend: false, isPending: false, isRequested: false);
    }

    return FriendshipStatus(
      isFriend: response['status'] == 'accepted',
      isPending: response['status'] == 'pending' && response['user_id'] == _currentUserId,
      isRequested: response['status'] == 'pending' && response['user_id'] == targetUserId,
    );
  }

  /// Subscribe to relationship changes
  Stream<void> subscribeToChanges() {
    return _supabase
        .from('user_friends')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }
}

/// Friendship status model
class FriendshipStatus {
  final bool isFriend;
  final bool isPending;
  final bool isRequested;

  FriendshipStatus({
    required this.isFriend,
    required this.isPending,
    required this.isRequested,
  });
}
