import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'delivery_task_model.dart';
import 'delivery_task_status.dart';

/// Phase DLV-3B — delivery_tasks/{orderId}/live/rider, the rider's live
/// position for one leg (written by the rider app, DLV-3A/3A2; readable by
/// the customer, the seller and admin — firestore.rules).
class RiderLivePoint {
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final bool isMocked;
  final DateTime? at;

  const RiderLivePoint({
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    this.isMocked = false,
    this.at,
  });

  static RiderLivePoint? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final at = m['at'];
    return RiderLivePoint(
      lat: lat,
      lng: lng,
      heading: (m['heading'] as num?)?.toDouble(),
      speed: (m['speed'] as num?)?.toDouble(),
      isMocked: m['isMocked'] == true,
      at: at is Timestamp
          ? at.toDate()
          : at is DateTime
              ? at
              : null,
    );
  }

  /// How long ago the rider's phone sent this, or null when unknown.
  Duration? age(DateTime now) => at == null ? null : now.difference(at!);

  /// The rider app sends at least every 30 s on an order
  /// (location_policy.dart); older than this and the map is out of date.
  static const Duration staleAfter = Duration(minutes: 2);

  bool isStale(DateTime now) {
    final a = age(now);
    return a == null || a > staleAfter;
  }
}

/// Phase DLV-3B — delivery_tasks/{orderId}.route, written by the
/// refreshDeliveryRoute function from Google's Routes API (two-wheeler,
/// traffic-aware; D-DLV-ROUTES). `via_pickup` has two legs (rider → store,
/// store → customer); `to_drop` one (rider → customer).
class DeliveryRoute {
  final String plan;
  final List<DeliveryRouteLeg> legs;
  final int? durationSeconds;
  final int? distanceMeters;
  final DateTime? computedAt;

  const DeliveryRoute({
    required this.plan,
    required this.legs,
    this.durationSeconds,
    this.distanceMeters,
    this.computedAt,
  });

  bool get viaPickup => plan == 'via_pickup';

  static DeliveryRoute? fromMap(dynamic m) {
    if (m is! Map) return null;
    final plan = m['plan'];
    final legs = m['legs'];
    if (plan is! String || legs is! List || legs.isEmpty) return null;
    final parsed = legs
        .whereType<Map>()
        .map((l) => DeliveryRouteLeg(
              polyline: l['polyline'] is String ? l['polyline'] as String : '',
              durationSeconds: (l['durationSeconds'] as num?)?.toInt(),
              distanceMeters: (l['distanceMeters'] as num?)?.toInt(),
            ))
        .toList();
    if (parsed.isEmpty) return null;
    final at = m['computedAt'];
    return DeliveryRoute(
      plan: plan,
      legs: parsed,
      durationSeconds: (m['durationSeconds'] as num?)?.toInt(),
      distanceMeters: (m['distanceMeters'] as num?)?.toInt(),
      computedAt: at is Timestamp ? at.toDate() : at is DateTime ? at : null,
    );
  }
}

class DeliveryRouteLeg {
  final String polyline;
  final int? durationSeconds;
  final int? distanceMeters;

  const DeliveryRouteLeg({required this.polyline, this.durationSeconds, this.distanceMeters});

  List<DeliveryPoint> get points => decodePolyline(polyline);
}

