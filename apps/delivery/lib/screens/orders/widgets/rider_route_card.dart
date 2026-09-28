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
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../navigation/navigation_launch.dart';
import '../../../navigation/rider_navigation.dart';
import '../../../providers/location_provider.dart';
import 'route_recovery.dart';

/// Map or the accessible text alternative -- mutually exclusive, matching a
/// segmented toggle rather than showing both at once.
enum RouteView { map, details }

/// See [DeliveryMotion.staleLocationThreshold] for the full doc comment --
/// kept as a top-level alias so every existing consumer here and in tests
/// keeps compiling unchanged.
const Duration kStaleLocationThreshold = DeliveryMotion.staleLocationThreshold;

/// See [DeliveryMotion.staleLocationCheckInterval] for the full doc comment.
const Duration kStaleLocationCheckInterval = DeliveryMotion.staleLocationCheckInterval;

/// Pure (no Firebase, no widget) so it is unit-testable directly: null [at]
/// (no live point recorded yet) is never stale -- there is nothing yet to
/// be out of date.
bool isPositionStale(DateTime? at, DateTime now, {Duration threshold = kStaleLocationThreshold}) =>
    at != null && now.difference(at) > threshold;

class RiderRouteCard extends StatefulWidget {
  const RiderRouteCard({
    super.key,
    required this.orderId,
    required this.stepIndex,
    this.dropFallback,
    this.customerName,
    this.customerPhone,
    this.storeName,
    this.taskStream,
    this.riderStream,
  });

  final String orderId;

  /// The active-order screen's DeliveryStep index.
  final int stepIndex;

  /// The order's own delivery coordinates, used until the task has `drop`.
  final DeliveryPoint? dropFallback;
  final String? customerName;

  /// DLVACC1: injectable in tests -- this widget previously read Firestore
  /// with no seam at all (see test/rider_route_stale_test.dart's own header
  /// comment), which meant its recovery states and accessible details
  /// content could never be driven by anything but a real backend. Defaults
  /// to the real `delivery_tasks/{orderId}` / `.../live/rider` streams.
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? taskStream;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? riderStream;

  /// DLVACC1: for the accessible details view's own "Call" action -- the
  /// task model deliberately carries no contact text at all.
  final String? customerPhone;

  /// DLVACC1: `sellers/{sellerId}.shopName`/`businessName`, fetched by the
  /// parent screen (never here -- a second independent fetch would risk a
  /// second, divergent data source). Null renders no store-name line at
  /// all, matching this repo's own established convention elsewhere,
  /// rather than a broken-looking empty one.
  final String? storeName;

  @override
  State<RiderRouteCard> createState() => _RiderRouteCardState();
}

