// Placeholder screens for remaining features

import 'package:flutter/material.dart';

// Matching screens
class MatchDiscoveryScreen extends StatelessWidget {
  const MatchDiscoveryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Discover')), body: const Center(child: Text('Match Discovery')));
}

class OnlineUsersScreen extends StatelessWidget {
  const OnlineUsersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Online Users')), body: const Center(child: Text('Online Users')));
}

// Wallet screens
class WomenWalletScreen extends StatelessWidget {
  const WomenWalletScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Earnings')), body: const Center(child: Text('Women Wallet')));
}

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Transaction History')), body: const Center(child: Text('Transactions')));
}

// Shift screens
class ShiftManagementScreen extends StatelessWidget {
  const ShiftManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Shift Management')), body: const Center(child: Text('Shifts')));
}

class ShiftComplianceScreen extends StatelessWidget {
  const ShiftComplianceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Compliance')), body: const Center(child: Text('Compliance')));
}

// Admin screens
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Analytics')), body: const Center(child: Text('Analytics')));
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Users')), body: const Center(child: Text('User Management')));
}

class AdminFinanceScreen extends StatelessWidget {
  const AdminFinanceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Finance')), body: const Center(child: Text('Finance')));
}

class AdminModerationScreen extends StatelessWidget {
  const AdminModerationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Moderation')), body: const Center(child: Text('Moderation')));
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Admin Settings')), body: const Center(child: Text('Settings')));
}

// Shared screens
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error, size: 64), const SizedBox(height: 16), const Text('Page Not Found')])));
}

class ApprovalPendingScreen extends StatelessWidget {
  const ApprovalPendingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.hourglass_empty, size: 64), const SizedBox(height: 16), const Text('Approval Pending')])));
}

class WelcomeTutorialScreen extends StatelessWidget {
  const WelcomeTutorialScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.waving_hand, size: 64), const SizedBox(height: 16), const Text('Welcome!')])));
}
