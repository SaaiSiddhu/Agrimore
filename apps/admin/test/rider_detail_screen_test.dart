// ADMR-58 — Delivery Partner 360.
//
// Same conventions as ADMR-56/57's own tests: TabBarView only builds the
// current tab (switchToTab is required), and a tall test viewport avoids
// later stacked sections in one ListView never being built at all (see
// the flutter-finder-skipoffstage-below-fold memory's ADMR-57 update).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/delivery/rider_detail_screen.dart';

Future<void> _seedRider(FakeFirebaseFirestore db, String riderId,
    {String name = 'Arun Kumar', bool isOnline = true}) async {
  await db.collection('delivery_partners').doc(riderId).set({
    'name': name,
    'phone': '9999999999',
    'vehicleNumber': 'KA01AB1234',
    'vehicleType': 'bike',
    'isOnline': isOnline,
    'totalDeliveries': 12,
    'rating': 4.5,
    'status': 'approved',
    // No KYC document fields set -- avoids exercising RiderReviewSheet's
    // FirebaseStorage-backed _KycTile at all in this harness.
  });
}

Future<void> pumpScreen(
    WidgetTester tester, FakeFirebaseFirestore firestore, String riderId) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: RiderDetailScreen(riderId: riderId, firestore: firestore),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> switchToTab(WidgetTester tester, String tabLabel) async {
  final tab = find.widgetWithText(Tab, tabLabel);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders identity fields for the found rider', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedRider(db, 'rider_1', name: 'Arun Kumar');

    await pumpScreen(tester, db, 'rider_1');

    // Shown both in the header and RiderReviewSheet's own embedded content.
    expect(find.text('Arun Kumar'), findsNWidgets(2));
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('a missing rider shows an honest not-found state, not a crash', (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpScreen(tester, db, 'does_not_exist');

    expect(find.textContaining('Delivery partner not found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P01: rider A never shows rider B\'s assignments', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedRider(db, 'rider_a', name: 'Rider A');
    await _seedRider(db, 'rider_b', name: 'Rider B');
    await db.collection('orders').add({
      'deliveryPartnerId': 'rider_a',
      'orderNumber': 'ORD-A1',
      'orderStatus': 'delivered',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('orders').add({
      'deliveryPartnerId': 'rider_b',
      'orderNumber': 'ORD-B1',
      'orderStatus': 'delivered',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'rider_a');
    await switchToTab(tester, 'Assignments');

    expect(find.text('Order #ORD-A1'), findsOneWidget);
    expect(find.text('Order #ORD-B1'), findsNothing);
  });

  testWidgets('earnings tab totals this rider\'s own deliveries only', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedRider(db, 'rider_earn');
    await db.collection('rider_earnings').doc('order_1').set({
      'orderId': 'order_1',
      'riderId': 'rider_earn',
      'orderNumber': 'ORD-900',
      'lines': <Map<String, dynamic>>[],
      'total': 55.0,
      'km': 3.2,
      'kmSource': 'route',
      'waitMinutes': 2,
      'codCollected': 0.0,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'rider_earn');
    await switchToTab(tester, 'Earnings');

    expect(find.textContaining('₹55.00 total earned'), findsOneWidget);
    expect(find.text('Order ORD-900'), findsOneWidget);
  });

  testWidgets('COD and cash tab shows cash held and a link to the full ledger',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedRider(db, 'rider_cod');
    await db.collection('rider_accounts').doc('rider_cod').set({
      'cashHeldPaise': 150000,
    });

    await pumpScreen(tester, db, 'rider_cod');
    await switchToTab(tester, 'COD & Cash');

    expect(find.text('₹1,500.00'), findsOneWidget);
    expect(find.text('View full cash ledger'), findsOneWidget);
  });

  testWidgets('bank and payout tab shows current destination and a pending change',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedRider(db, 'rider_bank');
    await db.collection('delivery_partners').doc('rider_bank').update({
      'bankAccountNumber': '1234567890',
      'ifscCode': 'HDFC0001',
      'accountHolderName': 'Arun Kumar',
    });
    await db.collection('rider_bank_change_requests').add({
      'riderId': 'rider_bank',
      'status': 'pending',
      'upiId': 'arun@upi',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'rider_bank');
    await switchToTab(tester, 'Bank & Payout');

    expect(find.textContaining('HDFC0001'), findsOneWidget);
    expect(find.text('New destination requested'), findsOneWidget);
  });

  testWidgets('support and audit tab scopes tickets/incidents/exceptions to this rider only',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedRider(db, 'rider_sup');
    await _seedRider(db, 'rider_other');
    await db.collection('rider_support_tickets').add({
      'riderId': 'rider_sup',
      'subject': 'App crashed at pickup',
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('rider_support_tickets').add({
      'riderId': 'rider_other',
      'subject': 'Someone else\'s ticket',
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'rider_sup');
    await switchToTab(tester, 'Support & Audit');

    expect(find.text('App crashed at pickup'), findsOneWidget);
    expect(find.text('Someone else\'s ticket'), findsNothing);
    expect(find.text('No incidents reported for this rider.'), findsOneWidget);
  });
}
