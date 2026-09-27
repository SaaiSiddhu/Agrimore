// ADMR-50 — closes part of the disclosed Order 360 widget-test gap.
//
// order_360_layout_test.dart's own header comment documented this exact,
// long-standing constraint: "admin_order_details_screen.dart's own
// StatefulWidget cannot be constructed here at all outside a real Firebase
// app... this file proves [pure functions], not the widget tree." ADMR-48
// already made OrderProvider's _firestore injectable and removed its two
// dead DatabaseService/AuthService fields; a fresh grep confirms
// loadOrderById and all 9 of its own sub-loaders reach Firebase through
// _firestore alone, with no other dependency.
//
// A genuinely full widget-level render of a FOUND order is still blocked —
// but by a separate, newly-discovered constraint, not the one ADMR-48
// closed: DeliveryFlagsCard (admin/lib/screens/admin/delivery/
// delivery_flags.dart), embedded unconditionally in this screen's main
// column, reads FirebaseFirestore.instance directly in its own build()
// when its own optional `data` parameter isn't supplied — a completely
// separate Firebase touchpoint from OrderProvider, out of this phase's own
// claimed scope (must_not_touch admin_order_details_screen.dart /
// delivery_flags.dart). Disclosed, not silently worked around: this file
// proves what's actually achievable within that scope — a real widget test
// for the "order not found" path (which returns before ever building
// DeliveryFlagsCard), and a real provider-level integration test proving
// the FULL loadOrderById chain — the actual data pipeline, not the pixels
// — works end to end against a seeded fake Firestore for a found order.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrimore_admin/providers/order_provider.dart';
import 'package:agrimore_admin/screens/admin/orders/admin_order_details_screen.dart';

void main() {
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
