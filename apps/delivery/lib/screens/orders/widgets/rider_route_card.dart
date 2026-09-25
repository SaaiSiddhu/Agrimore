// lib/screens/orders/widgets/rider_route_card.dart
//
// Phase DLV-3B / Phases 21–23 — the rider's route: a map with the road route
// to the store (and on to the customer, greyed), then to the customer after
// pickup — the same delivery_tasks/{orderId}.route the customer's tracking
// screen draws — with the rider's own position trimming what has been ridden,
// a "9 min · 2.6 km" headline, and one tap into Google Maps turn-by-turn.
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart'
    show
        DeliveryPoint,
        DeliveryTaskModel,
        DeliveryTaskStatus,
        RiderLivePoint,
        RouteProgress;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../navigation/rider_navigation.dart';

class RiderRouteCard extends StatefulWidget {
  const RiderRouteCard({
    super.key,
    required this.orderId,
    required this.stepIndex,
    this.dropFallback,
    this.customerName,
  });

  final String orderId;

  /// The active-order screen's DeliveryStep index.
  final int stepIndex;

  /// The order's own delivery coordinates, used until the task has `drop`.
  final DeliveryPoint? dropFallback;
  final String? customerName;

  @override
  State<RiderRouteCard> createState() => _RiderRouteCardState();
}

class _RiderRouteCardState extends State<RiderRouteCard> {
  final _subs = <StreamSubscription<dynamic>>[];
  DeliveryTaskModel? _task;
  DeliveryPoint? _rider;
  GoogleMapController? _map;
  Size? _mapSize;
  String? _framedFor;

  DocumentReference<Map<String, dynamic>> get _taskRef =>
      FirebaseFirestore.instance
          .collection('delivery_tasks')
          .doc(widget.orderId);

  @override
  void initState() {
    super.initState();
    try {
      _subs.add(
        _taskRef.snapshots().listen(
          (s) {
            if (!mounted) return;
            setState(
              () => _task = s.exists ? DeliveryTaskModel.fromFirestore(s) : null,
            );
            _frame();
          },
          onError: (Object e) => debugPrint('Rider route: task stream: $e'),
        ),
      );
      _subs.add(
        _taskRef.collection('live').doc('rider').snapshots().listen(
          (s) {
            if (!mounted) return;
            final p = RiderLivePoint.fromMap(s.data());
            setState(
              () => _rider =
                  p == null ? null : DeliveryPoint(lat: p.lat, lng: p.lng),
            );
            _frame();
          },
          onError: (Object e) => debugPrint('Rider route: live stream: $e'),
        ),
      );
    } catch (e) {
      debugPrint('Rider route: stream unavailable: $e');
    }
  }

