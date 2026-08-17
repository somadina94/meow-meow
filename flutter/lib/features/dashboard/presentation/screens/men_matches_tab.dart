import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Men's Matches Tab — women the user has matched with.
/// Uses the same matching logic / RPC as the web app.
class MenMatchesTab extends ConsumerStatefulWidget {
  const MenMatchesTab({super.key});

  @override
  ConsumerState<MenMatchesTab> createState() => _MenMatchesTabState();
}

class _MenMatchesTabState extends ConsumerState<MenMatchesTab> {
  bool _loading = true;
  List<MatchedUser> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profileSvc = ref.read(profileServiceProvider);
      final dashSvc = ref.read(dashboardServiceProvider);
      final profile = await profileSvc.getCurrentProfile();
      if (profile == null) {
        setState(() {
          _matches = [];
          _loading = false;
        });
        return;
      }
      final list = await dashSvc.getMatchedWomen(profile.userId);
      setState(() {
        _matches = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('MenMatchesTab load error: $e');
      setState(() {
        _matches = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _matches.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No matches yet.\nUse Find Match to discover women.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _matches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = _matches[i];
                      return ListTile(
                        leading: AppAvatar(
                          imageUrl: m.photoUrl,
                          name: m.fullName,
                        ),
                        title: Text(m.fullName),
                        subtitle: Text(
                          [m.country, m.primaryLanguage]
                              .where((s) => s != null && s.isNotEmpty)
                              .join(' • '),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.push('/profile/${m.userId}'),
                      );
                    },
                  ),
      ),
    );
  }
}
