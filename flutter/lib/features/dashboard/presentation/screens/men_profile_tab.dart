import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Men's Profile Tab
class MenProfileTab extends ConsumerWidget {
  const MenProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading profile')),
        data: (profile) => ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AppAvatar(imageUrl: profile?.photoUrl, name: profile?.fullName, radius: 48),
                  const SizedBox(height: 16),
                  Text(profile?.fullName ?? 'Your Name', style: Theme.of(context).textTheme.titleLarge),
                  if (profile?.age != null)
                    Text('${profile!.age} years old', style: Theme.of(context).textTheme.bodyMedium),
                  if (profile?.country != null || profile?.state != null)
                    Text(
                      [profile?.state, profile?.country].where((s) => s != null && s.isNotEmpty).join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (profile?.primaryLanguage != null)
                    Chip(label: Text(profile!.primaryLanguage!), avatar: const Icon(Icons.language, size: 16)),
                ],
              ),
            ),
            const Divider(),
            if (profile?.bio != null)
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('About'), subtitle: Text(profile!.bio!)),
            if (profile?.occupation != null)
              ListTile(leading: const Icon(Icons.work_outline), title: const Text('Occupation'), subtitle: Text(profile!.occupation!)),
            if (profile?.educationLevel != null)
              ListTile(leading: const Icon(Icons.school_outlined), title: const Text('Education'), subtitle: Text(profile!.educationLevel!)),
            if (profile?.religion != null)
              ListTile(leading: const Icon(Icons.church_outlined), title: const Text('Religion'), subtitle: Text(profile!.religion!)),
            if (profile?.maritalStatus != null)
              ListTile(leading: const Icon(Icons.favorite_outline), title: const Text('Marital Status'), subtitle: Text(profile!.maritalStatus!)),
            const Divider(),
            ListTile(leading: const Icon(Icons.edit), title: const Text('Edit Profile'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
            ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.settings)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.destructive),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.destructive)),
              onTap: () async {
                await authService.signOut();
                if (context.mounted) context.go(AppRoutes.auth);
              },
            ),
          ],
        ),
      ),
    );
  }
}
