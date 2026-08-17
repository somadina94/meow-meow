import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import 'widgets/online_women_section.dart';
import 'widgets/matches_section.dart';
import 'widgets/men_stats_section.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/notifications_section.dart';
import 'widgets/wallet_recharge_section.dart';
import 'widgets/admin_messages_section.dart';
import 'widgets/admin_chat_section.dart';

/// Home Tab - Main dashboard content for men
/// Synced with React DashboardScreen (mobile-optimized version)
/// Includes admin messages icon and admin chat icon in AppBar
class MenHomeTab extends ConsumerStatefulWidget {
  const MenHomeTab({super.key});

  @override
  ConsumerState<MenHomeTab> createState() => _MenHomeTabState();
}

class _MenHomeTabState extends ConsumerState<MenHomeTab> {
  String _userId = '';
  String _userName = '';
  String? _userPhoto;
  String _userLanguage = 'English';
  String _userCountry = '';
  double _walletBalance = 0;
  int _activeChatCount = 0;
  bool _isOnline = true;
  bool _isLoading = true;

  DashboardStats _stats = DashboardStats(gender: 'male');
  List<OnlineWoman> _sameLanguageWomen = [];
  List<OnlineWoman> _otherLanguageWomen = [];
  List<MatchedUser> _matchedWomen = [];
  List<AppNotification> _notifications = [];
  MenFreeMinutes _freeMinutes = MenFreeMinutes();

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

      // Redirect women to their dashboard
      if (profile.gender?.toLowerCase() == 'female') {
        if (mounted) context.go(AppRoutes.womenDashboard);
        return;
      }

      final languages = await profileService.getUserLanguages(profile.userId);
      final motherTongue = languages.isNotEmpty
          ? languages.first.languageName
          : profile.primaryLanguage ?? profile.preferredLanguage ?? 'English';

      setState(() {
        _userId = profile.userId;
        _userName = profile.fullName?.split(' ').first ?? 'User';
        _userPhoto = profile.photoUrl;
        _userLanguage = motherTongue;
        _userCountry = profile.country ?? '';
      });

      // Fetch all data in parallel
      await Future.wait([
        _fetchStats(),
        _fetchOnlineWomen(),
        _fetchMatches(),
        _fetchNotifications(),
        _fetchFreeMinutes(),
        _fetchWalletBalance(),
      ]);

      // Set online
      await _dashboardService.updateOnlineStatus(_userId, true);

      // Subscribe to realtime
      _subscribeToUpdates();
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStats() async {
    if (_userId.isEmpty) return;
    final stats = await _dashboardService.getDashboardStats(_userId);
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _fetchOnlineWomen() async {
    final women = await _dashboardService.getOnlineWomen();
    if (!mounted) return;

    final same = women
        .where((w) => w.motherTongue.toLowerCase() == _userLanguage.toLowerCase())
        .toList();
    final other = women
        .where((w) => w.motherTongue.toLowerCase() != _userLanguage.toLowerCase())
        .toList();

    same.sort(_sortByBadgeAndLoad);
    other.sort(_sortByBadgeAndLoad);

    setState(() {
      _sameLanguageWomen = same.take(10).toList();
      _otherLanguageWomen = other.take(15).toList();
    });
  }

  int _sortByBadgeAndLoad(OnlineWoman a, OnlineWoman b) {
    if (a.isEarningEligible != b.isEarningEligible) {
      return a.isEarningEligible ? -1 : 1;
    }
    if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
    if (a.isBusy != b.isBusy) return a.isBusy ? 1 : -1;
    return a.currentChatCount.compareTo(b.currentChatCount);
  }

  Future<void> _fetchMatches() async {
    if (_userId.isEmpty) return;
    final matches = await _dashboardService.getMatchedWomen(_userId);
    if (mounted) setState(() => _matchedWomen = matches);
  }

  Future<void> _fetchNotifications() async {
    if (_userId.isEmpty) return;
    final notifs = await _dashboardService.getNotifications(_userId);
    if (mounted) setState(() => _notifications = notifs);
  }

  Future<void> _fetchFreeMinutes() async {
    if (_userId.isEmpty) return;
    final fm = await _dashboardService.getMenFreeMinutes(_userId);
    if (mounted) setState(() => _freeMinutes = fm);
  }

  Future<void> _fetchWalletBalance() async {
    if (_userId.isEmpty) return;
    final balance = await _dashboardService.getMenWalletBalance(_userId);
    if (mounted) setState(() => _walletBalance = balance);
  }

  void _subscribeToUpdates() {
    _dashboardService.subscribeToDashboardUpdates(
      userId: _userId,
      isMale: true,
      onUserStatusChange: () {
        _fetchOnlineWomen();
        _fetchStats();
      },
      onChatSessionChange: () async {
        final count = await _dashboardService.getActiveChatCount(_userId, isMale: true);
        if (mounted) setState(() => _activeChatCount = count);
      },
      onWalletChange: _fetchWalletBalance,
      onAvailabilityChange: _fetchOnlineWomen,
      onNotificationChange: _fetchNotifications,
    );
  }

  Future<void> _handleStartChat(OnlineWoman woman) async {
    if (_activeChatCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max 3 parallel chats. Close one to start a new chat.')),
      );
      return;
    }

    final pricing = await _dashboardService.getChatPricing();
    final minBalance = pricing.ratePerMinute * 2;

    if (_walletBalance < minBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. Need at least ₹${minBalance.toStringAsFixed(0)}')),
      );
      return;
    }

