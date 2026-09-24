// Phase DLV-2C — the admin dispatch queue's logic: queue order, offer
// timeline, rider eligibility for manual assignment, which orders can take
// a rider, and the order fields an assignment writes.
import 'dart:io';

import 'package:agrimore_admin/screens/admin/delivery/dispatch_queue.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 12);
  Timestamp ago(Duration d) => Timestamp.fromDate(now.subtract(d));

  group('parity with functions/src/delivery/dispatch.ts', () {
    final src = File('../../functions/src/delivery/dispatch.ts').readAsStringSync();

    test('busy statuses match RIDER_ACTIVE_ORDER_STATUSES', () {
      final block = RegExp(r'RIDER_ACTIVE_ORDER_STATUSES = \[([^\]]*)\]')
          .firstMatch(src)!
          .group(1)!;
      final server =
          RegExp(r'"([^"]+)"').allMatches(block).map((m) => m.group(1)).toList();
      expect(riderActiveOrderStatuses, server);
    });

    test('location freshness matches LOCATION_FRESHNESS_MS', () {
      final m = RegExp(r'LOCATION_FRESHNESS_MS = (\d+) \* (\d+) \* (\d+);')
          .firstMatch(src)!;
      final ms = [1, 2, 3].map((i) => int.parse(m.group(i)!)).reduce((a, b) => a * b);
      expect(locationFreshness.inMilliseconds, ms);
    });

    test('cash on delivery is read as isCod reads it', () {
      for (final v in ['cod', 'COD', 'cash_on_delivery', 'Cash']) {
        expect(isCashOnDelivery(v), isTrue, reason: v);
      }
      for (final v in ['razorpay', 'upi', 'wallet', null, 3]) {
        expect(isCashOnDelivery(v), isFalse, reason: '$v');
      }
    });
  });

  group('queue', () {
    DispatchEntry e(String id, {bool needs = false, Duration? started, Duration? flagged, int wave = 1}) =>
        DispatchEntry.fromMap(id, {
          'status': 'dispatching',
          'wave': wave,
          'needsAdmin': needs,
          if (started != null) 'startedAt': ago(started),
          if (flagged != null) 'needsAdminSince': ago(flagged),
        });

    test('needs-a-rider first, longest flagged first; then longest searching', () {
      final sorted = sortDispatchQueue([
        e('new', started: const Duration(minutes: 1)),
        e('flaggedRecently', needs: true, started: const Duration(minutes: 30), flagged: const Duration(minutes: 2)),
        e('old', started: const Duration(minutes: 5)),
        e('flaggedLongAgo', needs: true, started: const Duration(minutes: 10), flagged: const Duration(minutes: 8)),
      ]);
      expect(sorted.map((x) => x.orderId),
          ['flaggedLongAgo', 'flaggedRecently', 'old', 'new']);
    });

    test('reads the dispatch document', () {
      final d = DispatchEntry.fromMap('o1', {
        'orderId': 'o1',
        'status': 'dispatching',
        'wave': 5,
        'radiusKm': 12,
        'needsAdmin': true,
        'offeredTo': ['a', 'b', 7],
        'declinedBy': ['a'],
        'startedAt': ago(const Duration(minutes: 9)),
      });
      expect(d.isOpen, isTrue);
      expect(d.isRetrying, isTrue);
      expect(d.radiusKm, 12);
      expect(d.offeredTo, ['a', 'b']);
      expect(d.searchingFor(now), const Duration(minutes: 9));
      expect(DispatchEntry.fromMap('x', {'wave': 3}).isRetrying, isFalse);
    });
  });

  group('offer timeline', () {
    test('a lapsed offer the scheduler has not swept yet reads No answer', () {
      final live = OfferEvent.fromMap({
        'riderId': 'r1',
        'status': 'offered',
        'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 10))),
      });
      final lapsed = OfferEvent.fromMap({
        'riderId': 'r1',
        'status': 'offered',
        'expiresAt': ago(const Duration(seconds: 5)),
      });
      expect(live.label(now), 'Ringing');
      expect(lapsed.label(now), 'No answer');
      expect(OfferEvent.fromMap({'status': 'expired'}).label(now), 'No answer');
      expect(OfferEvent.fromMap({'status': 'declined'}).label(now), 'Declined');
      expect(OfferEvent.fromMap({'status': 'withdrawn'}).label(now), 'Withdrawn');
    });

    test('pre-DLV-2A documents: partnerId and "pending"', () {
      final o = OfferEvent.fromMap({'partnerId': 'p9', 'status': 'pending'});
      expect(o.riderId, 'p9');
      expect(o.status, DeliveryOfferStatus.offered);
    });

    test('ordered by wave, then time', () {
      final sorted = sortOfferTimeline([
        OfferEvent.fromMap({'riderId': 'c', 'wave': 2, 'createdAt': ago(const Duration(minutes: 1))}),
        OfferEvent.fromMap({'riderId': 'b', 'wave': 1, 'createdAt': ago(const Duration(minutes: 2))}),
        OfferEvent.fromMap({'riderId': 'a', 'wave': 1, 'createdAt': ago(const Duration(minutes: 3))}),
      ]);
      expect(sorted.map((o) => o.riderId), ['a', 'b', 'c']);
    });
  });

  group('riders for manual assignment', () {
    const pickupLat = 11.0168, pickupLng = 76.9558; // Coimbatore
    AssignableRider r(String id, Map<String, dynamic> m, {Set<String> busy = const {}}) =>
        AssignableRider.fromMap(id, {'name': id, ...m},
            busy: busy, now: now, pickupLat: pickupLat, pickupLng: pickupLng);
    Map<String, dynamic> at(double lat, double lng, Duration age) => {
          'isOnline': true,
          'currentLat': lat,
          'currentLng': lng,
          'lastLocationUpdate': ago(age),
        };

    test('availability', () {
      expect(r('a', at(11.02, 76.96, const Duration(minutes: 2))).availability,
          RiderAvailability.available);
      expect(r('s', at(11.02, 76.96, const Duration(minutes: 6))).availability,
          RiderAvailability.staleLocation);
      expect(r('n', {'isOnline': true}).availability, RiderAvailability.noLocation);
      expect(r('b', at(11.02, 76.96, const Duration(minutes: 1)), busy: {'b'}).availability,
          RiderAvailability.busy);
      expect(r('o', {...at(11.02, 76.96, const Duration(minutes: 1)), 'isOnline': false}).availability,
          RiderAvailability.offline);
      expect(RiderAvailability.busy.canAssign, isFalse);
      expect(RiderAvailability.offline.canAssign, isFalse);
      expect(RiderAvailability.staleLocation.canAssign, isTrue);
    });

    test('distance to pickup', () {
      final x = r('x', at(11.0168 + 0.09, 76.9558, const Duration(minutes: 1)));
      expect(x.distanceKm, closeTo(10.0, 0.1)); // 0.09° latitude ≈ 10 km
      final unknown = AssignableRider.fromMap('u', at(11, 77, Duration.zero),
          busy: const {}, now: now);
      expect(unknown.distanceKm, isNull);
    });

    test('free riders first, nearest first; busy and offline last', () {
      final sorted = sortRiders([
        r('offline', {'isOnline': false}),
        r('far', at(11.0168 + 0.09, 76.9558, const Duration(minutes: 1))),
        r('busy', at(11.0168, 76.9558, const Duration(minutes: 1)), busy: {'busy'}),
        r('stale', at(11.0168, 76.9558, const Duration(hours: 2))),
        r('near', at(11.0168 + 0.01, 76.9558, const Duration(minutes: 1))),
      ]);
      expect(sorted.map((x) => x.id), ['near', 'far', 'stale', 'busy', 'offline']);
    });
  });

  group('which orders can take a rider', () {
    Map<String, dynamic> o(String? orderStatus, {String? status, String? partner}) => {
          'orderStatus': orderStatus,
          'status': status ?? orderStatus,
          if (partner != null) 'deliveryPartnerId': partner,
        };

    test('waiting for a rider → assign', () {
      expect(assignModeFor(o('ready_for_pickup')), AssignMode.assign);
      expect(assignModeFor(o('ready_for_pickup', partner: '')), AssignMode.assign);
    });

    test('a rider has it, not picked up → reassign', () {
      expect(assignModeFor(o('delivery_accepted', partner: 'r1')), AssignMode.reassign);
      // The pre-DLV-2C admin screen left orders like this.
      expect(assignModeFor(o('ready_for_pickup', partner: 'r1')), AssignMode.reassign);
    });

    test('anything else → not assignable, with a reason', () {
      expect(assignModeFor(o('pending')), isNull);
      expect(notAssignableMessage(o('pending')), contains('ready for pickup'));
      expect(assignModeFor(o('picked_up', partner: 'r1')), isNull);
      expect(notAssignableMessage(o('picked_up', partner: 'r1')), contains('picked this order up'));
      expect(assignModeFor(o('delivered', partner: 'r1')), isNull);
      // A seller/admin cancellation writes only `status` (DLV-2A d21).
      final cancelled = o('ready_for_pickup', status: 'cancelled');
      expect(assignModeFor(cancelled), isNull);
      expect(notAssignableMessage(cancelled), 'This order was cancelled.');
    });
  });

  group('the assignment write', () {
    test('leaves the order where the rider app and dispatch expect it', () {
      final u = assignmentOrderUpdate(
        riderId: 'r1',
        rider: {'name': 'Ravi', 'phone': '+91', 'vehicleType': 'bike', 'vehicleNumber': 'TN'},
        adminUid: 'admin1',
      );
      // The same pair acceptDeliveryOffer writes; `ready_for_pickup` (the
      // pre-DLV-2C value) is never shown by the rider app.
      expect(u['orderStatus'], 'delivery_accepted');
      expect(u['status'], 'delivery_accepted');
      expect(u['deliveryPartnerId'], 'r1');
      expect(u['deliveryAcceptedVia'], 'admin');
      expect(u['deliveryAssignedBy'], 'admin1');
      expect(u.containsKey('deliveryReassignedFrom'), isFalse);
      expect((u['deliveryPartner'] as Map)['name'], 'Ravi');
      final re = assignmentOrderUpdate(
          riderId: 'r2', rider: const {}, adminUid: 'a', previousRiderId: 'r1');
      expect(re['deliveryReassignedFrom'], 'r1');
    });

    // DLV-C1: the rider app's active-work query and the server's busy check
    // share DeliveryTaskStatus.riderActiveOrderStatuses (parity-tested with
    // dispatch.ts); an admin assignment must land in it.
    test('the rider app shows an admin assignment as an active order', () {
      final u = assignmentOrderUpdate(riderId: 'r1', rider: const {}, adminUid: 'a');
      expect(DeliveryTaskStatus.riderActiveOrderStatuses, contains(u['orderStatus']));
      expect(DeliveryTaskStatus.riderActiveOrderStatuses, isNot(contains('ready_for_pickup')));
      expect(
        DeliveryTaskStatus.fromOrderStatus(orderStatus: u['orderStatus'] as String?, status: u['status'] as String?, hasPartner: true),
        DeliveryTaskStatus.assigned,
      );
    });

    test('every refusal has a message', () {
      for (final o in AssignOutcome.values.where((o) => o != AssignOutcome.assigned)) {
        expect(o.refusalMessage, isNotEmpty, reason: o.name);
      }
    });
  });

  // DLV-D1: the in-transaction reservation check.
  test('a reservation blocks only while its order is active for that rider', () {
    expect(reservationBlocks({'deliveryPartnerId': 'r1', 'orderStatus': 'picked_up'}, 'r1'), isTrue);
    expect(reservationBlocks({'deliveryPartnerId': 'r1', 'orderStatus': 'delivered'}, 'r1'), isFalse);
    expect(reservationBlocks({'deliveryPartnerId': 'r2', 'orderStatus': 'picked_up'}, 'r1'), isFalse);
    expect(reservationBlocks(null, 'r1'), isFalse);
  });
}
