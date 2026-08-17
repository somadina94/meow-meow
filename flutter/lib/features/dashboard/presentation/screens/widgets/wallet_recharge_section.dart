import 'package:flutter/material.dart';
import '../../../../../core/services/dashboard_service.dart';
import '../../../../../core/theme/app_colors.dart';

/// Wallet & Recharge Section for Men's Dashboard
class WalletRechargeSection extends StatefulWidget {
  final double walletBalance;
  final String userId;
  final String userCountry;
  final DashboardService dashboardService;
  final void Function(double newBalance) onBalanceUpdated;

  const WalletRechargeSection({
    super.key,
    required this.walletBalance,
    required this.userId,
    required this.userCountry,
    required this.dashboardService,
    required this.onBalanceUpdated,
  });

  @override
  State<WalletRechargeSection> createState() => _WalletRechargeSectionState();
}

class _WalletRechargeSectionState extends State<WalletRechargeSection> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Balance', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '₹${widget.walletBalance.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : () => _showRechargeDialog(context),
                icon: const Icon(Icons.add_card),
                label: const Text('Recharge'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRechargeDialog(BuildContext context) {
    final amounts = [100, 200, 500, 1000, 2000, 5000];
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recharge Wallet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amounts.map((amt) => ActionChip(
                label: Text('₹$amt'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _processRecharge(amt.toDouble());
                },
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _processRecharge(double amount) async {
    setState(() => _isProcessing = true);
    
    final result = await widget.dashboardService.processRecharge(
      userId: widget.userId,
      amount: amount,
      gatewayName: 'in-app',
    );

    if (result.success && result.newBalance != null) {
      widget.onBalanceUpdated(result.newBalance!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('₹${amount.toStringAsFixed(0)} added to wallet!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Recharge failed')),
        );
      }
    }

    setState(() => _isProcessing = false);
  }
}
