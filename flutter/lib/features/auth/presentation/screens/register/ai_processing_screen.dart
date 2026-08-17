import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/theme/app_colors.dart';

/// AI Processing Screen - Synced with React AIProcessingScreen
class AIProcessingScreen extends StatefulWidget {
  const AIProcessingScreen({super.key});

  @override
  State<AIProcessingScreen> createState() => _AIProcessingScreenState();
}

class _AIProcessingScreenState extends State<AIProcessingScreen> {
  int _step = 0;
  final _steps = [
    'Verifying identity...',
    'Analyzing profile photos...',
    'Checking content guidelines...',
    'Setting up your account...',
    'Almost ready!',
  ];

  @override
  void initState() {
    super.initState();
    _runSteps();
  }

  Future<void> _runSteps() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _step = i);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) context.go(AppRoutes.registrationComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              Text('AI Processing', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(_steps[_step], style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: (_step + 1) / _steps.length),
            ],
          ),
        ),
      ),
    );
  }
}
