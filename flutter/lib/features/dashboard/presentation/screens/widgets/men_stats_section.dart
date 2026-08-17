import 'package:flutter/material.dart';
import '../../../../../core/services/dashboard_service.dart';
import '../../../../../core/theme/app_colors.dart';

/// Men's Stats Section (Online, Matches, Notifications)
class MenStatsSection extends StatelessWidget {
  final DashboardStats stats;
  final int activeChatCount;

  const MenStatsSection({super.key, required this.stats, required this.activeChatCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.people,
          value: '${stats.onlineCount}',
          label: 'Online Now',
          color: AppColors.success,
        ),
        _StatCard(
          icon: Icons.favorite,
          value: '${stats.matchCount}',
          label: 'Matches',
          color: AppColors.primary,
        ),
        _StatCard(
          icon: Icons.notifications,
          value: '${stats.unreadNotifications}',
          label: 'Notifications',
          color: AppColors.info,
        ),
      ].map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
