import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/password_reset_screen.dart';
import '../../features/auth/presentation/screens/register/language_country_screen.dart';
import '../../features/auth/presentation/screens/register/basic_info_screen.dart';
import '../../features/auth/presentation/screens/register/password_setup_screen.dart';
import '../../features/auth/presentation/screens/register/photo_upload_screen.dart';
import '../../features/auth/presentation/screens/register/location_setup_screen.dart';
import '../../features/auth/presentation/screens/register/language_preferences_screen.dart';
import '../../features/auth/presentation/screens/register/terms_agreement_screen.dart';
import '../../features/auth/presentation/screens/register/ai_processing_screen.dart';
import '../../features/auth/presentation/screens/register/registration_complete_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/women_dashboard_screen.dart';
import '../../features/matching/presentation/screens/matching_screen.dart';
import '../../features/matching/presentation/screens/match_discovery_screen.dart';
import '../../features/matching/presentation/screens/online_users_screen.dart';
import '../../features/profile/presentation/screens/profile_detail_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/wallet/presentation/screens/women_wallet_screen.dart';
import '../../features/wallet/presentation/screens/transaction_history_screen.dart';
import '../../features/gifts/presentation/screens/gift_sending_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shifts/presentation/screens/shift_management_screen.dart';
import '../../features/shifts/presentation/screens/shift_compliance_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/screens/admin_finance_screen.dart';
import '../../features/admin/presentation/screens/admin_moderation_screen.dart';
import '../../features/admin/presentation/screens/admin_settings_screen.dart';
import '../../features/admin/presentation/screens/admin_payout_screen.dart';
import '../../features/admin/presentation/screens/admin_chat_monitoring_screen.dart';
import '../../features/admin/presentation/screens/admin_language_groups_screen.dart';
import '../../features/admin/presentation/screens/admin_language_limits_screen.dart';
import '../../features/admin/presentation/screens/admin_kyc_management_screen.dart';
import '../../features/admin/presentation/screens/admin_user_lookup_screen.dart';
import '../../features/admin/presentation/screens/admin_policy_alerts_screen.dart';
import '../../features/admin/presentation/screens/admin_performance_screen.dart';
import '../../features/admin/presentation/screens/admin_legal_documents_screen.dart';
import '../../features/admin/presentation/screens/admin_backups_screen.dart';
import '../../features/admin/presentation/screens/admin_audit_logs_screen.dart';
import '../../features/admin/presentation/screens/admin_messaging_screen.dart';
import '../../features/admin/presentation/screens/admin_enable_disable_screen.dart';
import '../../features/video_call/presentation/screens/incoming_call_screen.dart';
import '../../features/video_call/presentation/screens/video_call_screen.dart';
import '../../features/private_groups/presentation/screens/private_groups_list_screen.dart';
import '../../features/private_groups/presentation/screens/private_group_call_screen.dart';
import '../../features/profile/presentation/screens/friends_screen.dart';
import '../../features/profile/presentation/screens/blocked_users_screen.dart';
import '../../features/wallet/presentation/screens/wallet_statement_export_screen.dart';
import '../../features/chat/presentation/screens/language_group_chat_screen.dart';
import '../../features/kyc/presentation/screens/kyc_screen.dart';
import '../../features/wallet/presentation/screens/recharge_screen.dart';
import '../../shared/screens/not_found_screen.dart';
import '../../shared/screens/approval_pending_screen.dart';
import '../../shared/screens/welcome_tutorial_screen.dart';
import '../services/auth_service.dart';
import 'navigation_key.dart';

/// App Route Names - Synced with React constants/index.ts ROUTES
class AppRoutes {
  AppRoutes._();

