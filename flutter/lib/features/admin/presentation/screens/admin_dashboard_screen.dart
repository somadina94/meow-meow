import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Admin Dashboard Screen — synced with React `AdminDashboard.tsx`.
/// Reads latest row from `platform_metrics` (kept current by server cron) and
/// pulls recent rows from `audit_logs` for the Recent Activity feed.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase
            .from('platform_metrics')
            .select()
            .order('metric_date', ascending: false)
            .limit(1)
            .maybeSingle(),
        _supabase
            .from('audit_logs')
            .select('id, action, resource_type, created_at, status')
            .order('created_at', ascending: false)
            .limit(5),
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = (results[0] as Map<String, dynamic>?) ?? {};
        _recentActivity = List<Map<String, dynamic>>.from(results[1] as List);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: const _AdminDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _StatCard(icon: Icons.people, label: 'Total Users', value: '${_metrics['total_users'] ?? 0}', color: AppColors.info),
                        _StatCard(icon: Icons.person, label: 'Active Today', value: '${_metrics['active_users'] ?? 0}', color: AppColors.success),
                        _StatCard(icon: Icons.chat, label: 'Active Chats', value: '${_metrics['active_chats'] ?? 0}', color: AppColors.primary),
                        _StatCard(icon: Icons.currency_rupee, label: 'Admin Profit', value: '₹${_metrics['admin_profit'] ?? 0}', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(label: const Text('Analytics'), onPressed: () => context.go(AppRoutes.adminAnalytics)),
                        ActionChip(label: const Text('User Management'), onPressed: () => context.go(AppRoutes.adminUsers)),
                        ActionChip(label: const Text('Moderation'), onPressed: () => context.go(AppRoutes.adminModeration)),
                        ActionChip(label: const Text('Settings'), onPressed: () => context.go(AppRoutes.adminSettings)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      child: _recentActivity.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No recent activity')),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentActivity.length,
                              itemBuilder: (context, index) {
                                final a = _recentActivity[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: const Icon(Icons.notifications, color: AppColors.primary),
                                  ),
                                  title: Text(a['action']?.toString() ?? 'Activity'),
                                  subtitle: Text('${a['resource_type'] ?? ''} • ${_fmtAgo(a['created_at']?.toString())}'),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  static const _items = <_NavItem>[
    _NavItem('Dashboard', Icons.dashboard, AppRoutes.admin),
    _NavItem('User Management', Icons.people, AppRoutes.adminUsers),
    _NavItem('Analytics', Icons.bar_chart, AppRoutes.adminAnalytics),
    _NavItem('Chat Monitoring', Icons.chat, AppRoutes.adminChatMonitoring),
    _NavItem('Language Groups', Icons.language, AppRoutes.adminLanguages),
    _NavItem('Language Limits', Icons.translate, AppRoutes.adminLanguageLimits),
    _NavItem('KYC Management', Icons.verified_user, AppRoutes.adminKyc),
    _NavItem('User Lookup', Icons.search, AppRoutes.adminUserLookup),
    _NavItem('Moderation', Icons.shield, AppRoutes.adminModeration),
    _NavItem('Policy Alerts', Icons.warning_amber, AppRoutes.adminPolicyAlerts),
    _NavItem('Performance', Icons.speed, AppRoutes.adminPerformance),
    _NavItem('Legal Documents', Icons.description, AppRoutes.adminLegalDocuments),
    _NavItem('Backups', Icons.backup, AppRoutes.adminBackups),
    _NavItem('Audit Logs', Icons.assignment, AppRoutes.adminAuditLogs),
    _NavItem('Messaging', Icons.campaign, AppRoutes.adminMessaging),
    _NavItem('Finance', Icons.attach_money, AppRoutes.adminFinance),
    _NavItem('Payout Statements', Icons.receipt_long, AppRoutes.adminPayouts),
    _NavItem('Enable / Disable', Icons.toggle_on, AppRoutes.adminEnableDisable),
    _NavItem('Settings', Icons.settings, AppRoutes.adminSettings),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(radius: 30, child: Icon(Icons.admin_panel_settings)),
                const SizedBox(height: 8),
                Text('Admin Panel',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          ..._items.map((item) {
            final selected = currentPath == item.path;
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              selected: selected,
              selectedTileColor: AppColors.primary.withOpacity(0.08),
              onTap: () {
                Navigator.pop(context);
                if (!selected) context.go(item.path);
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final String path;
  const _NavItem(this.title, this.icon, this.path);
}
