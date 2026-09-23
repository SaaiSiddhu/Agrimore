// lib/location/location_disclosure.dart
//
// Phase DLV-3A — the prominent disclosure Google Play requires before an app
// collects location while it is closed or not in use. Shown once, before the
// first location permission prompt; a rider who declines cannot go online
// (orders are offered by distance), and is asked again next time.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_policy.dart';
import 'rider_platform.dart';

const String _acceptedKey = 'dlv3a_location_disclosure_accepted';

Future<bool> locationDisclosureAccepted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) == true;
  } catch (e) {
    debugPrint('Disclosure flag read failed: $e');
    return false;
  }
}

/// True when the rider has accepted (now or before).
Future<bool> ensureLocationDisclosure(BuildContext context) async {
  if (await locationDisclosureAccepted()) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.location_on_rounded, size: 32),
      title: const Text(locationDisclosureTitle),
      content: const SingleChildScrollView(child: Text(locationDisclosureBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
  } catch (e) {
    debugPrint('Disclosure flag write failed: $e');
  }
  return true;
}

// Phase DLV-3A2 (D-DLV-BGLOC-ALWAYS) — the second step: 'Allow all the time',
// so location sharing restarts if the phone closes the app. Asked after the
// while-in-use grant (Android 11+ sends the rider to Settings for it). A rider
// who declines can still go online (see [backgroundLocationReminder]).
Future<bool> ensureBackgroundLocation(BuildContext context) async {
  if (!RiderPlatform.available) return true;
  if (await RiderPlatform.hasBackgroundLocation()) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.my_location_rounded, size: 32),
      title: const Text(backgroundLocationTitle),
      content: const SingleChildScrollView(child: Text(backgroundLocationBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  // Not Geolocator.requestPermission(): it bundles background with the
  // foreground permissions, which Android 11+ silently drops (device run).
  return RiderPlatform.requestBackgroundLocation();
}

const String _batteryGuideKey = 'dlv3a2_battery_guide_shown';

// Phase DLV-3A2 (D-DLV-BATTERY) — once, on first going online, when the phone
// is battery-optimising the app: explain and open the app's settings page.
Future<void> maybeShowBatteryGuide(BuildContext context) async {
  if (!RiderPlatform.available) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_batteryGuideKey) == true) return;
    if (await RiderPlatform.isIgnoringBatteryOptimizations()) return;
    await prefs.setBool(_batteryGuideKey, true);
  } catch (e) {
    debugPrint('Battery guide check failed: $e');
    return;
  }
  if (!context.mounted) return;
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.battery_saver_rounded, size: 32),
      title: const Text(batteryGuideTitle),
      content: const SingleChildScrollView(child: Text(batteryGuideBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
  if (open == true) await RiderPlatform.openBatterySettings();
}
