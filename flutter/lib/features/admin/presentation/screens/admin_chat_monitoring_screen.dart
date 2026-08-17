import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin Chat Monitoring — mirrors React AdminChatMonitoring.tsx.
/// Reads from `active_chat_sessions`.
class AdminChatMonitoringScreen extends ConsumerStatefulWidget {
  const AdminChatMonitoringScreen({super.key});

  @override
  ConsumerState<AdminChatMonitoringScreen> createState() => _AdminChatMonitoringScreenState();
}

class _AdminChatMonitoringScreenState extends ConsumerState<AdminChatMonitoringScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var query = _supabase.from('active_chat_sessions').select();
      if (_filter == 'active') query = query.eq('status', 'active');
      final res = await query.order('last_activity_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Monitoring'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) { setState(() => _filter = v); _load(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'active', child: Text('Active only')),
              PopupMenuItem(value: 'all', child: Text('All sessions')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No chat sessions'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _sessions[i];
                      final updated = DateTime.tryParse(s['last_activity_at']?.toString() ?? '');
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.chat)),
                        title: Text(
                          s['chat_id']?.toString() ?? '—',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        subtitle: Text(
                          'Mins: ${s['total_minutes'] ?? 0} • '
                          '₹${s['total_earned'] ?? 0}'
                          '${updated != null ? ' • ${DateFormat.Hm().format(updated)}' : ''}',
                        ),
                        trailing: Chip(
                          label: Text(s['status'] ?? '—'),
                          backgroundColor: (s['status'] == 'active')
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
