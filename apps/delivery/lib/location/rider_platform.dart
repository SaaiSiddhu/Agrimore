// lib/location/rider_platform.dart
//
// Phase DLV-3A2 — the Dart side of MainActivity's com.agrimore.delivery/rider
// channel: the native RiderLocationService (RiderLocationService.kt) that
// sends the rider's location while online, independent of the Flutter screen
// (D-DLV-NATIVE-LOC), and the checks the go-online flow needs.
//
// Android only. Elsewhere (tests, web) [available] is false and callers fall
// back to the Dart uploader in LocationProvider.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';

class RiderPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.agrimore.delivery/rider');

  static bool get available => !kIsWeb && Platform.isAndroid;

  static Future<T?> _call<T>(String method) async {
    if (!available) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } catch (e) {
      debugPrint('RiderPlatform.$method failed: $e');
      return null;
    }
  }

  /// Starts the native service; false when Android refused.
  static Future<bool> start() async => await _call<bool>('start') ?? false;

  /// Stops it and clears its restart flag.
  static Future<void> stop() async => _call<void>('stop');

  static Future<bool> isRunning() async =>
      await _call<bool>('isRunning') ?? false;

  /// 'Allow all the time' granted (always true before Android 10).
  static Future<bool> hasBackgroundLocation() async =>
      await _call<bool>('hasBackgroundLocation') ?? false;

  /// Asks for background location ALONE (Android 11+ drops a bundled
  /// request); true when granted.
  static Future<bool> requestBackgroundLocation() async =>
      await _call<bool>('requestBackgroundLocation') ?? false;

  /// The phone is not battery-optimising the app.
  static Future<bool> isIgnoringBatteryOptimizations() async =>
      await _call<bool>('isIgnoringBatteryOptimizations') ?? true;

  /// Opens the app's settings page (Battery / Autostart are there).
  static Future<bool> openBatterySettings() async =>
      await _call<bool>('openBatterySettings') ?? false;
}
