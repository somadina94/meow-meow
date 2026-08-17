import 'package:flutter/material.dart';
import '../../../../../core/services/dashboard_service.dart';

/// Notifications Section
class NotificationsSection extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback onViewAll;

  const NotificationsSection({
    super.key,
    required this.notifications,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        if (notifications.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No new activity yet', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          )
        else
          ...notifications.map((notif) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getNotifColor(notif.type).withOpacity(0.1),
                child: Icon(_getNotifIcon(notif.type), color: _getNotifColor(notif.type), size: 20),
              ),
              title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(notif.message, style: const TextStyle(fontSize: 12)),
              trailing: notif.isRead ? null : Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )),
      ],
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'match': return Icons.favorite;
      case 'message': return Icons.chat;
      default: return Icons.notifications;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'match': return Colors.pink;
      case 'message': return Colors.blue;
      default: return Colors.purple;
    }
  }
}