class _RiderRouteCardState extends State<RiderRouteCard> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _taskSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _riderSub;
  DeliveryTaskModel? _task;
  DeliveryPoint? _rider;
  DateTime? _riderAt;
  Timer? _staleTicker;
  bool _refreshing = false;
  GoogleMapController? _map;
  Size? _mapSize;
  String? _framedFor;
  RouteView _view = RouteView.map;

  /// DLVACC1: explicit, so a listener failure is a distinct, retryable
  /// state rather than a silently-frozen last-good frame.
  StreamStatus _taskStatus = const StreamStatus.pending();
  StreamStatus _riderStatus = const StreamStatus.pending();

  DocumentReference<Map<String, dynamic>> get _taskRef =>
      FirebaseFirestore.instance
          .collection('delivery_tasks')
          .doc(widget.orderId);

  /// _target/_rider being null already drives the screen's own "waiting for
  /// position" state, so there is nothing stale to additionally report then.
  bool get _isStale => isPositionStale(_riderAt, DateTime.now());

  @override
  void initState() {
    super.initState();
    // Re-evaluate staleness even when nothing new arrives -- the whole
    // point of "stale" is that the position stream has gone quiet.
    _staleTicker = Timer.periodic(kStaleLocationCheckInterval, (_) {
      if (mounted) setState(() {});
    });
    _listenTask();
    _listenRider();
  }

  /// DLVACC1: a genuine retry cancels the old subscription and opens a
  /// fresh one -- Firestore does not always resubscribe itself after
  /// onError (permission-denied is terminal for that subscription
  /// instance), so re-observing the same Stream object would just watch a
  /// stream that will never emit again.
  void _listenTask() {
    _taskSub?.cancel();
    setState(() => _taskStatus = const StreamStatus.pending());
    try {
      _taskSub = (widget.taskStream ?? _taskRef.snapshots()).listen(
        (s) {
          if (!mounted) return;
          setState(() {
            _task = s.exists ? DeliveryTaskModel.fromFirestore(s) : null;
            _taskStatus = StreamStatus.ok(fromCache: s.metadata.isFromCache);
          });
          _frame();
        },
        onError: (Object e) {
          debugPrint('Rider route: task stream: $e');
          if (mounted) {
            setState(() => _taskStatus = StreamStatus.error(e is FirebaseException ? e.code : null));
          }
        },
      );
    } catch (e) {
      debugPrint('Rider route: task stream unavailable: $e');
      setState(() => _taskStatus = const StreamStatus.error(null));
    }
  }

  void _listenRider() {
    _riderSub?.cancel();
    setState(() => _riderStatus = const StreamStatus.pending());
    try {
      _riderSub = (widget.riderStream ?? _taskRef.collection('live').doc('rider').snapshots()).listen(
        (s) {
          if (!mounted) return;
          final p = RiderLivePoint.fromMap(s.data());
          setState(() {
            _rider = p == null ? null : DeliveryPoint(lat: p.lat, lng: p.lng);
            _riderAt = p?.at;
            _riderStatus = StreamStatus.ok(fromCache: s.metadata.isFromCache);
          });
          _frame();
        },
        onError: (Object e) {
          debugPrint('Rider route: live stream: $e');
          if (mounted) {
            setState(() => _riderStatus = StreamStatus.error(e is FirebaseException ? e.code : null));
          }
        },
      );
    } catch (e) {
      debugPrint('Rider route: live stream unavailable: $e');
      setState(() => _riderStatus = const StreamStatus.error(null));
    }
  }

  @override
  void didUpdateWidget(RiderRouteCard old) {
    super.didUpdateWidget(old);
    if (old.stepIndex != widget.stepIndex) _frame();
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _riderSub?.cancel();
    _staleTicker?.cancel();
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
    if (dest == null || !mounted) return;
    await launchExternalNavigationWithFallback(context, dest);
  }

  Future<void> _call() async {
    final phone = widget.customerPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _copyAddress(DeliveryPoint p) {
    Clipboard.setData(ClipboardData(text: '${p.lat},${p.lng}'));
    final l = AppLocalizations.of(context);
    showDeliveryToast(context, message: l.routeCoordsCopied);
  }

  Future<void> _refreshLocation() async {
    setState(() => _refreshing = true);
    final ok = await context.read<LocationProvider>().refreshNow();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (!ok) {
      showDeliveryToast(
        context,
        message: AppLocalizations.of(context).routeRefreshFailed,
        tone: DeliveryBannerTone.danger,
      );
    }
  }

  Future<void> _checkSettings() async {
    final issue = context.read<LocationProvider>().issue;
    await (issue == LocationIssue.servicesOff
        ? Geolocator.openLocationSettings()
        : Geolocator.openAppSettings());
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
    final staleMinutes = _riderAt == null ? 0 : DateTime.now().difference(_riderAt!).inMinutes;
    final usesNativeService = context.watch<LocationProvider>().usesNativeService;
    return DeliveryCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeliverySpace.lg,
              DeliverySpace.md,
              DeliverySpace.lg,
              0,
            ),
            child: DeliverySegmented<RouteView>(
              selected: _view,
              onSelected: (v) => setState(() => _view = v),
              items: [
                DeliveryChipItem(
                  key: const ValueKey('route-view-map'),
                  value: RouteView.map,
                  label: l.routeViewMap,
                  icon: DeliveryIcons.map,
                ),
                DeliveryChipItem(
                  key: const ValueKey('route-view-details'),
                  value: RouteView.details,
                  label: l.routeViewDetails,
                  icon: DeliveryIcons.list,
                ),
              ],
            ),
          ),
          const SizedBox(height: DeliverySpace.sm),
          if (_taskStatus.health == StreamHealth.error)
            _streamErrorBanner(l, t, c, status: _taskStatus, onRetry: _listenTask, isTask: true)
          else if (_riderStatus.health == StreamHealth.error)
            _streamErrorBanner(l, t, c, status: _riderStatus, onRetry: _listenRider, isTask: false),
          if (_view == RouteView.map) ...[
            if (_isStale)
              StaleLocationBanner(
                minutesAgo: staleMinutes,
                canRefresh: !usesNativeService,
                refreshing: _refreshing,
                onRefresh: _refreshLocation,
                onCheckSettings: _checkSettings,
              ),
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
                  ExcludeSemantics(
                    child: Container(
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
          ] else
            _buildDetails(
              l,
              c,
              t,
              toStore: toStore,
              atStore: atStore,
              headline: headline,
            ),
        ],
      ),
    );
  }

  Widget _streamErrorBanner(
    AppLocalizations l,
    DeliveryType t,
    DeliveryColors c, {
    required StreamStatus status,
    required VoidCallback onRetry,
    required bool isTask,
  }) {
    final body = status.isPermissionDenied
        ? l.routeErrorPermissionBody
        : (isTask ? l.routeErrorTaskBody : l.routeErrorPositionBody);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DeliverySpace.lg, 0, DeliverySpace.lg, DeliverySpace.sm),
      child: DeliveryBanner(
        key: ValueKey(isTask ? 'route-task-error' : 'route-position-error'),
        tone: DeliveryTone.danger,
        icon: DeliveryIcons.offline,
        title: isTask ? l.routeErrorTaskTitle : l.routeErrorPositionTitle,
        body: body,
        actionLabel: l.actionRetry,
        onAction: onRetry,
      ),
    );
  }

  /// DLVACC1 — the accessible, non-map alternative: the same `_task`/
  /// `_rider`/`_geometry` the map reads, never a second model, so the two
  /// views can never disagree about the destination.
  Widget _buildDetails(
    AppLocalizations l,
    DeliveryColors c,
    DeliveryType t, {
    required bool toStore,
    required bool atStore,
    required String headline,
  }) {
    // Only genuinely still-pending gets "Loading…" wording -- a confirmed
    // error (the banner above already explains it) means "unavailable",
    // never "in progress and about to resolve on its own".
    final taskPending = _taskStatus.health == StreamHealth.pending;
    final geo = _geometry;
    final remaining = geo.ahead == null
        ? null
        : legRemaining(leg: geo.legs.first, ahead: geo.ahead!, legSeconds: geo.legSeconds);

    Widget section({
      required Key key,
      required IconData icon,
      required String label,
      required Widget child,
    }) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(DeliverySpace.lg, 0, DeliverySpace.lg, DeliverySpace.lg),
          child: Semantics(
            container: true,
            child: Column(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(child: Icon(icon, size: DeliveryIconSize.sm, color: c.textSecondary)),
                    const SizedBox(width: DeliverySpace.xs),
                    Text(label, style: t.labelMedium.copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: DeliverySpace.xs),
                child,
              ],
            ),
          ),
        );

    Widget actionRow(List<Widget> buttons) => Padding(
          padding: const EdgeInsets.only(top: DeliverySpace.sm),
          child: Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: DeliverySpace.sm),
                Expanded(child: buttons[i]),
              ],
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          key: const ValueKey('route-details-stage'),
          icon: DeliveryIcons.activeOrder,
          label: l.routeDetailsStageLabel,
          child: Text(
            headline,
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
        ),
        section(
          key: const ValueKey('route-details-pickup'),
          icon: DeliveryIcons.pickup,
          label: l.routeDetailsPickupLabel,
          child: _pickup == null
              ? Text(
                  taskPending ? l.routeDetailsLoadingPickup : l.routeDetailsPickupUnavailable,
                  style: t.bodyMedium.copyWith(color: c.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.storeName ?? l.routeStore,
                      style: t.bodyMedium.copyWith(color: c.textPrimary),
                    ),
                    if (_pickup!.pincode != null)
                      Text(
                        _pickup!.pincode!,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    actionRow([
                      DeliveryButton.secondary(
                        key: const ValueKey('route-details-pickup-navigate'),
                        label: l.routeNavigateStore,
                        icon: DeliveryIcons.navigation,
                        onPressed: () => launchExternalNavigationWithFallback(context, _pickup!),
                      ),
                      DeliveryButton.ghost(
                        key: const ValueKey('route-details-pickup-copy'),
                        label: l.routeCopyCoords,
                        icon: DeliveryIcons.copy,
                        onPressed: () => _copyAddress(_pickup!),
                      ),
                    ]),
                  ],
                ),
        ),
        section(
          key: const ValueKey('route-details-drop'),
          icon: DeliveryIcons.dropoff,
          label: l.routeDetailsDropLabel,
          child: _drop == null
              ? Text(
                  taskPending ? l.routeDetailsLoadingDrop : l.routeDetailsDropUnavailable,
                  style: t.bodyMedium.copyWith(color: c.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName ?? l.routeCustomer,
                      style: t.bodyMedium.copyWith(color: c.textPrimary),
                    ),
                    if (_drop!.pincode != null)
                      Text(
                        _drop!.pincode!,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    actionRow([
                      DeliveryButton.secondary(
                        key: const ValueKey('route-details-drop-navigate'),
                        label: l.routeNavigateCustomer,
                        icon: DeliveryIcons.navigation,
                        onPressed: () => launchExternalNavigationWithFallback(context, _drop!),
                      ),
                      if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty)
                        DeliveryButton.secondary(
                          key: const ValueKey('route-details-drop-call'),
                          label: l.activeCall,
                          icon: DeliveryIcons.call,
                          onPressed: _call,
                        ),
                      DeliveryButton.ghost(
                        key: const ValueKey('route-details-drop-copy'),
                        label: l.routeCopyCoords,
                        icon: DeliveryIcons.copy,
                        onPressed: () => _copyAddress(_drop!),
                      ),
                    ]),
                  ],
                ),
        ),
        section(
          key: const ValueKey('route-details-distance'),
          icon: DeliveryIcons.route,
          label: l.routeDetailsDistanceLabel,
          child: Text(
            remaining != null
                ? legSummary(l, remaining)
                : (taskPending ? l.routeDetailsLoadingRoute : l.routeDetailsRouteUnavailable),
            style: t.bodyMedium.copyWith(color: c.textPrimary),
          ),
        ),
        if (_taskStatus.fromCache || _riderStatus.fromCache)
          Padding(
            padding: const EdgeInsets.fromLTRB(DeliverySpace.lg, 0, DeliverySpace.lg, DeliverySpace.lg),
            child: Text(
              l.routeCachedBanner,
              style: t.bodySmall.copyWith(color: c.textTertiary),
            ),
          ),
      ],
    );
  }
}

