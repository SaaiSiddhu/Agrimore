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

  const DeliveryEta({
    required this.minutes,
    required this.stage,
    this.fromStaleLocation = false,
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
  }) {
    if (status == null || drop == null) return null;
    final stale = rider?.isStale(now) ?? false;
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

  /// "Arriving in 12 min" / "Arriving in about 1 h 10 min".
  static String label(DeliveryEta eta) {
    if (eta.stage == EtaStage.arriving) return 'Your delivery partner has arrived';
    final m = eta.minutes;
    final text = m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}';
    return m < 60 ? 'Arriving in $text' : 'Arriving in about $text';
  }
}
