// lib/offers/offer_alerts.dart
//
// Phase DLV-2B — the ringing alert for a delivery offer (D-DLV-ALERT: loud
// notification AND full-screen ringing, like Zomato/Swiggy).
//
// One Android notification does all of it:
//  • channel 'delivery_offers', importance max, the phone's ringtone, a strong
//    vibration pattern;
//  • FLAG_INSISTENT (4): the sound repeats until the notification goes away;
//  • fullScreenIntent + category call: over the lock screen it opens the app
//    straight onto the offer (MainActivity lifts the lock-screen barrier only
//    for this payload); while the phone is in use Android shows it as a
//    heads-up instead;
//  • timeoutAfter = the offer's remaining life, so an ignored offer stops
//    ringing on its own when it expires.
// No bundled audio file: the ringtone URI is the phone's own.
//
// It is raised from two places: the foreground OfferProvider (Firestore
// listener — works without FCM), and the FCM background handler below when
// the app is in the background or killed.
import 'package:agrimore_core/agrimore_core.dart';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agrimore_services/agrimore_services.dart'
    show NotificationService;
import 'package:agrimore_ui/agrimore_ui.dart' show wsConfirm;
import 'package:shared_preferences/shared_preferences.dart';

import '../app/device_localizations.dart';
import '../l10n/app_localizations.dart';
import 'delivery_offer.dart';
import 'offer_platform.dart';

const String offersChannelId = 'delivery_offers';
const UriAndroidNotificationSound _ringtone =
    UriAndroidNotificationSound('content://settings/system/ringtone');
final Int64List _vibration = Int64List.fromList([0, 900, 500, 900, 500, 900]);

/// Android's Notification.FLAG_INSISTENT: repeat the sound until cancelled.
const int _flagInsistent = 4;

/// The ringing alert is Android-only (the delivery app ships only there);
/// everywhere else — tests, web — the calls below do nothing.
bool get _alertsSupported => !kIsWeb && Platform.isAndroid;

/// The offers channel, named in the device language (lib/l10n).
AndroidNotificationChannel get offersChannel => AndroidNotificationChannel(
  offersChannelId,
  deviceLocalizations().offerChannelName,
  description: deviceLocalizations().offerChannelDescription,
  importance: Importance.max,
  playSound: true,
  sound: _ringtone,
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  enableVibration: true,
  vibrationPattern: _vibration,
);

/// Raises (or refreshes) the ringing alert for [orderId]. No-op once expired.
Future<void> showOfferAlert(
  FlutterLocalNotificationsPlugin plugin, {
  required String orderId,
  required DateTime expiresAt,
  required String body,
  DateTime? now,
}) async {
  if (!_alertsSupported) return;
  final remaining = expiresAt.difference(now ?? DateTime.now());
  if (remaining.inMilliseconds <= 0) return;
  final l = deviceLocalizations();
  final details = AndroidNotificationDetails(
    offersChannelId,
    l.offerChannelName,
    channelDescription: l.offerChannelDescription,
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    fullScreenIntent: true,
    visibility: NotificationVisibility.public, // offers carry no customer data
    ongoing: true,
    autoCancel: false,
    timeoutAfter: remaining.inMilliseconds,
    additionalFlags: Int32List.fromList([_flagInsistent]),
    sound: _ringtone,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
    vibrationPattern: _vibration,
    // Monochrome (alpha-only) status-bar icon; the launcher icon renders as
    // a blank square there.
    icon: 'ic_stat_delivery_offer',
  );
  await plugin.show(
    offerNotificationId(orderId),
    l.offerNotificationTitle,
    body,
    NotificationDetails(android: details),
    payload: offerPayload(orderId),
  );
}

Future<void> cancelOfferAlert(
    FlutterLocalNotificationsPlugin plugin, String orderId) async {
  if (!_alertsSupported) return;
  try {
    await plugin.cancel(offerNotificationId(orderId));
  } catch (e) {
    // Never let a failed cancel break the screen that is closing; the alert
    // also times out on its own at the offer's expiry.
    debugPrint('Cancelling offer alert failed: $e');
  }
}

/// FCM background/terminated handler for this app. Offers get the ringing
/// full-screen alert; every other message keeps the shared behaviour.
@pragma('vm:entry-point')
Future<void> deliveryBackgroundMessageHandler(RemoteMessage message) async {
  if (message.data['type'] != 'delivery_offer') {
    await NotificationService.showAdvancedNotification(message);
    return;
  }
  final orderId = message.data['orderId'];
  final expiresMs = int.tryParse('${message.data['expiresAt']}');
  if (orderId is! String || orderId.isEmpty || expiresMs == null) return;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresMs);
  if (!expiresAt.isAfter(DateTime.now())) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(offersChannel);

  // The push also carries a plain notification block (so builds that predate
  // DLV-2B still show something); Android posts that copy itself with the tag
  // dispatch.ts sets. Give it a moment to land, then replace it with the
  // ringing full-screen alert under a different id, so a late system copy can
  // never overwrite the ring.
  await Future<void>.delayed(DeliveryTiming.offerAlertReplaceDelay);
  await plugin.cancel(0, tag: offerNotificationTag(orderId));
  await showOfferAlert(
    plugin,
    orderId: orderId,
    expiresAt: expiresAt,
    body: message.notification?.body ?? deviceLocalizations().offerNotificationBody,
  );
}

const String _fullScreenPromptedKey = 'dlv2b_full_screen_prompted';

/// Asks for what the ringing alert needs, once, with an explanation first:
/// POST_NOTIFICATIONS (Android 13+) and, on Android 14+, full-screen alerts.
/// Never blocks going online — a rider who declines still gets heads-up
/// notifications and the in-app offer screen.
Future<void> ensureOfferAlertPermissions(BuildContext context) async {
  final android = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  try {
    await android.requestNotificationsPermission();
    if (await OfferPlatform.canUseFullScreenIntent()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_fullScreenPromptedKey) == true) return;
    await prefs.setBool(_fullScreenPromptedKey, true);
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    final ok = await wsConfirm(
      context,
      title: l.offerRingPromptTitle,
      message: l.offerRingPromptBody,
      confirmLabel: l.actionAllow,
      cancelLabel: l.actionNotNow,
    );
    if (ok == true) await android.requestFullScreenIntentPermission();
  } catch (e) {
    debugPrint('Offer alert permission request failed: $e');
  }
}
