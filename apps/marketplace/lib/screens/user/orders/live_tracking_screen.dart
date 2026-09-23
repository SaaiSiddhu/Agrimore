// lib/screens/user/orders/live_tracking_screen.dart
//
// Phase DLV-3B — the customer's live tracking screen, Zomato/Swiggy style.
//
// While the order is on its way: a full-bleed map (rider, store and home
// pins; the ROAD route from Google — D-DLV-ROUTES — drawn from
// delivery_tasks/{id}.route, the leg the rider is on in green and the rest
// grey), a floating ETA card counted down from the traffic-aware duration, and
// a sheet with the stage stepper, the delivery code, the rider, payment, the
// order and help. Once delivered or cancelled the map goes away and the
// screen becomes a receipt (DeliveredView).
//
// Data: orders/{id} (rider card, items, payment), delivery_tasks/{id}
// (stage, pickup/drop, route — server-written), its live/rider point
// (DLV-3A/3A2), and orders/{id}/secrets/delivery (the code, DLV-0).
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../app/routes.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/delivery_tracking_service.dart';
import 'rate_order_screen.dart';
import 'widgets/delivered_view.dart';
import 'widgets/tracking_marker_icons.dart';
import 'widgets/tracking_sections.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;

  const LiveTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> with TickerProviderStateMixin {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  GoogleMapController? _mapController;

  OrderModel? _order;
  DeliveryTaskModel? _task;
  RiderLivePoint? _live;
  DeliveryEta? _eta;
  String? _deliveryCode;

  LatLng? _riderShown;
  LatLng? _moveFrom;
  LatLng? _moveTo;
  late final AnimationController _moveController;
  late final AnimationController _pulseController;
  TrackingMarkerIcons? _icons;

  final List<StreamSubscription> _subs = [];
  Timer? _clock;
  EtaStage? _fittedForStage;
  String? _fittedRouteKey;
  bool _fittedOnce = false;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  static const LatLng _defaultLocation = LatLng(20.5937, 78.9629);
  static const double _sheetInitial = 0.42;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this)
      ..repeat(reverse: true);
    _moveController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)
      ..addListener(_onMoveTick);
    _loadMarkerIcons();
    _listen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After the first frame: loadOrderById notifies listeners, which threw
      // 'setState() or markNeedsBuild() called during build' from initState.
      if (mounted) context.read<OrderProvider>().loadOrderById(widget.orderId);
    });
    // Counts the ETA down and ages the 'location updated' note.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(_recompute);
    });
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final icons = await TrackingMarkerIcons.build();
      if (!mounted) return;
      setState(() {
        _icons = icons;
        _recompute();
      });
    } catch (e) {
      debugPrint('Marker icons: $e');
    }
  }

  void _listen() {
    _subs.add(_trackingService.streamOrderStatus(widget.orderId).listen((order) {
      if (order == null || !mounted) return;
      setState(() {
        _order = order;
        _recompute();
      });
    }, onError: (Object e) => debugPrint('Order stream: $e')));
    _subs.add(_trackingService.streamTask(widget.orderId).listen((task) {
      if (!mounted) return;
      setState(() {
        _task = task;
        _recompute();
      });
    }, onError: (Object e) => debugPrint('Delivery task stream: $e')));
    _subs.add(_trackingService.streamLivePoint(widget.orderId).listen((live) {
      if (!mounted) return;
      _live = live;
      if (live != null) {
        final next = LatLng(live.lat, live.lng);
        if (_riderShown == null) {
          _riderShown = next;
        } else {
          _moveFrom = _riderShown;
          _moveTo = next;
          _moveController.forward(from: 0);
        }
      }
      setState(_recompute);
    }, onError: (Object e) => debugPrint('Rider live point stream: $e')));
    _subs.add(FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('secrets')
        .doc('delivery')
        .snapshots()
        .listen((d) {
      final code = d.data()?['code'];
      if (!mounted) return;
      setState(() => _deliveryCode = code is String && code.isNotEmpty ? code : null);
    }, onError: (Object e) => debugPrint('Delivery code stream: $e')));
  }

  void _onMoveTick() {
    final from = _moveFrom, to = _moveTo;
    if (from == null || to == null || !mounted) return;
    final t = Curves.easeInOut.transform(_moveController.value);
    setState(() {
      _riderShown = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      _buildMapLayers();
    });
  }

  // ---------------------------------------------------------------- state

  DeliveryTaskStatus? get _status => _task?.status;

  bool get _finished {
    final s = (_order?.orderStatus ?? '').toLowerCase();
    return _status == DeliveryTaskStatus.delivered ||
        _status == DeliveryTaskStatus.returned ||
        _status == DeliveryTaskStatus.cancelled ||
        s == 'delivered' ||
        s == 'cancelled' ||
        s == 'refunded' ||
        s == 'returned';
  }

  bool get _cancelled {
    final s = (_order?.orderStatus ?? '').toLowerCase();
    return _status == DeliveryTaskStatus.cancelled || s == 'cancelled' || s == 'refunded';
  }

  bool get _riderLegActive => const {
        DeliveryTaskStatus.assigned,
        DeliveryTaskStatus.atPickup,
        DeliveryTaskStatus.pickedUp,
        DeliveryTaskStatus.enRoute,
        DeliveryTaskStatus.atDrop,
      }.contains(_status);

  bool get _beforePickup => _status == DeliveryTaskStatus.assigned || _status == DeliveryTaskStatus.atPickup;

  LatLng? get _dropLatLng {
    final d = _task?.drop;
    if (d != null) return LatLng(d.lat, d.lng);
    final a = _order?.deliveryAddress;
    if (a?.latitude != null && a?.longitude != null) return LatLng(a!.latitude!, a.longitude!);
    return null;
  }

  LatLng? get _pickupLatLng {
    final p = _task?.pickup;
    return p == null ? null : LatLng(p.lat, p.lng);
  }

  /// The road legs still ahead (DeliveryRoute.legsAhead — the same choice
  /// the rider's route card makes): rider → store → you before pickup,
  /// store/rider → you after.
  List<List<LatLng>> get _routeLegs {
    final route = _task?.route;
    if (route == null || !_riderLegActive) return const [];
    return [
      for (final leg in route.legsAhead(_status)) [for (final p in leg) LatLng(p.lat, p.lng)]
    ];
  }

  void _recompute() {
    final drop = _dropLatLng;
    _eta = DeliveryEtaCalculator.estimate(
      status: _status,
      rider: _live,
      pickup: _task?.pickup,
      drop: drop == null ? null : DeliveryPoint(lat: drop.latitude, lng: drop.longitude),
      now: DateTime.now(),
      route: _task?.route,
    );
    _buildMapLayers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitCameraIfNeeded();
    });
  }

  // ------------------------------------------------------------------ map

  void _buildMapLayers() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final drop = _dropLatLng;
    final pickup = _pickupLatLng;
    Offset anchor(bool drawn) => drawn ? const Offset(0.5, 0.5) : const Offset(0.5, 1);

    if (drop != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: drop,
        icon: _icons?.home ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: anchor(_icons != null),
        infoWindow: const InfoWindow(title: 'Your address'),
      ));
    }
    if (pickup != null && (_beforePickup || _status == DeliveryTaskStatus.searching || _task?.status == null)) {
      markers.add(Marker(
        markerId: const MarkerId('store'),
        position: pickup,
        icon: _icons?.store ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: anchor(_icons != null),
        infoWindow: const InfoWindow(title: 'Store'),
      ));
    }
    final legs = _routeLegs;
    var rider = _riderShown;
    List<LatLng>? activeLeg;
    if (legs.isNotEmpty) {
      activeLeg = legs.first;
      if (rider != null) {
        // Zomato/Swiggy style: the line starts at the bike and what has been
        // ridden disappears; small GPS drift is drawn on the road.
        final progress = RouteProgress.along(
          [for (final p in legs.first) DeliveryPoint(lat: p.latitude, lng: p.longitude)],
          DeliveryPoint(lat: rider.latitude, lng: rider.longitude),
        );
        if (progress != null) {
          final ahead = [for (final p in progress.remaining) LatLng(p.lat, p.lng)];
          if (progress.onRoute) {
            rider = ahead.first;
            activeLeg = ahead;
          } else {
            // Off the line until the server re-routes (> 150 m): join them.
            activeLeg = [rider, ...ahead];
          }
        }
      }
    }
    if (rider != null && _riderLegActive) {
      markers.add(Marker(
        markerId: const MarkerId('partner'),
        position: rider,
        zIndexInt: 2,
        anchor: anchor(_icons != null),
        icon: _icons?.rider ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _order?.deliveryPartner?.name ?? 'Delivery partner'),
      ));
    }

    if (legs.isNotEmpty && activeLeg != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_active'),
        points: activeLeg,
        color: kTrackGreen,
        width: 6,
        zIndex: 2,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
      for (var i = 1; i < legs.length; i++) {
        polylines.add(Polyline(
          polylineId: PolylineId('route_next_$i'),
          points: legs[i],
          color: const Color(0xFF9E9E9E),
          width: 5,
          zIndex: 1,
          jointType: JointType.round,
        ));
      }
    } else if (rider != null && _riderLegActive) {
      // No road route yet: a straight guide to the next stop.
      final next = _beforePickup && pickup != null ? pickup : drop;
      if (next != null) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route_guide'),
          points: [rider, next],
          color: kTrackGreen.withValues(alpha: 0.7),
          width: 4,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ));
      }
    } else if (!_riderLegActive && pickup != null && drop != null && !_finished) {
      // Still finding a rider: store → you, the way it will come.
      polylines.add(Polyline(
        polylineId: const PolylineId('store_to_home'),
        points: [pickup, drop],
        color: const Color(0xFF9E9E9E),
        width: 4,
        patterns: [PatternItem.dash(14), PatternItem.gap(10)],
      ));
    }
    _markers = markers;
    _polylines = polylines;
  }

  /// Frames the rider and the leg they are on, once, again at pickup and
  /// when a new route arrives — inside the band between the ETA card and the
  /// sheet, so nothing sits under either.
  Future<void> _fitCameraIfNeeded() async {
    final controller = _mapController;
    if (controller == null || _finished) return;
    final pts = <LatLng>[
      if (_riderShown != null && _riderLegActive) _riderShown!,
      // The whole way still ahead — rider, store and home before pickup —
      // so the customer sees the store → home road too.
      for (final leg in _routeLegs) ...leg,
      if (_beforePickup && _pickupLatLng != null) _pickupLatLng!,
      if (_riderLegActive && _dropLatLng != null) _dropLatLng!,
      if (!_riderLegActive && _pickupLatLng != null) _pickupLatLng!,
      if (!_riderLegActive && _dropLatLng != null) _dropLatLng!,
    ];
    if (pts.length < 2) return;
    final stage = _eta?.stage;
    final routeKey = '${_task?.route?.plan}:${_task?.route?.computedAt?.millisecondsSinceEpoch}';
    if (_fittedOnce && stage == _fittedForStage && routeKey == _fittedRouteKey) return;
    _fittedOnce = true;
    _fittedForStage = stage;
    _fittedRouteKey = routeKey;
    final bounds = LatLngBounds(
      southwest: LatLng(pts.map((p) => p.latitude).reduce(min), pts.map((p) => p.longitude).reduce(min)),
      northeast: LatLng(pts.map((p) => p.latitude).reduce(max), pts.map((p) => p.longitude).reduce(max)),
    );
    try {
      final media = MediaQuery.of(context);
      final size = media.size;
      final bandTop = media.padding.top + 200;
      final bandBottom = size.height * (1 - _sheetInitial);
      const pad = 48.0;
      // The zoom is computed here from the screen, not by newLatLngBounds:
      // on web that ran before the map had a size and left the camera at a
      // broken zoom (browser run: only zoom-0 tiles, a blank grey map).
      final zoom = fitZoom(
        bounds,
        widthPx: size.width - 2 * pad,
        heightPx: bandBottom - bandTop - 2 * pad,
      );
      final center = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );
      await controller.moveCamera(CameraUpdate.newLatLngZoom(center, zoom));
      // Put that centre in the middle of the band between the ETA card and
      // the sheet.
      await controller.moveCamera(CameraUpdate.scrollBy(0, size.height / 2 - (bandTop + bandBottom) / 2));
      final region = await controller.getVisibleRegion();
      final valid = region.northeast.latitude.isFinite &&
          region.southwest.latitude.isFinite &&
          region.northeast.latitude != region.southwest.latitude;
      if (!valid) throw StateError('map not laid out yet');
    } catch (e) {
      // Map not laid out yet (web): try again shortly.
      debugPrint('Tracking camera fit failed: $e');
      _fittedOnce = false;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _fitCameraIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _clock?.cancel();
    _moveController.dispose();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  Future<void> _callPartner() async {
    final phone = _order?.deliveryPartner?.phone;
    if (phone == null || phone.isEmpty) return _noContact();
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _messagePartner() async {
    final phone = _order?.deliveryPartner?.phone;
    if (phone == null || phone.isEmpty) return _noContact();
    final body = Uri.encodeComponent('Hi, regarding my Agrimore order #${_order?.orderNumber ?? ''}');
    try {
      await launchUrl(Uri.parse('sms:$phone?body=$body'));
    } catch (_) {
      await launchUrl(Uri.parse('sms:$phone'));
    }
  }

  void _noContact() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your delivery partner's number isn't available yet")),
    );
  }

  void _openHelp() => Navigator.of(context).pushNamed(AppRoutes.support);

  void _openRating() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RateOrderScreen(orderId: widget.orderId)),
      );

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final palette = TrackingPalette(isDark);
    final order = _order;

    if (order != null && _finished) {
      return DeliveredView(
        palette: palette,
        order: order,
        cancelled: _cancelled,
        deliveredAt: _task?.stepAt['delivered'],
        onRate: _openRating,
        onHelp: _openHelp,
        onDone: () => Navigator.of(context).maybePop(),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.sheet,
        body: Stack(
          children: [
            _buildMap(isDark),
            _buildTopBar(palette),
            _buildEtaCard(palette),
            _buildSheet(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final start = _dropLatLng ?? _pickupLatLng ?? _defaultLocation;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: start, zoom: _dropLatLng == null ? 5 : 14),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      style: isDark ? _darkMapStyle : null,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCameraIfNeeded();
      },
    );
  }

  Widget _circleButton(TrackingPalette p, IconData icon, String tooltip, VoidCallback onTap) => Material(
        color: p.card,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: p.text, size: 22),
        ),
      );

  Widget _buildTopBar(TrackingPalette p) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        child: Row(
          children: [
            _circleButton(p, Icons.arrow_back_rounded, 'Back', () => Navigator.of(context).maybePop()),
            const Spacer(),
            if (_order != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Text('Order #${_order!.orderNumber}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text)),
              ),
            const Spacer(),
            _circleButton(p, Icons.support_agent_rounded, 'Help', _openHelp),
          ],
        ),
      );

  Widget _buildEtaCard(TrackingPalette p) {
    final eta = _eta;
    final stage = DeliveryTrackingService.stageMessage(_status, _order?.orderStatus ?? 'pending');
    final arriveBy = eta == null || eta.stage == EtaStage.arriving
        ? null
        : TimeOfDay.fromDateTime(DateTime.now().add(Duration(minutes: eta.minutes))).format(context);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: kTrackGreen, borderRadius: BorderRadius.circular(14)),
              child: eta != null && eta.stage != EtaStage.arriving
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${eta.minutes}',
                            style: const TextStyle(
                                fontSize: 24, height: 1, fontWeight: FontWeight.w900, color: Colors.white)),
                        const Text('min', style: TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    )
                  : FadeTransition(
                      opacity: Tween(begin: 0.55, end: 1.0).animate(_pulseController),
                      child: Icon(
                        eta?.stage == EtaStage.arriving
                            ? Icons.door_front_door_rounded
                            : _riderLegActive
                                ? Icons.delivery_dining_rounded
                                : Icons.inventory_2_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eta == null
                        ? stage
                        : eta.stage == EtaStage.arriving
                            ? 'Your delivery partner is at your door'
                            : 'Arriving by $arriveBy',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.text),
                  ),
                  if (eta != null && eta.stage != EtaStage.arriving) ...[
                    const SizedBox(height: 3),
                    Text(stage, style: TextStyle(fontSize: 13, color: p.subtext)),
                  ],
                  const SizedBox(height: 4),
                  if (eta?.fromStaleLocation == true)
                    Text(locationAgeMessage(_live?.age(DateTime.now())),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE65100)))
                  else if (eta?.fromRoute == true)
                    Row(
                      children: [
                        const Icon(Icons.traffic_rounded, size: 14, color: kTrackGreen),
                        const SizedBox(width: 4),
                        Text('Live traffic',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.subtext)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(TrackingPalette p) {
    final order = _order;
    final partner = order?.deliveryPartner;
    final showCode = _deliveryCode != null && _riderLegActive;
    return DraggableScrollableSheet(
      initialChildSize: _sheetInitial,
      minChildSize: 0.22,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [_sheetInitial],
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))],
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: p.muted, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            TrackingStepper(
              palette: p,
              taskStatus: _status,
              orderStatus: order?.orderStatus ?? 'pending',
              stepAt: _task?.stepAt ?? const {},
              placedAt: order?.createdAt,
            ),
            if (showCode) DeliveryCodeCard(palette: p, code: _deliveryCode!),
            if (partner != null && _riderLegActive)
              RiderCard(palette: p, partner: partner, onCall: _callPartner, onMessage: _messagePartner)
            else
              RiderPendingCard(
                palette: p,
                message: _status == DeliveryTaskStatus.searching
                    ? 'Finding a delivery partner near the store'
                    : 'The store is preparing your order',
              ),
            if (order != null) OrderSummaryCard(palette: p, order: order),
            HelpCard(palette: p, onTap: _openHelp),
          ],
        ),
      ),
    );
  }

  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
  ]
  ''';
}

/// The Web-Mercator zoom at which [bounds] fits [widthPx] × [heightPx]
/// logical pixels (256-px tiles), clamped to 3–17.
double fitZoom(LatLngBounds bounds, {required double widthPx, required double heightPx}) {
  double mercY(double lat) {
    final s = sin(lat.clamp(-85.0, 85.0) * pi / 180);
    return log((1 + s) / (1 - s)) / 2;
  }

  final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude).abs();
  final ySpan = (mercY(bounds.northeast.latitude) - mercY(bounds.southwest.latitude)).abs();
  final w = max(widthPx, 1.0), h = max(heightPx, 1.0);
  final zx = lngSpan <= 1e-9 ? 17.0 : log(w * 360 / (lngSpan * 256)) / ln2;
  final zy = ySpan <= 1e-9 ? 17.0 : log(h * 2 * pi / (ySpan * 256)) / ln2;
  return min(zx, zy).clamp(3.0, 17.0);
}
