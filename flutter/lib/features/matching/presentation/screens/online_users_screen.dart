import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/theme/app_colors.dart';

/// Online Users Screen - Synced with React OnlineUsersScreen
class OnlineUsersScreen extends ConsumerStatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  ConsumerState<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends ConsumerState<OnlineUsersScreen> {
  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOnlineUsers();
  }

  Future<void> _loadOnlineUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('user_id, full_name, photo_url, age, country, gender')
          .eq('account_status', 'active')
          .order('updated_at', ascending: false)
          .limit(50);

      if (mounted) setState(() { _onlineUsers = (response as List).cast<Map<String, dynamic>>(); _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOnlineUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _onlineUsers.length,
                itemBuilder: (context, index) {
                  final user = _onlineUsers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: AppAvatar(imageUrl: user['photo_url'], name: user['full_name'], isOnline: true),
                      title: Text(user['full_name'] ?? 'Unknown'),
                      subtitle: Text([
                        if (user['age'] != null) '${user['age']} yrs',
                        if (user['country'] != null) user['country'],
                      ].join(' • ')),
                      onTap: () => context.push('/profile/${user['user_id']}'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
