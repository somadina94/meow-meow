import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Forgot Password Screen - Synced with React ForgotPasswordScreen
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await ref.read(authServiceProvider).sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _emailSent = success;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send reset email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _emailSent
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text('Reset email sent!', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Check your inbox for reset instructions.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    AppButton(onPressed: () => context.go(AppRoutes.auth), child: const Text('Back to Login')),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Enter your email to receive a password reset link.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  AppTextField(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 24),
                  AppButton(onPressed: _handleReset, isLoading: _isLoading, child: const Text('Send Reset Link')),
                ],
              ),
      ),
    );
  }
}
