import 'package:flutter/material.dart';
import '../../../../../core/services/dashboard_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Online Men Section for Women's Dashboard
/// Shows Premium (recharged) and Regular men in tabs
class OnlineMenSection extends StatelessWidget {
  final List<OnlineMan> rechargedMen;
  final List<OnlineMan> nonRechargedMen;
  final String womanLanguage;
  final bool hasGoldenBadge;
  final void Function(String userId) onViewProfile;
  final void Function(String userId)? onStartChat;

  const OnlineMenSection({
    super.key,
    required this.rechargedMen,
    required this.nonRechargedMen,
    required this.womanLanguage,
    required this.hasGoldenBadge,
    required this.onViewProfile,
    this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.emoji_events, size: 16),
                const SizedBox(width: 4),
                Text('Premium (${rechargedMen.length})'),
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people, size: 16),
                const SizedBox(width: 4),
                Text('Regular (${nonRechargedMen.length})'),
              ])),
            ],
          ),
          SizedBox(
            height: rechargedMen.isEmpty && nonRechargedMen.isEmpty ? 120 : 
                   (([rechargedMen.length, nonRechargedMen.length].reduce((a, b) => a > b ? a : b)) * 90.0).clamp(120, 400),
            child: TabBarView(
              children: [
                // Premium Men
                rechargedMen.isEmpty
                    ? _EmptyMenState(message: 'No premium men online')
                    : ListView.builder(
                        itemCount: rechargedMen.length,
                        itemBuilder: (context, index) => _ManCard(
                          man: rechargedMen[index],
                          isPremium: true,
                          hasGoldenBadge: hasGoldenBadge,
                          onViewProfile: () => onViewProfile(rechargedMen[index].userId),
                          onStartChat: onStartChat != null ? () => onStartChat!(rechargedMen[index].userId) : null,
                        ),
                      ),
                // Regular Men
                nonRechargedMen.isEmpty
                    ? _EmptyMenState(message: 'No regular users online')
                    : ListView.builder(
                        itemCount: nonRechargedMen.length,
                        itemBuilder: (context, index) => _ManCard(
                          man: nonRechargedMen[index],
                          isPremium: false,
                          hasGoldenBadge: hasGoldenBadge,
                          onViewProfile: () => onViewProfile(nonRechargedMen[index].userId),
                          onStartChat: onStartChat != null ? () => onStartChat!(nonRechargedMen[index].userId) : null,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMenState extends StatelessWidget {
  final String message;
  const _EmptyMenState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ManCard extends StatelessWidget {
  final OnlineMan man;
  final bool isPremium;
  final bool hasGoldenBadge;
  final VoidCallback onViewProfile;
  final VoidCallback? onStartChat;

  const _ManCard({
    required this.man,
    required this.isPremium,
    required this.hasGoldenBadge,
    required this.onViewProfile,
    this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: man.isSameLanguage 
            ? BorderSide(color: AppColors.primary.withOpacity(0.4), width: 1.5) 
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onViewProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  AppAvatar(imageUrl: man.photoUrl, name: man.fullName, radius: 24, isOnline: man.activeChatCount < 3),
                  if (isPremium)
                    Positioned(
                      top: -2, right: -2,
                      child: Icon(Icons.emoji_events, size: 16, color: Colors.amber.shade700),
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
                        Flexible(child: Text(man.fullName, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (man.age != null) Text(' ${man.age} yrs', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (man.isSameLanguage) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Same Language', style: TextStyle(fontSize: 9, color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Wallet balance (always visible for women)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.currency_rupee, size: 12, color: Colors.green.shade600),
                          Text('₹${man.walletBalance.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.language, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(man.motherTongue, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        if (man.country != null || man.state != null) ...[
                          const Text(' • ', style: TextStyle(fontSize: 11)),
                          Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Flexible(child: Text(
                            [man.state, man.country].where((s) => s != null).join(', '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (hasGoldenBadge && onStartChat != null)
                    FilledButton.tonal(
                      onPressed: onStartChat,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat, size: 14),
                        SizedBox(width: 4),
                        Text('Chat', style: TextStyle(fontSize: 12)),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: onViewProfile,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.visibility, size: 14),
                      SizedBox(width: 4),
                      Text('View', style: TextStyle(fontSize: 12)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