/// Google's encoded polyline format (the same decoder the server uses in
/// functions/src/delivery/deliveryRoute.ts). A truncated string decodes to
/// the points it does contain.
List<DeliveryPoint> decodePolyline(String encoded) {
  final out = <DeliveryPoint>[];
  var i = 0, lat = 0, lng = 0;
  int? next() {
    var shift = 0, result = 0, b = 0;
    do {
      if (i >= encoded.length) return null;
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (i < encoded.length) {
    final dLat = next();
    final dLng = next();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    out.add(DeliveryPoint(lat: lat / 1e5, lng: lng / 1e5));
  }
  return out;
}

/// Which part of the trip the ETA covers.
enum EtaStage {
  /// A rider is on the way to the seller (or at the seller).
  toPickup,

  /// The rider has the order and is on the way to the customer.
  toCustomer,

  /// The rider is at the customer's door.
  arriving,
}

class DeliveryEta {
  final int minutes;
  final EtaStage stage;

  /// The rider's last position is more than [RiderLivePoint.staleAfter] old:
  /// the estimate is from where they were.
  final bool fromStaleLocation;

  /// Counted down from the road route's traffic-aware duration (Google),
  /// rather than the straight-line estimate.
  final bool fromRoute;

  const DeliveryEta({
    required this.minutes,
    required this.stage,
    this.fromStaleLocation = false,
    this.fromRoute = false,
  });
}

/// OWNER_DECISION D-DLV-ETA: a free, stage-aware estimate — no routing API.
///
/// Road distance ≈ [roadFactor] × straight-line distance, ridden at
/// [averageSpeedKmh]; plus [pickupHandover] when the rider still has to
/// collect the order and [dropHandover] at the door. Before pickup:
/// rider → seller → customer; after pickup: rider → customer. No estimate
/// while no rider has the order, once it is finished, or when a needed
/// point is unknown — the screen then shows the status alone rather than an
/// invented number.
class DeliveryEtaCalculator {
  static const double roadFactor = 1.35;
  static const double averageSpeedKmh = 20;
  static const Duration pickupHandover = Duration(minutes: 5);
  static const Duration dropHandover = Duration(minutes: 2);
  static const int maxMinutes = 180;

  static double straightLineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }

  static double rideMinutes(double straightKm) =>
      straightKm * roadFactor / averageSpeedKmh * 60;

  static DeliveryEta? estimate({
    required DeliveryTaskStatus? status,
    required RiderLivePoint? rider,
    required DeliveryPoint? pickup,
    required DeliveryPoint? drop,
    required DateTime now,
    DeliveryRoute? route,
  }) {
    if (status == null || drop == null) return null;
    final stale = rider?.isStale(now) ?? false;
    final fromRoute = _fromRoute(status, route, now, stale);
    if (fromRoute != null) return fromRoute;
    DeliveryEta make(double minutes, EtaStage stage) => DeliveryEta(
          minutes: minutes.ceil().clamp(1, maxMinutes),
          stage: stage,
          fromStaleLocation: stale,
        );

    switch (status) {
      case DeliveryTaskStatus.assigned:
      case DeliveryTaskStatus.atPickup:
        if (rider == null || pickup == null) return null;
        final toStore = status == DeliveryTaskStatus.atPickup
            ? 0.0
            : rideMinutes(straightLineKm(rider.lat, rider.lng, pickup.lat, pickup.lng));
        final toCustomer = rideMinutes(straightLineKm(pickup.lat, pickup.lng, drop.lat, drop.lng));
        return make(
          toStore + pickupHandover.inMinutes + toCustomer + dropHandover.inMinutes,
          EtaStage.toPickup,
        );
      case DeliveryTaskStatus.pickedUp:
      case DeliveryTaskStatus.enRoute:
        if (rider == null) return null;
        return make(
          rideMinutes(straightLineKm(rider.lat, rider.lng, drop.lat, drop.lng)) +
              dropHandover.inMinutes,
          EtaStage.toCustomer,
        );
      case DeliveryTaskStatus.atDrop:
        return make(1, EtaStage.arriving);
      case DeliveryTaskStatus.searching:
      case DeliveryTaskStatus.delivered:
      case DeliveryTaskStatus.failedAttempt:
      case DeliveryTaskStatus.returningToSeller:
      case DeliveryTaskStatus.returned:
      case DeliveryTaskStatus.cancelled:
        return null;
    }
  }

  /// A route older than this is not trusted for the ETA (the server
  /// refreshes it every 5 min while the rider moves).
  static const Duration routeFreshFor = Duration(minutes: 7);

  /// Google's traffic-aware duration counted down since it was computed,
  /// plus the same handovers — when the route matches the stage and is
  /// fresh; null otherwise (the straight-line estimate is used).
  static DeliveryEta? _fromRoute(
      DeliveryTaskStatus status, DeliveryRoute? route, DateTime now, bool stale) {
    if (route == null || route.computedAt == null) return null;
    final age = now.difference(route.computedAt!);
    if (age.isNegative || age > routeFreshFor) return null;
    final int? total = route.durationSeconds ??
        (route.legs.every((l) => l.durationSeconds != null)
            ? route.legs.fold<int>(0, (a, l) => a + l.durationSeconds!)
            : null);
    if (total == null) return null;
    final EtaStage stage;
    Duration handover;
    switch (status) {
      case DeliveryTaskStatus.assigned:
        if (!route.viaPickup) return null;
        stage = EtaStage.toPickup;
        handover = pickupHandover + dropHandover;
        break;
      case DeliveryTaskStatus.atPickup:
        if (route.viaPickup) return null;
        stage = EtaStage.toPickup;
        handover = pickupHandover + dropHandover;
        break;
      case DeliveryTaskStatus.pickedUp:
      case DeliveryTaskStatus.enRoute:
        if (route.viaPickup) return null;
        stage = EtaStage.toCustomer;
        handover = dropHandover;
        break;
      default:
        return null;
    }
    final remaining = Duration(seconds: total) - age;
    final ride = remaining.isNegative ? const Duration(minutes: 1) : remaining;
    final minutes = ((ride + handover).inSeconds / 60).ceil().clamp(1, maxMinutes);
    return DeliveryEta(minutes: minutes, stage: stage, fromStaleLocation: stale, fromRoute: true);
  }

  /// "Arriving in 12 min" / "Arriving in about 1 h 10 min".
  static String label(DeliveryEta eta) {
    if (eta.stage == EtaStage.arriving) return 'Your delivery partner has arrived';
    final m = eta.minutes;
    final text = m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}';
    return m < 60 ? 'Arriving in $text' : 'Arriving in about $text';
  }
}
