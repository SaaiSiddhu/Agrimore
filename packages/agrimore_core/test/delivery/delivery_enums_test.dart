// Phase DLV-1A — the delivery vocabulary.
//
// Asserted against test/fixtures/delivery_status_table.json, the SAME file
// functions/scripts/phaseDLV1A_delivery_states_test.js asserts the TypeScript
// mirror against. A change to the table, the Dart enum or the TS mirror alone
// fails a suite — that is the parity guard.
import 'dart:convert';
import 'dart:io';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _table() => jsonDecode(
      File('test/fixtures/delivery_status_table.json').readAsStringSync(),
    ) as Map<String, dynamic>;

DeliveryTaskStatus _byName(String name) =>
    DeliveryTaskStatus.values.firstWhere((s) => s.name == name);

void main() {
  final table = _table();

  group('DeliveryTaskStatus wire values', () {
    final wire = (table['taskStatusWire'] as Map).cast<String, String>();

    test('the enum has exactly the table\'s states', () {
      expect(
        DeliveryTaskStatus.values.map((s) => s.name).toSet(),
        wire.keys.toSet(),
      );
    });

    wire.forEach((name, value) {
      test('$name <-> "$value"', () {
        expect(_byName(name).wire, value);
        expect(DeliveryTaskStatus.fromWire(value), _byName(name));
      });
    });

    test('an unknown wire value parses to null, never throws', () {
      expect(DeliveryTaskStatus.fromWire('nonsense'), isNull);
      expect(DeliveryTaskStatus.fromWire(null), isNull);
    });
  });

  group('terminal states', () {
    final terminal = (table['terminal'] as List).cast<String>().toSet();
    for (final s in DeliveryTaskStatus.values) {
      test('${s.name}.isTerminal == ${terminal.contains(s.name)}', () {
        expect(s.isTerminal, terminal.contains(s.name));
      });
    }
  });

  group('transitions', () {
    final transitions = (table['transitions'] as Map).map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>().toSet()),
    );
    for (final from in DeliveryTaskStatus.values) {
      for (final to in DeliveryTaskStatus.values) {
        final allowed = transitions[from.name]!.contains(to.name);
        test('${from.name} -> ${to.name} is ${allowed ? 'allowed' : 'refused'}',
            () {
          expect(from.canTransitionTo(to), allowed);
        });
      }
    }
  });

  // DLV-C1: the rider app's active-work query and the server's busy check.
  group('riderActiveOrderStatuses', () {
    test('is exactly the table\'s list, in order', () {
      expect(DeliveryTaskStatus.riderActiveOrderStatuses,
          List<String>.from(table['riderActiveOrderStatuses'] as List));
    });
    for (final v in DeliveryTaskStatus.riderActiveOrderStatuses) {
      test('"$v" is an open rider leg', () {
        final s = DeliveryTaskStatus.fromOrderStatus(orderStatus: v, status: null, hasPartner: true);
        expect(s, isNotNull);
        expect(s!.isTerminal, isFalse);
        expect(s, isNot(DeliveryTaskStatus.searching));
      });
    }
  });

  group('fromOrderStatus (every legacy spelling in the repository)', () {
    for (final raw in (table['fromOrderStatus'] as List)) {
      final c = raw as Map<String, dynamic>;
      final expected = c['expect'] as String?;
      test(
          'orderStatus=${c['orderStatus']} status=${c['status']} '
          'hasPartner=${c['hasPartner']} -> $expected', () {
        final got = DeliveryTaskStatus.fromOrderStatus(
          orderStatus: c['orderStatus'] as String?,
          status: c['status'] as String?,
          hasPartner: c['hasPartner'] as bool,
        );
        expect(got?.name, expected);
      });
    }
  });

  group('rider and money enums keep today\'s stored strings', () {
    test('RiderKycStatus: stored strings round-trip; absent reads as pending',
        () {
      for (final s in RiderKycStatus.values) {
        expect(RiderKycStatus.fromWire(s.wire), s);
      }
      expect(RiderKycStatus.pending.wire, 'pending');
      expect(RiderKycStatus.approved.wire, 'approved');
      // add_delivery_partner_dialog.dart has never written `status`; the
      // delivery app's auth_provider.dart reads that as pending.
      expect(RiderKycStatus.fromWire(null), RiderKycStatus.pending);
      expect(RiderKycStatus.fromWire('APPROVED'), RiderKycStatus.approved);
      expect(RiderKycStatus.approved.canOperate, isTrue);
      expect(RiderKycStatus.pending.canOperate, isFalse);
      expect(RiderKycStatus.suspended.canOperate, isFalse);
    });

    test('VehicleType accepts what the two sign-up forms write', () {
      // partner_registration_screen.dart: Bike / Cycle / Van, lower-cased.
      expect(VehicleType.fromWire('bike'), VehicleType.bike);
      expect(VehicleType.fromWire('cycle'), VehicleType.bicycle);
      expect(VehicleType.fromWire('van'), VehicleType.van);
      // add_delivery_partner_dialog.dart: bike / ev.
      expect(VehicleType.fromWire('ev'), VehicleType.ev);
      expect(VehicleType.fromWire('Scooter'), VehicleType.scooter);
      expect(VehicleType.fromWire(null), VehicleType.bike);
      expect(VehicleType.fromWire('hovercraft'), VehicleType.bike);
      for (final v in VehicleType.values) {
        expect(VehicleType.fromWire(v.wire), v);
      }
    });

    test('CodSettlementStatus: "pending" is what confirmDelivery writes', () {
      expect(CodSettlementStatus.fromWire('pending'),
          CodSettlementStatus.pending);
      expect(CodSettlementStatus.fromWire(null),
          CodSettlementStatus.notApplicable);
      for (final v in CodSettlementStatus.values) {
        expect(CodSettlementStatus.fromWire(v.wire), v);
      }
    });

    test('the remaining enums round-trip and never throw', () {
      for (final v in RiderDutyStatus.values) {
        expect(RiderDutyStatus.fromWire(v.wire), v);
      }
      expect(RiderDutyStatus.fromWire('???'), RiderDutyStatus.offline);
      for (final v in DeliveryOfferStatus.values) {
        expect(DeliveryOfferStatus.fromWire(v.wire), v);
      }
      // notifications.ts writes delivery_requests with status "pending".
      expect(DeliveryOfferStatus.fromWire('pending'),
          DeliveryOfferStatus.offered);
      for (final v in DeliveryFailureReason.values) {
        expect(DeliveryFailureReason.fromWire(v.wire), v);
      }
      expect(DeliveryFailureReason.fromWire('???'),
          DeliveryFailureReason.other);
      for (final v in EarningType.values) {
        expect(EarningType.fromWire(v.wire), v);
      }
      expect(EarningType.fromWire('???'), isNull);
    });
  });

  group('DeliveryTaskModel', () {
    test('fromMap/toMap round-trip, unknown status tolerated', () {
      final m = DeliveryTaskModel.fromMap({
        'orderId': 'o1',
        'orderNumber': 'ORD1',
        'status': 'en_route',
        'riderId': 'r1',
        'sellerId': 's1',
        'customerId': 'c1',
        'pickup': {'lat': 9.9, 'lng': 78.1},
        'drop': {'lat': 9.8, 'lng': 78.2, 'pincode': '625001'},
        'paymentMethod': 'cod',
        'codAmount': 450,
        'legacyStatus': 'out_for_delivery',
        'lastTransitionAllowed': true,
      }, 'o1');
      expect(m.status, DeliveryTaskStatus.enRoute);
      expect(m.isCod, isTrue);
      expect(m.drop?.pincode, '625001');
      final back = DeliveryTaskModel.fromMap(m.toMap(), 'o1');
      expect(back.status, m.status);
      expect(back.codAmount, 450);
      expect(back.pickup?.lat, 9.9);

      final odd = DeliveryTaskModel.fromMap({'status': 'future'}, 'o2');
      expect(odd.status, isNull);
      expect(odd.orderId, 'o2');
    });

    test('copyWith changes only what it is given', () {
      final m = DeliveryTaskModel.fromMap({'status': 'assigned'}, 'o3');
      final n = m.copyWith(status: DeliveryTaskStatus.atPickup);
      expect(n.status, DeliveryTaskStatus.atPickup);
      expect(n.orderId, 'o3');
    });
  });

  group('DeliveryTiming (DLV-P1)', () {
    final timing = (table['timing'] as Map).cast<String, int>();

    test('mirrors the server', () {
      expect(DeliveryTiming.offerLifetime.inMilliseconds, timing['offerLifetimeMs']);
      expect(DeliveryTiming.riderSilentOffline.inMilliseconds, timing['riderSilentOfflineMs']);
      expect(DeliveryTiming.dispatchLocationFreshness.inMilliseconds, timing['dispatchLocationFreshnessMs']);
    });

    test('a still rider keeps sending well inside dispatch freshness', () {
      for (final hb in [DeliveryTiming.idleHeartbeat, DeliveryTiming.taskHeartbeat]) {
        expect(hb + DeliveryTiming.uploadCheckInterval, lessThan(DeliveryTiming.dispatchLocationFreshness));
      }
      expect(DeliveryTiming.reportFixRequestLimit, lessThan(DeliveryTiming.reportFixTimeout));
      expect(DeliveryTiming.taskMinUploadGap, lessThanOrEqualTo(DeliveryTiming.taskHeartbeat));
    });
  });
}
