import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/matching_service.dart';
import '../../../../shared/models/match_model.dart';
import '../../../../shared/widgets/common_widgets.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  MatchFilters _filters = const MatchFilters();
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Match'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.close : Icons.tune),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showFilters ? null : 0,
            child: _showFilters ? _buildFiltersPanel() : null,
          ),

          // Results
          Expanded(
            child: _MatchResults(filters: _filters),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Age Range', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Min'),
                  value: _filters.minAge ?? 18,
                  items: List.generate(43, (i) => i + 18)
                      .map((age) => DropdownMenuItem(value: age, child: Text('$age')))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _filters = _filters.copyWith(minAge: value));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Max'),
                  value: _filters.maxAge ?? 60,
                  items: List.generate(43, (i) => i + 18)
                      .map((age) => DropdownMenuItem(value: age, child: Text('$age')))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _filters = _filters.copyWith(maxAge: value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: _filters.onlineOnly ?? false,
                  onChanged: (value) {
                    setState(() => _filters = _filters.copyWith(onlineOnly: value));
                  },
                  title: const Text('Online only'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  value: _filters.verifiedOnly ?? false,
                  onChanged: (value) {
                    setState(() => _filters = _filters.copyWith(verifiedOnly: value));
                  },
                  title: const Text('Verified only'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _filters = const MatchFilters());
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showFilters = false),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchResults extends ConsumerWidget {
  final MatchFilters filters;

  const _MatchResults({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) return const SizedBox();

        final matchingService = ref.watch(matchingServiceProvider);
        return FutureBuilder(
          future: matchingService.findMatches(
            userId: user.id,
            filters: filters,
            limit: 50,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final matches = snapshot.data ?? [];
            if (matches.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off,
                title: 'No matches found',
                subtitle: 'Try adjusting your filters',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return _MatchCard(match: match);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(icon: Icons.error, title: 'Error loading'),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchProfileModel match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/profile/${match.userId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: match.photoUrl != null
                    ? Image.network(
                        match.photoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.secondary,
                        child: const Icon(Icons.person, size: 40),
                      ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${match.fullName ?? "User"}, ${match.age ?? 0}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (match.isVerified)
                          const Icon(Icons.verified, size: 18, color: AppColors.info),
                        if (match.isOnline) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.online,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (match.state != null || match.country != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Text(
                            [match.state, match.country].where((s) => s != null).join(', '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getMatchColor(match.matchScore).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${match.matchScore}% Match',
                            style: TextStyle(
                              color: _getMatchColor(match.matchScore),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (match.commonInterests.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${match.commonInterests.length} common interests',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action
              IconButton(
                icon: const Icon(Icons.chat, color: AppColors.primary),
                onPressed: () {
                  // Start chat
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMatchColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.warning;
    return AppColors.mutedForeground;
  }
}
