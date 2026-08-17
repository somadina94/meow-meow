import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../widgets/theme_selector_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationSound = true;
  bool _notificationVibration = true;
  bool _showOnlineStatus = true;
  bool _autoTranslate = true;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader('Account', colorScheme),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Verify Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // Notifications Section
          _buildSectionHeader('Notifications', colorScheme),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('Notification Sound'),
            value: _notificationSound,
            onChanged: (value) => setState(() => _notificationSound = value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibration'),
            value: _notificationVibration,
            onChanged: (value) => setState(() => _notificationVibration = value),
          ),

          // Privacy Section
          _buildSectionHeader('Privacy', colorScheme),
          SwitchListTile(
            secondary: const Icon(Icons.visibility),
            title: const Text('Show Online Status'),
            subtitle: const Text('Let others see when you\'re online'),
            value: _showOnlineStatus,
            onChanged: (value) => setState(() => _showOnlineStatus = value),
          ),

          // Language Section
          _buildSectionHeader('Language & Translation', colorScheme),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('App Language'),
            subtitle: Text(_getLanguageName(locale.languageCode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: const Text('Auto-translate Messages'),
            subtitle: const Text('Automatically translate incoming messages'),
            value: _autoTranslate,
            onChanged: (value) => setState(() => _autoTranslate = value),
          ),

          // Appearance Section - Now uses ThemeSelectorWidget with 20 themes
          _buildSectionHeader('Appearance', colorScheme),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ThemeSelectorWidget(),
          ),

          // Support Section
          _buildSectionHeader('Support', colorScheme),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {},
          ),

          // Danger Zone
          _buildSectionHeader('Account Actions', colorScheme),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.tertiary),
            title: const Text('Sign Out'),
            onTap: () => _showSignOutDialog(),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: colorScheme.error),
            title: Text('Delete Account', style: TextStyle(color: colorScheme.error)),
            onTap: () => _showDeleteAccountDialog(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
            ),
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = {
      'en': 'English',
      'hi': 'Hindi',
      'ar': 'Arabic',
      'bn': 'Bengali',
      'es': 'Spanish',
      'fr': 'French',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ur': 'Urdu',
      'zh': 'Chinese',
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final code = languages.keys.elementAt(index);
                final name = languages.values.elementAt(index);
                final isSelected = ref.read(localeProvider).languageCode == code;

                return ListTile(
                  title: Text(name),
                  trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocaleByCode(code);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSignOutDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authServiceProvider).signOut();
                if (mounted) context.go(AppRoutes.auth);
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action cannot be undone. All your data will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please contact support to delete your account')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageName(String code) {
    final languages = {
      'en': 'English',
      'hi': 'Hindi',
      'ar': 'Arabic',
      'bn': 'Bengali',
      'es': 'Spanish',
      'fr': 'French',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ur': 'Urdu',
      'zh': 'Chinese',
    };
    return languages[code] ?? 'English';
  }
}
