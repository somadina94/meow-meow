import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin Policy Alerts — mirrors React AdminPolicyAlerts.tsx.
/// Real table: `policy_violation_alerts` with `status` (pending/reviewed) and `severity`.
class AdminPolicyAlertsScreen extends ConsumerStatefulWidget {
  const AdminPolicyAlertsScreen({super.key});

  @override
  ConsumerState<AdminPolicyAlertsScreen> createState() => _AdminPolicyAlertsScreenState();
}

class _AdminPolicyAlertsScreenState extends ConsumerState<AdminPolicyAlertsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('policy_violation_alerts')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _alerts = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(String id) async {
    try {
      final auth = _supabase.auth.currentUser?.id;
      await _supabase.from('policy_violation_alerts').update({
        'status': 'reviewed',
        'reviewed_at': DateTime.now().toIso8601String(),
        if (auth != null) 'reviewed_by': auth,
      }).eq('id', id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Color _sevColor(String? sev) {
    switch (sev) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policy Alerts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(child: Text('No pending alerts 🎉'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _alerts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = _alerts[i];
                      final sev = a['severity']?.toString();
                      final created = DateTime.tryParse(a['created_at']?.toString() ?? '');
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _sevColor(sev).withOpacity(0.15),
                          child: Icon(Icons.warning, color: _sevColor(sev)),
                        ),
                        title: Text('${a['violation_type'] ?? a['alert_type'] ?? 'Alert'}'),
                        subtitle: Text(
                          '${a['content'] ?? ''}'
                          '${created != null ? '\n${DateFormat.yMd().add_Hm().format(created)}' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _resolve(a['id']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
