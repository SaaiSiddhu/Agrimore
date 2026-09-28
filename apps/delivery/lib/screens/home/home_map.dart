// lib/screens/home/home_map.dart
//
// Phase DLVHOME1 — Home's own real, interactive map (owner brief: "Redesign
// Home around a real, interactive map"). Reuses the existing map SDK
// (google_maps_flutter, already used by rider_route_card.dart), the existing
// LocationProvider (never a second location subscription while the rider is
// online — LocationProvider.currentPosition is read, not re-subscribed to;
// only when offline does this widget make a single one-shot
// Geolocator.getCurrentPosition/getLastKnownPosition call for an initial
// camera target, exactly once per permission grant) and Geolocator's own
// settings launchers for permission/service recovery, matching
// rider_route_card.dart's established _checkSettings pattern. No synthetic
// roads, no fabricated location, no mock operational data — genuinely honest
// loading / permission-denied / location-disabled / unavailable / failure
// states, each with a real recovery action.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/location_provider.dart';

/// Google's own published night-mode style (public, no proprietary/owner
/// data) — the only supported way to darken google_maps_flutter's tiles;
/// nothing here is a fabricated overlay.
const String _kDarkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1a1a"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a1a1a"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#242424"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#7a7a7a"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#383838"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9a9a9a"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#4a4a4a"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2a2a2a"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e0e0e"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#5a5a5a"}]}
]
''';

/// A neutral fallback centre (India, zoomed far out) used only when neither
/// LocationProvider nor a one-shot fix has ever produced a real position —
/// never presented as the rider's own location (no marker/blue dot is drawn
/// for it; it only frames an otherwise-empty map so pan/zoom still work).
const LatLng _kFallbackCenter = LatLng(22.3511, 78.6677);

enum _MapState { loading, ready, permissionDenied, servicesDisabled, unavailable }

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  State<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  GoogleMapController? _controller;
  LatLng? _initialTarget;
  _MapState _state = _MapState.loading;
  bool _following = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    // GoogleMapController itself needs no explicit dispose call (the
    // platform view owns its lifecycle); dropping the reference here is
    // enough to avoid holding a stale controller past this widget's life.
    _controller = null;
    super.dispose();
  }

  LocationProvider get _location => context.read<LocationProvider>();

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    setState(() => _state = _MapState.loading);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _state = _MapState.servicesDisabled);
        return;
      }
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        setState(() => _state = _MapState.permissionDenied);
        return;
      }
      final live = _location.currentPosition;
      if (live != null) {
        _initialTarget = LatLng(live.latitude, live.longitude);
        setState(() => _state = _MapState.ready);
        return;
      }
      // Offline (LocationProvider is not streaming yet): exactly one
      // best-effort fix for the initial camera target, never a stream of
      // our own alongside LocationProvider's.
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: DeliveryMotion.locationTimeout,
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        setState(() => _state = _MapState.unavailable);
        return;
      }
      _initialTarget = LatLng(pos.latitude, pos.longitude);
      setState(() => _state = _MapState.ready);
    } catch (e) {
      debugPrint('HomeMap: location check failed: $e');
      setState(() => _state = _MapState.unavailable);
    } finally {
      _checking = false;
    }
  }

  Future<void> _recenter() async {
    final live = _location.currentPosition;
    final target = live != null
        ? LatLng(live.latitude, live.longitude)
        : _initialTarget;
    if (target == null || _controller == null) {
      // No known fix at all: re-run the honest check instead of pretending.
      await _check();
      return;
    }
    setState(() => _following = true);
    await _controller!.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  Future<void> _openSettings(_MapState state) => state == _MapState.servicesDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    // Live position while the rider is online, tracked by LocationProvider
    // itself (no second subscription) — moves the blue dot / recenter
    // target without re-querying anything here.
    final live = context.select<LocationProvider, Position?>((p) => p.currentPosition);
    final myLocationEnabled = _state == _MapState.ready;

    if (_state == _MapState.loading && _initialTarget == null) {
      return ColoredBox(
        color: c.surfaceMuted,
        child: Center(
          child: DeliveryLoadingState(label: l.homeMapLoading),
        ),
      );
    }

    final center = live != null
        ? LatLng(live.latitude, live.longitude)
        : (_initialTarget ?? _kFallbackCenter);

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          key: const ValueKey('home-map'),
          initialCameraPosition: CameraPosition(target: center, zoom: 15),
          style: c.isDark ? _kDarkMapStyle : null,
          myLocationEnabled: myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          onMapCreated: (ctrl) => _controller = ctrl,
          // A deliberate pan/pinch by the rider stops auto-follow until
          // they tap recenter again — the map must never keep snapping back
          // while they are exploring it.
          onCameraMoveStarted: () {
            if (_following) setState(() => _following = false);
          },
        ),
        if (_state != _MapState.ready)
          Positioned(
            left: DeliverySpace.page,
            right: DeliverySpace.page,
            top: DeliverySpace.md,
            child: _StateBanner(
              state: _state,
              onRetry: _check,
              onOpenSettings: () => _openSettings(_state),
            ),
          ),
        Positioned(
          right: DeliverySpace.md,
          bottom: DeliverySpace.md,
          child: _RecenterButton(
            key: const ValueKey('home-map-recenter'),
            following: _following,
            onTap: _recenter,
          ),
        ),
      ],
    );
  }
}

class _StateBanner extends StatelessWidget {
  const _StateBanner({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final _MapState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    switch (state) {
      case _MapState.permissionDenied:
        return DeliveryBanner(
          key: const ValueKey('home-map-permission-denied'),
          tone: DeliveryBannerTone.warning,
          icon: DeliveryIcons.locationOff,
          title: l.homeMapPermissionDeniedTitle,
          body: l.homeMapPermissionDeniedBody,
          actionLabel: l.actionOpenSettings,
          onAction: onOpenSettings,
        );
      case _MapState.servicesDisabled:
        return DeliveryBanner(
          key: const ValueKey('home-map-services-disabled'),
          tone: DeliveryBannerTone.warning,
          icon: DeliveryIcons.locationOff,
          title: l.homeMapServicesDisabledTitle,
          body: l.homeMapServicesDisabledBody,
          actionLabel: l.actionOpenSettings,
          onAction: onOpenSettings,
        );
      case _MapState.unavailable:
        return DeliveryBanner(
          key: const ValueKey('home-map-unavailable'),
          tone: DeliveryBannerTone.danger,
          icon: DeliveryIcons.offline,
          title: l.homeMapUnavailableTitle,
          body: l.homeMapUnavailableBody,
          actionLabel: l.actionRetry,
          onAction: onRetry,
        );
      case _MapState.loading:
      case _MapState.ready:
        return const SizedBox.shrink();
    }
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({super.key, required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.homeMapRecenter,
      child: Material(
        color: c.raised,
        shape: const CircleBorder(),
        elevation: DeliveryElevation.floating,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: DeliverySize.touchTarget,
            height: DeliverySize.touchTarget,
            child: Icon(
              DeliveryIcons.locate,
              color: following ? c.primary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
