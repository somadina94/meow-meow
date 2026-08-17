import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Women-only language group chat with background translation.
/// Each language code (e.g., "hi", "ta") gets a single shared room.
class LanguageGroupChatScreen extends StatefulWidget {
  final String languageCode;
  final String languageName;

  const LanguageGroupChatScreen({
    super.key,
    required this.languageCode,
    required this.languageName,
  });

  @override
  State<LanguageGroupChatScreen> createState() =>
      _LanguageGroupChatScreenState();
}

class _LanguageGroupChatScreenState extends State<LanguageGroupChatScreen> {
  final _supabase = Supabase.instance.client;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  RealtimeChannel? _chan;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _chan?.unsubscribe();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('language_community_messages')
          .select('*, sender:sender_id(full_name, photo_url)')
          .eq('language_code', widget.languageCode)
          .order('created_at')
          .limit(200);
      setState(() => _msgs = List<Map<String, dynamic>>.from(data));
      _scrollToBottom();
    } catch (_) {}
  }

  void _subscribe() {
    _chan = _supabase
        .channel('lang_chat_${widget.languageCode}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'language_community_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'language_code',
            value: widget.languageCode,
          ),
          callback: (payload) {
            setState(() => _msgs.add(payload.newRecord));
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      // Direct insert mirrors React `LanguageGroupChat.tsx`.
      // No `send_language_group_message` RPC exists.
      final senderId = _supabase.auth.currentUser?.id;
      if (senderId == null) throw Exception('Not signed in');
      await _supabase.from('language_community_messages').insert({
        'language_code': widget.languageCode,
        'sender_id': senderId,
        'message': text,
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.languageName} Group')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(8),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                final isMe = m['sender_id'] == uid;
                final sender = m['sender'] as Map<String, dynamic>?;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe && sender != null)
                          Text(sender['full_name'] as String? ?? '',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(m['text'] as String? ?? ''),
                        if (m['translated_text'] != null &&
                            m['translated_text'] != m['text'])
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              m['translated_text'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
