// ADMR-48 — OrderProvider's order list is now genuinely testWidgets-testable.
//
// PROBLEM: every OrderProvider-dependent screen this session touched shared
// one constraint, disclosed repeatedly rather than worked around: the
// State/Provider classes read FirebaseFirestore.instance in a field
// initializer, so they crash outside a real Firebase app and could only be
// verified by extracting pure logic out of them, never by pumping the real
// widget tree. loadOrders() (the admin order list OrderManagementScreen
// renders) uses only _firestore, no DatabaseService/AuthService — so
// injecting just that one dependency is enough to make this one real,
// already-shipped screen testable end to end: a seeded FakeFirebaseFirestore
// stands in for FirebaseFirestore.instance, and the actual widget tree
// (Provider -> stream listener -> OrderModel.fromMap -> rendered card) runs
// unmodified. Every other OrderProvider method remains real-Firebase-only.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrimore_admin/providers/order_provider.dart';
import 'package:agrimore_admin/screens/admin/orders/order_management_screen.dart';

Future<void> _pumpScreen(WidgetTester tester, FakeFirebaseFirestore firestore) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<OrderProvider>(
        create: (_) => OrderProvider(firestore: firestore),
        child: const OrderManagementScreen(),
      ),
    ),
  );
  // The list load is kicked off from a post-frame callback and lands via a
  // real (fake) Firestore snapshot stream — pumpAndSettle drains both.
  await tester.pumpAndSettle();
}

Map<String, dynamic> _orderDoc({
  required String orderNumber,
  String status = 'pending',
  double total = 250.0,
  String customerName = 'Asha Devi',
}) {
  return {
    'orderNumber': orderNumber,
    'orderStatus': status,
    'total': total,
    'subtotal': total,
    'paymentMethod': 'cod',
    'items': <Map<String, dynamic>>[],
    'deliveryAddress': {
      'name': customerName,
      'phone': '9876543210',
      'addressLine1': '1 Main Street',
      'addressLine2': '',
      'city': 'Chennai',
      'state': 'Tamil Nadu',
      'zipcode': '600001',
    },
    'createdAt': Timestamp.fromDate(DateTime(2026, 9, 20)),
  };
}

void main() {
  group('OrderManagementScreen against a seeded fake Firestore', () {
    testWidgets('renders a real order pulled through the actual provider/stream/model pipeline',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('orders').add(_orderDoc(orderNumber: 'ORD-1001'));

      await _pumpScreen(tester, firestore);

      expect(find.text('Order #ORD-1001'), findsOneWidget);
    });

    testWidgets('renders multiple seeded orders, one card each', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('orders').add(_orderDoc(orderNumber: 'ORD-2001'));
      await firestore.collection('orders').add(_orderDoc(orderNumber: 'ORD-2002', status: 'shipped'));

      await _pumpScreen(tester, firestore);

      expect(find.text('Order #ORD-2001'), findsOneWidget);
      expect(find.text('Order #ORD-2002'), findsOneWidget);
    });

    testWidgets('an empty orders collection renders no order card, not a crash',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpScreen(tester, firestore);

      expect(find.textContaining('Order #'), findsNothing);
    });

    testWidgets('a later write to the fake Firestore updates the rendered list live',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('orders').add(_orderDoc(orderNumber: 'ORD-3001'));

      await _pumpScreen(tester, firestore);
      expect(find.text('Order #ORD-3001'), findsOneWidget);
      expect(find.text('Order #ORD-3002'), findsNothing);

      await firestore.collection('orders').add(_orderDoc(orderNumber: 'ORD-3002'));
      await tester.pumpAndSettle();

      expect(find.text('Order #ORD-3001'), findsOneWidget);
      expect(find.text('Order #ORD-3002'), findsOneWidget);
    });
  });
}
