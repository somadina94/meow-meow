import 'package:flutter/material.dart';
import '../../../../../core/services/dashboard_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Matches Section for Men's Dashboard
class MatchesSection extends StatelessWidget {
  final List<MatchedUser> matches;
  final bool isLoading;
  final VoidCallback onRefresh;
  final void Function(String userId, String name) onStartChat;
  final void Function(String userId) onViewProfile;

  const MatchesSection({
    super.key,
    required this.matches,
    required this.isLoading,
    required this.onRefresh,
    required this.onStartChat,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(Icons.favorite, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Your Matches', style: Theme.of(context).textTheme.titleMedium),
            ]),
            TextButton.icon(
              onPressed: onRefresh,
              icon: Icon(Icons.refresh, size: 16, color: isLoading ? Colors.grey : null),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.favorite_border, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No matches yet', style: TextStyle(color: Colors.grey.shade600)),
                    Text('Like profiles to start matching!', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onViewProfile(match.userId),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (match.photoUrl != null)
                                  Image.network(match.photoUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.secondary.withOpacity(0.3),
                                      child: const Icon(Icons.person, size: 40),
                                    ),
                                  )
                                else
                                  Container(
                                    color: AppColors.secondary.withOpacity(0.3),
                                    child: const Icon(Icons.person, size: 40),
                                  ),
                                Positioned(
                                  bottom: 4, right: 4,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: match.isOnline ? AppColors.success : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${match.fullName}${match.age != null ? ', ${match.age}' : ''}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  if (match.primaryLanguage != null)
                                    Text(match.primaryLanguage!, style: TextStyle(fontSize: 10, color: AppColors.primary), maxLines: 1),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 24,
                                          child: FilledButton.tonal(
                                            onPressed: () => onStartChat(match.userId, match.fullName),
                                            style: FilledButton.styleFrom(padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 10)),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [Icon(Icons.chat, size: 10), SizedBox(width: 2), Text('Chat')],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        height: 24, width: 30,
                                        child: OutlinedButton(
                                          onPressed: () => onViewProfile(match.userId),
                                          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                                          child: const Icon(Icons.visibility, size: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
