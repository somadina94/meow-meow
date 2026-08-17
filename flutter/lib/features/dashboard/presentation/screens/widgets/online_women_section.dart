import 'package:flutter/material.dart';
import '../../../../../core/services/dashboard_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Online Women Section for Men's Dashboard
/// Shows same-language women first, then other languages
class OnlineWomenSection extends StatelessWidget {
  final List<OnlineWoman> sameLanguageWomen;
  final List<OnlineWoman> otherLanguageWomen;
  final String userLanguage;
  final bool isLoading;
  final VoidCallback onRefresh;
  final void Function(OnlineWoman woman) onStartChat;
  final void Function(String userId) onViewProfile;

  const OnlineWomenSection({
    super.key,
    required this.sameLanguageWomen,
    required this.otherLanguageWomen,
    required this.userLanguage,
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
            Row(
              children: [
                const Icon(Icons.people, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text('Women Online', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            TextButton.icon(
              onPressed: onRefresh,
              icon: Icon(Icons.refresh, size: 16, color: isLoading ? Colors.grey : null),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Same Language
        _SectionHeader(label: 'Same Language', tag: userLanguage, count: sameLanguageWomen.length, color: AppColors.success),
        const SizedBox(height: 8),
        if (sameLanguageWomen.isEmpty)
          _EmptyState(message: 'No women speaking $userLanguage')
        else
          ...sameLanguageWomen.map((w) => _WomanCard(
            woman: w,
            onChat: () => onStartChat(w),
            onViewProfile: () => onViewProfile(w.userId),
            highlightColor: AppColors.success,
          )),

        const SizedBox(height: 16),

        // Other Languages
        _SectionHeader(label: 'Other Languages', count: otherLanguageWomen.length, color: AppColors.info),
        const SizedBox(height: 8),
        if (otherLanguageWomen.isEmpty)
          const _EmptyState(message: 'No other language women online')
        else
          ...otherLanguageWomen.map((w) => _WomanCard(
            woman: w,
            onChat: () => onStartChat(w),
            onViewProfile: () => onViewProfile(w.userId),
            highlightColor: AppColors.info,
            showTranslation: true,
            targetLanguage: userLanguage,
          )),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? tag;
  final int count;
  final Color color;

  const _SectionHeader({required this.label, this.tag, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        if (tag != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(tag!, style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
        const SizedBox(width: 8),
        Text('($count)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WomanCard extends StatelessWidget {
  final OnlineWoman woman;
  final VoidCallback onChat;
  final VoidCallback onViewProfile;
  final Color highlightColor;
  final bool showTranslation;
  final String? targetLanguage;

  const _WomanCard({
    required this.woman,
    required this.onChat,
    required this.onViewProfile,
    required this.highlightColor,
    this.showTranslation = false,
    this.targetLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlightColor.withOpacity(0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: onChat,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  AppAvatar(imageUrl: woman.photoUrl, name: woman.fullName, radius: 20, isOnline: !woman.isBusy),
                  if (woman.isEarningEligible)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        child: const Icon(Icons.star, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(woman.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (woman.age != null) ...[
                          const SizedBox(width: 6),
                          Text('${woman.age} yrs', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (showTranslation && targetLanguage != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(woman.motherTongue, style: TextStyle(fontSize: 10, color: AppColors.info)),
                          ),
                          const Text(' → ', style: TextStyle(fontSize: 10)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(targetLanguage!, style: TextStyle(fontSize: 10, color: AppColors.primary)),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: highlightColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(woman.motherTongue, style: TextStyle(fontSize: 10, color: highlightColor)),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: onViewProfile,
                tooltip: 'View Profile',
              ),
              FilledButton.tonal(
                onPressed: woman.isBusy ? null : onChat,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat, size: 14),
                    const SizedBox(width: 4),
                    Text(woman.isBusy ? 'Busy' : 'Chat', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
