import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Enable / Disable — mirrors React AdminEnableDisable.tsx.
/// Real table: `app_settings` (setting_key, setting_value as JSONB, setting_type, category).
/// Boolean toggles are stored as JSON booleans (true/false).
class AdminEnableDisableScreen extends ConsumerStatefulWidget {
  const AdminEnableDisableScreen({super.key});

  @override
  ConsumerState<AdminEnableDisableScreen> createState() => _AdminEnableDisableScreenState();
}

class _AdminEnableDisableScreenState extends ConsumerState<AdminEnableDisableScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _flags = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('app_settings')
          .select()
          .eq('setting_type', 'boolean')
          .order('category')
          .order('setting_key');
      if (!mounted) return;
      setState(() {
        _flags = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  Future<void> _toggle(Map<String, dynamic> f) async {
    final newVal = !_asBool(f['setting_value']);
    try {
      await _supabase.from('app_settings').update({
        'setting_value': jsonEncode(newVal),
      }).eq('id', f['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enable / Disable')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _flags.isEmpty
              ? const Center(child: Text('No boolean settings configured'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _flags.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = _flags[i];
                      return SwitchListTile(
                        title: Text(f['setting_key']?.toString() ?? '—'),
                        subtitle: Text(
                          '${f['category'] ?? 'general'} • ${f['description'] ?? ''}',
                        ),
                        value: _asBool(f['setting_value']),
                        onChanged: (_) => _toggle(f),
                      );
                    },
                  ),
                ),
    );
  }
}