    final result = await _dashboardService.startChatSession(
      manUserId: _userId,
      womanUserId: woman.userId,
      ratePerMinute: pricing.ratePerMinute,
    );

    if (result.success && result.chatId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat started with ${woman.fullName}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to start chat')),
      );
    }
  }

  void _showAdminMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.mail, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Admin Messages',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                child: AdminMessagesSection(userId: _userId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.shield, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Chat with Admin',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AdminChatSection(
                userId: _userId,
                userName: _userName,
              ),
            ),
          ],
        ),
      ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🐱 Meow Meow'),
        actions: [
          // Online toggle
          Switch(
            value: _isOnline,
            onChanged: (val) {
              setState(() => _isOnline = val);
              _dashboardService.updateOnlineStatus(_userId, val);
            },
            activeColor: AppColors.success,
          ),
          // Admin Messages icon (synced with React dashboard header)
          IconButton(
            icon: const Icon(Icons.mail_outline, size: 20),
            onPressed: _showAdminMessages,
            tooltip: 'Admin Messages',
          ),
          // Admin Chat icon (synced with React dashboard header)
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 20),
            onPressed: _showAdminChat,
            tooltip: 'Chat with Admin',
          ),
          IconButton(
            icon: const Icon(Icons.people, size: 20),
            onPressed: () {},
            tooltip: 'Friends & Blocked',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, size: 20),
            onPressed: () => context.push(AppRoutes.wallet),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Status
              _buildWelcomeSection(),
              const SizedBox(height: 16),

              // Admin Messages (inline, non-blocking)
              if (_userId.isNotEmpty)
                AdminMessagesSection(userId: _userId),
              const SizedBox(height: 16),

              // Wallet & Recharge
              WalletRechargeSection(
                walletBalance: _walletBalance,
                userId: _userId,
                userCountry: _userCountry,
                dashboardService: _dashboardService,
                onBalanceUpdated: (balance) => setState(() => _walletBalance = balance),
              ),
              const SizedBox(height: 16),

              // Online Women
              OnlineWomenSection(
                sameLanguageWomen: _sameLanguageWomen,
                otherLanguageWomen: _otherLanguageWomen,
                userLanguage: _userLanguage,
                isLoading: false,
                onRefresh: _fetchOnlineWomen,
                onStartChat: _handleStartChat,
                onViewProfile: (userId) => context.push('/profile/$userId'),
              ),
              const SizedBox(height: 16),

              // Matches
              MatchesSection(
                matches: _matchedWomen,
                isLoading: false,
                onRefresh: _fetchMatches,
                onStartChat: (userId, name) async {
                  final woman = _sameLanguageWomen.firstWhere(
                    (w) => w.userId == userId,
                    orElse: () => OnlineWoman(userId: userId, fullName: name, motherTongue: ''),
                  );
                  await _handleStartChat(woman);
                },
                onViewProfile: (userId) => context.push('/profile/$userId'),
              ),
              const SizedBox(height: 16),

              // Stats
              MenStatsSection(stats: _stats, activeChatCount: _activeChatCount),
              const SizedBox(height: 16),

              // Free Minutes
              if (_freeMinutes.hasFreeMinutes) ...[
                _buildFreeMinutesBadge(),
                const SizedBox(height: 16),
              ],

              // Quick Actions
              QuickActionsGrid(
                actions: [
                  QuickAction(icon: Icons.search, label: 'Find Match', onTap: () => context.push(AppRoutes.findMatch)),
                  QuickAction(icon: Icons.chat, label: 'Messages', onTap: () => context.push(AppRoutes.matchDiscovery)),
                  QuickAction(icon: Icons.favorite, label: 'Matches', onTap: () => context.push(AppRoutes.matchDiscovery)),
                  QuickAction(icon: Icons.person, label: 'Profile', onTap: () {}),
                ],
              ),
              const SizedBox(height: 16),

              // Notifications
              NotificationsSection(
                notifications: _notifications,
                onViewAll: () {},
              ),
              const SizedBox(height: 16),

              // Transaction History
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, size: 20),
                  title: const Text('Transaction History'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  dense: true,
                  onTap: () => context.push(AppRoutes.transactionHistory),
                ),
              ),

              // CTA Banner
              const SizedBox(height: 16),
              Card(
                color: AppColors.primary.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Boost your profile!', style: Theme.of(context).textTheme.titleSmall),
                            Text('Get more matches with premium features',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => context.push(AppRoutes.wallet),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                ),
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
        AppAvatar(
          imageUrl: _userPhoto,
          name: _userName,
          radius: 22,
          isOnline: _isOnline,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $_userName! 👋',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Ready to make new connections?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _activeChatCount >= 3
                ? Colors.red.withOpacity(0.1)
                : AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _activeChatCount >= 3 ? Colors.red : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _activeChatCount >= 3 ? 'Busy(3)' : 'Available',
                style: TextStyle(
                  color: _activeChatCount >= 3 ? Colors.red : AppColors.success,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFreeMinutesBadge() {
    return Card(
      color: AppColors.info.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.timer, color: AppColors.info, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Free Chat Minutes', style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${_freeMinutes.freeMinutesRemaining} of ${_freeMinutes.freeMinutesTotal} remaining',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_freeMinutes.nextResetAt != null)
                    Text(
                      'Resets: ${_freeMinutes.nextResetAt!.day}/${_freeMinutes.nextResetAt!.month}/${_freeMinutes.nextResetAt!.year}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
