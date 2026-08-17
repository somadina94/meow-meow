import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Service Provider
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

/// Platform Metrics Model - Synced with platform_metrics table
class PlatformMetrics {
  final int totalUsers;
  final int activeUsers;
  final int maleUsers;
  final int femaleUsers;
  final int newUsers;
  final int totalChats;
  final int activeChats;
  final int totalMessages;
  final int totalMatches;
  final int totalVideoCalls;
  final double videoCallMinutes;
  final double videoCallRevenue;
  final double menRecharges;
  final double menSpent;
  final double womenEarnings;
  final double adminProfit;
  final double giftRevenue;
  final int pendingWithdrawals;
  final int completedWithdrawals;

  const PlatformMetrics({
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.maleUsers = 0,
    this.femaleUsers = 0,
    this.newUsers = 0,
    this.totalChats = 0,
    this.activeChats = 0,
    this.totalMessages = 0,
    this.totalMatches = 0,
    this.totalVideoCalls = 0,
    this.videoCallMinutes = 0,
    this.videoCallRevenue = 0,
    this.menRecharges = 0,
    this.menSpent = 0,
    this.womenEarnings = 0,
    this.adminProfit = 0,
    this.giftRevenue = 0,
    this.pendingWithdrawals = 0,
    this.completedWithdrawals = 0,
  });
}

/// Audit Log Model
class AuditLogModel {
  final String id;
  final String adminId;
  final String? adminEmail;
  final String action;
  final String actionType;
  final String resourceType;
  final String? resourceId;
  final String? details;
  final String status;
  final DateTime? createdAt;

  const AuditLogModel({
    required this.id,
    required this.adminId,
    this.adminEmail,
    required this.action,
    required this.actionType,
    required this.resourceType,
    this.resourceId,
    this.details,
    this.status = 'success',
    this.createdAt,
  });
}

/// Admin Service - Synced with React admin.service.ts
class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Check if user is admin
  Future<bool> isAdmin(String userId) async {
    try {
      final response = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .eq('role', 'admin')
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Get platform metrics
  Future<PlatformMetrics?> getPlatformMetrics({String? date}) async {
    try {
      var query = _client
          .from('platform_metrics')
          .select()
          .order('metric_date', ascending: false)
          .limit(1);

      if (date != null) query = query.eq('metric_date', date);

      final response = await query.maybeSingle();
      if (response == null) return null;

      return PlatformMetrics(
        totalUsers: response['total_users'] ?? 0,
        activeUsers: response['active_users'] ?? 0,
        maleUsers: response['male_users'] ?? 0,
        femaleUsers: response['female_users'] ?? 0,
        newUsers: response['new_users'] ?? 0,
        totalChats: response['total_chats'] ?? 0,
        activeChats: response['active_chats'] ?? 0,
        totalMessages: response['total_messages'] ?? 0,
        totalMatches: response['total_matches'] ?? 0,
        totalVideoCalls: response['total_video_calls'] ?? 0,
        videoCallMinutes: (response['video_call_minutes'] as num?)?.toDouble() ?? 0,
        videoCallRevenue: (response['video_call_revenue'] as num?)?.toDouble() ?? 0,
        menRecharges: (response['men_recharges'] as num?)?.toDouble() ?? 0,
        menSpent: (response['men_spent'] as num?)?.toDouble() ?? 0,
        womenEarnings: (response['women_earnings'] as num?)?.toDouble() ?? 0,
        adminProfit: (response['admin_profit'] as num?)?.toDouble() ?? 0,
        giftRevenue: (response['gift_revenue'] as num?)?.toDouble() ?? 0,
        pendingWithdrawals: response['pending_withdrawals'] ?? 0,
        completedWithdrawals: response['completed_withdrawals'] ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get audit logs
  Future<List<AuditLogModel>> getAuditLogs({int page = 1, int limit = 50}) async {
    try {
      final offset = (page - 1) * limit;
      final response = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => AuditLogModel(
        id: json['id'],
        adminId: json['admin_id'],
        adminEmail: json['admin_email'],
        action: json['action'],
        actionType: json['action_type'] ?? 'admin',
        resourceType: json['resource_type'],
        resourceId: json['resource_id'],
        details: json['details'],
        status: json['status'] ?? 'success',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  /// Create audit log
  Future<void> createAuditLog({
    required String adminId,
    required String action,
    required String resourceType,
    String? resourceId,
    String? details,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'admin_id': adminId,
        'action': action,
        'action_type': 'admin',
        'resource_type': resourceType,
        'resource_id': resourceId,
        'details': details,
      });
    } catch (_) {}
  }

  /// Get all users with pagination
  Future<List<Map<String, dynamic>>> getUsers({
    int page = 1,
    int limit = 50,
    String? gender,
    String? status,
  }) async {
    try {
      final offset = (page - 1) * limit;
      var query = _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (gender != null) query = query.eq('gender', gender);
      if (status != null) query = query.eq('account_status', status);

      final response = await query;
      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Update user status
  Future<bool> updateUserStatus(String userId, String status) async {
    try {
      await _client
          .from('profiles')
          .update({'account_status': status})
          .eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get pending women approvals
  Future<List<Map<String, dynamic>>> getPendingWomenApprovals() async {
    try {
      final response = await _client
          .from('female_profiles')
          .select()
          .eq('approval_status', 'pending')
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Approve or reject woman
  Future<bool> updateWomanApproval(String userId, bool approved, {String? reason}) async {
    try {
      await _client.from('female_profiles').update({
        'approval_status': approved ? 'approved' : 'rejected',
        'ai_disapproval_reason': approved ? null : reason,
      }).eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get admin revenue summary
  Future<Map<String, double>> getRevenueSummary() async {
    try {
      final response = await _client
          .from('admin_revenue_transactions')
          .select('transaction_type, amount');

      final summary = <String, double>{
        'totalRecharge': 0,
        'totalChatRevenue': 0,
        'totalVideoRevenue': 0,
        'totalGiftRevenue': 0,
        'grandTotal': 0,
      };

      for (final tx in (response as List)) {
        final amount = (tx['amount'] as num).toDouble();
        summary['grandTotal'] = (summary['grandTotal'] ?? 0) + amount;
        switch (tx['transaction_type']) {
          case 'recharge':
            summary['totalRecharge'] = (summary['totalRecharge'] ?? 0) + amount;
            break;
          case 'chat_revenue':
            summary['totalChatRevenue'] = (summary['totalChatRevenue'] ?? 0) + amount;
            break;
          case 'video_revenue':
            summary['totalVideoRevenue'] = (summary['totalVideoRevenue'] ?? 0) + amount;
            break;
          case 'gift_revenue':
            summary['totalGiftRevenue'] = (summary['totalGiftRevenue'] ?? 0) + amount;
            break;
        }
      }
      return summary;
    } catch (_) {
      return {};
    }
  }
}
