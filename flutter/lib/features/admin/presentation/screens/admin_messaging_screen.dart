import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Messaging — mirrors React AdminMessaging.tsx.
/// Real table: `admin_broadcast_messages` (subject, message, admin_id, recipient_id, is_broadcast).
class AdminMessagingScreen extends ConsumerStatefulWidget {
  const AdminMessagingScreen({super.key});

  @override
  ConsumerState<AdminMessagingScreen> createState() => _AdminMessagingScreenState();
}

class _AdminMessagingScreenState extends ConsumerState<AdminMessagingScreen> {
  final _supabase = Supabase.instance.client;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subject.text.isEmpty || _message.text.isEmpty) return;
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) return;
    setState(() => _sending = true);
    try {
      await _supabase.from('admin_broadcast_messages').insert({
        'admin_id': adminId,
        'subject': _subject.text,
        'message': _message.text,
        'is_broadcast': true,
      });
      if (mounted) {
        _subject.clear();
        _message.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast sent')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Messaging')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.campaign),
              label: const Text('Send broadcast to all users'),
            ),
            const SizedBox(height: 8),
            Text(
              'Note: Broadcasts auto-expire after 7 days per data retention policy.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
