import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  Future<void> initialize() async {
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
    });
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Token saved to Firestore');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
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
