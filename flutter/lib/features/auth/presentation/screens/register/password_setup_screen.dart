import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Password Setup Screen - Synced with React PasswordSetupScreen
class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create a strong password', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('At least 8 characters with uppercase, lowercase, and number', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(controller: _confirmController, label: 'Confirm Password', obscureText: true),
            const Spacer(),
            AppButton(
              onPressed: () {
                if (_passwordController.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min 8 characters')));
                  return;
                }
                if (_passwordController.text != _confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                context.push(AppRoutes.photoUpload);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
