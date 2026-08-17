import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shift Management Screen — placeholder.
/// Hooks into the same Supabase tables/RPCs the React shift management uses.
class ShiftManagementScreen extends ConsumerWidget {
  const ShiftManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Management')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Shift management UI — to be wired against the same '
            'shift_schedules / women_availability tables used by the web app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
