import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _blocked = [];
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
      final data = await _supabase
          .from('user_blocks')
          .select('*, blocked:blocked_user_id(id, full_name, photo_url)')
          .eq('blocked_by', uid);
      setState(() {
        _blocked = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String blockedId) async {
    await _supabase.rpc('unblock_user', params: {'p_blocked_id': blockedId});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? const Center(child: Text('No blocked users'))
              : ListView.separated(
                  itemCount: _blocked.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final b = _blocked[i]['blocked'] as Map<String, dynamic>?;
                    if (b == null) return const SizedBox.shrink();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: b['photo_url'] != null
                            ? NetworkImage(b['photo_url'] as String)
                            : null,
                        child: b['photo_url'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(b['full_name'] as String? ?? 'User'),
                      trailing: TextButton(
                        onPressed: () => _unblock(b['id'] as String),
                        child: const Text('Unblock'),
                      ),
                    );
                  },
                ),
    );
  }
}
