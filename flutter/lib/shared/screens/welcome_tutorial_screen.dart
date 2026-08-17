import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../core/theme/app_colors.dart';

/// Welcome Tutorial Screen - Synced with React WelcomeTutorialScreen
class WelcomeTutorialScreen extends StatefulWidget {
  const WelcomeTutorialScreen({super.key});

  @override
  State<WelcomeTutorialScreen> createState() => _WelcomeTutorialScreenState();
}

class _WelcomeTutorialScreenState extends State<WelcomeTutorialScreen> {
  int _currentPage = 0;

  final _pages = [
    {'icon': '🐱', 'title': 'Welcome to Meow Meow!', 'desc': 'Find your purrfect match based on language and culture.'},
    {'icon': '💬', 'title': 'Chat Instantly', 'desc': 'Real-time chat with auto-translation in 15+ languages.'},
    {'icon': '📹', 'title': 'Video Calls', 'desc': 'Connect face-to-face with video calling.'},
    {'icon': '🎁', 'title': 'Send Gifts', 'desc': 'Show appreciation with virtual gifts.'},
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(page['icon']!, style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              Text(page['title']!, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(page['desc']!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 48),
              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentPage ? AppColors.primary : AppColors.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
              const SizedBox(height: 48),
              AppButton(
                onPressed: () {
                  if (_currentPage < _pages.length - 1) {
                    setState(() => _currentPage++);
                  } else {
                    context.go(AppRoutes.dashboard);
                  }
                },
                child: Text(_currentPage < _pages.length - 1 ? 'Next' : 'Get Started'),
              ),
              if (_currentPage < _pages.length - 1)
                TextButton(
                  onPressed: () => context.go(AppRoutes.dashboard),
                  child: const Text('Skip'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
