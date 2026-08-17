import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/theme/app_colors.dart';

/// Admin Users Screen - Synced with React AdminUserManagement
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _filterGender;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await ref.read(adminServiceProvider).getUsers(
      gender: _filterGender,
      status: _filterStatus,
    );
    if (mounted) setState(() { _users = users; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) { setState(() => _filterGender = v == 'all' ? null : v); _loadUsers(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'male', child: Text('Male')),
              const PopupMenuItem(value: 'female', child: Text('Female')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final status = user['account_status'] ?? 'active';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: AppAvatar(imageUrl: user['photo_url'], name: user['full_name']),
                      title: Text(user['full_name'] ?? 'Unknown'),
                      subtitle: Text([user['gender'], user['country']].where((s) => s != null).join(' • ')),
                      trailing: Chip(
                        label: Text(status, style: const TextStyle(fontSize: 11)),
                        backgroundColor: status == 'active' ? AppColors.success.withOpacity(0.1) : AppColors.destructive.withOpacity(0.1),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
