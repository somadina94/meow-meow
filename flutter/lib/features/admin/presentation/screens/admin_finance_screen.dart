import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Admin Finance Screen - Synced with React AdminFinanceDashboard
class AdminFinanceScreen extends ConsumerStatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  ConsumerState<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends ConsumerState<AdminFinanceScreen> {
  Map<String, double> _revenue = {};
  PlatformMetrics? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ref.read(adminServiceProvider).getRevenueSummary(),
      ref.read(adminServiceProvider).getPlatformMetrics(),
    ]);
    if (mounted) setState(() {
      _revenue = results[0] as Map<String, double>;
      _metrics = results[1] as PlatformMetrics?;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text('Total Revenue', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          Text('₹${(_revenue['grandTotal'] ?? 0).toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _tile('Men Recharges', '₹${_metrics?.menRecharges.toStringAsFixed(0) ?? '0'}', Icons.payment),
                  _tile('Men Spent', '₹${_metrics?.menSpent.toStringAsFixed(0) ?? '0'}', Icons.shopping_cart),
                  _tile('Women Earnings', '₹${_metrics?.womenEarnings.toStringAsFixed(0) ?? '0'}', Icons.account_balance_wallet),
                  _tile('Pending Withdrawals', '${_metrics?.pendingWithdrawals ?? 0}', Icons.pending),
                  _tile('Completed Withdrawals', '${_metrics?.completedWithdrawals ?? 0}', Icons.check_circle),
                ],
              ),
            ),
    );
  }

  Widget _tile(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
