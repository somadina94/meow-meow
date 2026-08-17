import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Approval Pending Screen - Synced with React ApprovalPendingScreen
class ApprovalPendingScreen extends StatelessWidget {
  const ApprovalPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 80, color: AppColors.warning),
              const SizedBox(height: 24),
              Text('Approval Pending', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 16),
              Text(
                'Your profile is being reviewed by our team. You will be notified once approved.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => context.go(AppRoutes.auth),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
