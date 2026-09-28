// ADMR-50/51 — closes the disclosed Order 360 widget-test gap.
//
// order_360_layout_test.dart's own header comment documented this exact,
// long-standing constraint: "admin_order_details_screen.dart's own
// StatefulWidget cannot be constructed here at all outside a real Firebase
// app... this file proves [pure functions], not the widget tree." ADMR-48
// made OrderProvider's _firestore injectable and removed its two dead
// DatabaseService/AuthService fields; a fresh grep confirmed loadOrderById
// and all 9 of its own sub-loaders reach Firebase through _firestore
// alone, with no other dependency.
//
// ADMR-50 found one more, separate blocker on the happy path: DeliveryFlagsCard
// (admin/lib/screens/admin/delivery/delivery_flags.dart), embedded
// unconditionally in this screen's main column, read FirebaseFirestore.instance
// directly in its own build() whenever its own optional `data` parameter
// wasn't supplied — independent of OrderProvider entirely. ADMR-51 closed
// that: DeliveryFlagsCard now also takes an injectable firestore, exposed
// from OrderProvider via a new `firestore` getter and threaded through
// admin_order_details_screen.dart's own call site. This file now covers
// both the not-found path and a full, genuinely pixel-level render of a
// found order — the actual data pipeline AND the actual widget tree.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrimore_admin/providers/order_provider.dart';
import 'package:agrimore_admin/screens/admin/orders/admin_order_details_screen.dart';
import 'package:agrimore_admin/screens/admin/widgets/actor_support_cases_section.dart';

