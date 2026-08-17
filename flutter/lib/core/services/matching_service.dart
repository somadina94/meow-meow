import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/match_model.dart';
import '../../shared/models/user_model.dart';

/// Matching Service Provider
final matchingServiceProvider = Provider<MatchingService>((ref) {
  return MatchingService();
});

/// Matching Service
/// 
/// Handles user matching and discovery.
class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get online users
  Future<List<MatchProfileModel>> getOnlineUsers({
    String? gender,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('profiles')
          .select('*, user_status!inner(*)')
          .eq('user_status.is_online', true)
          .eq('account_status', 'active')
          .eq('approval_status', 'approved');

      if (gender != null) {
        query = query.eq('gender', gender);
      }

      final response = await query.limit(limit);

      return (response as List).map((json) => _mapToMatchProfile(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Find matches based on filters
  Future<List<MatchProfileModel>> findMatches({
    required String userId,
    MatchFilters? filters,
    int limit = 20,
  }) async {
    try {
      // Get current user profile
      final userProfile = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      final userGender = userProfile['gender'];
      final oppositeGender = userGender == 'male' ? 'female' : 'male';

      var query = _client
          .from('profiles')
          .select()
          .eq('gender', oppositeGender)
          .eq('account_status', 'active')
          .eq('approval_status', 'approved')
          .neq('user_id', userId);

      // Apply filters
      if (filters != null) {
        if (filters.minAge != null) {
          query = query.gte('age', filters.minAge!);
        }
        if (filters.maxAge != null) {
          query = query.lte('age', filters.maxAge!);
        }
        if (filters.country != null) {
          query = query.eq('country', filters.country!);
        }
        if (filters.state != null) {
          query = query.eq('state', filters.state!);
        }
        if (filters.verifiedOnly == true) {
          query = query.eq('is_verified', true);
        }
      }

      final response = await query.limit(limit);

      // Calculate match scores
      final userInterests = (userProfile['interests'] as List?)?.cast<String>() ?? [];
      final userLanguages = await _getUserLanguages(userId);

      return (response as List).map((json) {
        final profile = _mapToMatchProfile(json);
        final profileInterests = (json['interests'] as List?)?.cast<String>() ?? [];
        final commonInterests = userInterests
            .where((i) => profileInterests.contains(i))
            .toList();

        // Simple match score calculation
        int score = 50;
        score += commonInterests.length * 10;
        if (json['country'] == userProfile['country']) score += 15;
        if (json['state'] == userProfile['state']) score += 10;
        if (json['is_verified'] == true) score += 5;

        return profile.copyWith(
          matchScore: score.clamp(0, 100),
          commonInterests: commonInterests,
        );
      }).toList()
        ..sort((a, b) => b.matchScore.compareTo(a.matchScore));
    } catch (e) {
      return [];
    }
  }

  /// Get user's matches
  Future<List<MatchModel>> getUserMatches(String userId) async {
    try {
      final response = await _client
          .from('matches')
          .select()
          .or('user_id.eq.$userId,matched_user_id.eq.$userId')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => MatchModel(
                id: json['id'],
                userId: json['user_id'],
                matchedUserId: json['matched_user_id'],
                matchScore: json['match_score'],
                status: json['status'] ?? 'pending',
                matchedAt: json['matched_at'] != null
                    ? DateTime.parse(json['matched_at'])
                    : null,
                createdAt: json['created_at'] != null
                    ? DateTime.parse(json['created_at'])
                    : null,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Create a match
  Future<bool> createMatch({
    required String userId,
    required String matchedUserId,
    int? matchScore,
  }) async {
    try {
      await _client.from('matches').insert({
        'user_id': userId,
        'matched_user_id': matchedUserId,
        'match_score': matchScore,
        'status': 'pending',
        'matched_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update match status
  Future<bool> updateMatchStatus(String matchId, String status) async {
    try {
      await _client.from('matches').update({
        'status': status,
      }).eq('id', matchId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user languages helper
  Future<List<String>> _getUserLanguages(String userId) async {
    try {
      final response = await _client
          .from('user_languages')
          .select('language_name')
          .eq('user_id', userId);

      return (response as List)
          .map((item) => item['language_name'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Map to MatchProfileModel
  MatchProfileModel _mapToMatchProfile(Map<String, dynamic> json) {
    return MatchProfileModel(
      id: json['id'],
      userId: json['user_id'],
      fullName: json['full_name'],
      age: json['age'],
      gender: json['gender'],
      country: json['country'],
      state: json['state'],
      bio: json['bio'],
      photoUrl: json['photo_url'],
      interests: (json['interests'] as List?)?.cast<String>() ?? [],
      occupation: json['occupation'],
      isVerified: json['is_verified'] ?? false,
      isOnline: json['user_status']?['is_online'] ?? false,
    );
  }
}
