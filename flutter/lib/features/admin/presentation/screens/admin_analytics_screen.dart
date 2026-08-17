import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Admin Analytics Screen - Synced with React AdminAnalyticsDashboard
class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  Map<String, double> _revenue = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final revenue = await ref.read(adminServiceProvider).getRevenueSummary();
    if (mounted) setState(() { _revenue = revenue; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Revenue Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _revenueCard('Total Revenue', _revenue['grandTotal'] ?? 0, Icons.account_balance, AppColors.primary),
                  _revenueCard('Recharge Revenue', _revenue['totalRecharge'] ?? 0, Icons.payment, AppColors.success),
                  _revenueCard('Chat Revenue', _revenue['totalChatRevenue'] ?? 0, Icons.chat, AppColors.info),
                  _revenueCard('Video Revenue', _revenue['totalVideoRevenue'] ?? 0, Icons.videocam, AppColors.warning),
                  _revenueCard('Gift Revenue', _revenue['totalGiftRevenue'] ?? 0, Icons.card_giftcard, AppColors.female),
                ],
              ),
            ),
    );
  }

  Widget _revenueCard(String label, double amount, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(label),
        trailing: Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
