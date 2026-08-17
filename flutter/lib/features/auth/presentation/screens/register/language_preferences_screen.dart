import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Language Preferences Screen - Synced with React LanguagePreferencesScreen
class LanguagePreferencesScreen extends StatelessWidget {
  const LanguagePreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Urdu', 'Arabic', 'Spanish', 'French'];
    final selected = <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Language Preferences')),
      body: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select languages you speak', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: languages.map((lang) => FilterChip(
                    label: Text(lang),
                    selected: selected.contains(lang),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          if (selected.length < 5) selected.add(lang);
                        } else {
                          selected.remove(lang);
                        }
                      });
                    },
                  )).toList(),
                ),
              ),
              AppButton(
                onPressed: selected.isNotEmpty ? () => context.push(AppRoutes.termsAgreement) : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