void main() {
  testWidgets(
    'AdminOrderDetailsScreen: a seeded order renders through the real provider/9-loader-chain/widget pipeline, including DeliveryFlagsCard',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final doc = await firestore.collection('orders').add({
        'orderNumber': 'ORD-9101',
        'orderStatus': 'processing',
        'total': 750.0,
        'subtotal': 750.0,
        'paymentMethod': 'cod',
        'items': <Map<String, dynamic>>[],
        'deliveryAddress': {
          'name': 'Arun Kumar',
          'phone': '9988776655',
          'addressLine1': '9 Mount Road',
          'addressLine2': '',
          'city': 'Chennai',
          'state': 'Tamil Nadu',
          'zipcode': '600006',
        },
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>(
            create: (_) => OrderProvider(firestore: firestore),
            child: AdminOrderDetailsScreen(orderId: doc.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order #ORD-9101'), findsOneWidget);
      expect(find.text('Order not found'), findsNothing);
      // DeliveryFlagsCard renders nothing for an order with no
      // deliveryStepChecks (SizedBox.shrink) — the point of this
      // assertion is that the screen finished building at all, with no
      // FirebaseException from that embedded widget.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AdminOrderDetailsScreen: a genuinely absent order id renders the existing empty state, not a crash',
    (tester) async {
      final firestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>(
            create: (_) => OrderProvider(firestore: firestore),
            child: const AdminOrderDetailsScreen(orderId: 'does-not-exist'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order not found'), findsOneWidget);
    },
  );

  group('OrderProvider.loadOrderById — the full 9-loader chain against a seeded fake Firestore', () {
    test('a found order populates selectedOrder and settles every loading flag to false', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await firestore.collection('orders').add({
        'orderNumber': 'ORD-9001',
        'orderStatus': 'processing',
        'total': 500.0,
        'subtotal': 500.0,
        'paymentMethod': 'cod',
        'items': <Map<String, dynamic>>[],
        'deliveryAddress': {
          'name': 'Priya Sharma',
          'phone': '9123456780',
          'addressLine1': '5 Anna Salai',
          'addressLine2': '',
          'city': 'Chennai',
          'state': 'Tamil Nadu',
          'zipcode': '600002',
        },
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 15)),
      });

      final provider = OrderProvider(firestore: firestore);
      await provider.loadOrderById(doc.id);

      expect(provider.error, isNull);
      expect(provider.selectedOrder, isNotNull);
      expect(provider.selectedOrder!.orderNumber, 'ORD-9001');
      expect(provider.selectedOrder!.deliveryAddress.name, 'Priya Sharma');
      expect(provider.isLoading, isFalse);
      expect(provider.isLoadingTimeline, isFalse);
      expect(provider.isLoadingDispatchOffers, isFalse);
      expect(provider.isLoadingRiderEarning, isFalse);
      expect(provider.isLoadingCommissionExceptions, isFalse);
      expect(provider.isLoadingSupportTickets, isFalse);
      expect(provider.isLoadingDeliveryExceptions, isFalse);
      expect(provider.isLoadingRiderIncidents, isFalse);
      expect(provider.isLoadingSellerPayouts, isFalse);
      expect(provider.isLoadingRiderCashAccount, isFalse);
    });

    test('an absent order id leaves selectedOrder null and records the not-found error', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = OrderProvider(firestore: firestore);

      await provider.loadOrderById('does-not-exist');

      expect(provider.selectedOrder, isNull);
      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    });
  });

  // ADMR-64 additions below: the new Support Cases card stacks one
  // ActorSupportCasesSection per actor role this specific order actually
  // carries (customer always; seller/rider/associate only when present).
  group('Support Cases card (ADMR-64)', () {
    Map<String, dynamic> _orderMap({
      String? sellerId,
      String? deliveryPartnerId,
      String? employeeUid,
    }) =>
        {
          'orderNumber': 'ORD-CASE1',
          'orderStatus': 'processing',
          'total': 300.0,
          'subtotal': 300.0,
          'paymentMethod': 'cod',
          'userId': 'cust_order1',
          if (sellerId != null) 'sellerId': sellerId,
          if (deliveryPartnerId != null) 'deliveryPartnerId': deliveryPartnerId,
          if (employeeUid != null) 'employeeUid': employeeUid,
          'items': <Map<String, dynamic>>[],
          'deliveryAddress': {
            'name': 'Arun Kumar',
            'phone': '9988776655',
            'addressLine1': '9 Mount Road',
            'addressLine2': '',
            'city': 'Chennai',
            'state': 'Tamil Nadu',
            'zipcode': '600006',
          },
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
        };

    testWidgets('an order with no seller/rider/associate shows only the Customer section',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final doc = await firestore.collection('orders').add(_orderMap());

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>(
            create: (_) => OrderProvider(firestore: firestore),
            child: AdminOrderDetailsScreen(orderId: doc.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Seller'), findsNothing);
      expect(find.text('Delivery Partner'), findsNothing);
      expect(find.text('Sales Associate'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'an order with all four actor ids shows all four sections, and a real case for one of them',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final doc = await firestore.collection('orders').add(_orderMap(
            sellerId: 'seller_order1',
            deliveryPartnerId: 'rider_order1',
            employeeUid: 'assoc_order1',
          ));
      await firestore.collection('support_cases').add({
        'title': 'Seller shipped the wrong item',
        'category': 'product_issue',
        'primaryActor': {'type': 'seller', 'id': 'seller_order1'},
        'status': 'open',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 11)),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>(
            create: (_) => OrderProvider(firestore: firestore),
            child: AdminOrderDetailsScreen(orderId: doc.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);
      expect(find.text('Delivery Partner'), findsOneWidget);
      expect(find.text('Sales Associate'), findsOneWidget);
      expect(find.text('Seller shipped the wrong item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ADMR-67 additions below: cases genuinely LINKED to this order, distinct
  // from ADMR-64's own actor-context history above.
  //
  // The cross-order isolation guarantee itself (order A's own case never
  // leaking into order B's view, even sharing a customer) is proven against
  // a REAL Firebase emulator in phaseADMR67_order_specific_cases_test.js
  // (o05/o06/o07, 7/7 passing) -- NOT here. A fresh, isolated probe during
  // this phase confirmed fake_cloud_firestore's own arrayContains never
  // matches a Map-shaped array element at all (0 docs found for the single
  // simplest positive case, not just the cross-order negative one) --
  // Dart's default Map.== is identity-based, not the value-based comparison
  // real Firestore's own array-contains uses server-side. New memory:
  // agrimore-fake-cloud-firestore-arraycontains-map-never-matches. These
  // widget tests are scoped to what this harness CAN prove honestly: the
  // two-section split renders with the right headers and doesn't crash.
  group('Order-linked cases section (ADMR-67)', () {
    testWidgets(
        'renders both section headers without crashing, real filtering is '
        'proven server-side only (see phaseADMR67_order_specific_cases_test.js)',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final doc = await firestore.collection('orders').add({
        'orderNumber': 'ORD-LINK1',
        'orderStatus': 'processing',
        'total': 100.0,
        'subtotal': 100.0,
        'paymentMethod': 'cod',
        'userId': 'cust_link1',
        'items': <Map<String, dynamic>>[],
        'deliveryAddress': {
          'name': 'Test',
          'phone': '9999999999',
          'addressLine1': '1 Test St',
          'addressLine2': '',
          'city': 'Chennai',
          'state': 'Tamil Nadu',
          'zipcode': '600001',
        },
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
      });
      await firestore.collection('support_cases').add({
        'title': 'Genuinely about this order',
        'category': 'delivery_issue',
        'primaryActor': {'type': 'customer', 'id': 'cust_link1'},
        'linkedRecords': [
          {'type': 'order', 'id': doc.id}
        ],
        'status': 'open',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 11)),
      });
      // Same customer, but this case is about a DIFFERENT order -- must
      // never appear in the "about this order" section.
      await firestore.collection('support_cases').add({
        'title': 'About some other order entirely',
        'category': 'delivery_issue',
        'primaryActor': {'type': 'customer', 'id': 'cust_link1'},
        'linkedRecords': [
          {'type': 'order', 'id': 'a-completely-different-order'}
        ],
        'status': 'open',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 12)),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>(
            create: (_) => OrderProvider(firestore: firestore),
            child: AdminOrderDetailsScreen(orderId: doc.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cases About This Order'), findsOneWidget);
      expect(find.text('Other Cases Involving These People'), findsOneWidget);
      expect(find.byType(OrderLinkedSupportCasesSection), findsOneWidget);
      // Both seeded cases share primaryActor.customer, so ADMR-63's own
      // actor-scoped query (proven separately, real Firestore semantics
      // that DO work under this harness) legitimately renders both of them
      // in "Other Cases Involving These People" -- this only confirms that
      // section still works normally alongside the new one, not the new
      // query's own filtering (see the group's own header comment).
      expect(find.text('Genuinely about this order'), findsOneWidget);
      expect(find.text('About some other order entirely'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