  @override
  void didUpdateWidget(RiderRouteCard old) {
    super.didUpdateWidget(old);
    if (old.stepIndex != widget.stepIndex) _frame();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  DeliveryTaskStatus? get _status => taskStatusForStep(widget.stepIndex);
  RiderLeg? get _leg => riderLegFor(_status);
  DeliveryPoint? get _pickup => _task?.pickup;
  DeliveryPoint? get _drop => _task?.drop ?? widget.dropFallback;
  DeliveryPoint? get _target => _leg == RiderLeg.toStore ? _pickup : _drop;

  /// Road legs still ahead, first active, the active one trimmed at the
  /// rider (what has been ridden disappears; GPS drift snaps onto the road).
  ({
    List<List<DeliveryPoint>> legs,
    List<DeliveryPoint>? ahead,
    int? legSeconds,
  }) get _geometry {
    final route = _task?.route;
    final legs = route?.legsAhead(_status) ?? const <List<DeliveryPoint>>[];
    if (legs.isEmpty) return (legs: legs, ahead: null, legSeconds: null);
    final activeIndex = route!.viaPickup && _leg == RiderLeg.toCustomer ? 1 : 0;
    final legSeconds = route.legs[activeIndex].durationSeconds;
    final rider = _rider;
    if (rider == null) {
      return (legs: legs, ahead: legs.first, legSeconds: legSeconds);
    }
    final progress = RouteProgress.along(legs.first, rider);
    if (progress == null) {
      return (legs: legs, ahead: legs.first, legSeconds: legSeconds);
    }
    return (
      legs: legs,
      ahead: progress.onRoute
          ? progress.remaining
          : [rider, ...progress.remaining],
      legSeconds: legSeconds,
    );
  }

  Future<void> _frame() async {
    final map = _map, size = _mapSize;
    if (map == null || size == null) return;
    final key =
        '${_leg?.name}|${_task?.route?.computedAt?.millisecondsSinceEpoch}';
    if (_framedFor == key) return;
    final pts = <DeliveryPoint>[
      if (_rider != null) _rider!,
      if (_target != null) _target!,
      ...?_geometry.legs.firstOrNull,
    ];
    if (pts.length < 2) return;
    final lat = pts.map((p) => p.lat), lng = pts.map((p) => p.lng);
    final center = LatLng(
      (lat.reduce((a, b) => a < b ? a : b) +
              lat.reduce((a, b) => a > b ? a : b)) /
          2,
      (lng.reduce((a, b) => a < b ? a : b) +
              lng.reduce((a, b) => a > b ? a : b)) /
          2,
    );
    final zoom = fitZoomFor(
      pts,
      widthPx: size.width - 72,
      heightPx: size.height - 110,
    );
    try {
      await map.moveCamera(CameraUpdate.newLatLngZoom(center, zoom));
      final region = await map.getVisibleRegion();
      final valid = region.northeast.latitude.isFinite &&
          region.northeast.latitude != region.southwest.latitude;
      if (!valid) throw StateError('map not laid out yet');
      _framedFor = key;
    } catch (e) {
      debugPrint('Rider route: camera: $e');
      Future.delayed(DeliveryMotion.slow, () {
        if (mounted) _frame();
      });
    }
  }

  Future<void> _navigate() async {
    final dest = _target;
    if (dest == null) return;
    var opened = false;
    if (!kIsWeb) {
      try {
        opened = await launchUrl(
          turnByTurnUri(dest),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }
    if (!opened) {
      opened = await launchUrl(
        directionsUri(dest),
        mode: LaunchMode.externalApplication,
      );
    }
    if (!opened && mounted) {
      showDeliveryToast(
        context,
        message: AppLocalizations.of(context).routeMapsMissing,
        tone: DeliveryBannerTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final leg = _leg;
    if (leg == null) return const SizedBox.shrink();
    final geo = _geometry;
    final target = _target;
    final toStore = leg == RiderLeg.toStore;
    final atStore = _status == DeliveryTaskStatus.atPickup;
    final routeColor = c.brand;

    final markers = <Marker>{
      if (_pickup != null && toStore)
        Marker(
          markerId: const MarkerId('store'),
          position: LatLng(_pickup!.lat, _pickup!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: l.routeStore),
        ),
      if (_drop != null)
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(_drop!.lat, _drop!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.customerName ?? l.routeCustomer,
          ),
        ),
      if (_rider != null && kIsWeb)
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_rider!.lat, _rider!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: l.routeYou),
        ),
    };
    LatLng ll(DeliveryPoint p) => LatLng(p.lat, p.lng);
    final polylines = <Polyline>{};
    if (geo.ahead != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('active'),
          points: [for (final p in geo.ahead!) ll(p)],
          color: routeColor,
          width: 6,
          zIndex: 2,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
      for (var i = 1; i < geo.legs.length; i++) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('next_$i'),
            points: [for (final p in geo.legs[i]) ll(p)],
            color: c.textTertiary,
            width: 5,
            zIndex: 1,
            jointType: JointType.round,
          ),
        );
      }
    } else if (_rider != null && target != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('guide'),
          points: [ll(_rider!), ll(target)],
          color: routeColor.withValues(alpha: DeliveryOpacity.disabled),
          width: 4,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ),
      );
    }

    final name = widget.customerName;
    final headline = atStore
        ? l.routeAtStore
        : toStore
            ? l.routeToStore
            : (name != null && name.isNotEmpty
                ? l.routeToCustomer(name)
                : l.routeToCustomerNoName);
    final remaining = geo.ahead == null
        ? null
        : legRemaining(
            leg: geo.legs.first,
            ahead: geo.ahead!,
            legSeconds: geo.legSeconds,
          );
    final sub = atStore
        ? l.routeAtStoreHint
        : remaining != null
            ? legSummary(l, remaining)
            : target == null
                ? (toStore ? l.routeStoreUnknown : l.routeCustomerUnknown)
                : l.routePending;

    final start = target ?? _rider ?? _drop ?? _pickup;
    return DeliveryCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: DeliverySize.mapHeight,
            color: c.surfaceVariant,
            child: start == null
                ? Center(
                    child: Text(
                      l.routeWaiting,
                      style: t.bodyMedium.copyWith(color: c.textSecondary),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      _mapSize = Size(box.maxWidth, box.maxHeight);
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: ll(start),
                          zoom: 14,
                        ),
                        markers: markers,
                        polylines: polylines,
                        myLocationEnabled: !kIsWeb,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        onMapCreated: (ctrl) {
                          _map = ctrl;
                          _framedFor = null;
                          Future.delayed(DeliveryMotion.slow, _frame);
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeliverySpace.lg,
              DeliverySpace.md,
              DeliverySpace.lg,
              DeliverySpace.md,
            ),
            child: Row(
              children: [
                Container(
                  width: DeliverySize.avatarMd,
                  height: DeliverySize.avatarMd,
                  decoration: BoxDecoration(
                    color: c.brandSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    toStore ? DeliveryIcons.store : DeliveryIcons.home,
                    color: routeColor,
                  ),
                ),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: DeliverySpace.s2),
                      Text(
                        sub,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeliverySpace.lg,
              0,
              DeliverySpace.lg,
              DeliverySpace.lg,
            ),
            child: DeliveryButton.primary(
              label: toStore ? l.routeNavigateStore : l.routeNavigateCustomer,
              icon: DeliveryIcons.navigation,
              onPressed: target == null ? null : _navigate,
            ),
          ),
        ],
      ),
    );
  }
}
