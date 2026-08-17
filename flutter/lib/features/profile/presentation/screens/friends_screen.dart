import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FriendsScreen — synced with React useUserRelationships.
/// Real table is `user_friends` (not `friendships`).
/// Profile photo column is `photo_url` (not `profile_photo_url`).
/// Unfriend goes through canonical RPC `unfriend_user(p_target_user_id)`.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // user_friends rows are bidirectional — match either direction.
      final rows = await _supabase
          .from('user_friends')
          .select('id, user_id, friend_id, status')
          .eq('status', 'accepted')
          .or('user_id.eq.$uid,friend_id.eq.$uid');

      final friendIds = (rows as List)
          .map((r) {
            final u = r['user_id'] as String;
            final f = r['friend_id'] as String;
            return u == uid ? f : u;
          })
          .toSet()
          .toList();

      if (friendIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _friends = [];
          _loading = false;
        });
        return;
      }

      final profiles = await _supabase
          .from('profiles')
          .select('user_id, full_name, photo_url')
          .inFilter('user_id', friendIds);

      if (!mounted) return;
      setState(() {
        _friends = List<Map<String, dynamic>>.from(profiles);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _unfriend(String friendId) async {
    try {
      await _supabase
          .rpc('unfriend_user', params: {'p_target_user_id': friendId});
    } catch (_) {/* ignore — UI will refresh */}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? const Center(child: Text('No friends yet'))
              : ListView.separated(
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = _friends[i];
                    final photo = f['photo_url'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            photo != null ? NetworkImage(photo) : null,
                        child: photo == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(f['full_name'] as String? ?? 'User'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove),
                        onPressed: () => _unfriend(f['user_id'] as String),
                      ),
                    );
                  },
                ),
    );
  }
}
