import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import 'widgets/online_men_section.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/notifications_section.dart';

/// Women's Home Tab - Synced with React WomenDashboardScreen
/// Sections:
/// 1. Welcome & Status (online toggle, active chat count)
/// 2. Wallet Balance + Today's Earnings + Top Earner (3 cards)
/// 3. Golden Badge section (Indian women only)
/// 4. Online Men (Premium tabs / Regular tabs)
/// 5. Key Stats (Premium Men, Today's Earnings, Matches)
/// 6. Chat mode info card
/// 7. Quick Actions
/// 8. Notifications
class WomenHomeTab extends ConsumerStatefulWidget {
  const WomenHomeTab({super.key});

  @override
  ConsumerState<WomenHomeTab> createState() => _WomenHomeTabState();
}

class _WomenHomeTabState extends ConsumerState<WomenHomeTab> {
  String _userId = '';
  String _userName = '';
  String? _userPhoto;
  String _womanLanguage = 'English';
  String _womanCountry = '';
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isIndianWoman = false;
  bool _hasGoldenBadge = false;
  String? _goldenBadgeExpiry;
  bool _isPurchasingBadge = false;
  int _activeChatCount = 0;

  // Stats
  double _myWalletBalance = 0;
  double _myTodayEarnings = 0;
  TopEarner? _biggestEarner;
  DashboardStats _stats = DashboardStats(gender: 'female');

  List<OnlineMan> _rechargedMen = [];
  List<OnlineMan> _nonRechargedMen = [];
  List<AppNotification> _notifications = [];

  late final DashboardService _dashboardService;

