// Registration flow placeholder screens

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';

class LanguageCountryScreen extends StatelessWidget {
  const LanguageCountryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language & Country')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Country'),
              items: [
                DropdownMenuItem(value: 'IN', child: Text('India')),
                DropdownMenuItem(value: 'US', child: Text('United States')),
              ],
              onChanged: null,
            ),
            const SizedBox(height: 16),
            const DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Primary Language'),
              items: [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'hi', child: Text('Hindi')),
              ],
              onChanged: null,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.basicInfo),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BasicInfoScreen extends StatelessWidget {
  const BasicInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Info')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Date of Birth')),
            const SizedBox(height: 16),
            const DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Gender'),
              items: [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: null,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.photoUpload),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordSetupScreen extends StatelessWidget {
  const PasswordSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.termsAgreement),
                child: const Text('Continue to Terms'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoUploadScreen extends StatelessWidget {
  const PhotoUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Photos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: List.generate(6, (index) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_a_photo, size: 32),
                  );
                }),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.locationSetup),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationSetupScreen extends StatelessWidget {
  const LocationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Location')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Detect location button
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement geolocation with OpenStreetMap Nominatim
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Detecting location...')),
                );
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Detect My Location'),
            ),
            const SizedBox(height: 24),
            const DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Country'),
              items: [
                DropdownMenuItem(value: 'IN', child: Text('India')),
                DropdownMenuItem(value: 'US', child: Text('United States')),
              ],
              onChanged: null,
            ),
            const SizedBox(height: 16),
            const DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'State / Province'),
              items: [
                DropdownMenuItem(value: 'MH', child: Text('Maharashtra')),
                DropdownMenuItem(value: 'DL', child: Text('Delhi')),
              ],
              onChanged: null,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Village / Town / City',
                hintText: 'Enter your village, town, or city',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.passwordSetup),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguagePreferencesScreen extends StatelessWidget {
  const LanguagePreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Languages You Speak')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: ['English', 'Hindi', 'Tamil', 'Telugu'].map((lang) {
                return FilterChip(label: Text(lang), onSelected: (_) {});
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.termsAgreement),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TermsAgreementScreen extends StatelessWidget {
  const TermsAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Expanded(child: SingleChildScrollView(child: Text('Terms and conditions text here...'))),
            CheckboxListTile(
              value: false,
              onChanged: (_) {},
              title: const Text('I agree to the Terms of Service'),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.aiProcessing),
                child: const Text('Accept & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIProcessingScreen extends StatelessWidget {
  const AIProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Processing your profile...', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('This may take a moment'),
          ],
        ),
      ),
    );
  }
}

class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text('Registration Complete!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
