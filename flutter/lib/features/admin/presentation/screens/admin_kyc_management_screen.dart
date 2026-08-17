import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin KYC Management — mirrors React AdminKYCManagement.tsx.
/// Real table: `women_kyc` with column `verification_status` (pending/approved/rejected).
class AdminKycManagementScreen extends ConsumerStatefulWidget {
  const AdminKycManagementScreen({super.key});

  @override
  ConsumerState<AdminKycManagementScreen> createState() => _AdminKycManagementScreenState();
}

class _AdminKycManagementScreenState extends ConsumerState<AdminKycManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String _status = 'pending';
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('women_kyc')
          .select()
          .eq('verification_status', _status)
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(String id, String decision, {String? reason}) async {
    try {
      final auth = _supabase.auth.currentUser?.id;
      await _supabase.from('women_kyc').update({
        'verification_status': decision,
        'verified_at': DateTime.now().toIso8601String(),
        if (auth != null) 'verified_by': auth,
        if (decision == 'rejected' && reason != null) 'rejection_reason': reason,
      }).eq('id', id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(String id) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject KYC'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Reject')),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) await _decide(id, 'rejected', reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['pending', 'approved', 'rejected'].map((s) {
                final active = _status == s;
                return TextButton(
                  onPressed: () { setState(() => _status = s); _load(); },
                  child: Text(
                    s.toUpperCase(),
                    style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text('No $_status submissions'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final k = _items[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.verified_user)),
                        title: Text(k['full_name_as_per_bank']?.toString() ?? k['user_id']?.toString() ?? '—'),
                        subtitle: Text(
                          'Bank: ${k['bank_name'] ?? '—'} • A/C: ${k['account_number'] ?? '—'}\n'
                          'IFSC: ${k['ifsc_code'] ?? '—'}',
                        ),
                        isThreeLine: true,
                        trailing: _status == 'pending'
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _decide(k['id'], 'approved'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _reject(k['id']),
                                ),
                              ])
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}
