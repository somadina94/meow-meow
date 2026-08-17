import 'package:flutter/material.dart';

/// Quick Action model
class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  QuickAction({required this.icon, required this.label, required this.onTap});
}

/// Quick Actions Grid - 2x2 grid of action buttons
class QuickActionsGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionsGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: actions.length > 2 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: actions.map((action) => _ActionCard(action: action)).toList(),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final QuickAction action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(action.label, style: Theme.of(context).textTheme.labelMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
