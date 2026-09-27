// ADMR-56 — Customer 360.
//
// TabBarView builds every tab's widget tree up front (it wraps a plain
// PageView, not a lazy builder), so every tab's content is findable via
// find.text without simulating a tab switch -- these tests rely on that.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrimore_admin/providers/admin_provider.dart';
import 'package:agrimore_admin/screens/admin/users/customer_detail_screen.dart';

Future<void> _seedUser(FakeFirebaseFirestore db, String uid,
    {String name = 'Priya Sharma', bool isActive = true}) async {
  await db.collection('users').doc(uid).set({
    'email': '$uid@example.com',
    'name': name,
    'role': 'user',
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'isActive': isActive,
    'phoneVerified': true,
    'emailVerified': false,
    'profileCompleted': true,
  });
}

Future<void> pumpScreen(
    WidgetTester tester, FakeFirebaseFirestore firestore, String userId) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AdminProvider())],
      child: MaterialApp(
        home: CustomerDetailScreen(userId: userId, firestore: firestore),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// TabBarView wraps a plain PageView, which only builds the current (and
// possibly a neighboring) page, not every tab up front -- so a tab's
// content is only in the tree once its own Tab has actually been
// selected. Tap the tab's own label in the TabBar (not the TabBarView's
// content, which doesn't exist yet) to switch.
Future<void> switchToTab(WidgetTester tester, String tabLabel) async {
  final tab = find.widgetWithText(Tab, tabLabel);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders identity fields for the found customer', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedUser(db, 'cust_1', name: 'Priya Sharma');

    await pumpScreen(tester, db, 'cust_1');

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('cust_1@example.com'), findsWidgets);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Phone verified'), findsOneWidget);
    expect(find.text('Email unverified'), findsOneWidget);
  });

  testWidgets('a missing customer shows an honest not-found state, not a crash',
      (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpScreen(tester, db, 'does_not_exist');

    expect(find.text('Customer not found. They may have been removed.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P01: customer A never shows customer B\'s orders', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedUser(db, 'cust_a', name: 'Customer A');
    await _seedUser(db, 'cust_b', name: 'Customer B');
    await db.collection('orders').add({
      'userId': 'cust_a',
      'orderNumber': 'ORD-A1',
      'orderStatus': 'delivered',
      'paymentStatus': 'paid',
      'paymentMethod': 'cod',
      'total': 199.0,
      'subtotal': 199.0,
      'items': <Map<String, dynamic>>[],
      'deliveryAddress': <String, dynamic>{},
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('orders').add({
      'userId': 'cust_b',
      'orderNumber': 'ORD-B1',
      'orderStatus': 'delivered',
      'paymentStatus': 'paid',
      'paymentMethod': 'cod',
      'total': 299.0,
      'subtotal': 299.0,
      'items': <Map<String, dynamic>>[],
      'deliveryAddress': <String, dynamic>{},
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'cust_a');
    await switchToTab(tester, 'Orders');

    expect(find.text('Order #ORD-A1'), findsOneWidget);
    expect(find.text('Order #ORD-B1'), findsNothing);
  });

  testWidgets(
      'order pagination shows one page (20) with no duplicates and a Load '
      'more control, and tapping it settles cleanly', (tester) async {
    // NOTE on scope: fake_cloud_firestore 3.1.0's startAfterDocument,
    // combined with limit()+orderBy(), was independently confirmed (a
    // throwaway diagnostic script, not committed) to return zero documents
    // for the second page even when real matching documents exist beyond
    // the cursor -- a fake-library limitation, not an app bug: the
    // production code uses the standard, documented Firestore cursor
    // pattern (q.limit(n).startAfterDocument(lastDoc)). Bumping past 3.1.0
    // would require cloud_firestore ^6.x, a real-plugin major version
    // change across the whole app -- out of scope for this phase. This
    // test therefore proves what fake_cloud_firestore CAN prove here:
    // exactly one page loads, in the right order, no duplicates, and the
    // load-more control's loading/settled state machine doesn't hang or
    // throw -- not that a second page's content arrives (unverifiable in
    // this harness; see the ledger's own disclosure of this limitation).
    final db = FakeFirebaseFirestore();
    await _seedUser(db, 'cust_many');
    for (var i = 0; i < 25; i++) {
      await db.collection('orders').add({
        'userId': 'cust_many',
        'orderNumber': 'ORD-${i.toString().padLeft(3, '0')}',
        'orderStatus': 'delivered',
        'paymentStatus': 'paid',
        'paymentMethod': 'cod',
        'total': 10.0,
        'subtotal': 10.0,
        'items': <Map<String, dynamic>>[],
        'deliveryAddress': <String, dynamic>{},
        // Distinct timestamps so ordering (and hence the pagination cursor)
        // is well-defined -- same-millisecond writes would make
        // orderBy(createdAt) ties arbitrary.
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1).add(Duration(minutes: i))),
      });
    }

    await pumpScreen(tester, db, 'cust_many');
    await switchToTab(tester, 'Orders');

    // Newest (i=24) first, exactly one page, no duplicates.
    expect(find.text('Order #ORD-024'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
    final firstPageLabels = find
        .textContaining('Order #ORD-')
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .toList();
    expect(firstPageLabels.length, 20);
    expect(firstPageLabels.toSet().length, 20, reason: 'no duplicate order rows');

    final loadMore = find.text('Load more');
    await tester.ensureVisible(loadMore);
    await tester.pumpAndSettle();
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet, coins and Product Credit are shown as separate figures',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedUser(db, 'cust_wallet');
    await db.collection('wallets').doc('cust_wallet').set({
      'userId': 'cust_wallet',
      'balance': 150.0,
      'coins': 40,
      'referralCode': 'REF123',
      'referralCount': 2,
      'isActive': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    await db.collection('product_credit_balances').doc('cust_wallet').set({
      'available': 75.0,
      'onHold': 25.0,
      'lifetimeEarned': 100.0,
    });

    await pumpScreen(tester, db, 'cust_wallet');
    await switchToTab(tester, 'Wallet & Rewards');

    expect(find.text('₹150.00'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('₹75.00'), findsOneWidget);
    expect(find.text('₹25.00'), findsOneWidget);
  });

  testWidgets('addresses tab renders a seeded address', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedUser(db, 'cust_addr');
    await db.collection('addresses').add({
      'id': 'addr_1',
      'userId': 'cust_addr',
      'name': 'Priya Sharma',
      'phone': '9999999999',
      'addressLine1': '12 MG Road',
      'addressLine2': 'Near Park',
      'city': 'Bengaluru',
      'state': 'KA',
      'zipcode': '560001',
      'isDefault': true,
      'createdAt': Timestamp.now(),
    });

    await pumpScreen(tester, db, 'cust_addr');
    await switchToTab(tester, 'Addresses');

    expect(find.textContaining('12 MG Road'), findsOneWidget);
  });

  testWidgets('support tab discloses no case system exists, rather than faking one',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedUser(db, 'cust_support');

    await pumpScreen(tester, db, 'cust_support');
    await switchToTab(tester, 'Support & Audit');

    expect(
        find.textContaining('No dedicated customer support-case system exists yet'),
        findsOneWidget);
  });
}
