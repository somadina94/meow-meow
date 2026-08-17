import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Language Limits — mirrors React AdminLanguageLimits.tsx.
/// Real columns: language_name, max_chat_women, max_call_women, max_earning_women, etc.
class AdminLanguageLimitsScreen extends ConsumerStatefulWidget {
  const AdminLanguageLimitsScreen({super.key});

  @override
  ConsumerState<AdminLanguageLimitsScreen> createState() => _AdminLanguageLimitsScreenState();
}

class _AdminLanguageLimitsScreenState extends ConsumerState<AdminLanguageLimitsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _limits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('language_limits')
          .select()
          .order('language_name');
      if (!mounted) return;
      setState(() {
        _limits = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editLimits(Map<String, dynamic> row) async {
    final chat = TextEditingController(text: '${row['max_chat_women'] ?? 0}');
    final call = TextEditingController(text: '${row['max_call_women'] ?? 0}');
    final earn = TextEditingController(text: '${row['max_earning_women'] ?? 0}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(row['language_name']?.toString() ?? 'Limits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: chat, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max chat women')),
            TextField(controller: call, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max call women')),
            TextField(controller: earn, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max earning women')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await _supabase.from('language_limits').update({
        'max_chat_women': int.tryParse(chat.text) ?? 0,
        'max_call_women': int.tryParse(call.text) ?? 0,
        'max_earning_women': int.tryParse(earn.text) ?? 0,
      }).eq('id', row['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language Limits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _limits.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final l = _limits[i];
                  return ListTile(
                    title: Text(l['language_name']?.toString() ?? '—'),
                    subtitle: Text(
                      'Chat: ${l['current_chat_women'] ?? 0}/${l['max_chat_women'] ?? 0} • '
                      'Call: ${l['current_call_women'] ?? 0}/${l['max_call_women'] ?? 0} • '
                      'Earn: ${l['current_earning_women'] ?? 0}/${l['max_earning_women'] ?? 0}',
                    ),
                    trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editLimits(l)),
                  );
                },
              ),
            ),
    );
  }
}
