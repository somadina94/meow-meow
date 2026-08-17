import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';

/// Profile Service Provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Current User Profile Provider - fetches from profiles table
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final service = ref.watch(profileServiceProvider);
  return service.getCurrentProfile();
});

/// Profile Service
/// 
/// Handles all profile-related operations.
/// All data is fetched from the profiles table (single source of truth).
class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get profile by user ID from profiles table
  Future<UserModel?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return _mapToUserModel(response);
    } catch (e) {
      return null;
    }
  }

  /// Get current user's profile from profiles table
  Future<UserModel?> getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  /// Update profile in profiles table
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      // Protected fields that should not be updated directly
      final protectedFields = ['phone', 'email', 'gender', 'user_id', 'id', 'created_at'];
      final safeUpdates = Map<String, dynamic>.from(updates);
      for (final field in protectedFields) {
        safeUpdates.remove(field);
      }

      await _client
          .from('profiles')
          .update({
            ...safeUpdates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user languages from user_languages table
  Future<List<UserLanguageModel>> getUserLanguages(String userId) async {
    try {
      final response = await _client
          .from('user_languages')
          .select()
          .eq('user_id', userId);

      return (response as List)
          .map((item) => UserLanguageModel(
                id: item['id'],
                userId: item['user_id'],
                languageCode: item['language_code'],
                languageName: item['language_name'],
                createdAt: item['created_at'] != null
                    ? DateTime.parse(item['created_at'])
                    : null,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add user language
  Future<bool> addUserLanguage(String userId, String languageCode, String languageName) async {
    try {
      // Delete existing languages first (one language per user)
      await _client.from('user_languages').delete().eq('user_id', userId);
      
      // Insert new language
      await _client.from('user_languages').insert({
        'user_id': userId,
        'language_code': languageCode,
        'language_name': languageName,
      });

      // Also update profile's primary_language
      await updateProfile(userId, {
        'primary_language': languageName,
        'preferred_language': languageName,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove user language
  Future<bool> removeUserLanguage(String userId, String languageCode) async {
    try {
      await _client
          .from('user_languages')
          .delete()
          .eq('user_id', userId)
          .eq('language_code', languageCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update online status in user_status table
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _client.from('user_status').upsert({
        'user_id': userId,
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get user photos from user_photos table
  Future<List<Map<String, dynamic>>> getUserPhotos(String userId) async {
    try {
      final response = await _client
          .from('user_photos')
          .select()
          .eq('user_id', userId)
          .order('display_order', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Add user photo
  Future<bool> addUserPhoto(String userId, String photoUrl, {bool isPrimary = false}) async {
    try {
      // Get current max order
      final existing = await getUserPhotos(userId);
      final maxOrder = existing.isEmpty
          ? 0
          : existing.map((p) => p['display_order'] as int).reduce((a, b) => a > b ? a : b);

      await _client.from('user_photos').insert({
        'user_id': userId,
        'photo_url': photoUrl,
        'is_primary': isPrimary,
        'display_order': maxOrder + 1,
        'photo_type': 'profile',
      });

      // If primary, update profile photo_url
      if (isPrimary) {
        await updateProfile(userId, {'photo_url': photoUrl});
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete user photo
  Future<bool> deleteUserPhoto(String photoId) async {
    try {
      await _client.from('user_photos').delete().eq('id', photoId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get wallet balance
  Future<double> getWalletBalance(String userId) async {
    try {
      final response = await _client
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      return (response?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Subscribe to profile changes
  RealtimeChannel subscribeToProfile(
    String userId,
    void Function(UserModel profile) onUpdate,
  ) {
    return _client.channel('profile:$userId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final model = _mapToUserModel(payload.newRecord);
        if (model != null) {
          onUpdate(model);
        }
      },
    ).subscribe();
  }

  /// Map database response to UserModel
  /// Uses UserModel.fromJson for consistent mapping
  UserModel? _mapToUserModel(Map<String, dynamic> json) {
    try {
      return UserModel.fromJson(json);
    } catch (e) {
      return null;
    }
  }
}
