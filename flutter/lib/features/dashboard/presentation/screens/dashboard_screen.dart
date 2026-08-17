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
import 'widgets/online_women_section.dart';
import 'widgets/matches_section.dart';
import 'widgets/men_stats_section.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/notifications_section.dart';
import 'widgets/wallet_recharge_section.dart';
import 'men_home_tab.dart';
import 'men_matches_tab.dart';
import 'men_chats_tab.dart';
import 'men_profile_tab.dart';
import 'men_groups_tab.dart';

/// Men's Dashboard Screen - Synced with React DashboardScreen
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          MenHomeTab(),
          MenMatchesTab(),
          MenGroupsTab(),
          MenChatsTab(),
          MenProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
