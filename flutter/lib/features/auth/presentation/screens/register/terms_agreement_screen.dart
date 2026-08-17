import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Terms Agreement Screen - Synced with React TermsAgreementScreen
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _agreedTerms = false;
  bool _agreedPrivacy = false;
  bool _agreedAge = false;

  @override
  Widget build(BuildContext context) {
    final allAgreed = _agreedTerms && _agreedPrivacy && _agreedAge;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Please review and accept', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _agreedTerms,
              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
              title: const Text('I agree to the Terms of Service'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _agreedPrivacy,
              onChanged: (v) => setState(() => _agreedPrivacy = v ?? false),
              title: const Text('I agree to the Privacy Policy'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _agreedAge,
              onChanged: (v) => setState(() => _agreedAge = v ?? false),
              title: const Text('I confirm I am 18 years or older'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            AppButton(
              onPressed: allAgreed ? () => context.push(AppRoutes.aiProcessing) : null,
              child: const Text('Accept & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
