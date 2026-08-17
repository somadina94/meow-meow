import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Location Setup Screen - Synced with React LocationSetupScreen
class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  String? _selectedState;
  String? _selectedCity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Where are you located?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            AppTextField(
              label: 'State / Province',
              hint: 'Enter your state',
              controller: TextEditingController(text: _selectedState),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'City',
              hint: 'Enter your city',
              controller: TextEditingController(text: _selectedCity),
            ),
            const Spacer(),
            AppButton(
              onPressed: () => context.push(AppRoutes.languagePreferences),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
