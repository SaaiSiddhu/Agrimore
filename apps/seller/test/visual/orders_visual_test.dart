import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/orders/seller_order_detail_screen.dart';
import 'package:seller/screens/orders/seller_orders_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  final orders = [
    fixtureOrder('1042', 'pending', quantity: 5, price: 116, method: 'razorpay'),
    fixtureOrder('1041', 'processing', name: 'Ramesh Kumar', product: 'Green chillies', quantity: 1, price: 320),
    fixtureOrder('1040', 'delivered', name: 'Green Valley Foods', quantity: 3, price: 320, method: 'razorpay'),
    fixtureOrder('1039', 'cancelled', name: 'Anita Rao', quantity: 1, price: 210, method: 'razorpay'),
  ];

  for (final (name, b) in [('orders_list_light', Brightness.light), ('orders_list_dark', Brightness.dark)]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, const SellerOrdersScreen(), orders: orders, brightness: b);
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }

  for (final (name, status, b) in [
    ('order_detail_placed_light', 'pending', Brightness.light),
    ('order_detail_packing_dark', 'processing', Brightness.dark),
  ]) {
    testWidgets(name, (tester) async {
      final o = fixtureOrder('1042', status, method: 'razorpay');
      await pumpSellerApp(tester, SellerOrderDetailScreen(order: o), orders: [o], brightness: b, size: const Size(390, 1400));
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }

  testWidgets('order_reject_sheet', (tester) async {
    final o = fixtureOrder('1042', 'pending', method: 'razorpay');
    await pumpSellerApp(tester, SellerOrderDetailScreen(order: o), orders: [o], size: const Size(390, 900));
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'order_reject_sheet');
  });

  testWidgets('orders_tablet_split', (tester) async {
    await pumpSellerApp(tester, const SellerOrdersScreen(), orders: orders, size: const Size(1280, 800));
    await tester.tap(find.text('#1042'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'orders_tablet_split');
  });
}
