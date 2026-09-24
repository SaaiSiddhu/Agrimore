import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/home/dashboard_screen.dart';
import 'package:seller/screens/home/home_stats.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);

  final now = DateTime.utc(2026, 9, 23, 3); // 08:30 IST
  final stats = {
    for (final (day, gross, orders) in [
      ('20260917', 1400.0, 3), ('20260918', 1800.0, 4), ('20260919', 1200.0, 3), ('20260920', 2600.0, 5),
      ('20260921', 2100.0, 4), ('20260922', 2400.0, 5), ('20260923', 2500.0, 4),
      ('20260916', 1500.0, 3), ('20260915', 1300.0, 3), ('20260914', 1600.0, 3), ('20260913', 1700.0, 4),
      ('20260912', 1500.0, 3), ('20260911', 1800.0, 4), ('20260910', 1800.0, 5),
    ])
      day: DayStat(day: day, gross: gross, orders: orders, cancelled: 0),
  };
  final orders = [
    fixtureOrder('1042', 'pending', createdAt: DateTime.utc(2026, 9, 23, 2, 40)),
    fixtureOrder('1041', 'pending'),
    fixtureOrder('1040', 'confirmed'),
  ];
  final products = [fixtureProduct('a', stock: 2), fixtureProduct('b', stock: 0), fixtureProduct('c')];

  for (final (name, brightness, size, scale) in [
    ('home_phone_light', Brightness.light, const Size(390, 844), 1.0),
    ('home_phone_dark', Brightness.dark, const Size(390, 844), 1.0),
    ('home_phone_text200', Brightness.light, const Size(390, 844), 2.0),
  ]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(
        tester,
        DashboardScreen(now: now, stats: stats, pendingPayout: 3840, rating: 4.5, reviewCount: 20),
        orders: orders,
        products: products,
        user: fixtureSeller(name: 'Kaveri Fresh'),
        brightness: brightness,
        size: size,
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
}
