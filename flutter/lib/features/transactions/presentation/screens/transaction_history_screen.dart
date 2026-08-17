import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  String? _userGender;

  // Pricing from admin
  double _chatRate = 4;
  double _videoRate = 8;
  double _womenChatEarningRate = 2;
  double _womenVideoEarningRate = 4;

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _deposits = [];
  List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> _chatCharges = [];
  List<Map<String, dynamic>> _videoCharges = [];
  List<Map<String, dynamic>> _giftTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Deduplicate & consolidate incremental billing rows.
  /// Strips numeric values to get a stable "billing key", then within a 90s window
  /// keeps only the LARGEST amount per key+direction — collapsing per-second ticks into one entry.
  List<Map<String, dynamic>> _deduplicateTransactions(List<Map<String, dynamic>> txns) {
    if (txns.isEmpty) return txns;
    final sorted = List<Map<String, dynamic>>.from(txns)
      ..sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));

    String getBillingKey(String desc) {
      return desc.replaceAll(RegExp(r'[\d.,]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < sorted.length; i++) {
      final curr = sorted[i];
      final descA = (curr['description'] ?? '').toString().trim().toLowerCase();
      final isBillingLine = descA.contains('chat debit') || descA.contains('chat earning') ||
          descA.contains('video call debit') || descA.contains('video call earning') ||
          descA.contains('video debit') || descA.contains('video earning') ||
          descA.contains('group call') || descA.contains('group tip');

      if (!isBillingLine) {
        result.add(curr);
        continue;
      }

      final dateA = DateTime.tryParse(curr['created_at'] ?? '');
      final keyA = getBillingKey(descA);
      final typeA = curr['type']?.toString();
      bool replacedExisting = false;

      for (int j = result.length - 1; j >= 0; j--) {
        final accepted = result[j];
        final dateB = DateTime.tryParse(accepted['created_at'] ?? '');
        if (dateA != null && dateB != null && dateA.difference(dateB).inMilliseconds.abs() > 90000) break;

        final descB = (accepted['description'] ?? '').toString().trim().toLowerCase();
        final keyB = getBillingKey(descB);
        final typeB = accepted['type']?.toString();
        final sameDirection = typeA == typeB;

        if (sameDirection && keyA == keyB) {
          final currAmount = (curr['amount'] ?? 0).toDouble();
          final acceptedAmount = (accepted['amount'] ?? 0).toDouble();
          if (currAmount >= acceptedAmount) {
            result[j] = curr;
          }
          replacedExisting = true;
          break;
        }
      }

      if (!replacedExisting) {
        result.add(curr);
      }
    }
    return result.reversed.toList(); // Return newest first
  }

  Future<void> _loadTransactions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load pricing
      final pricingData = await _supabase
          .from('chat_pricing')
          .select('rate_per_minute, video_rate_per_minute, women_earning_rate, video_women_earning_rate')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (pricingData != null) {
        _chatRate = (pricingData['rate_per_minute'] ?? 4).toDouble();
        _videoRate = (pricingData['video_rate_per_minute'] ?? 8).toDouble();
        _womenChatEarningRate = (pricingData['women_earning_rate'] ?? 2).toDouble();
        _womenVideoEarningRate = (pricingData['video_women_earning_rate'] ?? 4).toDouble();
      }

      // Load user gender
      final profileData = await _supabase
          .from('profiles')
          .select('gender')
          .eq('user_id', userId)
          .maybeSingle();
      _userGender = (profileData?['gender'] ?? '').toString().toLowerCase();

      // Load wallet transactions
      final walletTransactions = await _supabase
          .from('wallet_transactions')
          .select()
          .or('user_id.eq.$userId,recipient_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(200);

      // Load gift transactions
      final giftTxns = await _supabase
          .from('gift_transactions')
          .select('*, gifts(*)')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);

      final allTxns = _deduplicateTransactions(
        List<Map<String, dynamic>>.from(walletTransactions),
      );

      setState(() {
        _allTransactions = allTxns;
        _deposits = allTxns.where((t) =>
            t['type'] == 'deposit' || t['type'] == 'add_money' || t['type'] == 'credit').toList();
        _withdrawals = allTxns.where((t) => t['type'] == 'withdrawal').toList();
        _chatCharges = allTxns.where((t) {
          final desc = (t['description'] ?? '').toString().toLowerCase();
          return desc.contains('chat') && !desc.contains('video') && !desc.contains('group');
        }).toList();
        _videoCharges = allTxns.where((t) {
          final desc = (t['description'] ?? '').toString().toLowerCase();
          return desc.contains('video');
        }).toList();
        _giftTransactions = List<Map<String, dynamic>>.from(giftTxns);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  bool get _isMale => _userGender == 'male';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Deposits'),
            Tab(text: 'Withdrawals'),
            Tab(text: 'Chat'),
            Tab(text: 'Video'),
            Tab(text: 'Gifts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCards(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionList(_allTransactions),
                      _buildTransactionList(_deposits),
                      _buildTransactionList(_withdrawals),
                      _buildTransactionList(_chatCharges),
                      _buildTransactionList(_videoCharges),
                      _buildGiftTransactionList(_giftTransactions),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    final chatTotal = _chatCharges.fold<double>(
        0, (sum, t) => sum + (t['amount'] ?? 0).toDouble());
    final videoTotal = _videoCharges.fold<double>(
        0, (sum, t) => sum + (t['amount'] ?? 0).toDouble());

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Card(
              color: Colors.blue.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Icon(Icons.chat_bubble, color: Colors.blue, size: 20),
                    const SizedBox(height: 4),
                    Text('Chats', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    Text('₹${chatTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text(
                      _isMale
                          ? '₹${_chatRate.toStringAsFixed(0)}/min charged'
                          : '₹${_womenChatEarningRate.toStringAsFixed(0)}/min earned',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              color: Colors.purple.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Icon(Icons.video_call, color: Colors.purple, size: 20),
                    const SizedBox(height: 4),
                    Text('Video', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    Text('₹${videoTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    Text(
                      _isMale
                          ? '₹${_videoRate.toStringAsFixed(0)}/min charged'
                          : '₹${_womenVideoEarningRate.toStringAsFixed(0)}/min earned',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No transactions yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) => _buildTransactionCard(transactions[index]),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final type = txn['type'] as String? ?? 'unknown';
    final amount = (txn['amount'] ?? 0).toDouble();
    final date = DateTime.tryParse(txn['created_at'] ?? '');
    final description = txn['description'] as String?;
    final status = txn['status'] as String? ?? 'completed';
    final descLower = (description ?? '').toLowerCase();

    final isCredit = type == 'deposit' || type == 'add_money' || type == 'credit' ||
        type == 'chat_earning' || type == 'gift_received';

    IconData icon;
    Color iconColor;

    if (descLower.contains('video')) {
      icon = Icons.video_call;
      iconColor = _isMale ? Colors.purple : Colors.pink;
    } else if (descLower.contains('chat') && !descLower.contains('group')) {
      icon = Icons.chat_bubble;
      iconColor = _isMale ? Colors.blue : Colors.green;
    } else if (descLower.contains('gift') || descLower.contains('tip')) {
      icon = Icons.card_giftcard;
      iconColor = Colors.amber;
    } else if (descLower.contains('group')) {
      icon = Icons.groups;
      iconColor = Colors.teal;
    } else if (type == 'deposit' || type == 'add_money' || type == 'credit') {
      icon = Icons.add_circle;
      iconColor = Colors.green;
    } else if (type == 'withdrawal') {
      icon = Icons.remove_circle;
      iconColor = Colors.red;
    } else {
      icon = Icons.receipt;
      iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          description ?? _formatTransactionType(type),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null)
              Text(DateFormat('MMM d, yyyy • h:mm a').format(date),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green : Colors.red,
              ),
            ),
            if (status != 'completed')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'pending'
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: status == 'pending' ? Colors.orange : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _showTransactionDetails(txn),
      ),
    );
  }

  Widget _buildGiftTransactionList(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No gift transactions yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    final userId = _supabase.auth.currentUser?.id;

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final txn = transactions[index];
          final gift = txn['gifts'] as Map<String, dynamic>?;
          final isSent = txn['sender_id'] == userId;
          final date = DateTime.tryParse(txn['created_at'] ?? '');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSent
                    ? Colors.purple.withOpacity(0.1)
                    : Colors.pink.withOpacity(0.1),
                child: Text(gift?['emoji'] ?? '🎁', style: const TextStyle(fontSize: 24)),
              ),
              title: Text(gift?['name'] ?? 'Gift',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isSent ? 'Sent' : 'Received',
                      style: TextStyle(
                          color: isSent ? Colors.purple : Colors.pink, fontSize: 12)),
                  if (date != null)
                    Text(DateFormat('MMM d, yyyy • h:mm a').format(date),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
              trailing: Text(
                '₹${(txn['price_paid'] ?? 0).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSent ? Colors.purple : Colors.pink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTransactionType(String type) {
    switch (type) {
      case 'deposit':
      case 'add_money':
        return 'Money Added';
      case 'withdrawal':
        return 'Withdrawal';
      case 'chat_charge':
        return 'Chat Charge';
      case 'chat_earning':
        return 'Chat Earning';
      case 'gift_sent':
        return 'Gift Sent';
      case 'gift_received':
        return 'Gift Received';
      case 'video_call':
        return 'Video Call';
      case 'transfer':
        return 'Transfer';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _showTransactionDetails(Map<String, dynamic> txn) {
    final date = DateTime.tryParse(txn['created_at'] ?? '');

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Transaction Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildDetailRow('Type', _formatTransactionType(txn['type'] ?? '')),
            _buildDetailRow('Amount', '₹${(txn['amount'] ?? 0).toStringAsFixed(2)}'),
            _buildDetailRow('Status', (txn['status'] ?? 'completed').toUpperCase()),
            if (date != null)
              _buildDetailRow('Date', DateFormat('MMM d, yyyy h:mm a').format(date)),
            if (txn['description'] != null)
              _buildDetailRow('Description', txn['description']),
            if (txn['id'] != null)
              _buildDetailRow('Transaction ID', txn['id'].toString().substring(0, 8)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