/// Phase DLVMAP1 (21.6 Stale rider location). [canRefresh] is false on
/// native Android, where RiderLocationService alone decides when to send --
/// LocationProvider.refreshNow() is a no-op there, so only "Check settings"
/// is offered instead of a button that would silently do nothing.
/// Public (not private): directly widget-tested without needing
/// RiderRouteCard's own Firestore-backed state (test/rider_route_stale_test.dart).
class StaleLocationBanner extends StatelessWidget {
  const StaleLocationBanner({
    super.key,
    required this.minutesAgo,
    required this.canRefresh,
    required this.refreshing,
    required this.onRefresh,
    required this.onCheckSettings,
  });
  final int minutesAgo;
  final bool canRefresh;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onCheckSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final pair = c.tone(DeliveryTone.warning);
    return Container(
      color: pair.container,
      padding: const EdgeInsets.all(DeliverySpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(DeliveryIcons.pending, color: pair.text, size: DeliveryIconSize.md),
              const SizedBox(width: DeliverySpace.sm),
              Expanded(
                child: Text(
                  l.routeStaleTitle,
                  style: t.titleSmall.copyWith(color: pair.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: DeliverySpace.s2),
          Text(
            // This banner only renders when _isStale, which itself requires
            // more than kStaleLocationThreshold (2 min) to have passed.
            l.routeUpdatedMinAgo(minutesAgo),
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          Text(
            canRefresh ? l.routeStaleBodyRefreshable : l.routeStaleBodyNative,
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DeliverySpace.sm),
          Row(
            children: [
              if (canRefresh) ...[
                Expanded(
                  child: DeliveryButton.secondary(
                    key: const ValueKey('route-refresh-location'),
                    label: l.routeRefreshLocation,
                    icon: DeliveryIcons.refresh,
                    isLoading: refreshing,
                    onPressed: refreshing ? null : onRefresh,
                  ),
                ),
                const SizedBox(width: DeliverySpace.sm),
              ],
              Expanded(
                child: DeliveryButton.secondary(
                  key: const ValueKey('route-check-settings'),
                  label: l.routeCheckSettings,
                  icon: DeliveryIcons.settings,
                  onPressed: onCheckSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
