// Phase DLV-3B — the customer's stage-aware ETA (D-DLV-ETA).
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 12);
  const km = 1 / 111.2; // degrees of latitude per km
  const store = DeliveryPoint(lat: 9.9252, lng: 78.1198);
  const home = DeliveryPoint(lat: 9.9252 - 3 * km, lng: 78.1198, pincode: '625002'); // 3 km south
  RiderLivePoint riderAt(double kmNorthOfStore, {Duration age = Duration.zero}) =>
      RiderLivePoint(lat: store.lat + kmNorthOfStore * km, lng: store.lng, at: now.subtract(age));

  DeliveryEta? eta(DeliveryTaskStatus? s, RiderLivePoint? r, {DeliveryPoint? pickup = store, DeliveryPoint? drop = home}) =>
      DeliveryEtaCalculator.estimate(status: s, rider: r, pickup: pickup, drop: drop, now: now);

  // 1 km of straight line = 1.35 km of road at 20 km/h = 4.05 min.
  double ride(double straightKm) => straightKm * 1.35 / 20 * 60;

  test('the road model', () {
    expect(DeliveryEtaCalculator.straightLineKm(store.lat, store.lng, home.lat, home.lng), closeTo(3, 0.01));
    expect(DeliveryEtaCalculator.rideMinutes(1), closeTo(4.05, 1e-9));
  });

  test('before pickup: rider → store, handover, store → customer, door', () {
    final e = eta(DeliveryTaskStatus.assigned, riderAt(2))!;
    // 2 km to the store + 5 + 3 km to the customer + 2 = 8.1 + 5 + 12.15 + 2 = 27.25 → 28.
    expect(e.minutes, (ride(2) + 5 + ride(3) + 2).ceil());
    expect(e.minutes, 28);
    expect(e.stage, EtaStage.toPickup);
  });

  test('at the store: no ride to the store any more', () {
    final e = eta(DeliveryTaskStatus.atPickup, riderAt(0))!;
    expect(e.minutes, (5 + ride(3) + 2).ceil());
    expect(e.stage, EtaStage.toPickup);
  });

  test('after pickup: straight to the customer; changes stage', () {
    final picked = eta(DeliveryTaskStatus.pickedUp, riderAt(0))!;
    expect(picked.minutes, (ride(3) + 2).ceil());
    expect(picked.stage, EtaStage.toCustomer);
    // Halfway there (1.5 km from the customer).
    final half = eta(DeliveryTaskStatus.enRoute, riderAt(-1.5))!;
    expect(half.minutes, (ride(1.5) + 2).ceil());
    expect(half.minutes, lessThan(picked.minutes));
  });

  test('picking up makes the ETA drop by the store leg and handover', () {
    final before = eta(DeliveryTaskStatus.atPickup, riderAt(0))!;
    final after = eta(DeliveryTaskStatus.pickedUp, riderAt(0))!;
    expect(before.minutes - after.minutes, 5);
  });

  test('at the door', () {
    final e = eta(DeliveryTaskStatus.atDrop, riderAt(-3))!;
    expect(e.stage, EtaStage.arriving);
    expect(DeliveryEtaCalculator.label(e), 'Your delivery partner has arrived');
  });

  test('no invented number without a rider, a point, or once finished', () {
    expect(eta(DeliveryTaskStatus.searching, riderAt(1)), isNull);
    expect(eta(DeliveryTaskStatus.assigned, null), isNull);
    expect(eta(DeliveryTaskStatus.enRoute, null), isNull);
    expect(eta(DeliveryTaskStatus.assigned, riderAt(1), pickup: null), isNull);
    expect(eta(DeliveryTaskStatus.enRoute, riderAt(1), drop: null), isNull);
    expect(eta(null, riderAt(1)), isNull);
    for (final s in [
      DeliveryTaskStatus.delivered,
      DeliveryTaskStatus.cancelled,
      DeliveryTaskStatus.returned,
      DeliveryTaskStatus.failedAttempt,
      DeliveryTaskStatus.returningToSeller,
    ]) {
      expect(eta(s, riderAt(1)), isNull, reason: s.name);
    }
  });

  test('an old position is used but flagged', () {
    final fresh = eta(DeliveryTaskStatus.enRoute, riderAt(-1, age: const Duration(seconds: 90)))!;
    final stale = eta(DeliveryTaskStatus.enRoute, riderAt(-1, age: const Duration(minutes: 3)))!;
    expect(fresh.fromStaleLocation, isFalse);
    expect(stale.fromStaleLocation, isTrue);
    expect(stale.minutes, fresh.minutes);
    expect(const RiderLivePoint(lat: 1, lng: 1).isStale(now), isTrue, reason: 'no timestamp');
  });

  test('bounded and labelled', () {
    final far = eta(DeliveryTaskStatus.enRoute, riderAt(900))!;
    expect(far.minutes, DeliveryEtaCalculator.maxMinutes);
    expect(DeliveryEtaCalculator.label(const DeliveryEta(minutes: 12, stage: EtaStage.toCustomer)), 'Arriving in 12 min');
    expect(DeliveryEtaCalculator.label(const DeliveryEta(minutes: 70, stage: EtaStage.toCustomer)), 'Arriving in about 1 h 10 min');
    expect(DeliveryEtaCalculator.label(const DeliveryEta(minutes: 120, stage: EtaStage.toCustomer)), 'Arriving in about 2 h');
    // Never zero.
    expect(eta(DeliveryTaskStatus.enRoute, RiderLivePoint(lat: home.lat, lng: home.lng, at: now))!.minutes, greaterThanOrEqualTo(1));
  });

  test('reads the live document the rider app writes', () {
    final p = RiderLivePoint.fromMap({
      'riderId': 'r', 'lat': 9.9, 'lng': 78.1, 'heading': 180, 'speed': 6.5,
      'accuracy': 5, 'isMocked': true, 'at': Timestamp.fromDate(now),
    })!;
    expect(p.lat, 9.9);
    expect(p.heading, 180);
    expect(p.isMocked, isTrue);
    expect(p.at, now);
    expect(RiderLivePoint.fromMap({'lat': 1}), isNull);
    expect(RiderLivePoint.fromMap(null), isNull);
    expect(RiderLivePoint.fromMap({'lat': 1, 'lng': 2, 'heading': null})!.heading, isNull);
  });

  group('road route (D-DLV-ROUTES)', () {
    test('decodes Google\'s reference polyline, like the server', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.length, 3);
      expect(pts[0].lat, closeTo(38.5, 1e-9));
      expect(pts[0].lng, closeTo(-120.2, 1e-9));
      expect(pts[2].lat, closeTo(43.252, 1e-9));
      expect(pts[2].lng, closeTo(-126.453, 1e-9));
      expect(decodePolyline('_p~iF~ps'), isA<List<DeliveryPoint>>());
      expect(decodePolyline(''), isEmpty);
    });

    DeliveryRoute route(String plan, int seconds, {Duration age = Duration.zero, int legs = 1}) => DeliveryRoute.fromMap({
          'plan': plan,
          'durationSeconds': seconds,
          'computedAt': Timestamp.fromDate(now.subtract(age)),
          'legs': List.generate(legs, (_) => {'polyline': '_p~iF~ps|U', 'durationSeconds': seconds ~/ legs}),
        })!;

    test('reads the route the function writes', () {
      final r = route('via_pickup', 1500, legs: 2);
      expect(r.viaPickup, isTrue);
      expect(r.legs.length, 2);
      expect(r.legs.first.points, isNotEmpty);
      expect(DeliveryRoute.fromMap({'plan': 'to_drop', 'legs': []}), isNull);
      expect(DeliveryRoute.fromMap(null), isNull);
      final task = DeliveryTaskModel.fromMap({'status': 'en_route', 'route': {'plan': 'to_drop', 'legs': [{'polyline': 'x'}]}}, 'o');
      expect(task.route?.plan, 'to_drop');
    });

    test('counts Google\'s traffic-aware time down, plus handovers', () {
      // 15 min ride computed 3 min ago → 12 min left + 2 min at the door.
      final e = DeliveryEtaCalculator.estimate(status: DeliveryTaskStatus.enRoute, rider: riderAt(-1),
          pickup: store, drop: home, now: now, route: route('to_drop', 900, age: const Duration(minutes: 3)))!;
      expect(e.fromRoute, isTrue);
      expect(e.minutes, 14);
      // Before pickup: via the store, + 5 min handover + 2 at the door.
      final b = DeliveryEtaCalculator.estimate(status: DeliveryTaskStatus.assigned, rider: riderAt(2),
          pickup: store, drop: home, now: now, route: route('via_pickup', 1200, legs: 2))!;
      expect(b.minutes, 20 + 5 + 2);
      expect(b.stage, EtaStage.toPickup);
    });

    test('a route that no longer fits falls back to the estimate', () {
      final est = eta(DeliveryTaskStatus.enRoute, riderAt(-1))!;
      for (final r in [
        route('via_pickup', 900, legs: 2), // stage changed: picked up since
        route('to_drop', 900, age: const Duration(minutes: 8)), // too old
      ]) {
        final e = DeliveryEtaCalculator.estimate(status: DeliveryTaskStatus.enRoute, rider: riderAt(-1),
            pickup: store, drop: home, now: now, route: r)!;
        expect(e.fromRoute, isFalse);
        expect(e.minutes, est.minutes);
      }
      final late = DeliveryEtaCalculator.estimate(status: DeliveryTaskStatus.enRoute, rider: riderAt(-1),
          pickup: store, drop: home, now: now, route: route('to_drop', 60, age: const Duration(minutes: 4)))!;
      expect(late.minutes, 3, reason: 'overdue ride floors at 1 min + 2 at the door');
      expect(DeliveryEtaCalculator.estimate(status: DeliveryTaskStatus.delivered, rider: riderAt(0),
          pickup: store, drop: home, now: now, route: route('to_drop', 900)), isNull);
    });
  });
}
