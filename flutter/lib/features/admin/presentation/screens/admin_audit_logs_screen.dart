import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin Audit Logs — mirrors React AdminAuditLogs.tsx.
/// Real table: `audit_logs` with admin_email, action, action_type, resource_type, resource_id.
class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _logs = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final l = _logs[i];
                  final t = DateTime.tryParse(l['created_at']?.toString() ?? '');
                  final ok = l['status'] == 'success';
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      ok ? Icons.check_circle_outline : Icons.error_outline,
                      size: 20,
                      color: ok ? Colors.green : Colors.red,
                    ),
                    title: Text('${l['action'] ?? '—'} • ${l['resource_type'] ?? ''}'),
                    subtitle: Text(
                      'By: ${l['admin_email'] ?? l['admin_id'] ?? '—'}\n'
                      '${t != null ? DateFormat.yMd().add_Hms().format(t) : ''}',
                    ),
                    isThreeLine: true,
                    trailing: l['resource_id'] != null
                        ? Text(
                            l['resource_id'].toString().length >= 8
                                ? l['resource_id'].toString().substring(0, 8)
                                : l['resource_id'].toString(),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          )
                        : null,
                  );
                },
              ),
            ),
    );
  }
}
