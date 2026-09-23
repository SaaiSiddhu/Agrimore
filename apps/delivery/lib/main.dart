// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart'
    hide DefaultFirebaseOptions;
import 'app/app.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/location_provider.dart';
import 'providers/offer_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'offers/delivery_offer.dart';
import 'offers/offer_alerts.dart';
import 'offers/offer_launch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } else {
    await Firebase.initializeApp();
  }
  // Phase 17, Workstream 2: monitoring mode only — see
  // AppCheckService's header comment. Never blocks startup (activate()
  // swallows its own errors internally).
  await AppCheckService.activate();
  // Phase DLV-2B: delivery offers ring on their own channel and open the
  // incoming-offer screen; every other message keeps the shared handling.
  NotificationService.navigatorKey = deliveryNavigatorKey;
  await NotificationService.initialize(
    backgroundHandler: deliveryBackgroundMessageHandler,
    extraChannels: [offersChannel],
    // In the foreground the OfferProvider listener rings and opens the
    // offer itself (it also works without FCM); skip the plain duplicate.
    onForegroundMessage: (m) async => m.data['type'] == 'delivery_offer',
    onMessageOpened: (m) async {
      if (m.data['type'] != 'delivery_offer') return false;
      OfferLaunch.request(m.data['orderId'] as String?);
      return true;
    },
    onNotificationResponse: (r) {
      final orderId = orderIdFromPayload(r.payload);
      if (orderId == null) return false;
      OfferLaunch.request(orderId);
      return true;
    },
  );
  // Launched by the full-screen offer alert (or a tap on it) from cold.
  try {
    final launch =
        await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      OfferLaunch.request(orderIdFromPayload(launch!.notificationResponse?.payload));
    }
  } catch (e) {
    debugPrint('Notification launch details unavailable: $e');
  }

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeliveryAuthProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryOrderProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => OfferProvider()),
      ],
      child: const App(),
    );
  }
}
