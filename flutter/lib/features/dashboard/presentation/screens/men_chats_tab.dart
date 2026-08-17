import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Men's Active Chats tab — list of chat sessions for the logged-in man.
/// Reads from active_chat_sessions (same table as the React app).
class MenChatsTab extends ConsumerStatefulWidget {
  const MenChatsTab({super.key});

  @override
  ConsumerState<MenChatsTab> createState() => _MenChatsTabState();
}

class _MenChatsTabState extends ConsumerState<MenChatsTab> {
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
              'last_message, last_message_at, unread_count')
          .eq('user_id', uid)
          .order('last_message_at', ascending: false)
          .limit(50);
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('MenChatsTab load error: $e');
      setState(() {
        _sessions = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
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
                            'No active chats yet.\nStart one from the Home tab.',
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
                        trailing: unread > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('$unread',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              )
                            : const Icon(Icons.chevron_right, size: 18),
                        onTap: () =>
                            context.push('/chat/${s['partner_id']}'),
                      );
                    },
                  ),
      ),
    );
  }
}
