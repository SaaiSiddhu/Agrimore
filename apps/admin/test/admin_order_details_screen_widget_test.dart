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
}
