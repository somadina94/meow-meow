import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/wallet_service.dart';
import '../../../../shared/models/gift_model.dart';
import '../../../../shared/models/wallet_model.dart';
import '../../../../shared/widgets/common_widgets.dart';

class GiftSendingScreen extends ConsumerStatefulWidget {
  final String receiverId;

  const GiftSendingScreen({super.key, required this.receiverId});

  @override
  ConsumerState<GiftSendingScreen> createState() => _GiftSendingScreenState();
}

class _GiftSendingScreenState extends ConsumerState<GiftSendingScreen> {
  List<GiftModel> _gifts = [];
  GiftModel? _selectedGift;
  WalletModel? _wallet;
  bool _isLoading = true;
  bool _isSending = false;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final walletService = ref.read(walletServiceProvider);
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;

    if (userId != null) {
      final gifts = await walletService.getGifts();
      final wallet = await walletService.getWallet(userId);

      if (mounted) {
        setState(() {
          _gifts = gifts;
          _wallet = wallet;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;

    final balance = _wallet?.balance ?? 0;
    if (balance < _selectedGift!.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    setState(() => _isSending = true);

    final walletService = ref.read(walletServiceProvider);
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;

    if (userId != null) {
      final result = await walletService.sendGift(
        senderId: userId,
        receiverId: widget.receiverId,
        giftId: _selectedGift!.id,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSending = false);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedGift!.emoji} Gift sent successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to send gift'),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send a Gift'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.secondary,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Balance'),
                      Text(
                        '₹${_wallet?.balance.toStringAsFixed(2) ?? "0.00"}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                ),

                // Gift grid
                Expanded(
                  child: _gifts.isEmpty
                      ? const EmptyState(
                          icon: Icons.card_giftcard,
                          title: 'No gifts available',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _gifts.length,
                          itemBuilder: (context, index) {
                            final gift = _gifts[index];
                            final isSelected = _selectedGift?.id == gift.id;
                            final canAfford =
                                (_wallet?.balance ?? 0) >= gift.price;

                            return GestureDetector(
                              onTap: canAfford
                                  ? () => setState(() => _selectedGift = gift)
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Opacity(
                                  opacity: canAfford ? 1 : 0.5,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        gift.emoji,
                                        style: const TextStyle(fontSize: 40),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        gift.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${gift.price.toStringAsFixed(0)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Message and Send button
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_selectedGift != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _selectedGift!.emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedGift!.name,
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '₹${_selectedGift!.price.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _selectedGift = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Add a message (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        onPressed: _selectedGift == null ? null : _sendGift,
                        isLoading: _isSending,
                        child: Text(
                          _selectedGift == null
                              ? 'Select a Gift'
                              : 'Send Gift (₹${_selectedGift!.price.toStringAsFixed(0)})',
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
