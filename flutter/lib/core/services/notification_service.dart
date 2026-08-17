import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/navigation_key.dart';

/// Notification Service
/// 
/// Handles local and push notifications.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize notification service
  static Future<void> initialize() async {
    // Initialize local notifications
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    // Configure Firebase Messaging
    await _configureFirebaseMessaging();
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    // Request Firebase Messaging permissions
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Configure Firebase Messaging
  static Future<void> _configureFirebaseMessaging() async {
    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification tap when app was terminated
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  /// Handle foreground message
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');
    
    if (message.notification != null) {
      showNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle background message
  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message received: ${message.notification?.title}');
  }

  /// Handle notification open from background/terminated state.
  static void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification opened: ${message.notification?.title}');
    _route(message.data);
  }

  /// Handle local notification tap.
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload == null || !payload.contains(':')) return;
    final parts = payload.split(':');
    _route({'type': parts[0], 'id': parts.sublist(1).join(':')});
  }

  /// Route to the appropriate screen based on FCM data payload.
  ///
  /// Expected payload shapes:
  ///   { "type": "chat",  "id": "<chatId>" }
  ///   { "type": "match", "id": "<userId>" }
  ///   { "type": "gift",  "id": "<senderId>" }
  ///   { "type": "call",  "id": "<callId>", ...callerFields }
  static void _route(Map<String, dynamic> data) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    final type = data['type'] as String?;
    final id = data['id'] as String?;
    if (type == null || id == null) return;

    switch (type) {
      case 'chat':
        nav.pushNamed('/chat/$id');
        break;
      case 'match':
        nav.pushNamed('/profile/$id');
        break;
      case 'gift':
        nav.pushNamed('/wallet');
        break;
      case 'call':
        nav.pushNamed('/incoming-call', arguments: data);
        break;
    }
  }

  /// Show local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'meow_meow_channel',
      'Meow Meow Notifications',
      channelDescription: 'Notifications from Meow Meow app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show chat message notification
  static Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String chatId,
    String? senderPhotoUrl,
  }) async {
    await showNotification(
      title: senderName,
      body: message,
      payload: 'chat:$chatId',
    );
  }

  /// Show match notification
  static Future<void> showMatchNotification({
    required String userName,
    required String userId,
  }) async {
    await showNotification(
      title: 'New Match!',
      body: 'You matched with $userName',
      payload: 'match:$userId',
    );
  }

  /// Show gift notification
  static Future<void> showGiftNotification({
    required String senderName,
    required String giftName,
    required String senderId,
  }) async {
    await showNotification(
      title: 'Gift Received!',
      body: '$senderName sent you a $giftName',
      payload: 'gift:$senderId',
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancel(int id) async {
    await _localNotifications.cancel(id);
  }
}
