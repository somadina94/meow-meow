import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Women's Earnings Tab - synced with React WomenDashboardScreen earnings section
class WomenEarningsTab extends ConsumerStatefulWidget {
  const WomenEarningsTab({super.key});

  @override
  ConsumerState<WomenEarningsTab> createState() => _WomenEarningsTabState();
}

class _WomenEarningsTabState extends ConsumerState<WomenEarningsTab> {
  double _totalBalance = 0;
  double _todayEarnings = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getCurrentProfile();
      if (profile == null) return;

      final dashService = ref.read(dashboardServiceProvider);
      final balance = await dashService.getWomenWalletBalance(profile.userId);
      final today = await dashService.getTodayEarnings(profile.userId);

      if (mounted) {
        setState(() {
          _totalBalance = balance;
          _todayEarnings = today;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.womenWallet),
            child: const Text('Wallet'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Balance Card
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('Total Balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text('₹${_totalBalance.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.womenWallet),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                        child: const Text('Withdraw'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Today's Earnings
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Today's Earnings", style: TextStyle(fontSize: 12)),
                          Text('₹${_todayEarnings.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Earnings breakdown
            Row(
              children: [
                Expanded(child: _EarningTypeCard(icon: Icons.chat, label: 'Chat', amount: '—')),
                const SizedBox(width: 12),
                Expanded(child: _EarningTypeCard(icon: Icons.videocam, label: 'Video', amount: '—')),
                const SizedBox(width: 12),
                Expanded(child: _EarningTypeCard(icon: Icons.card_giftcard, label: 'Gifts', amount: '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;

  const _EarningTypeCard({required this.icon, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(amount, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
