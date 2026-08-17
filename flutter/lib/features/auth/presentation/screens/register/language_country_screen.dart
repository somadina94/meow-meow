import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Language & Country Selection - Synced with React LanguageCountryScreen
class LanguageCountryScreen extends StatefulWidget {
  const LanguageCountryScreen({super.key});

  @override
  State<LanguageCountryScreen> createState() => _LanguageCountryScreenState();
}

class _LanguageCountryScreenState extends State<LanguageCountryScreen> {
  String? _selectedLanguage;
  String? _selectedCountry;

  final _languages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Odia', 'Urdu', 'Arabic', 'Spanish', 'French', 'Chinese'];
  final _countries = ['India', 'Pakistan', 'Bangladesh', 'Sri Lanka', 'Nepal', 'UAE', 'Saudi Arabia', 'Qatar', 'Kuwait', 'Bahrain', 'Oman', 'USA', 'UK', 'Canada', 'Australia'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language & Country')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select your mother tongue', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(labelText: 'Mother Tongue'),
              items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => setState(() => _selectedLanguage = v),
            ),
            const SizedBox(height: 24),
            Text('Select your country', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: const InputDecoration(labelText: 'Country'),
              items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCountry = v),
            ),
            const Spacer(),
            AppButton(
              onPressed: _selectedLanguage != null && _selectedCountry != null
                  ? () => context.push(AppRoutes.basicInfo)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
