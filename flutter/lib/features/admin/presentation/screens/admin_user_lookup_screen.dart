import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin User Lookup — mirrors React AdminUserLookup.tsx
class AdminUserLookupScreen extends ConsumerStatefulWidget {
  const AdminUserLookupScreen({super.key});

  @override
  ConsumerState<AdminUserLookupScreen> createState() => _AdminUserLookupScreenState();
}

class _AdminUserLookupScreenState extends ConsumerState<AdminUserLookupScreen> {
  final _supabase = Supabase.instance.client;
  final _ctrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .or('full_name.ilike.%$q%,phone.ilike.%$q%,email.ilike.%$q%')
          .limit(50);
      if (!mounted) return;
      setState(() {
        _results = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Lookup')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: u['photo_url'] != null
                                  ? NetworkImage(u['photo_url'])
                                  : null,
                              child: u['photo_url'] == null
                                  ? Text(((u['full_name'] ?? 'U').toString())[0])
                                  : null,
                            ),
                            title: Text(u['full_name']?.toString() ?? '—'),
                            subtitle: Text(
                                '${u['gender'] ?? ''} • ${u['country'] ?? ''} • ${u['phone'] ?? u['email'] ?? ''}'),
                            trailing: Chip(label: Text(u['account_status'] ?? 'active')),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
