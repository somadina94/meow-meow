import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Women's Private Groups tab — shows groups the user can host or join.
/// Same private_groups table as the web app.
class WomenGroupsTab extends ConsumerStatefulWidget {
  const WomenGroupsTab({super.key});

  @override
  ConsumerState<WomenGroupsTab> createState() => _WomenGroupsTabState();
}

class _WomenGroupsTabState extends ConsumerState<WomenGroupsTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _client
          .from('private_groups')
          .select('id, flower_name, host_id, host_name, '
              'is_live, active_men_count')
          .order('is_live', ascending: false)
          .limit(50);
      setState(() {
        _groups = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('WomenGroupsTab load error: $e');
      setState(() {
        _groups = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Private Groups')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.videocam),
        label: const Text('Go Live'),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Go-Live flow — WebRTC wiring TODO')),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No groups available.\nTap Go Live to host one.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final g = _groups[i];
                      final isMine = g['host_id'] == myId;
                      final isLive = (g['is_live'] ?? false) as bool;
                      return ListTile(
                        leading: AppAvatar(
                          name: (g['flower_name'] as String?) ?? 'Group',
                        ),
                        title: Text(
                            (g['flower_name'] as String?) ?? 'Group'),
                        subtitle: Text(isMine
                            ? 'Your group'
                            : 'Host: ${(g['host_name'] as String?) ?? '—'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLive ? Colors.red : Colors.grey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isLive ? 'LIVE' : 'OFFLINE',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${g['active_men_count'] ?? 0} 👤',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
