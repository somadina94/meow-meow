import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/matching_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/models/match_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/theme/app_colors.dart';

/// Match Discovery Screen — synced with React MatchDiscoveryScreen.
///
/// Discovery rules: opposite sex only (server-enforced via RPC).
/// Client filters: age range + country (Indian states focus).
class MatchDiscoveryScreen extends ConsumerStatefulWidget {
  const MatchDiscoveryScreen({super.key});

  @override
  ConsumerState<MatchDiscoveryScreen> createState() =>
      _MatchDiscoveryScreenState();
}

class _MatchDiscoveryScreenState
    extends ConsumerState<MatchDiscoveryScreen> {
  List<MatchProfileModel> _all = [];
  bool _isLoading = true;

  RangeValues _ageRange = const RangeValues(18, 60);
  String? _country;
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    final service = ref.read(matchingServiceProvider);
    final suggestions = await service.getMatchSuggestions(userId);
    if (mounted) {
      setState(() {
        _all = suggestions;
        _isLoading = false;
      });
    }
  }

  List<MatchProfileModel> get _filtered => _all.where((m) {
        final age = m.age;
        if (age != null && (age < _ageRange.start || age > _ageRange.end)) {
          return false;
        }
        if (_country != null && m.country != _country) return false;
        if (_verifiedOnly && !m.isVerified) return false;
        return true;
      }).toList();

  Future<void> _openFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Age: ${_ageRange.start.toInt()} – ${_ageRange.end.toInt()}'),
              RangeSlider(
                values: _ageRange,
                min: 18, max: 80, divisions: 62,
                labels: RangeLabels(
                  _ageRange.start.toInt().toString(),
                  _ageRange.end.toInt().toString(),
                ),
                onChanged: (v) => setSheet(() => _ageRange = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _country,
                decoration: const InputDecoration(
                  labelText: 'Country / Region',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 'India', child: Text('India')),
                ],
                onChanged: (v) => setSheet(() => _country = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Verified profiles only'),
                value: _verifiedOnly,
                onChanged: (v) => setSheet(() => _verifiedOnly = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheet(() {
                          _ageRange = const RangeValues(18, 60);
                          _country = null;
                          _verifiedOnly = false;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Matches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: _openFilters,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
              ? const EmptyState(
                  icon: Icons.favorite_border,
                  title: 'No matches found',
                  subtitle: 'Try adjusting your filters',
                )
              : RefreshIndicator(
                  onRefresh: _loadSuggestions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final match = results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: AppAvatar(
                            imageUrl: match.photoUrl,
                            name: match.fullName,
                            radius: 28,
                          ),
                          title: Text(match.fullName ?? 'Unknown'),
                          subtitle: Text([
                            if (match.age != null) '${match.age} yrs',
                            if (match.country != null) match.country!,
                            '${match.matchScore}% match',
                          ].join(' • ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (match.isVerified)
                                Icon(Icons.verified,
                                    color: AppColors.primary, size: 18),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () =>
                              context.push('/profile/${match.userId}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
