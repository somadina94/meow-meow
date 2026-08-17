import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Wallet recharge screen (men only — funds the chat/call wallet).
///
/// Wallet is credited server-side by the `razorpay-webhook` edge function
/// after Razorpay confirms payment. Do NOT update balance from the client.
class RechargeScreen extends ConsumerStatefulWidget {
  const RechargeScreen({super.key});

  @override
  ConsumerState<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends ConsumerState<RechargeScreen> {
  static const _amounts = [100, 250, 500, 1000, 2000, 5000];
  int? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(paymentServiceProvider).init(
          onSuccess: (r) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment received. Wallet will update shortly.'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop(true);
          },
          onError: (r) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: ${r.message ?? "unknown"}'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _busy = false);
          },
        );
  }

  @override
  void dispose() {
    ref.read(paymentServiceProvider).dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_selected == null || _busy) return;
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;
    if (userId == null) {
      setState(() => _busy = false);
      return;
    }

    final pay = ref.read(paymentServiceProvider);
    final order = await pay.createOrder(
      userId: userId,
      amountInRupees: _selected!,
    );

    if (order == null || !mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start payment. Try again.')),
      );
      return;
    }

    final profile = await ref.read(profileServiceProvider).getProfile(userId);

    pay.openCheckout(
      keyId: order['key_id'] as String,
      orderId: order['order_id'] as String,
      amountInPaise: (order['amount'] as num).toInt(),
      userEmail: profile?.email ?? auth.currentUser?.email ?? '',
      userPhone: profile?.phone ?? '',
      userName: profile?.fullName ?? 'User',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharge Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose an amount',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: _amounts.map((a) {
                  final selected = _selected == a;
                  return InkWell(
                    onTap: () => setState(() => _selected = a),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.15)
                            : null,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('₹$a',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selected == null || _busy ? null : _pay,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_selected == null
                      ? 'Select an amount'
                      : 'Pay ₹$_selected'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Payments are processed by Razorpay. Your wallet is credited '
              'automatically once payment is confirmed.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
