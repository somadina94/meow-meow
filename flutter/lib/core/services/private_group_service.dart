import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/private_group_model.dart';

/// Private Group Service Provider
final privateGroupServiceProvider = Provider<PrivateGroupService>((ref) {
  return PrivateGroupService();
});

/// Private Group Service
///
/// Handles private group video call rooms.
/// Synced with React PrivateGroupsSection/AvailableGroupsSection and usePrivateGroupCall hook.
/// DB columns: name, min_gift_amount, access_type, is_active, is_live, owner_id,
///   owner_language, stream_id, current_host_id, current_host_name, participant_count
class PrivateGroupService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get available groups (live with a host)
  Future<List<PrivateGroupModel>> getAvailableGroups() async {
    try {
      final response = await _client
          .from('private_groups')
          .select()
          .eq('is_active', true)
          .eq('is_live', true)
          .not('current_host_id', 'is', null)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PrivateGroupModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user's own groups
  Future<List<PrivateGroupModel>> getMyGroups(String userId) async {
    try {
      final response = await _client
          .from('private_groups')
          .select()
          .eq('owner_id', userId)
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PrivateGroupModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Start live stream for group (host goes live)
  Future<bool> startLive(String groupId, String hostId, String hostName) async {
    try {
      await _client.from('private_groups').update({
        'is_live': true,
        'current_host_id': hostId,
        'current_host_name': hostName,
        'stream_id': 'stream_${groupId}_${DateTime.now().millisecondsSinceEpoch}',
        'participant_count': 1,
      }).eq('id', groupId);

      // Add host as member
      await _client.from('group_memberships').upsert({
        'group_id': groupId,
        'user_id': hostId,
        'has_access': true,
        'gift_amount_paid': 0,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stop live stream
  Future<bool> stopLive(String groupId) async {
    try {
      await _client.from('private_groups').update({
        'is_live': false,
        'stream_id': null,
        'current_host_id': null,
        'current_host_name': null,
        'participant_count': 0,
      }).eq('id', groupId);

      // Remove all memberships
      await _client.from('group_memberships').delete().eq('group_id', groupId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Join group as participant
  Future<bool> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Add membership
      await _client.from('group_memberships').upsert({
        'group_id': groupId,
        'user_id': userId,
        'has_access': true,
        'gift_amount_paid': 0,
      });

      // Increment participant count
      final group = await _client
          .from('private_groups')
          .select('participant_count')
          .eq('id', groupId)
          .single();

      final currentCount = group['participant_count'] as int? ?? 0;
      await _client.from('private_groups').update({
        'participant_count': currentCount + 1,
      }).eq('id', groupId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Leave group
  Future<bool> leaveGroup(String groupId, String userId) async {
    try {
      await _client
          .from('group_memberships')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      // Decrement participant count
      final group = await _client
          .from('private_groups')
          .select('participant_count')
          .eq('id', groupId)
          .single();

      final currentCount = group['participant_count'] as int? ?? 0;
      await _client.from('private_groups').update({
        'participant_count': (currentCount - 1).clamp(0, 999),
      }).eq('id', groupId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send tip to host via canonical SoT RPC `bill_group_gift_or_tip`.
  /// (Mirrors React group-call billing path; 50/50 split is enforced server-side.)
  Future<bool> sendTip({
    required String groupId,
    required String userId,
    required double amount,
    String? description,
  }) async {
    try {
      final response = await _client.rpc('bill_group_gift_or_tip', params: {
        'p_group_id': groupId,
        'p_man_id': userId,
        'p_amount': amount,
        'p_type': 'tip',
        'p_description': description ?? 'Group tip',
        'p_reference_id': null,
      });

      final data = response is Map<String, dynamic> ? response : null;
      return data?['success'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get group members
  Future<List<GroupMembershipModel>> getGroupMembers(String groupId) async {
    try {
      final response = await _client
          .from('group_memberships')
          .select()
          .eq('group_id', groupId);

      return (response as List)
          .map((json) => GroupMembershipModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Subscribe to group updates
  RealtimeChannel subscribeToGroup(
    String groupId,
    void Function(PrivateGroupModel group) onUpdate,
  ) {
    return _client.channel('group:$groupId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'private_groups',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: groupId,
      ),
      callback: (payload) {
        onUpdate(PrivateGroupModel.fromJson(payload.newRecord));
      },
    ).subscribe();
  }

  /// Subscribe to available groups (live groups)
  RealtimeChannel subscribeToAvailableGroups(
    void Function() onUpdate,
  ) {
    return _client.channel('live_groups').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'private_groups',
      callback: (_) => onUpdate(),
    ).subscribe();
  }
}
