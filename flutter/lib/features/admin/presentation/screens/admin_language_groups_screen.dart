import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Language Groups — mirrors React AdminLanguageGroups.tsx.
/// Real columns: name, languages (array), is_active, max_women_users, current_women_count.
class AdminLanguageGroupsScreen extends ConsumerStatefulWidget {
  const AdminLanguageGroupsScreen({super.key});

  @override
  ConsumerState<AdminLanguageGroupsScreen> createState() => _AdminLanguageGroupsScreenState();
}

class _AdminLanguageGroupsScreenState extends ConsumerState<AdminLanguageGroupsScreen> {
  final _supabase = Supabase.instance.client;
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
      final res = await _supabase
          .from('language_groups')
          .select()
          .order('priority', ascending: true);
      if (!mounted) return;
      setState(() {
        _groups = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> g) async {
    final newVal = !(g['is_active'] == true);
    try {
      await _supabase.from('language_groups').update({'is_active': newVal}).eq('id', g['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language Groups')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final g = _groups[i];
                  final langs = (g['languages'] is List)
                      ? (g['languages'] as List).join(', ')
                      : '';
                  return SwitchListTile(
                    title: Text(g['name']?.toString() ?? '—'),
                    subtitle: Text(
                      'Women: ${g['current_women_count'] ?? 0}/${g['max_women_users'] ?? '∞'}'
                      '${langs.isNotEmpty ? '\n$langs' : ''}',
                    ),
                    isThreeLine: langs.isNotEmpty,
                    value: g['is_active'] == true,
                    onChanged: (_) => _toggle(g),
                  );
                },
              ),
            ),
    );
  }
}
