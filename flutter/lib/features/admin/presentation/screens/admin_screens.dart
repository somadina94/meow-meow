import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

// ============================================================================
// Admin Analytics Dashboard
// ============================================================================

class AdminAnalyticsDashboard extends ConsumerStatefulWidget {
  const AdminAnalyticsDashboard({super.key});

  @override
  ConsumerState<AdminAnalyticsDashboard> createState() => _AdminAnalyticsDashboardState();
}

class _AdminAnalyticsDashboardState extends ConsumerState<AdminAnalyticsDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final response = await _supabase
          .from('platform_metrics')
          .select()
          .order('metric_date', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        _metrics = response ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildChartPlaceholder('User Growth'),
                    const SizedBox(height: 24),
                    _buildChartPlaceholder('Revenue Overview'),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Total Users', '${_metrics['total_users'] ?? 0}', Icons.people),
        _buildMetricCard('Active Users', '${_metrics['active_users'] ?? 0}', Icons.person),
        _buildMetricCard('Total Revenue', '₹${_metrics['admin_profit'] ?? 0}', Icons.currency_rupee),
        _buildMetricCard('Active Chats', '${_metrics['active_chats'] ?? 0}', Icons.chat),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder(String title) {
    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Expanded(
              child: Center(child: Text('Chart visualization\n(Use fl_chart package)', textAlign: TextAlign.center)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Admin User Management
// ============================================================================

class AdminUserManagement extends ConsumerStatefulWidget {
  const AdminUserManagement({super.key});

  @override
  ConsumerState<AdminUserManagement> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends ConsumerState<AdminUserManagement> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['photo_url'] != null ? NetworkImage(user['photo_url']) : null,
                          child: user['photo_url'] == null ? Text((user['full_name'] ?? 'U')[0]) : null,
                        ),
                        title: Text(user['full_name'] ?? 'Unknown'),
                        subtitle: Text('${user['gender'] ?? ''} • ${user['country'] ?? ''}'),
                        trailing: Chip(
                          label: Text(user['account_status'] ?? 'active'),
                          backgroundColor: user['account_status'] == 'active'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                        ),
                        onTap: () => _showUserActions(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showUserActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Profile'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Suspend User'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete User'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Admin Finance Dashboard
// ============================================================================

class AdminFinanceDashboard extends ConsumerStatefulWidget {
  const AdminFinanceDashboard({super.key});

  @override
  ConsumerState<AdminFinanceDashboard> createState() => _AdminFinanceDashboardState();
}

class _AdminFinanceDashboardState extends ConsumerState<AdminFinanceDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _financeData = {};

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    try {
      final response = await _supabase
          .from('platform_metrics')
          .select()
          .order('metric_date', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        _financeData = response ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFinanceCard('Total Revenue', '₹${_financeData['admin_profit'] ?? 0}', Colors.green),
                  _buildFinanceCard('Men Recharges', '₹${_financeData['men_recharges'] ?? 0}', Colors.blue),
                  _buildFinanceCard('Women Earnings', '₹${_financeData['women_earnings'] ?? 0}', Colors.purple),
                  _buildFinanceCard('Gift Revenue', '₹${_financeData['gift_revenue'] ?? 0}', Colors.orange),
                  _buildFinanceCard('Video Revenue', '₹${_financeData['video_call_revenue'] ?? 0}', Colors.red),
                ],
              ),
            ),
    );
  }

  Widget _buildFinanceCard(String title, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.currency_rupee, color: color)),
        title: Text(title),
        trailing: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

// ============================================================================
// Admin Moderation Screen
// ============================================================================

class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final response = await _supabase
          .from('moderation_reports')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Moderation')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('No pending reports'))
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          child: const Icon(Icons.flag, color: Colors.red),
                        ),
                        title: Text(report['report_type'] ?? 'Report'),
                        subtitle: Text(report['content'] ?? 'No details'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _handleReport(report['id'], 'approved'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _handleReport(report['id'], 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _handleReport(String id, String action) async {
    try {
      await _supabase.from('moderation_reports').update({
        'status': action == 'approved' ? 'actioned' : 'dismissed',
        'action_taken': action,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      _loadReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ============================================================================
// Admin Settings Screen
// ============================================================================

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: ListView(
        children: [
          _buildSection(context, 'Pricing', [
            ListTile(
              leading: const Icon(Icons.chat_bubble),
              title: const Text('Chat Pricing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('Gift Pricing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.video_call),
              title: const Text('Video Call Pricing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          _buildSection(context, 'System', [
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup Management'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit Logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Performance'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          _buildSection(context, 'Content', [
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language Groups'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Legal Documents'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...children,
      ],
    );
  }
}

// ============================================================================
// Admin Audit Logs
// ============================================================================

class AdminAuditLogs extends ConsumerStatefulWidget {
  const AdminAuditLogs({super.key});

  @override
  ConsumerState<AdminAuditLogs> createState() => _AdminAuditLogsState();
}

class _AdminAuditLogsState extends ConsumerState<AdminAuditLogs> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      setState(() {
        _logs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final date = DateTime.tryParse(log['created_at'] ?? '');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(Icons.history, color: AppColors.primary, size: 20),
                  ),
                  title: Text(log['action'] ?? 'Unknown Action'),
                  subtitle: Text(
                    '${log['resource_type'] ?? ''} • ${date != null ? DateFormat('MMM d, h:mm a').format(date) : ''}',
                  ),
                  trailing: Text(log['status'] ?? '', style: const TextStyle(fontSize: 12)),
                );
              },
            ),
    );
  }
}

// ============================================================================
// Admin Chat Monitoring
// ============================================================================

class AdminChatMonitoring extends ConsumerStatefulWidget {
  const AdminChatMonitoring({super.key});

  @override
  ConsumerState<AdminChatMonitoring> createState() => _AdminChatMonitoringState();
}

class _AdminChatMonitoringState extends ConsumerState<AdminChatMonitoring> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeSessions = [];

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
  }

  Future<void> _loadActiveSessions() async {
    try {
      final response = await _supabase
          .from('active_chat_sessions')
          .select()
          .eq('status', 'active')
          .order('last_activity_at', ascending: false)
          .limit(50);

      setState(() {
        _activeSessions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Monitoring'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadActiveSessions),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeSessions.isEmpty
              ? const Center(child: Text('No active chat sessions'))
              : ListView.builder(
                  itemCount: _activeSessions.length,
                  itemBuilder: (context, index) {
                    final session = _activeSessions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.chat)),
                        title: Text('Session ${session['id']?.substring(0, 8) ?? ''}'),
                        subtitle: Text('Duration: ${session['total_minutes'] ?? 0} min'),
                        trailing: Text('₹${session['total_earned'] ?? 0}'),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// Admin Policy Alerts
// ============================================================================

class AdminPolicyAlerts extends ConsumerStatefulWidget {
  const AdminPolicyAlerts({super.key});

  @override
  ConsumerState<AdminPolicyAlerts> createState() => _AdminPolicyAlertsState();
}

class _AdminPolicyAlertsState extends ConsumerState<AdminPolicyAlerts> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final response = await _supabase
          .from('policy_violation_alerts')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _alerts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policy Alerts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(child: Text('No pending alerts'))
              : ListView.builder(
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    final severity = alert['severity'] ?? 'medium';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: severity == 'high'
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          child: Icon(
                            Icons.warning,
                            color: severity == 'high' ? Colors.red : Colors.orange,
                          ),
                        ),
                        title: Text(alert['violation_type'] ?? 'Unknown'),
                        subtitle: Text(alert['content'] ?? 'No details'),
                        trailing: Chip(
                          label: Text(severity.toString().toUpperCase()),
                          backgroundColor: severity == 'high'
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
