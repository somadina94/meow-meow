import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/wallet_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/wallet_model.dart';

/// Transaction History Screen - Synced with React TransactionHistoryScreen
/// Shows bank statement, chat/video/group/private/gift tabs with gender-specific views.
/// Men see spending (debits), women see earnings (credits).
/// Rates: Chat ₹4/min men debit, ₹2/min women earn
///        Video ₹8/min men debit, ₹4/min women earn
///        Group ₹4/min per man, ₹2/min per man for host
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _userId;
  String? _userGender;
  double _currentBalance = 0;
  double _openingBalance = 0;

  ChatPricingModel _pricing = const ChatPricingModel();
  List<WalletTransactionModel> _walletTransactions = [];
  List<ChatSessionModel> _chatSessions = [];
  List<VideoCallSessionModel> _videoCallSessions = [];
  List<WomenEarningsModel> _womenEarnings = [];
  List<GiftTransactionModel> _giftTransactions = [];
  List<WithdrawalRequestModel> _withdrawalRequests = [];
  List<UnifiedTransaction> _unifiedTransactions = [];

  bool get _isMale => _userGender == 'male';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final walletService = ref.read(walletServiceProvider);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _userId = user.id;

    try {
      // Fetch profile gender
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('gender')
          .eq('user_id', user.id)
          .maybeSingle();

      final gender = (profile?['gender'] as String?)?.toLowerCase();
      _userGender = gender;

      // Update tab count based on gender (women get Withdrawals tab)
      if (!_isMale) {
        _tabController.dispose();
        _tabController = TabController(length: 7, vsync: this);
      } else {
        _tabController.dispose();
        _tabController = TabController(length: 6, vsync: this);
      }

      // Parallel fetch
      final results = await Future.wait([
        walletService.getChatPricing(),
        _isMale
            ? walletService.getMenWalletBalance(user.id)
            : walletService.getWomenWalletBalance(user.id),
        walletService.getAllTransactions(user.id),
        walletService.getChatSessions(user.id, gender ?? 'male'),
        walletService.getVideoCallSessions(user.id, gender ?? 'male'),
        if (!_isMale) walletService.getAllWomenEarnings(user.id),
        walletService.getGiftTransactions(user.id),
        if (!_isMale) walletService.getWithdrawalRequests(user.id),
      ]);

      int idx = 0;
      _pricing = results[idx++] as ChatPricingModel;
      _currentBalance = results[idx++] as double;
      _walletTransactions = results[idx++] as List<WalletTransactionModel>;
      _chatSessions = results[idx++] as List<ChatSessionModel>;
      _videoCallSessions = results[idx++] as List<VideoCallSessionModel>;
      if (!_isMale) _womenEarnings = results[idx++] as List<WomenEarningsModel>;
      _giftTransactions = results[idx++] as List<GiftTransactionModel>;
      if (!_isMale) _withdrawalRequests = results[idx++] as List<WithdrawalRequestModel>;

      // Calculate opening balance
      _computeOpeningBalance();

      // Build unified transactions
      _buildUnifiedTransactions();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeOpeningBalance() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    if (_isMale) {
      double thisMonthCredits = 0, thisMonthDebits = 0;
      for (final tx in _walletTransactions) {
        if (tx.createdAt != null && tx.createdAt!.isAfter(monthStart)) {
          if (tx.type == 'credit') {
            thisMonthCredits += tx.amount;
          } else {
            thisMonthDebits += tx.amount;
          }
        }
      }
      _openingBalance = _currentBalance - thisMonthCredits + thisMonthDebits;
    } else {
      double priorBalance = 0;
      for (final e in _womenEarnings) {
        if (e.createdAt != null && e.createdAt!.isBefore(monthStart)) {
          priorBalance += e.amount;
        }
      }
      for (final tx in _walletTransactions) {
        if (tx.createdAt != null && tx.createdAt!.isBefore(monthStart)) {
          if (tx.type == 'credit') {
            priorBalance += tx.amount;
          } else {
            priorBalance -= tx.amount;
          }
        }
      }
      _openingBalance = priorBalance;
    }
  }

  void _buildUnifiedTransactions() {
    final unified = <UnifiedTransaction>[];
    final seenIds = <String>{};

    // Add wallet transactions.
    // Women's earnings are sourced from `_womenEarnings` (which is itself a
    // derived view over wallet_transactions earning rows), so skip credit
    // entries here for women to avoid double-counting.
    for (final tx in _walletTransactions) {
      if (!_isMale && tx.type == 'credit') continue;
      if (seenIds.contains(tx.id)) continue;
      seenIds.add(tx.id);

      final desc = (tx.description ?? '').toLowerCase();
      String type = 'other';
      String icon = 'arrow';

      if (tx.type == 'credit' && (desc.contains('recharge') || desc.contains('deposit') || desc.contains('added'))) {
        type = 'recharge'; icon = 'wallet';
      } else if (desc.contains('withdrawal')) {
        type = 'withdrawal'; icon = 'wallet';
      } else if (desc.contains('golden badge')) {
        type = 'other'; icon = 'wallet';
      } else if (desc.contains('group')) {
        type = 'chat'; icon = 'chat';
      } else if (desc.contains('gift') || desc.contains('tip')) {
        type = 'gift'; icon = 'gift';
      } else if (desc.contains('chat') && !desc.contains('group')) {
        type = 'chat'; icon = 'chat';
      } else if (desc.contains('video') && !desc.contains('group')) {
        type = 'video'; icon = 'video';
      }

      unified.add(UnifiedTransaction(
        id: tx.id,
        type: type,
        amount: tx.amount,
        description: tx.description ?? (tx.type == 'credit' ? 'Credit' : 'Debit'),
        createdAt: tx.createdAt ?? DateTime.now(),
        status: tx.status,
        isCredit: tx.type == 'credit',
        icon: icon,
      ));
    }

    // For women: add earning rows (derived from wallet_transactions credits)
    if (!_isMale) {
      for (final earning in _womenEarnings) {
        final earningId = 'earning-${earning.id}';
        if (seenIds.contains(earningId)) continue;
        seenIds.add(earningId);

        final descLower = (earning.description ?? '').toLowerCase();
        final earningType = earning.earningType.toLowerCase();
        String type = 'other';
        String icon = 'arrow';

        if (descLower.contains('group')) {
          type = 'chat'; icon = 'chat';
        } else if (earningType.contains('chat')) {
          type = 'chat'; icon = 'chat';
        } else if (earningType.contains('video') || earningType.contains('private')) {
          type = 'video'; icon = 'video';
        } else if (earningType.contains('gift')) {
          type = 'gift'; icon = 'gift';
        }

        unified.add(UnifiedTransaction(
          id: earningId,
          type: type,
          amount: earning.amount,
          description: earning.description ?? 'Earning',
          createdAt: earning.createdAt ?? DateTime.now(),
          status: 'completed',
          isCredit: true,
          icon: icon,
        ));
      }
    }

    // Deduplicate & consolidate incremental billing rows.
    // Strips numeric values to get a stable "billing key", then within a 90s window
    // keeps only the LARGEST amount per key+direction — collapsing per-second ticks into one entry.
    unified.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    String getBillingKey(String desc) {
      return desc.replaceAll(RegExp(r'[\d.,]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final deduped = <UnifiedTransaction>[];
    for (int i = 0; i < unified.length; i++) {
      final tx = unified[i];
      final descLower = tx.description.toLowerCase();
      final isBilling = descLower.contains('group call') ||
          descLower.contains('group tip') ||
          descLower.contains('chat debit') ||
          descLower.contains('chat earning') ||
          descLower.contains('video call debit') ||
          descLower.contains('video call earning') ||
          descLower.contains('video debit') ||
          descLower.contains('video earning');

      if (!isBilling) {
        deduped.add(tx);
        continue;
      }

      final txKey = getBillingKey(descLower);
      bool replacedExisting = false;

      for (int j = deduped.length - 1; j >= 0; j--) {
        final accepted = deduped[j];
        if (tx.createdAt.difference(accepted.createdAt).inMilliseconds.abs() > 90000) break;

        final sameDirection = accepted.isCredit == tx.isCredit;
        final acceptedKey = getBillingKey(accepted.description.toLowerCase());

        if (sameDirection && txKey == acceptedKey) {
          if (tx.amount >= accepted.amount) {
            deduped[j] = tx;
          }
          replacedExisting = true;
          break;
        }
      }

      if (!replacedExisting) {
        deduped.add(tx);
      }
    }

    // Filter to current month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final currentMonth = deduped.where((tx) =>
        tx.createdAt.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
        tx.createdAt.isBefore(monthEnd)).toList();

    // Compute running balance
    currentMonth.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    double runningBal = _openingBalance;
    for (final tx in currentMonth) {
      if (tx.isCredit) {
        runningBal += tx.amount;
      } else {
        runningBal -= tx.amount;
      }
      tx.balanceAfter = runningBal;
    }

    // Sort descending for display
    currentMonth.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _unifiedTransactions = currentMonth;
  }

  String _formatDuration(double minutes) {
    final totalSeconds = (minutes * 60).round();
    if (totalSeconds < 60) return '${totalSeconds}s';
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (mins < 60) return secs > 0 ? '${mins}m ${secs}s' : '${mins}m';
    final hours = mins ~/ 60;
    final remainMins = mins % 60;
    return remainMins > 0 ? '${hours}h ${remainMins}m' : '${hours}h';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM HH:mm').format(date);
  }

  String _formatFullDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = <Tab>[
      const Tab(text: 'Statement'),
      const Tab(text: 'Chats'),
      const Tab(text: 'Video'),
      const Tab(text: 'Group'),
      const Tab(text: 'Private'),
      const Tab(text: 'Gifts'),
      if (!_isMale) const Tab(text: 'Withdrawals'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Balance', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
              Text('₹${_currentBalance.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: tabs,
          labelStyle: const TextStyle(fontSize: 12),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStatementTab(),
            _buildChatsTab(),
            _buildVideoTab(),
            _buildGroupTab(),
            _buildPrivateTab(),
            _buildGiftsTab(),
            if (!_isMale) _buildWithdrawalsTab(),
          ],
        ),
      ),
    );
  }

  // ─── SUMMARY CARDS ───
  Widget _buildSummaryCards() {
    final chatAmount = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('chat') ?? false) && !(t.description?.toLowerCase().contains('group') ?? false)).fold(0.0, (sum, t) => sum + t.amount)
        : _womenEarnings.where((e) => e.earningType == 'chat').fold(0.0, (sum, e) => sum + e.amount);

    final videoAmount = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('video') ?? false)).fold(0.0, (sum, t) => sum + t.amount)
        : _womenEarnings.where((e) => e.earningType == 'video_call' || e.earningType == 'private_call').fold(0.0, (sum, e) => sum + e.amount);

    final groupAmount = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('group') ?? false)).fold(0.0, (sum, t) => sum + t.amount)
        : _womenEarnings.where((e) => e.description?.toLowerCase().contains('group') ?? false).fold(0.0, (sum, e) => sum + e.amount);

    final giftAmount = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && ((t.description?.toLowerCase().contains('gift') ?? false) || (t.description?.toLowerCase().contains('tip') ?? false))).fold(0.0, (sum, t) => sum + t.amount)
        : _womenEarnings.where((e) => e.earningType == 'gift').fold(0.0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        // Opening Balance
        Card(
          color: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('📋 ', style: TextStyle(fontSize: 18)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Opening Balance (C/F)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Carry forward from previous month', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ]),
                Text('₹${_openingBalance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Category cards
        Row(
          children: [
            _summaryCard('Chats', chatAmount, Icons.chat, Colors.blue,
                _isMale ? '₹${_pricing.ratePerMinute.toStringAsFixed(0)}/min' : '₹${_pricing.womenEarningRate.toStringAsFixed(0)}/min'),
            const SizedBox(width: 8),
            _summaryCard('Video', videoAmount, Icons.videocam, Colors.purple,
                _isMale ? '₹${_pricing.videoRatePerMinute.toStringAsFixed(0)}/min' : '₹${_pricing.videoWomenEarningRate.toStringAsFixed(0)}/min'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _summaryCard('Group', groupAmount, Icons.group, Colors.teal,
                _isMale ? '₹${_pricing.ratePerMinute.toStringAsFixed(0)}/min each' : '₹${_pricing.womenEarningRate.toStringAsFixed(0)}/min/user'),
            const SizedBox(width: 8),
            _summaryCard('Gifts', giftAmount, Icons.card_giftcard, Colors.amber, ''),
          ],
        ),
        const SizedBox(height: 8),
        // Total card
        Card(
          color: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(_isMale ? 'Total Spending' : 'Total Earnings',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  '₹${(_isMale ? _walletTransactions.where((t) => t.type == 'debit').fold(0.0, (s, t) => s + t.amount) : _womenEarnings.fold(0.0, (s, e) => s + e.amount)).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, IconData icon, Color color, String rate) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Text('₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              if (rate.isNotEmpty)
                Text(rate, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STATEMENT TAB ───
  Widget _buildStatementTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 16),
        // Statement header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _stmtRow('Company:', 'Meow-meow'),
                _stmtRow('Account Status:', 'Active'),
                _stmtRow('Type:', _isMale ? 'Spending Account' : 'Earnings Account'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('${_unifiedTransactions.length} entries this month', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 8),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text('Date', style: _headerStyle)),
              Expanded(flex: 3, child: Text('Description', style: _headerStyle)),
              SizedBox(width: 65, child: Text('Debit', style: _headerStyle.copyWith(color: Colors.red))),
              SizedBox(width: 65, child: Text('Credit', style: _headerStyle.copyWith(color: Colors.green))),
              SizedBox(width: 65, child: Text('Balance', style: _headerStyle)),
            ],
          ),
        ),
        // Opening balance row
        _statementRow(
          DateFormat('dd/MM').format(DateTime(DateTime.now().year, DateTime.now().month, 1)),
          'Opening Balance (C/F)',
          null,
          null,
          _openingBalance,
          highlight: true,
        ),
        // Transaction rows
        ..._unifiedTransactions.map((tx) => _statementRow(
              _formatDate(tx.createdAt),
              tx.description,
              tx.isCredit ? null : tx.amount,
              tx.isCredit ? tx.amount : null,
              tx.balanceAfter,
            )),
        // Closing balance
        _statementRow('Today', 'Closing Balance', null, null, _currentBalance, highlight: true),
      ],
    );
  }

  Widget _statementRow(String date, String desc, double? debit, double? credit, double? balance, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withOpacity(0.05) : null,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey))),
          Expanded(
            flex: 3,
            child: Text(desc, style: TextStyle(fontSize: 10, fontWeight: highlight ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 65,
            child: Text(debit != null ? '₹${debit.toStringAsFixed(2)}' : '',
                style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 65,
            child: Text(credit != null ? '₹${credit.toStringAsFixed(2)}' : '',
                style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 65,
            child: Text(balance != null ? '₹${balance.toStringAsFixed(2)}' : '-',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: highlight ? AppColors.primary : null)),
          ),
        ],
      ),
    );
  }

  Widget _stmtRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey);

  // ─── CHATS TAB ───
  Widget _buildChatsTab() {
    if (_chatSessions.isEmpty) {
      return _emptyState(Icons.chat, 'No chat sessions yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chatSessions.length,
      itemBuilder: (context, index) {
        final s = _chatSessions[index];
        final amount = _isMale
            ? _walletTransactions
                .where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('chat') ?? false) && !(t.description?.toLowerCase().contains('group') ?? false) &&
                    t.createdAt != null && s.startedAt != null &&
                    t.createdAt!.isAfter(s.startedAt!) &&
                    (s.endedAt == null || t.createdAt!.isBefore(s.endedAt!.add(const Duration(seconds: 30)))))
                .fold(0.0, (sum, t) => sum + t.amount)
            : s.totalEarned;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (_isMale ? Colors.red : Colors.green).withOpacity(0.1),
              child: Icon(Icons.chat, color: _isMale ? Colors.red : Colors.green, size: 20),
            ),
            title: Text('Chat with ${s.partnerName ?? "Anonymous"}', style: const TextStyle(fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_formatDuration(s.totalMinutes)} • ${_isMale ? "₹${s.ratePerMinute}/min charged" : "₹${_pricing.womenEarningRate}/min earned"}',
                    style: const TextStyle(fontSize: 11)),
                if (s.startedAt != null) Text(_formatFullDate(s.startedAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                if (s.endReason != null) Text(_endReasonText(s.endReason!), style: const TextStyle(fontSize: 10, color: Colors.amber)),
              ],
            ),
            trailing: Text(
              '${_isMale ? "-" : "+"}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: _isMale ? Colors.red : Colors.green),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // ─── VIDEO TAB ───
  Widget _buildVideoTab() {
    if (_videoCallSessions.isEmpty) {
      return _emptyState(Icons.videocam, 'No video calls yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videoCallSessions.length,
      itemBuilder: (context, index) {
        final s = _videoCallSessions[index];
        final amount = _isMale
            ? _walletTransactions
                .where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('video') ?? false) &&
                    t.createdAt != null && (s.startedAt ?? s.createdAt) != null &&
                    t.createdAt!.isAfter((s.startedAt ?? s.createdAt!).subtract(const Duration(seconds: 5))) &&
                    (s.endedAt == null || t.createdAt!.isBefore(s.endedAt!.add(const Duration(seconds: 30)))))
                .fold(0.0, (sum, t) => sum + t.amount)
            : s.totalEarned;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (_isMale ? Colors.purple : Colors.pink).withOpacity(0.1),
              child: Icon(Icons.videocam, color: _isMale ? Colors.purple : Colors.pink, size: 20),
            ),
            title: Text('Video with ${s.partnerName ?? "Anonymous"}', style: const TextStyle(fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_formatDuration(s.totalMinutes)} • ${_isMale ? "₹${_pricing.videoRatePerMinute}/min charged" : "₹${_pricing.videoWomenEarningRate}/min earned"}',
                    style: const TextStyle(fontSize: 11)),
                if (s.startedAt != null) Text(_formatFullDate(s.startedAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                if (s.endReason != null) Text(_endReasonText(s.endReason!), style: const TextStyle(fontSize: 10, color: Colors.amber)),
              ],
            ),
            trailing: Text(
              '${_isMale ? "-" : "+"}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: _isMale ? Colors.purple : Colors.pink),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // ─── GROUP TAB ───
  Widget _buildGroupTab() {
    final groupEntries = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('group') ?? false)).toList()
        : _womenEarnings.where((e) => e.description?.toLowerCase().contains('group') ?? false).toList();

    final callEntries = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('group call') ?? false)).toList()
        : _womenEarnings.where((e) => e.description?.toLowerCase().contains('group call') ?? false).toList();

    final tipEntries = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('group tip') ?? false)).toList()
        : _womenEarnings.where((e) => e.description?.toLowerCase().contains('group tip') ?? false).toList();

    final totalAmount = groupEntries.fold(0.0, (sum, e) {
      if (e is WalletTransactionModel) return sum + e.amount;
      if (e is WomenEarningsModel) return sum + e.amount;
      return sum;
    });
    final callAmount = callEntries.fold(0.0, (sum, e) {
      if (e is WalletTransactionModel) return sum + e.amount;
      if (e is WomenEarningsModel) return sum + e.amount;
      return sum;
    });
    final tipAmount = tipEntries.fold(0.0, (sum, e) {
      if (e is WalletTransactionModel) return sum + e.amount;
      if (e is WomenEarningsModel) return sum + e.amount;
      return sum;
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            _summaryCard(_isMale ? 'Total Spent' : 'Total Earned', totalAmount, Icons.group, Colors.teal, ''),
            const SizedBox(width: 8),
            _summaryCard('Calls', callAmount, Icons.phone, Colors.blue, '${callEntries.length} entries'),
            const SizedBox(width: 8),
            _summaryCard('Tips', tipAmount, Icons.card_giftcard, Colors.amber, '${tipEntries.length} tips'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isMale
              ? 'Men pay ₹${_pricing.ratePerMinute.toStringAsFixed(0)}/min per group call'
              : 'Host earns ₹${_pricing.womenEarningRate.toStringAsFixed(0)}/min per participant',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (groupEntries.isEmpty) _emptyState(Icons.group, 'No group call entries'),
        ...groupEntries.map((entry) {
          final amount = entry is WalletTransactionModel ? entry.amount : (entry as WomenEarningsModel).amount;
          final desc = entry is WalletTransactionModel ? entry.description : (entry as WomenEarningsModel).description;
          final date = entry is WalletTransactionModel ? entry.createdAt : (entry as WomenEarningsModel).createdAt;
          final isTip = (desc?.toLowerCase().contains('tip') ?? false);

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: (isTip ? Colors.amber : (_isMale ? Colors.red : Colors.green)).withOpacity(0.1),
                child: Icon(isTip ? Icons.card_giftcard : Icons.group,
                    size: 16, color: isTip ? Colors.amber : (_isMale ? Colors.red : Colors.green)),
              ),
              title: Text(desc ?? 'Group', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              subtitle: Text(_formatFullDate(date), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              trailing: Text(
                '${_isMale ? "-" : "+"}₹${amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isMale ? Colors.red : Colors.green),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── PRIVATE TAB (1-to-1 video calls) ───
  Widget _buildPrivateTab() {
    // Private calls are 1-to-1 video calls tracked in video_call_sessions
    // Already shown in video tab; this tab is for dedicated private call view
    final privateTx = _isMale
        ? _walletTransactions.where((t) => t.type == 'debit' && (t.description?.toLowerCase().contains('private') ?? false)).toList()
        : _womenEarnings.where((e) => e.earningType == 'private_call' || (e.description?.toLowerCase().contains('private') ?? false)).toList();

    if (privateTx.isEmpty) {
      return _emptyState(Icons.phone_in_talk, 'No private calls yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: privateTx.length,
      itemBuilder: (context, index) {
        final entry = privateTx[index];
        final amount = entry is WalletTransactionModel ? entry.amount : (entry as WomenEarningsModel).amount;
        final desc = entry is WalletTransactionModel ? entry.description : (entry as WomenEarningsModel).description;
        final date = entry is WalletTransactionModel ? entry.createdAt : (entry as WomenEarningsModel).createdAt;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.withOpacity(0.1),
              child: const Icon(Icons.phone_in_talk, color: Colors.indigo, size: 20),
            ),
            title: Text(desc ?? 'Private Call', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
            subtitle: Text(_formatFullDate(date), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            trailing: Text(
              '${_isMale ? "-" : "+"}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: _isMale ? Colors.red : Colors.green),
            ),
          ),
        );
      },
    );
  }

  // ─── GIFTS TAB ───
  Widget _buildGiftsTab() {
    if (_giftTransactions.isEmpty) {
      return _emptyState(Icons.card_giftcard, 'No gift transactions yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _giftTransactions.length,
      itemBuilder: (context, index) {
        final g = _giftTransactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(g.giftEmoji ?? '🎁', style: const TextStyle(fontSize: 24)),
            title: Text(
              '${g.isSender ? "Sent" : "Received"} ${g.giftName ?? "Gift"} ${g.isSender ? "to" : "from"} ${g.partnerName ?? "Anonymous"}',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g.message != null) Text('"${g.message}"', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[600])),
                Text(_formatFullDate(g.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
            trailing: Text(
              '${g.isSender ? "-" : "+"}₹${g.pricePaid.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: g.isSender ? Colors.red : Colors.green),
            ),
            isThreeLine: g.message != null,
          ),
        );
      },
    );
  }

  // ─── WITHDRAWALS TAB ───
  Widget _buildWithdrawalsTab() {
    if (_withdrawalRequests.isEmpty) {
      return _emptyState(Icons.account_balance_wallet, 'No withdrawal requests yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _withdrawalRequests.length,
      itemBuilder: (context, index) {
        final w = _withdrawalRequests[index];
        Color statusColor;
        switch (w.status) {
          case 'approved':
          case 'completed':
            statusColor = Colors.green;
            break;
          case 'rejected':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.amber;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
            ),
            title: Text('Withdrawal ₹${w.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(w.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                ),
                Text(_formatFullDate(w.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                if (w.rejectionReason != null)
                  Text('Reason: ${w.rejectionReason}', style: const TextStyle(fontSize: 10, color: Colors.red)),
              ],
            ),
            trailing: Text('-₹${w.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  String _endReasonText(String reason) {
    switch (reason) {
      case 'insufficient_balance':
        return 'Ended - Low balance';
      case 'inactivity_timeout':
        return 'Ended - Inactivity';
      case 'user_disconnected':
        return 'User disconnected';
      case 'woman_disconnected':
        return 'Partner disconnected';
      default:
        return reason;
    }
  }
}
