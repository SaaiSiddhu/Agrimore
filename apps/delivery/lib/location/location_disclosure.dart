// lib/location/location_disclosure.dart
//
// Phase DLV-3A / Phase 19 — the prominent disclosure Google Play requires
// before an app collects location while it is closed or not in use. Shown
// once, before the first location permission prompt; a rider who declines
// cannot go online (orders are offered by distance), and is asked again next
// time.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/design_system.dart';
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
  final c = context.colors;
  final t = context.text;

  final ok = await showDeliveryDisclosureDialog(
    context: context,
    icon: DeliveryIcons.location,
    title: l.locationDisclosureTitle,
    confirmLabel: l.actionContinue,
    cancelLabel: l.actionNotNow,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.locationDisclosureBody,
          style: t.bodyMedium.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DeliverySpace.md),
        DeliveryCard(
          variant: DeliveryCardVariant.brand,
          padding: const EdgeInsets.all(DeliverySpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DisclosurePoint(
                icon: DeliveryIcons.compass,
                text: l.locDisclosureBullet1,
              ),
              const SizedBox(height: DeliverySpace.sm),
              _DisclosurePoint(
                icon: DeliveryIcons.route,
                text: l.locDisclosureBullet2,
              ),
              const SizedBox(height: DeliverySpace.sm),
              _DisclosurePoint(
                icon: DeliveryIcons.shield,
                text: l.locDisclosureBullet3,
              ),
            ],
          ),
        ),
      ],
    ),
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
  final c = context.colors;
  final t = context.text;

  final ok = await showDeliveryDisclosureDialog(
    context: context,
    icon: DeliveryIcons.locate,
    title: l.backgroundLocationTitle,
    confirmLabel: l.actionContinue,
    cancelLabel: l.actionNotNow,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.backgroundLocationBody,
          style: t.bodyMedium.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DeliverySpace.md),
        DeliveryCard(
          variant: DeliveryCardVariant.muted,
          padding: const EdgeInsets.all(DeliverySpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DisclosurePoint(
                icon: DeliveryIcons.settings,
                text: l.locBackgroundStep1,
              ),
              const SizedBox(height: DeliverySpace.sm),
              _DisclosurePoint(
                icon: DeliveryIcons.check,
                text: l.locBackgroundStep2,
              ),
            ],
          ),
        ),
      ],
    ),
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
  final open = await showDeliveryConfirmDialog(
    context: context,
    icon: DeliveryIcons.battery,
    title: l.batteryGuideTitle,
    body: l.batteryGuideBody,
    confirmLabel: l.actionOpenSettings,
    cancelLabel: l.actionLater,
  );
  if (open) await RiderPlatform.openBatterySettings();
}

class _DisclosurePoint extends StatelessWidget {
  const _DisclosurePoint({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: DeliveryIconSize.sm, color: c.brand),
        const SizedBox(width: DeliverySpace.sm),
        Expanded(
          child: Text(
            text,
            style: t.bodySmall.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
