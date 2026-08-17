import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wallet statement export — calls canonical RPC and exports CSV.
/// Mirrors the 10-column statement format from the React app.
class WalletStatementExportScreen extends StatefulWidget {
  const WalletStatementExportScreen({super.key});

  @override
  State<WalletStatementExportScreen> createState() =>
      _WalletStatementExportScreenState();
}

class _WalletStatementExportScreenState
    extends State<WalletStatementExportScreen> {
  final _supabase = Supabase.instance.client;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _busy = false;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  String _csvEscape(dynamic v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      // Canonical statement RPC: returns id, session_id, session_type,
      // transaction_type, debit, credit, description, reference_id,
      // counterparty_id, running_balance, created_at, duration_seconds,
      // rate_per_minute.
      final rows = await _supabase.rpc('get_ledger_statement', params: {
        'p_user_id': _supabase.auth.currentUser?.id,
        'p_from_date': _range.start.toIso8601String().split('T').first,
        'p_to_date': _range.end.toIso8601String().split('T').first,
      }) as List<dynamic>;

      final headers = [
        'Date', 'Time', 'Type', 'Description', 'Reference',
        'Debit', 'Credit', 'Balance', 'Status', 'Counterparty',
      ];
      final buf = StringBuffer(headers.map(_csvEscape).join(','))..writeln();
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        final created = m['created_at']?.toString() ?? '';
        final dt = DateTime.tryParse(created);
        final date = dt != null
            ? '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
            : '';
        final time = dt != null
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}'
            : '';
        buf.writeln([
          date,
          time,
          m['transaction_type'] ?? '',
          m['description'] ?? '',
          m['reference_id'] ?? '',
          m['debit'] ?? 0,
          m['credit'] ?? 0,
          m['running_balance'] ?? 0,
          'completed',
          m['counterparty_id'] ?? '',
        ].map(_csvEscape).join(','));
      }

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/wallet_statement_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Wallet Statement');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Statement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Date range'),
              subtitle: Text(
                  '${_range.start.toLocal().toString().split(' ').first}  →  ${_range.end.toLocal().toString().split(' ').first}'),
              onTap: _pickRange,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
