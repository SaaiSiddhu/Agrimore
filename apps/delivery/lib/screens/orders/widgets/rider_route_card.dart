// lib/screens/orders/widgets/rider_route_card.dart
//
// Phase DLV-3B — the rider's route: a map with the road route to the store
// (and on to the customer, greyed), then to the customer after pickup — the
// same delivery_tasks/{orderId}.route the customer's tracking screen draws —
// with the rider's own position trimming what has been ridden, a
// "9 min · 2.6 km" headline, and one tap into Google Maps turn-by-turn.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrimore_core/agrimore_core.dart';

import '../../../navigation/rider_navigation.dart';

const _navBlue = Color(0xFF1A73E8);

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
      FirebaseFirestore.instance.collection('delivery_tasks').doc(widget.orderId);

  @override
  void initState() {
    super.initState();
    _subs.add(_taskRef.snapshots().listen((s) {
      if (!mounted) return;
      setState(() => _task = s.exists ? DeliveryTaskModel.fromFirestore(s) : null);
      _frame();
    }, onError: (Object e) => debugPrint('Rider route: task stream: $e')));
    _subs.add(_taskRef.collection('live').doc('rider').snapshots().listen((s) {
      if (!mounted) return;
      final p = RiderLivePoint.fromMap(s.data());
      setState(() => _rider = p == null ? null : DeliveryPoint(lat: p.lat, lng: p.lng));
      _frame();
    }, onError: (Object e) => debugPrint('Rider route: live stream: $e')));
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
  ({List<List<DeliveryPoint>> legs, List<DeliveryPoint>? ahead, int? legSeconds}) get _geometry {
    final route = _task?.route;
    final legs = route?.legsAhead(_status) ?? const <List<DeliveryPoint>>[];
    if (legs.isEmpty) return (legs: legs, ahead: null, legSeconds: null);
    final activeIndex = route!.viaPickup && _leg == RiderLeg.toCustomer ? 1 : 0;
    final legSeconds = route.legs[activeIndex].durationSeconds;
    final rider = _rider;
    if (rider == null) return (legs: legs, ahead: legs.first, legSeconds: legSeconds);
    final progress = RouteProgress.along(legs.first, rider);
    if (progress == null) return (legs: legs, ahead: legs.first, legSeconds: legSeconds);
    return (
      legs: legs,
      ahead: progress.onRoute ? progress.remaining : [rider, ...progress.remaining],
      legSeconds: legSeconds,
    );
  }

  Future<void> _frame() async {
    final map = _map, size = _mapSize;
    if (map == null || size == null) return;
    // Once per leg and per new route — not on every position ping, so the
    // rider can pan the map without it snapping back.
    final key = '${_leg?.name}|${_task?.route?.computedAt?.millisecondsSinceEpoch}';
    if (_framedFor == key) return;
    final pts = <DeliveryPoint>[
      if (_rider != null) _rider!,
      if (_target != null) _target!,
      ...?_geometry.legs.firstOrNull,
    ];
    if (pts.length < 2) return;
    final lat = pts.map((p) => p.lat), lng = pts.map((p) => p.lng);
    final center = LatLng(
      (lat.reduce((a, b) => a < b ? a : b) + lat.reduce((a, b) => a > b ? a : b)) / 2,
      (lng.reduce((a, b) => a < b ? a : b) + lng.reduce((a, b) => a > b ? a : b)) / 2,
    );
    // Room for the pins (drawn above their point) and the edges.
    final zoom = fitZoomFor(pts, widthPx: size.width - 72, heightPx: size.height - 110);
    try {
      await map.moveCamera(CameraUpdate.newLatLngZoom(center, zoom));
      // On web the first move can land before the map has a size; only a
      // real visible region counts as framed (as on the customer screen).
      final region = await map.getVisibleRegion();
      final valid = region.northeast.latitude.isFinite &&
          region.northeast.latitude != region.southwest.latitude;
      if (!valid) throw StateError('map not laid out yet');
      _framedFor = key;
    } catch (e) {
      debugPrint('Rider route: camera: $e');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _frame();
      });
    }
  }

  Future<void> _navigate() async {
    final dest = _target;
    if (dest == null) return;
    // The intent opens Google Maps straight into two-wheeler navigation;
    // without the app (or on web) the Maps URL does the same in a browser.
    var opened = false;
    if (!kIsWeb) {
      try {
        opened = await launchUrl(turnByTurnUri(dest), mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened) {
      opened = await launchUrl(directionsUri(dest), mode: LaunchMode.externalApplication);
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps. Please install it and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final leg = _leg;
    if (leg == null) return const SizedBox.shrink();
    final geo = _geometry;
    final target = _target;
    final toStore = leg == RiderLeg.toStore;
    final atStore = _status == DeliveryTaskStatus.atPickup;

    final markers = <Marker>{
      if (_pickup != null && toStore)
        Marker(
          markerId: const MarkerId('store'),
          position: LatLng(_pickup!.lat, _pickup!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Store'),
        ),
      if (_drop != null)
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(_drop!.lat, _drop!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.customerName ?? 'Customer'),
        ),
      if (_rider != null && kIsWeb)
        // On the phone the map's own blue dot shows the rider.
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_rider!.lat, _rider!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'You'),
        ),
    };
    LatLng ll(DeliveryPoint p) => LatLng(p.lat, p.lng);
    final polylines = <Polyline>{};
    if (geo.ahead != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('active'),
        points: [for (final p in geo.ahead!) ll(p)],
        color: _navBlue,
        width: 6,
        zIndex: 2,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
      for (var i = 1; i < geo.legs.length; i++) {
        polylines.add(Polyline(
          polylineId: PolylineId('next_$i'),
          points: [for (final p in geo.legs[i]) ll(p)],
          color: const Color(0xFF9E9E9E),
          width: 5,
          zIndex: 1,
          jointType: JointType.round,
        ));
      }
    } else if (_rider != null && target != null) {
      // No road route yet: a straight guide; Navigate still gives the road.
      polylines.add(Polyline(
        polylineId: const PolylineId('guide'),
        points: [ll(_rider!), ll(target)],
        color: _navBlue.withValues(alpha: 0.6),
        width: 4,
        patterns: [PatternItem.dash(18), PatternItem.gap(10)],
      ));
    }

    final headline = atStore
        ? 'You are at the store'
        : toStore
            ? 'Head to the store'
            : 'Deliver to ${widget.customerName?.isNotEmpty == true ? widget.customerName : 'the customer'}';
    final remaining = geo.ahead == null
        ? null
        : legRemaining(leg: geo.legs.first, ahead: geo.ahead!, legSeconds: geo.legSeconds);
    final sub = atStore
        ? 'Collect the order, then tap Picked Up'
        : remaining != null
            ? legSummary(remaining)
            : target == null
                ? (toStore ? 'Store location not available' : 'Customer location not available')
                : 'Road route on its way — Navigate gives it now';

    final start = target ?? _rider ?? _drop ?? _pickup;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 240,
            child: start == null
                ? Center(child: Text('Waiting for the route…', style: TextStyle(color: cs.onSurfaceVariant)))
                : LayoutBuilder(builder: (context, box) {
                    _mapSize = Size(box.maxWidth, box.maxHeight);
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(target: ll(start), zoom: 14),
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: !kIsWeb,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      onMapCreated: (c) {
                        _map = c;
                        _framedFor = null;
                        Future.delayed(const Duration(milliseconds: 300), _frame);
                      },
                    );
                  }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _navBlue.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(toStore ? Icons.storefront_rounded : Icons.home_rounded, color: _navBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: target == null ? null : _navigate,
              style: FilledButton.styleFrom(
                backgroundColor: _navBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(toStore ? 'Navigate to store' : 'Navigate to customer',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
