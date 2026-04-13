import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../firebase_options.dart';
import '../app/routes.dart';

// Global Notification Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background Handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message: ${message.notification?.title}');
  debugPrint('📦 Background data: ${message.data}');
  
  if (!kIsWeb) {
    await NotificationService.showAdvancedNotification(message);
  }
}

class NotificationService {
  static String? _pendingFCMToken;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    if (kIsWeb) {
      // Web initialization is handled by FCMService
      return;
    }
    await _initializeMobileFCM();
  }

  static Future<void> _initializeMobileFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('✅ Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await messaging.getToken();
      debugPrint('🎫 FCM Token: $token');

      if (token != null) {
        _pendingFCMToken = token;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await savePendingToken(currentUser.uid);
        } else {
          debugPrint('⏳ Token will be saved after login');
        }
      }

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      // Enhanced notification tap handler
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          debugPrint('📱 Notification tapped!');
          debugPrint('📦 Payload: ${response.payload}');
          
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(response.payload!);
              debugPrint('📦 Parsed data: $data');
              
              final actionUrl = data['actionUrl'] as String?;
              if (actionUrl != null && actionUrl.isNotEmpty) {
                debugPrint('🎯 ActionUrl found: $actionUrl');
                handleNotificationNavigation(actionUrl);
              } else {
                debugPrint('⚠️ No actionUrl in payload');
              }
            } catch (e) {
              debugPrint('⚠️ Payload not JSON, treating as string: ${response.payload}');
            }
          }
        },
      );

      // Create notification channels
      await _createNotificationChannels();

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('📬 Foreground message received');
        debugPrint('📦 Title: ${message.notification?.title}');
        debugPrint('📦 Body: ${message.notification?.body}');
        debugPrint('📦 Data: ${message.data}');
        
        await showAdvancedNotification(message);
      });

      // Handle notification opened app (background state)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📱 Notification opened app from background');
        debugPrint('📦 Data: ${message.data}');
        
        final actionUrl = message.data['actionUrl'] as String?;
        if (actionUrl != null && actionUrl.isNotEmpty) {
          debugPrint('🎯 Navigating to: $actionUrl');
          Future.delayed(const Duration(milliseconds: 500), () {
            handleNotificationNavigation(actionUrl);
          });
        }
      });

      // Handle app opened from terminated state
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📱 App opened from terminated state via notification');
        debugPrint('📦 Initial message data: ${initialMessage.data}');
        
        final actionUrl = initialMessage.data['actionUrl'] as String?;
        if (actionUrl != null && actionUrl.isNotEmpty) {
          debugPrint('🎯 Initial navigation to: $actionUrl');
          Future.delayed(const Duration(seconds: 1), () {
            handleNotificationNavigation(actionUrl);
          });
        }
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 Token refreshed: $newToken');
        _pendingFCMToken = newToken;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          savePendingToken(currentUser.uid);
        }
      });
    }
  }

  static Future<void> savePendingToken(String userId) async {
    if (_pendingFCMToken == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([_pendingFCMToken!]),
        'lastTokenUpdate': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      debugPrint('✅ FCM Token saved to Firestore for user: $userId');
      _pendingFCMToken = null;
    } catch (e) {
      debugPrint('❌ Error saving token: $e');
    }
  }

  static Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'default_channel',
        'Default Notifications',
        description: 'Default notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'high_priority_channel',
        'Important Notifications',
        description: 'Important notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'product_channel',
        'Product Notifications',
        description: 'Product notifications',
        importance: Importance.high,
        playSound: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'order_channel',
        'Order Notifications',
        description: 'Order notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    ];

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    for (var channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }
    debugPrint('✅ Notification channels created');
  }

  static Future<void> showAdvancedNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    if (notification == null) return;

    debugPrint('🔔 Showing notification: ${notification.title}');
    debugPrint('📦 Notification data: ${message.data}');

    String? imageUrl = message.data['imageUrl'] as String?;
    String? notificationType = message.data['type'] as String?;
    String? actionUrl = message.data['actionUrl'] as String?;
    String? bigPicturePath;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      bigPicturePath = await _downloadAndSaveFile(imageUrl, 'notification_image');
    }

    String channelId = notificationType == 'product'
        ? 'product_channel'
        : notificationType == 'urgent'
            ? 'high_priority_channel'
            : notificationType == 'order'
                ? 'order_channel'
                : 'default_channel';

    final payload = jsonEncode({
      'actionUrl': actionUrl ?? '',
      'imageUrl': imageUrl ?? '',
      'type': notificationType ?? 'general',
      ...message.data,
    });

    debugPrint('📦 Notification payload: $payload');

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: 'Agrimore notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      color: const Color(0xFF2E7D32),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: bigPicturePath != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(bigPicturePath),
              largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              contentTitle: notification.title,
              htmlFormatContentTitle: true,
              summaryText: notification.body,
              htmlFormatSummaryText: true,
              hideExpandedLargeIcon: false,
            )
          : BigTextStyleInformation(
              notification.body ?? '',
              htmlFormatBigText: true,
              contentTitle: notification.title,
              htmlFormatContentTitle: true,
            ),
      actions: const [
        AndroidNotificationAction('open', 'Open', showsUserInterface: true)
      ],
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title ?? 'Agrimore',
      notification.body ?? '',
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          badgeNumber: 1,
        ),
      ),
      payload: payload,
    );

    debugPrint('✅ Notification shown successfully');
  }

  static String _getChannelName(String channelId) => {
        'product_channel': 'Product Notifications',
        'high_priority_channel': 'Important Notifications',
        'order_channel': 'Order Notifications'
      }[channelId] ??
      'Default Notifications';

  static Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName.jpg';
      final response = await http.get(Uri.parse(url));
      await File(filePath).writeAsBytes(response.bodyBytes);
      debugPrint('✅ Image downloaded: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Error downloading image: $e');
      return null;
    }
  }

  static void handleNotificationNavigation(String actionUrl) {
    debugPrint('🚀 handleNotificationNavigation called with: $actionUrl');
    
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ Navigator context is null, retrying in 1 second...');
      Future.delayed(const Duration(seconds: 1), () {
        handleNotificationNavigation(actionUrl);
      });
      return;
    }

    try {
      String cleanUrl = actionUrl.trim().replaceAll(RegExp(r'^/+|/+$'), '');
      debugPrint('🧹 Cleaned URL: $cleanUrl');

      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        debugPrint('🌐 External URL detected, opening in browser...');
        return;
      }

      if (!cleanUrl.startsWith('/')) {
        cleanUrl = '/$cleanUrl';
      }
      debugPrint('📍 Final route: $cleanUrl');

      final uri = Uri.parse(cleanUrl);
      final path = uri.path;
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();

      debugPrint('🔍 Path segments: $segments');

      if (segments.isEmpty) {
        Navigator.of(context).pushNamed('/');
        return;
      }

      final firstSegment = segments[0];

      switch (firstSegment) {
        case 'product':
          if (segments.length >= 2) {
            final productId = segments[1];
            debugPrint('🛍️ Navigating to product: $productId');
            AppRoutes.navigateToProductDetails(context, productId);
          }
          break;

        case 'order':
        case 'orders':
          if (segments.length >= 2) {
            final orderId = segments[1];
            debugPrint('📦 Navigating to order: $orderId');
            AppRoutes.navigateToOrderDetails(context, orderId);
          } else {
            debugPrint('📦 Navigating to orders list');
            AppRoutes.navigateToOrders(context);
          }
          break;

        case 'category':
          if (segments.length >= 2) {
            final categoryId = segments[1];
            debugPrint('📂 Navigating to category: $categoryId');
            AppRoutes.navigateToCategoryProducts(context, categoryId);
          }
          break;

        case 'profile':
          debugPrint('👤 Navigating to profile');
          Navigator.of(context).pushNamed('/profile');
          break;

        case 'cart':
          debugPrint('🛒 Navigating to cart');
          Navigator.of(context).pushNamed('/cart');
          break;

        case 'wishlist':
          debugPrint('❤️ Navigating to wishlist');
          Navigator.of(context).pushNamed('/wishlist');
          break;

        default:
          debugPrint('📍 Navigating to generic route: $cleanUrl');
          Navigator.of(context).pushNamed(cleanUrl).catchError((error) {
            debugPrint('❌ Navigation error: $error');
            Navigator.of(context).pushNamed('/');
          });
      }
    } catch (e) {
      debugPrint('❌ Navigation exception: $e');
      Navigator.of(context).pushNamed('/');
    }
  }
}
