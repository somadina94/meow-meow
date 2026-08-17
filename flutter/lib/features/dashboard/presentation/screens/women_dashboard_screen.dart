import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/models/user_model.dart';
import 'widgets/admin_messages_section.dart';
import 'widgets/admin_chat_section.dart';
import 'women_home_tab.dart';
import 'women_chats_tab.dart';
import 'women_groups_tab.dart';
import 'women_earnings_tab.dart';
import 'women_profile_tab.dart';

/// Women's Dashboard Screen - Synced with React WomenDashboardScreen
/// Updated: Admin messages & chat accessible via AppBar icons (non-blocking)
class WomenDashboardScreen extends ConsumerStatefulWidget {
  const WomenDashboardScreen({super.key});

  @override
  ConsumerState<WomenDashboardScreen> createState() => _WomenDashboardScreenState();
}

class _WomenDashboardScreenState extends ConsumerState<WomenDashboardScreen> {
  int _currentIndex = 0;
  String _userId = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final profileService = ref.read(profileServiceProvider);
    final profile = await profileService.getCurrentProfile();
    if (profile != null && mounted) {
      setState(() {
        _userId = profile.userId;
        _userName = profile.fullName?.split(' ').first ?? 'User';
      });
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
                  Text('Admin Messages', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
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
                  Text('Chat with Admin', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AdminChatSection(userId: _userId, userName: _userName),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐱 Meow Meow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline, size: 20),
            onPressed: _userId.isNotEmpty ? _showAdminMessages : null,
            tooltip: 'Admin Messages',
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 20),
            onPressed: _userId.isNotEmpty ? _showAdminChat : null,
            tooltip: 'Chat with Admin',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          WomenHomeTab(),
          WomenChatsTab(),
          WomenGroupsTab(),
          WomenEarningsTab(),
          WomenProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
