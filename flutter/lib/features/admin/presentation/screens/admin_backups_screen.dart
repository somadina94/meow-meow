import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin Backup Management — mirrors React AdminBackupManagement.tsx.
/// Real table: `backup_logs` with size_bytes (not size_mb) and status.
class AdminBackupsScreen extends ConsumerStatefulWidget {
  const AdminBackupsScreen({super.key});

  @override
  ConsumerState<AdminBackupsScreen> createState() => _AdminBackupsScreenState();
}

class _AdminBackupsScreenState extends ConsumerState<AdminBackupsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _running = false;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('backup_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _backups = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runBackup() async {
    setState(() => _running = true);
    try {
      await _supabase.functions.invoke('trigger-backup');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup triggered')),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _fmtSize(dynamic bytes) {
    final b = (bytes is num) ? bytes.toDouble() : 0.0;
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _running ? null : _runBackup,
        icon: _running
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.backup),
        label: const Text('Run backup'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _backups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = _backups[i];
                  final t = DateTime.tryParse(b['created_at']?.toString() ?? '');
                  final ok = b['status'] == 'success' || b['status'] == 'completed';
                  return ListTile(
                    leading: Icon(ok ? Icons.check_circle : Icons.error,
                        color: ok ? Colors.green : Colors.red),
                    title: Text(b['backup_type']?.toString() ?? 'Backup'),
                    subtitle: Text(
                      '${t != null ? DateFormat.yMd().add_Hm().format(t) : '—'} • ${_fmtSize(b['size_bytes'])}'
                      '${b['error_message'] != null ? '\n${b['error_message']}' : ''}',
                    ),
                    trailing: Text(b['status']?.toString() ?? '—'),
                  );
                },
              ),
            ),
    );
  }
}