  @override
  void initState() {
    super.initState();
    _dashboardService = ref.read(dashboardServiceProvider);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getCurrentProfile();

      if (profile == null || !mounted) return;

      // Check approval
      if (profile.gender?.toLowerCase() == 'female' && profile.approvalStatus != 'approved') {
        if (mounted) context.go(AppRoutes.approvalPending);
        return;
      }

      // Redirect men
      if (profile.gender?.toLowerCase() == 'male') {
        if (mounted) context.go(AppRoutes.dashboard);
        return;
      }

      final isIndian = profile.isIndian == true ||
          (profile.country?.toLowerCase().contains('india') ?? false);

      final languages = await profileService.getUserLanguages(profile.userId);
      final motherTongue = languages.isNotEmpty
          ? languages.first.languageName
          : profile.primaryLanguage ?? profile.preferredLanguage ?? 'English';

      setState(() {
        _userId = profile.userId;
        _userName = profile.fullName?.split(' ').first ?? 'User';
        _userPhoto = profile.photoUrl;
        _womanLanguage = motherTongue;
        _womanCountry = profile.country ?? '';
        _isIndianWoman = isIndian;
      });

      // Check golden badge
      final badgeInfo = await _dashboardService.checkGoldenBadge(_userId);
      setState(() {
        _hasGoldenBadge = badgeInfo.hasGoldenBadge;
        _goldenBadgeExpiry = badgeInfo.expiresAt;
      });

      // Fetch all data in parallel
      await Future.wait([
        _fetchOnlineMen(),
        _fetchNotifications(),
        _fetchTodayEarnings(),
        _fetchWalletBalance(),
        _fetchStats(),
        _fetchActiveChatCount(),
      ]);

      await _dashboardService.updateOnlineStatus(_userId, true);
      _subscribeToUpdates();
    } catch (e) {
      debugPrint('Women dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOnlineMen() async {
    final men = await _dashboardService.getOnlineMen(womanLanguage: _womanLanguage);
    if (!mounted) return;

    // Sort: lowest chat count first, then same language, then wallet balance
    men.sort((a, b) {
      if (a.activeChatCount != b.activeChatCount) return a.activeChatCount.compareTo(b.activeChatCount);
      if (a.isSameLanguage != b.isSameLanguage) return a.isSameLanguage ? -1 : 1;
      return b.walletBalance.compareTo(a.walletBalance);
    });

    final recharged = men.where((m) => m.hasRecharged).toList()
      ..sort((a, b) => b.walletBalance.compareTo(a.walletBalance));
    final nonRecharged = men.where((m) => !m.hasRecharged).toList();

    setState(() {
      _rechargedMen = recharged;
      _nonRechargedMen = nonRecharged;
      _stats = DashboardStats(
        gender: 'female',
        onlineCount: men.length,
      );
    });
  }

  Future<void> _fetchNotifications() async {
    if (_userId.isEmpty) return;
    final notifs = await _dashboardService.getNotifications(_userId);
    if (mounted) setState(() => _notifications = notifs);
  }

  Future<void> _fetchTodayEarnings() async {
    if (_userId.isEmpty) return;
    final earnings = await _dashboardService.getTodayEarnings(_userId);
    final topEarner = await _dashboardService.getTopEarnerToday();
    if (mounted) {
      setState(() {
        _myTodayEarnings = earnings;
        _biggestEarner = topEarner;
      });
    }
  }

  Future<void> _fetchWalletBalance() async {
    if (_userId.isEmpty) return;
    final balance = await _dashboardService.getWomenWalletBalance(_userId);
    if (mounted) setState(() => _myWalletBalance = balance);
  }

  Future<void> _fetchStats() async {
    if (_userId.isEmpty) return;
    final stats = await _dashboardService.getDashboardStats(_userId);
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _fetchActiveChatCount() async {
    if (_userId.isEmpty) return;
    final count = await _dashboardService.getActiveChatCount(_userId, isMale: false);
    if (mounted) setState(() => _activeChatCount = count);
  }

  void _subscribeToUpdates() {
    _dashboardService.subscribeToDashboardUpdates(
      userId: _userId,
      isMale: false,
      onUserStatusChange: _fetchOnlineMen,
      onChatSessionChange: () {
        _fetchActiveChatCount();
        _loadDashboard();
      },
      onWalletChange: _fetchWalletBalance,
      onEarningsChange: () {
        _fetchTodayEarnings();
        _fetchWalletBalance();
      },
      onNotificationChange: _fetchNotifications,
    );
  }

  Future<void> _handlePurchaseGoldenBadge() async {
    setState(() => _isPurchasingBadge = true);
    try {
      final result = await _dashboardService.purchaseGoldenBadge(_userId);
      if (result['success'] == true) {
        setState(() {
          _hasGoldenBadge = true;
          _goldenBadgeExpiry = result['expires_at'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🌟 Golden Badge Activated! You can now initiate chats.')),
          );
        }
        _loadDashboard();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Purchase failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasingBadge = false);
    }
  }

  void _handleViewProfile(String userId) {
    context.push('/profile/$userId');
  }

  void _handleStartChat(String userId) {
    if (!_hasGoldenBadge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Women cannot initiate chats. Purchase a Golden Badge to unlock this feature.')),
      );
      return;
    }
    // Golden badge holder can initiate via edge function
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting chat...')),
    );
  }

  @override
  void dispose() {
    if (_userId.isNotEmpty) {
      _dashboardService.updateOnlineStatus(_userId, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🐱 Dashboard'),
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (val) {
              setState(() => _isOnline = val);
              _dashboardService.updateOnlineStatus(_userId, val);
            },
            activeColor: AppColors.success,
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {},
            tooltip: 'Friends & Blocked',
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () => context.push(AppRoutes.shiftManagement),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Status
              _buildWelcomeSection(),
              const SizedBox(height: 16),

              // Wallet Balance + Today's Earnings + Top Earner
              _buildEarningsSummary(),
              const SizedBox(height: 16),

              // Golden Badge Section (Indian women only)
              if (_isIndianWoman) ...[
                _buildGoldenBadgeSection(),
                const SizedBox(height: 16),
              ],

              // Chat Mode Info
              _buildChatModeCard(),
              const SizedBox(height: 16),

              // Online Men (Premium / Regular tabs)
              OnlineMenSection(
                rechargedMen: _rechargedMen,
                nonRechargedMen: _nonRechargedMen,
                womanLanguage: _womanLanguage,
                hasGoldenBadge: _hasGoldenBadge,
                onViewProfile: _handleViewProfile,
                onStartChat: _hasGoldenBadge ? _handleStartChat : null,
              ),
              const SizedBox(height: 20),

              // Key Stats
              _buildWomenStats(),
              const SizedBox(height: 20),

              // Quick Actions
              QuickActionsGrid(
                actions: [
                  QuickAction(icon: Icons.chat, label: 'Messages', onTap: () => context.push(AppRoutes.matchDiscovery)),
                  QuickAction(icon: Icons.account_balance_wallet, label: 'Withdraw', onTap: () => context.push(AppRoutes.womenWallet)),
                  QuickAction(icon: Icons.favorite, label: 'Matches', onTap: () => context.push(AppRoutes.matchDiscovery)),
                  QuickAction(icon: Icons.person, label: 'Profile', onTap: () {}),
                ],
              ),
              const SizedBox(height: 20),

              // Notifications
              NotificationsSection(
                notifications: _notifications,
                onViewAll: () {},
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Row(
      children: [
        AppAvatar(imageUrl: _userPhoto, name: _userName, radius: 24, isOnline: _isOnline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back, $_userName! 👋', style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${_rechargedMen.length + _nonRechargedMen.length} men online right now',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _activeChatCount >= 3 ? Colors.red.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _activeChatCount >= 3 ? Colors.red : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _activeChatCount >= 3 ? 'Busy(3)' : 'Available',
                style: TextStyle(color: _activeChatCount >= 3 ? Colors.red : AppColors.success, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsSummary() {
    return Row(
      children: [
        // Wallet Balance
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: InkWell(
              onTap: () => context.push(AppRoutes.womenWallet),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 6),
                        Text('Balance', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('₹${_myWalletBalance.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Today's Earnings
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.currency_rupee, size: 16, color: Colors.green.shade700),
                      ),
                      const SizedBox(width: 6),
                      Text('Today', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('₹${_myTodayEarnings.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Top Earner
        Expanded(
          child: Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.emoji_events, size: 16, color: Colors.amber.shade700),
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: Text('Top', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_biggestEarner != null) ...[
                    Text(_biggestEarner!.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('₹${_biggestEarner!.amount.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
                  ] else
                    Text('No earnings', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoldenBadgeSection() {
    if (_hasGoldenBadge) {
      return Card(
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.star, color: Colors.amber.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌟 Golden Badge Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                          child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Text('You can initiate chats with men', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    if (_goldenBadgeExpiry != null)
                      Text(
                        'Expires: ${DateTime.tryParse(_goldenBadgeExpiry!)?.toLocal().toString().split(' ').first ?? ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.star, color: Colors.amber.shade500, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌟 Golden Badge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Buy for ₹1,000/month to initiate chats with men',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            FilledButton(
              onPressed: _isPurchasingBadge ? null : _handlePurchaseGoldenBadge,
              child: _isPurchasingBadge
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('₹1,000'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatModeCard() {
    return Card(
      color: AppColors.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.chat, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasGoldenBadge ? 'Chat & Call Mode' : 'Reply Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    _hasGoldenBadge
                        ? 'You can initiate chats & calls, and reply to incoming ones'
                        : 'You can reply to messages from men who start chats with you',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_activeChatCount active', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWomenStats() {
    return Row(
      children: [
        _WomenStatCard(icon: Icons.emoji_events, value: '${_rechargedMen.length}', label: 'Premium Men', color: AppColors.primary),
        const SizedBox(width: 8),
        _WomenStatCard(icon: Icons.currency_rupee, value: '₹${_myTodayEarnings.toStringAsFixed(0)}', label: "Today's Earnings", color: AppColors.success),
        const SizedBox(width: 8),
        _WomenStatCard(icon: Icons.favorite, value: '${_stats.matchCount}', label: 'Matches', color: Colors.pink),
      ].map((w) => Expanded(child: w)).toList(),
    );
  }
}

class _WomenStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _WomenStatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
