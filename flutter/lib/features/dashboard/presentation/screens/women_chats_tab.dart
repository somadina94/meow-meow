import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Women's Active Chats tab — list of in-progress chat sessions.
/// Same active_chat_sessions table as the web app.
class WomenChatsTab extends ConsumerStatefulWidget {
  const WomenChatsTab({super.key});

  @override
  ConsumerState<WomenChatsTab> createState() => _WomenChatsTabState();
}

class _WomenChatsTabState extends ConsumerState<WomenChatsTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _sessions = [];
          _loading = false;
        });
        return;
      }
      final res = await _client
          .from('active_chat_sessions')
          .select('chat_id, partner_id, partner_name, partner_photo, '
              'last_message, last_message_at, unread_count, earnings_so_far')
          .eq('user_id', uid)
          .order('last_message_at', ascending: false)
          .limit(50);
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('WomenChatsTab load error: $e');
      setState(() {
        _sessions = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Chats')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _sessions.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No active chats right now.\n'
                            'Stay online — men will start chats with you.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = _sessions[i];
                      final earn = (s['earnings_so_far'] as num?) ?? 0;
                      final unread = (s['unread_count'] ?? 0) as int;
                      return ListTile(
                        leading: AppAvatar(
                          imageUrl: s['partner_photo'] as String?,
                          name: (s['partner_name'] as String?) ?? 'User',
                        ),
                        title: Text((s['partner_name'] as String?) ?? 'User'),
                        subtitle: Text(
                          (s['last_message'] as String?) ?? 'Tap to open',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('₹${earn.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(height: 4),
                              Text('$unread new',
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ],
                        ),
                        onTap: () =>
                            context.push('/chat/${s['partner_id']}'),
                      );
                    },
                  ),
      ),
    );
  }
}
