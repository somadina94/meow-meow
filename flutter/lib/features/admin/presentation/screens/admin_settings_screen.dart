import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/admin_service.dart';

/// Admin Settings Screen - Synced with React AdminSettings
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, 'Chat Settings', [
            ListTile(title: const Text('Chat Pricing'), subtitle: const Text('Configure per-minute rates'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
            ListTile(title: const Text('Video Call Pricing'), subtitle: const Text('Configure video rates'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ]),
          _section(context, 'Platform Settings', [
            ListTile(title: const Text('Language Groups'), subtitle: const Text('Manage language group limits'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
            ListTile(title: const Text('Gift Pricing'), subtitle: const Text('Configure gift prices'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
            ListTile(title: const Text('Legal Documents'), subtitle: const Text('Manage legal policies'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ]),
          _section(context, 'System', [
            ListTile(title: const Text('Backup Management'), subtitle: const Text('Database backups'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
            ListTile(title: const Text('Audit Logs'), subtitle: const Text('View admin activity'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
            ListTile(title: const Text('Performance'), subtitle: const Text('System monitoring'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(child: Column(children: children)),
        const SizedBox(height: 8),
      ],
    );
  }
}
