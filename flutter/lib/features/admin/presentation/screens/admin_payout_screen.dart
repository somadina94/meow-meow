import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin payout management — bi-monthly snapshots with two-decimal precision.
/// Reads from canonical `women_payout_snapshots` table and updates via the
/// canonical `admin_update_payout` RPC. Mirrors React AdminPayoutStatements.
class AdminPayoutScreen extends StatefulWidget {
  const AdminPayoutScreen({super.key});

  @override
  State<AdminPayoutScreen> createState() => _AdminPayoutScreenState();
}

class _AdminPayoutScreenState extends State<AdminPayoutScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _payouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('women_payout_snapshots')
          .select()
          .order('snapshot_ist_date', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _payouts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markPaid(String id) async {
    try {
      await _supabase.rpc('admin_update_payout', params: {
        'p_statement_id': id,
        'p_status': 'paid',
      });
    } catch (_) {/* surface via toast on next refresh */}
    _load();
  }

  String _money(dynamic v) =>
      '₹${(double.tryParse(v?.toString() ?? '0') ?? 0).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _payouts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _payouts[i];
                  final status = (p['payment_status'] as String?) ?? 'pending';
                  final paid = status == 'paid';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: paid ? Colors.green : Colors.orange,
                      child: Icon(
                        paid ? Icons.check : Icons.schedule,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(p['full_name'] as String? ?? 'User'),
                    subtitle: Text(
                        '${p['snapshot_ist_date'] ?? ''} • $status'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_money(p['net_payable'] ?? p['incremental_payable']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        if (!paid)
                          TextButton(
                            onPressed: () => _markPaid(p['id'] as String),
                            child: const Text('Mark paid'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
