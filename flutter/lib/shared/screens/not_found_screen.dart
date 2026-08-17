import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/common_widgets.dart';

/// Not Found Screen - Synced with React NotFound
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('404 - Page Not Found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("The page you're looking for doesn't exist.", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            AppButton(
              isFullWidth: false,
              onPressed: () => context.go(AppRoutes.auth),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
