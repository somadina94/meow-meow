import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';

/// Admin Messages Section - Synced with React AdminMessagesWidget
/// Shows broadcast and direct messages from admin
class AdminMessagesSection extends StatefulWidget {
  final String userId;

  const AdminMessagesSection({super.key, required this.userId});

  @override
  State<AdminMessagesSection> createState() => _AdminMessagesSectionState();
}

class _AdminMessagesSectionState extends State<AdminMessagesSection> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      // Fetch broadcast messages
      final broadcasts = await _client
          .from('admin_broadcast_messages')
          .select()
          .eq('is_broadcast', true)
          .order('created_at', ascending: false)
          .limit(5);

      // Fetch direct messages to this user
      final directMessages = await _client
          .from('admin_broadcast_messages')
          .select()
          .eq('recipient_id', widget.userId)
          .eq('is_broadcast', false)
          .order('created_at', ascending: false)
          .limit(5);

      final allMessages = <Map<String, dynamic>>[
        ...(broadcasts as List).cast<Map<String, dynamic>>(),
        ...(directMessages as List).cast<Map<String, dynamic>>(),
      ];

      // Sort by date descending
      allMessages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _messages = allMessages.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Admin Messages',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_messages.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(_messages.map((msg) => _buildMessageItem(msg))),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final isBroadcast = msg['is_broadcast'] == true;
    final subject = msg['subject'] as String? ?? 'No Subject';
    final message = msg['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isBroadcast)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Broadcast',
                      style: TextStyle(fontSize: 9, color: AppColors.primary),
                    ),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    subject,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatTimeAgo(createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
