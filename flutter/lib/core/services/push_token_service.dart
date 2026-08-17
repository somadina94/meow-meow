import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers the device's FCM token with Supabase so the `send-push`
/// edge function can push to it.
///
/// Web stores tokens in `push_subscriptions` (endpoint+p256dh+auth).
/// Native stores tokens in the same table using `endpoint = "fcm:<token>"`,
/// keeping the existing send-push function compatible without DB changes.
final pushTokenServiceProvider =
    Provider<PushTokenService>((ref) => PushTokenService());

class PushTokenService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Call after the user is signed in.
  Future<void> registerForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PushToken] no FCM token yet');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      final endpoint = 'fcm:$token';

      await _client.from('push_subscriptions').upsert({
        'user_id': user.id,
        'endpoint': endpoint,
        'p256dh': '', // unused for FCM but column is NOT NULL on web schema
        'auth': '',
        'user_agent': 'flutter-$platform',
      }, onConflict: 'user_id,endpoint');

      // Refresh token if Firebase rotates it.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await _client.from('push_subscriptions').upsert({
            'user_id': user.id,
            'endpoint': 'fcm:$newToken',
            'p256dh': '',
            'auth': '',
            'user_agent': 'flutter-$platform',
          }, onConflict: 'user_id,endpoint');
        } catch (e) {
          debugPrint('[PushToken] refresh upsert failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[PushToken] register failed: $e');
    }
  }

  Future<void> unregister() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client
          .from('push_subscriptions')
          .delete()
          .eq('user_id', user.id)
          .eq('endpoint', 'fcm:$token');
    } catch (e) {
      debugPrint('[PushToken] unregister failed: $e');
    }
  }
}