  static const String auth = '/';
  static const String forgotPassword = '/forgot-password';
  static const String passwordReset = '/password-reset';
  static const String register = '/register';
  static const String basicInfo = '/basic-info';
  static const String passwordSetup = '/password-setup';
  static const String photoUpload = '/photo-upload';
  static const String locationSetup = '/location-setup';
  static const String languagePreferences = '/language-preferences';
  static const String termsAgreement = '/terms-agreement';
  static const String aiProcessing = '/ai-processing';
  static const String registrationComplete = '/registration-complete';
  static const String welcomeTutorial = '/welcome-tutorial';
  static const String approvalPending = '/approval-pending';
  static const String dashboard = '/dashboard';
  static const String womenDashboard = '/women-dashboard';
  static const String onlineUsers = '/online-users';
  static const String findMatch = '/find-match';
  static const String matchDiscovery = '/match-discovery';
  static const String profile = '/profile/:userId';
  static const String chat = '/chat/:partnerId';
  static const String wallet = '/wallet';
  static const String womenWallet = '/women-wallet';
  static const String transactionHistory = '/transaction-history';
  static const String sendGift = '/send-gift/:receiverId';
  static const String settings = '/settings';
  static const String shiftManagement = '/shift-management';
  static const String shiftCompliance = '/shift-compliance';
  static const String admin = '/admin';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminUsers = '/admin/users';
  static const String adminFinance = '/admin/finance';
  static const String adminModeration = '/admin/moderation';
  static const String adminSettings = '/admin/settings';
  static const String adminPayouts = '/admin/payouts';
  static const String adminChatMonitoring = '/admin/chat-monitoring';
  static const String adminLanguages = '/admin/languages';
  static const String adminLanguageLimits = '/admin/language-limits';
  static const String adminKyc = '/admin/kyc';
  static const String adminUserLookup = '/admin/user-lookup';
  static const String adminPolicyAlerts = '/admin/policy-alerts';
  static const String adminPerformance = '/admin/performance';
  static const String adminLegalDocuments = '/admin/legal-documents';
  static const String adminBackups = '/admin/backups';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminMessaging = '/admin/messaging';
  static const String adminEnableDisable = '/admin/enable-disable';
  static const String incomingCall = '/incoming-call';
  static const String videoCall = '/video-call';
  static const String privateGroups = '/private-groups';
  static const String privateGroupCall = '/private-groups/:roomId';
  static const String friends = '/friends';
  static const String blockedUsers = '/blocked-users';
  static const String walletStatementExport = '/wallet/export';
  static const String languageGroupChat = '/language-group/:code';
  static const String kyc = '/kyc';
  static const String recharge = '/wallet/recharge';
}

