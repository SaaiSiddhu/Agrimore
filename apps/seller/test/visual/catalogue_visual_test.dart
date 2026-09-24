import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/products/seller_products_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  final products = [
    fixtureProduct('a', name: 'Fresh tomatoes', stock: 25, draft: true, active: false),
    fixtureProduct('b', name: 'Green chillies', stock: 3, price: 120),
    fixtureProduct('c', name: 'Rice', stock: 0, price: 60),
  ];
  for (final (name, b) in [('catalogue_light', Brightness.light), ('catalogue_dark', Brightness.dark)]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, const SellerProductsScreen(), products: products, brightness: b);
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
  testWidgets('catalogue_selecting', (tester) async {
    await pumpSellerApp(tester, const SellerProductsScreen(), products: products);
    await tester.longPress(find.text('Green chillies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'catalogue_selecting');
  });
}
