import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shift Compliance Screen — placeholder.
/// Reads from the same compliance tables as the React app.
class ShiftComplianceScreen extends ConsumerWidget {
  const ShiftComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Compliance')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Shift compliance dashboard — pending wiring against '
            'compliance RPCs shared with the web app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