/// App Router Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.auth,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isLoggedIn = await authService.isLoggedIn();
      final isAuthRoute = state.matchedLocation == AppRoutes.auth ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.passwordReset ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation == AppRoutes.basicInfo ||
          state.matchedLocation == AppRoutes.passwordSetup ||
          state.matchedLocation == AppRoutes.photoUpload ||
          state.matchedLocation == AppRoutes.locationSetup ||
          state.matchedLocation == AppRoutes.languagePreferences ||
          state.matchedLocation == AppRoutes.termsAgreement ||
          state.matchedLocation == AppRoutes.aiProcessing ||
          state.matchedLocation == AppRoutes.registrationComplete;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.auth;
      if (isLoggedIn && state.matchedLocation == AppRoutes.auth) return AppRoutes.dashboard;
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // Auth Routes
      GoRoute(path: AppRoutes.auth, builder: (_, __) => const AuthScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.passwordReset, builder: (_, __) => const PasswordResetScreen()),
      
      // Registration Routes
      GoRoute(path: AppRoutes.register, builder: (_, __) => const LanguageCountryScreen()),
      GoRoute(path: AppRoutes.basicInfo, builder: (_, __) => const BasicInfoScreen()),
      GoRoute(path: AppRoutes.passwordSetup, builder: (_, __) => const PasswordSetupScreen()),
      GoRoute(path: AppRoutes.photoUpload, builder: (_, __) => const PhotoUploadScreen()),
      GoRoute(path: AppRoutes.locationSetup, builder: (_, __) => const LocationSetupScreen()),
      GoRoute(path: AppRoutes.languagePreferences, builder: (_, __) => const LanguagePreferencesScreen()),
      GoRoute(path: AppRoutes.termsAgreement, builder: (_, __) => const TermsAgreementScreen()),
      GoRoute(path: AppRoutes.aiProcessing, builder: (_, __) => const AIProcessingScreen()),
      GoRoute(path: AppRoutes.registrationComplete, builder: (_, __) => const RegistrationCompleteScreen()),
      GoRoute(path: AppRoutes.welcomeTutorial, builder: (_, __) => const WelcomeTutorialScreen()),
      GoRoute(path: AppRoutes.approvalPending, builder: (_, __) => const ApprovalPendingScreen()),
      
      // Dashboard Routes
      GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const DashboardScreen()),
      GoRoute(path: AppRoutes.womenDashboard, builder: (_, __) => const WomenDashboardScreen()),
      
      // Matching Routes
      GoRoute(path: AppRoutes.onlineUsers, builder: (_, __) => const OnlineUsersScreen()),
      GoRoute(path: AppRoutes.findMatch, builder: (_, __) => const MatchingScreen()),
      GoRoute(path: AppRoutes.matchDiscovery, builder: (_, __) => const MatchDiscoveryScreen()),
      
      // Profile Routes
      GoRoute(path: AppRoutes.profile, builder: (_, state) => ProfileDetailScreen(userId: state.pathParameters['userId']!)),
      
      // Chat Routes
      GoRoute(path: AppRoutes.chat, builder: (_, state) => ChatScreen(chatId: state.pathParameters['partnerId']!)),
      
      // Wallet Routes
      GoRoute(path: AppRoutes.wallet, builder: (_, __) => const WalletScreen()),
      GoRoute(path: AppRoutes.womenWallet, builder: (_, __) => const WomenWalletScreen()),
      GoRoute(path: AppRoutes.transactionHistory, builder: (_, __) => const TransactionHistoryScreen()),
      
      // Gift Routes
      GoRoute(path: AppRoutes.sendGift, builder: (_, state) => GiftSendingScreen(receiverId: state.pathParameters['receiverId']!)),
      
      // Settings Routes
      GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
      
      // Shift Routes
      GoRoute(path: AppRoutes.shiftManagement, builder: (_, __) => const ShiftManagementScreen()),
      GoRoute(path: AppRoutes.shiftCompliance, builder: (_, __) => const ShiftComplianceScreen()),
      
      // Admin Routes
      GoRoute(path: AppRoutes.admin, builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: AppRoutes.adminAnalytics, builder: (_, __) => const AdminAnalyticsScreen()),
      GoRoute(path: AppRoutes.adminUsers, builder: (_, __) => const AdminUsersScreen()),
      GoRoute(path: AppRoutes.adminFinance, builder: (_, __) => const AdminFinanceScreen()),
      GoRoute(path: AppRoutes.adminModeration, builder: (_, __) => const AdminModerationScreen()),
      GoRoute(path: AppRoutes.adminSettings, builder: (_, __) => const AdminSettingsScreen()),
      GoRoute(path: AppRoutes.adminPayouts, builder: (_, __) => const AdminPayoutScreen()),
      GoRoute(path: AppRoutes.adminChatMonitoring, builder: (_, __) => const AdminChatMonitoringScreen()),
      GoRoute(path: AppRoutes.adminLanguages, builder: (_, __) => const AdminLanguageGroupsScreen()),
      GoRoute(path: AppRoutes.adminLanguageLimits, builder: (_, __) => const AdminLanguageLimitsScreen()),
      GoRoute(path: AppRoutes.adminKyc, builder: (_, __) => const AdminKycManagementScreen()),
      GoRoute(path: AppRoutes.adminUserLookup, builder: (_, __) => const AdminUserLookupScreen()),
      GoRoute(path: AppRoutes.adminPolicyAlerts, builder: (_, __) => const AdminPolicyAlertsScreen()),
      GoRoute(path: AppRoutes.adminPerformance, builder: (_, __) => const AdminPerformanceScreen()),
      GoRoute(path: AppRoutes.adminLegalDocuments, builder: (_, __) => const AdminLegalDocumentsScreen()),
      GoRoute(path: AppRoutes.adminBackups, builder: (_, __) => const AdminBackupsScreen()),
      GoRoute(path: AppRoutes.adminAuditLogs, builder: (_, __) => const AdminAuditLogsScreen()),
      GoRoute(path: AppRoutes.adminMessaging, builder: (_, __) => const AdminMessagingScreen()),
      GoRoute(path: AppRoutes.adminEnableDisable, builder: (_, __) => const AdminEnableDisableScreen()),

      // Calls
      GoRoute(
        path: AppRoutes.incomingCall,
        builder: (_, state) {
          final e = state.extra as Map<String, dynamic>;
          return IncomingCallScreen(
            callId: e['callId'] as String,
            callerId: e['callerId'] as String,
            callerName: e['callerName'] as String,
            callerAvatar: e['callerAvatar'] as String?,
            isVideo: (e['isVideo'] as bool?) ?? true,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.videoCall,
        builder: (_, state) {
          final e = state.extra as Map<String, dynamic>;
          return VideoCallScreen(
            callId: e['callId'] as String,
            peerId: e['peerId'] as String,
            peerName: e['peerName'] as String,
            isCaller: (e['isCaller'] as bool?) ?? true,
          );
        },
      ),

      // Private groups
      GoRoute(
        path: AppRoutes.privateGroups,
        builder: (_, state) => PrivateGroupsListScreen(
          isMale: ((state.extra as Map?)?['isMale'] as bool?) ?? true,
        ),
      ),
      GoRoute(
        path: AppRoutes.privateGroupCall,
        builder: (_, state) {
          final e = (state.extra as Map?) ?? {};
          return PrivateGroupCallScreen(
            roomId: state.pathParameters['roomId']!,
            roomName: (e['roomName'] as String?) ?? 'Room',
            isHost: (e['isHost'] as bool?) ?? false,
          );
        },
      ),

      // Profile relationships
      GoRoute(path: AppRoutes.friends, builder: (_, __) => const FriendsScreen()),
      GoRoute(path: AppRoutes.blockedUsers, builder: (_, __) => const BlockedUsersScreen()),

      // Wallet extras
      GoRoute(path: AppRoutes.walletStatementExport, builder: (_, __) => const WalletStatementExportScreen()),
      GoRoute(path: AppRoutes.recharge, builder: (_, __) => const RechargeScreen()),

      // KYC
      GoRoute(path: AppRoutes.kyc, builder: (_, __) => const KycScreen()),

      // Language group chat
      GoRoute(
        path: AppRoutes.languageGroupChat,
        builder: (_, state) {
          final e = (state.extra as Map?) ?? {};
          return LanguageGroupChatScreen(
            languageCode: state.pathParameters['code']!,
            languageName: (e['languageName'] as String?) ?? state.pathParameters['code']!,
          );
        },
      ),
    ],
  );
});
