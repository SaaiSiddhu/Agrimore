// lib/location/location_disclosure.dart
//
// Phase DLV-3A — the prominent disclosure Google Play requires before an app
// collects location while it is closed or not in use. Shown once, before the
// first location permission prompt; a rider who declines cannot go online
// (orders are offered by distance), and is asked again next time.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
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
  final l = AppLocalizations.of(context);
  final ok = await wsConfirm(
    context,
    icon: AgIcons.location,
    title: l.locationDisclosureTitle,
    message: l.locationDisclosureBody,
    confirmLabel: l.actionContinue,
    cancelLabel: l.actionNotNow,
    dismissible: false,
  );
  if (!ok) return false;
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
// who declines can still go online (see backgroundLocationReminder in lib/l10n).
Future<bool> ensureBackgroundLocation(BuildContext context) async {
  if (!RiderPlatform.available) return true;
  if (await RiderPlatform.hasBackgroundLocation()) return true;
  if (!context.mounted) return false;
  final l = AppLocalizations.of(context);
  final ok = await wsConfirm(
    context,
    icon: AgIcons.locate,
    title: l.backgroundLocationTitle,
    message: l.backgroundLocationBody,
    confirmLabel: l.actionContinue,
    cancelLabel: l.actionNotNow,
  );
  if (!ok) return false;
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
  final l = AppLocalizations.of(context);
  final open = await wsConfirm(
    context,
    icon: AgIcons.battery,
    title: l.batteryGuideTitle,
    message: l.batteryGuideBody,
    confirmLabel: l.actionOpenSettings,
    cancelLabel: l.actionLater,
  );
  if (open) await RiderPlatform.openBatterySettings();
}
