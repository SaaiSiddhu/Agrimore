// lib/screens/settings/device_readiness_screen.dart
//
// Phase DLVOA1 — the discoverable entry point device_readiness.dart's own
// header describes: every concern is re-read from live platform state on
// open AND on every return to the foreground (WidgetsBindingObserver),
// never from a "prompted once" flag, so a permission revoked after this
// screen was last seen shows up as needing attention again. Never gates
// or mentions going online -- that flow is unaffected either way.
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../location/location_disclosure.dart';
import '../../location/rider_platform.dart';
import '../../offers/device_readiness.dart';
import '../../offers/offer_alerts.dart';
import '../../offers/offer_platform.dart';
import '../../providers/location_provider.dart';

class DeviceReadinessScreen extends StatefulWidget {
  const DeviceReadinessScreen({
    super.key,
    this.readiness,
    this.hasLocationPermission,
  });

  /// Injected in tests.
  final Future<List<ReadinessItem>> Function()? readiness;
  final Future<bool> Function()? hasLocationPermission;

  @override
  State<DeviceReadinessScreen> createState() => _DeviceReadinessScreenState();
}

class _DeviceReadinessScreenState extends State<DeviceReadinessScreen>
    with WidgetsBindingObserver {
  List<ReadinessItem>? _items;
  bool _fixing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A rider who left this screen to change a setting in the OS Settings
    // app returns here in "resumed" -- reread rather than show a stale row.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final items = await (widget.readiness ?? _defaultReadiness)();
    if (mounted) setState(() => _items = items);
  }

  Future<List<ReadinessItem>> _defaultReadiness() => currentDeviceReadiness(
        hasLocationPermission:
            widget.hasLocationPermission ?? _defaultHasLocationPermission,
      );

  Future<bool> _defaultHasLocationPermission() =>
      LocationProvider().canTrackWithoutPrompt();

  Future<void> _fix(ReadinessItemId id) async {
    if (_fixing || !mounted) return;
    setState(() => _fixing = true);
    try {
      switch (id) {
        case ReadinessItemId.notifications:
          await ensureOfferAlertPermissions(context);
        case ReadinessItemId.fullScreenAlert:
          await OfferPlatform.canUseFullScreenIntent();
          if (mounted) await ensureOfferAlertPermissions(context);
        case ReadinessItemId.location:
          await LocationProvider().ensurePermission();
        case ReadinessItemId.backgroundLocation:
          if (mounted) await ensureBackgroundLocation(context);
        case ReadinessItemId.battery:
          await RiderPlatform.openBatterySettings();
      }
    } catch (e) {
      debugPrint('Readiness fix failed for $id: $e');
    } finally {
      if (mounted) setState(() => _fixing = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final items = _items;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.readinessScreenTitle)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(DeliverySpace.page),
              children: [
                Text(
                  l.readinessScreenIntro,
                  style: t.bodyMedium.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: DeliverySpace.lg),
                for (final item in items) ...[
                  _readinessRow(context, item),
                  const SizedBox(height: DeliverySpace.sm),
                ],
              ],
            ),
    );
  }

  Widget _readinessRow(BuildContext context, ReadinessItem item) {
    final l = AppLocalizations.of(context);
    final (title, body) = switch (item.id) {
      ReadinessItemId.notifications => (
          l.readinessNotificationsTitle,
          l.readinessNotificationsBody,
        ),
      ReadinessItemId.fullScreenAlert => (
          l.readinessFullScreenTitle,
          l.readinessFullScreenBody,
        ),
      ReadinessItemId.location => (
          l.readinessLocationTitle,
          l.readinessLocationBody,
        ),
      ReadinessItemId.backgroundLocation => (
          l.readinessBackgroundLocationTitle,
          l.readinessBackgroundLocationBody,
        ),
      ReadinessItemId.battery => (
          l.readinessBatteryTitle,
          l.readinessBatteryBody,
        ),
    };
    final icon = switch (item.id) {
      ReadinessItemId.notifications => DeliveryIcons.bell,
      ReadinessItemId.fullScreenAlert => DeliveryIcons.shieldAlert,
      ReadinessItemId.location => DeliveryIcons.location,
      ReadinessItemId.backgroundLocation => DeliveryIcons.locate,
      ReadinessItemId.battery => DeliveryIcons.battery,
    };
    final c = context.colors;
    final t = context.text;
    return DeliveryBanner(
      key: ValueKey('readiness-${item.id.name}'),
      tone: item.ready ? DeliveryTone.success : DeliveryTone.warning,
      icon: icon,
      title: title,
      body: body,
      trailing: Text(
        item.ready ? l.readinessReady : l.readinessActionNeeded,
        style: t.labelMedium.copyWith(
          color: item.ready ? c.success.text : c.warning.text,
        ),
      ),
      actionLabel: !item.ready && item.actionable ? l.readinessFix : null,
      onAction: !item.ready && item.actionable && !_fixing
          ? () => _fix(item.id)
          : null,
    );
  }
}
