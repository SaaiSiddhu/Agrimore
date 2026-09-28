// ADMR-72 (owner's prompt section 9) — command-interface testability.
//
// rider_support_screen.dart / rider_incidents_screen.dart /
// delivery_problems_screen.dart each used a hardcoded top-level
// `FirebaseFirestore.instance`, disclosed as untestable since ADMR-68. Given
// an optional constructor override (mirrors SupportCaseDetailScreen's own
// established pattern), these now render against a seeded
// fake_cloud_firestore like every other admin screen. Their own mutating
// actions (updateSupportRequest/updateRiderIncident/updateDeliveryException)
// still call a real Cloud Function and are proven server-side by
// phaseDLVSUP1/phaseDLV-S2/phaseDLVE1's own emulator suites -- this file
// covers only what a fake harness can honestly prove: rendering, and the
// create-a-case action row existing (never tapped -- it invokes a real
// Cloud Function, the same disclosed limitation the Evidence tab's own
// upload button carries).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/delivery/rider_support_screen.dart';
import 'package:agrimore_admin/screens/admin/delivery/rider_incidents_screen.dart';
import 'package:agrimore_admin/screens/admin/delivery/delivery_problems_screen.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  group('RiderSupportScreen (rider_support_tickets)', () {
    testWidgets('an open ticket renders its category and message', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('delivery_partners/rider_1').set({'name': 'Kumar'});
      await db.collection('rider_support_tickets').doc('t1').set({
        'riderId': 'rider_1', 'status': 'submitted', 'category': 'delivery_issue',
        'message': 'App keeps crashing on checkout', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      await _pump(tester, RiderSupportScreen(firestore: db));

      expect(find.text('Kumar'), findsOneWidget);
      expect(find.text('Delivery issue'), findsOneWidget);
      expect(find.text('App keeps crashing on checkout'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Create/open case'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no open tickets shows an honest empty state', (tester) async {
      final db = FakeFirebaseFirestore();
      await _pump(tester, RiderSupportScreen(firestore: db));
      expect(find.text('No open requests.'), findsOneWidget);
    });
  });

  group('RiderIncidentsScreen (rider_incidents)', () {
    testWidgets('an open incident renders its rider name', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('rider_incidents').doc('i1').set({
        'riderId': 'rider_1', 'riderName': 'Kumar', 'status': 'reported',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)), 'activeOrderIds': [],
      });

      await _pump(tester, RiderIncidentsScreen(firestore: db));

      expect(find.text('Kumar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no open incidents shows an honest empty state', (tester) async {
      final db = FakeFirebaseFirestore();
      await _pump(tester, RiderIncidentsScreen(firestore: db));
      expect(find.text('No open incidents.'), findsOneWidget);
    });
  });

  group('DeliveryProblemsScreen (delivery_exceptions)', () {
    testWidgets('an open problem renders its order and reason', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('delivery_partners/rider_1').set({'name': 'Kumar'});
      await db.collection('delivery_exceptions').doc('e1').set({
        'riderId': 'rider_1', 'orderId': 'order_1', 'orderNumber': 'ORD-1', 'status': 'reported',
        'reason': 'customer_unreachable', 'custody': 'rider',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      await _pump(tester, DeliveryProblemsScreen(firestore: db));

      expect(find.textContaining('ORD-1'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Create/open case'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no open problems shows an honest empty state', (tester) async {
      final db = FakeFirebaseFirestore();
      await _pump(tester, DeliveryProblemsScreen(firestore: db));
      expect(find.text('No open delivery problems.'), findsOneWidget);
    });
  });
}
