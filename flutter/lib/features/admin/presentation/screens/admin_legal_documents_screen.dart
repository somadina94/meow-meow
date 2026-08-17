import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Legal Documents — mirrors React AdminLegalDocuments.tsx.
/// Real columns: name, document_type, version, description, file_path, is_active.
class AdminLegalDocumentsScreen extends ConsumerStatefulWidget {
  const AdminLegalDocumentsScreen({super.key});

  @override
  ConsumerState<AdminLegalDocumentsScreen> createState() => _AdminLegalDocumentsScreenState();
}

class _AdminLegalDocumentsScreenState extends ConsumerState<AdminLegalDocumentsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('legal_documents')
          .select()
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _docs = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> doc) async {
    try {
      await _supabase.from('legal_documents').update({
        'is_active': !(doc['is_active'] == true),
      }).eq('id', doc['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Documents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = _docs[i];
                  return SwitchListTile(
                    secondary: const Icon(Icons.description),
                    title: Text(d['name']?.toString() ?? '—'),
                    subtitle: Text(
                      '${d['document_type'] ?? '—'} • v${d['version'] ?? '1'}\n'
                      '${d['description'] ?? ''}',
                    ),
                    isThreeLine: true,
                    value: d['is_active'] == true,
                    onChanged: (_) => _toggleActive(d),
                  );
                },
              ),
            ),
    );
  }
}
