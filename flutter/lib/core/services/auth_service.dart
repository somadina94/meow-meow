import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_cleanup_service.dart';

/// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Current User Provider
final currentUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session?.user);
});

/// Auth User Model
class AuthUser {
  final String id;
  final String? email;

  AuthUser({required this.id, this.email});

  factory AuthUser.fromSupabaseUser(User user) {
    return AuthUser(id: user.id, email: user.email);
  }
}

/// Auth Response Model
class AuthResponseModel {
  final bool success;
  final AuthUser? user;
  final String? error;

  AuthResponseModel({required this.success, this.user, this.error});
}

/// Authentication Service - Synced with React auth.service.ts
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<bool> isLoggedIn() async {
    return _client.auth.currentSession != null;
  }

  /// Sign in with email and password
  Future<AuthResponseModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return AuthResponseModel(
          success: true,
          user: AuthUser.fromSupabaseUser(response.user!),
        );
      }
      return AuthResponseModel(success: false, error: 'Sign in failed.');
    } on AuthException catch (e) {
      return AuthResponseModel(success: false, error: e.message);
    } catch (e) {
      return AuthResponseModel(success: false, error: 'An unexpected error occurred');
    }
  }

  /// Sign up with email and password
  Future<AuthResponseModel> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(email: email, password: password);

      if (response.user != null) {
        return AuthResponseModel(
          success: true,
          user: AuthUser.fromSupabaseUser(response.user!),
        );
      }
      return AuthResponseModel(success: false, error: 'Sign up failed.');
    } on AuthException catch (e) {
      return AuthResponseModel(success: false, error: e.message);
    } catch (e) {
      return AuthResponseModel(success: false, error: 'An unexpected error occurred');
    }
  }

  /// Sign out - centralized session cleanup synced with React session-cleanup.service.ts
  /// Handles: active chats, video calls, private groups, user status, women availability
  Future<void> signOut() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await SessionCleanupService.cleanupAllUserSessions(user.id);
      }
    } catch (_) {
      // Don't block logout if cleanup fails
    }

    await _client.auth.signOut();
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasRole(String role) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    try {
      final response = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .eq('role', role)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAdmin() async => hasRole('admin');

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
