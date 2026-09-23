// lib/offers/offer_platform.dart
//
// Phase DLV-2B — the two Android-only switches the offer flow needs, served by
// MainActivity.kt over one method channel:
//
//  • showOverLockScreen(bool) — lets the incoming-offer screen appear over the
//    lock screen and turn the screen on. Enabled only while an offer is on
//    screen and cleared when it closes. A blanket android:showWhenLocked on
//    the activity would leave the whole app (customer names, addresses,
//    phone numbers) readable on a locked phone.
//  • canUseFullScreenIntent() — Android 14+ lets users (and Play policy)
//    revoke full-screen alerts; the app explains before sending the rider to
//    the settings page.
//
// Every call is best-effort: on other platforms, or if the channel is absent
// (tests, web), they do nothing and report "allowed".
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class OfferPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.agrimore.delivery/offers');

  static bool get _android => !kIsWeb && Platform.isAndroid;

  static Future<void> showOverLockScreen(bool show) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('showOverLockScreen', {'show': show});
    } catch (_) {
      // Best effort: the offer still shows normally when unlocked.
    }
  }

  static Future<bool> canUseFullScreenIntent() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } catch (_) {
      return true;
    }
  }
}
