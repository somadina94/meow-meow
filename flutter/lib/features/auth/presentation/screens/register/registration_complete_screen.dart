import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Registration Complete Screen - Synced with React RegistrationCompleteScreen
class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text('Registration Complete! 🎉', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 16),
              Text('Your account has been created successfully.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              AppButton(
                onPressed: () => context.go(AppRoutes.welcomeTutorial),
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
