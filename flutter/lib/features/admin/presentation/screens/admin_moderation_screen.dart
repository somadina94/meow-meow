import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/theme/app_colors.dart';

/// Admin Moderation Screen - Synced with React AdminModerationScreen
class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen> {
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    final pending = await ref.read(adminServiceProvider).getPendingWomenApprovals();
    if (mounted) setState(() { _pendingApprovals = pending; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderation')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingApprovals.isEmpty
              ? const EmptyState(icon: Icons.check_circle, title: 'No pending approvals')
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingApprovals.length,
                    itemBuilder: (context, index) {
                      final profile = _pendingApprovals[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppAvatar(imageUrl: profile['photo_url'], name: profile['full_name']),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(profile['full_name'] ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                                        Text(profile['country'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      await ref.read(adminServiceProvider).updateWomanApproval(profile['user_id'], false, reason: 'Rejected by admin');
                                      _loadPending();
                                    },
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await ref.read(adminServiceProvider).updateWomanApproval(profile['user_id'], true);
                                      _loadPending();
                                    },
                                    child: const Text('Approve'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
