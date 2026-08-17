import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Men's Private Groups tab — shows the 50 flower rooms with live status.
/// Reads from private_groups (same as web).
class MenGroupsTab extends ConsumerStatefulWidget {
  const MenGroupsTab({super.key});

  @override
  ConsumerState<MenGroupsTab> createState() => _MenGroupsTabState();
}

class _MenGroupsTabState extends ConsumerState<MenGroupsTab> {
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
          .select('id, flower_name, host_id, host_name, host_photo, '
              'is_live, active_men_count, started_at')
          .order('is_live', ascending: false)
          .order('active_men_count', ascending: false)
          .limit(50);
      setState(() {
        _groups = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('MenGroupsTab load error: $e');
      setState(() {
        _groups = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Private Groups')),
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
                            'No live groups right now.\nCheck back soon.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _groups.length,
                    itemBuilder: (context, i) {
                      final g = _groups[i];
                      final isLive = (g['is_live'] ?? false) as bool;
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: isLive
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Joining group… (WebRTC TODO)')),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                AppAvatar(
                                  imageUrl: g['host_photo'] as String?,
                                  name:
                                      (g['flower_name'] as String?) ?? 'Group',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (g['flower_name'] as String?) ?? 'Group',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Host: ${(g['host_name'] as String?) ?? '—'}',
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLive
                                            ? Colors.red
                                            : Colors.grey,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isLive ? 'LIVE' : 'OFFLINE',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        '${g['active_men_count'] ?? 0} 👤',
                                        style:
                                            const TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
