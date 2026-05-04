import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background message: ${message.notification?.title}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✅ Your VAPID key
  static const String _vapidKey = 'BOe57aGDa_k374ps-OOGLibtGfUpFdYEpCbD-gfzOvXmSHkDIzm63T9N8u7bRxinGM8XpbwcE_dMbWyPd8J_QKY';

  Future<void> initialize({void Function(RemoteMessage message)? onNotificationTap}) async {
    print('🔔 Initializing FCM...');

    // Request permission (iOS & Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    }

    // Initialize local notifications (for mobile)
    if (!kIsWeb) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );
    }

    // Get FCM token with VAPID key
    String? token;
    if (kIsWeb) {
      token = await _messaging.getToken(vapidKey: _vapidKey);
    } else {
      token = await _messaging.getToken();
    }
    
    print('🎫 FCM Token: $token');
    
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // Subscribe to all_users topic
    if (!kIsWeb) {
      try {
        await _messaging.subscribeToTopic('all_users');
        print('✅ Subscribed to all_users topic');
      } catch (e) {
        print('❌ Topic subscription failed: $e');
      }
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // Handle background messages (mobile only)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📬 Foreground message: ${message.notification?.title}');
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    });

    // Handle notification tap (app opened)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Notification tapped: ${message.data}');
      if (onNotificationTap != null) {
        onNotificationTap(message);
      } else {
        _handleNotificationClick(message);
      }
    });
  }

  void _handleNotificationClick(RemoteMessage message) {
    // Note: To navigate, we use a global navigatorKey or routing setup.
    // Ensure you have a global navigatorKey defined in your app.dart
    // and use it here.
    final type = message.data['type'];
    final actionUrl = message.data['actionUrl'];
    final orderId = message.data['orderId'];
    final productId = message.data['productId'];

    // In a real implementation, you would use a global NavigatorKey to navigate
    // e.g. navigatorKey.currentState?.pushNamed(...)
    print('🔀 Notification routing type: $type, orderId: $orderId');
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': token, // Store exactly as requested by user
        'fcmTokens': FieldValue.arrayUnion([token]), // Keep array for multi-device support
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Token saved to Firestore');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'agrimore_customer_channel',
      'Agrimore Customer Alerts',
      channelDescription: 'Order updates, product reveals, and important alerts.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFF0D9B5C), // Agrimore Green
      enableLights: true,
      ledColor: Color(0xFF0D9B5C),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }
}
