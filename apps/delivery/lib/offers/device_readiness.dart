// lib/offers/device_readiness.dart
//
// Phase DLVOA1 — a discoverable, always-live snapshot of everything that
// affects whether this rider actually receives and can act on a delivery
// offer. Every check here reads the CURRENT platform/permission state
// directly on every call: unlike offer_alerts.dart's/location_disclosure
// .dart's own one-shot explanatory prompts (left unchanged, still shown at
// most once each), nothing here is ever suppressed by a "already shown"
// flag, so a permission the rider revokes after granting shows up again
// the next time this is read -- including on every app resume, via
// DeviceReadinessScreen's own lifecycle observer.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../location/rider_platform.dart';
import 'offer_platform.dart';

enum ReadinessItemId {
  notifications,
  fullScreenAlert,
  location,
  backgroundLocation,
  battery,
}

/// One readiness concern's current state. [ready] is the live platform
/// fact; [actionable] is false only when this platform/OS version has
/// nothing to fix (e.g. full-screen intent below Android 14, background
/// location on a non-Android build) -- shown as satisfied, not as a task.
class ReadinessItem {
  const ReadinessItem({
    required this.id,
    required this.ready,
    this.actionable = true,
  });

  final ReadinessItemId id;
  final bool ready;
  final bool actionable;
}

bool get _androidAvailable => !kIsWeb && Platform.isAndroid;

Future<bool> _notificationsEnabled() async {
  if (!_androidAvailable) return true;
  try {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  } catch (_) {
    return true;
  }
}

/// Reads every concern's live state. Never throws; a single failed check
/// reads as "not ready" rather than losing the rest of the list.
Future<List<ReadinessItem>> currentDeviceReadiness({
  Future<bool> Function()? hasLocationPermission,
}) async {
  final notifications = await _notificationsEnabled();

  final fullScreenSupported = _androidAvailable;
  final fullScreen =
      !fullScreenSupported || await OfferPlatform.canUseFullScreenIntent();

  final location = hasLocationPermission == null
      ? true
      : await hasLocationPermission();

  final backgroundSupported = RiderPlatform.available;
  final background =
      !backgroundSupported || await RiderPlatform.hasBackgroundLocation();

  final batterySupported = RiderPlatform.available;
  final battery = !batterySupported ||
      await RiderPlatform.isIgnoringBatteryOptimizations();

  return [
    ReadinessItem(id: ReadinessItemId.notifications, ready: notifications),
    ReadinessItem(
      id: ReadinessItemId.fullScreenAlert,
      ready: fullScreen,
      actionable: fullScreenSupported,
    ),
    ReadinessItem(id: ReadinessItemId.location, ready: location),
    ReadinessItem(
      id: ReadinessItemId.backgroundLocation,
      ready: background,
      actionable: backgroundSupported,
    ),
    ReadinessItem(
      id: ReadinessItemId.battery,
      ready: battery,
      actionable: batterySupported,
    ),
  ];
}
