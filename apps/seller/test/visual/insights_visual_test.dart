import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/home/home_stats.dart';
import 'package:seller/screens/insights/health_screen.dart';
import 'package:seller/screens/insights/insights_rules.dart';
import 'package:seller/screens/insights/insights_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  final now = DateTime.utc(2026, 9, 24, 6);
  final keys = istDayKeys(now, 14);
  final stats = {
    for (var i = 0; i < keys.length; i++)
      keys[i]: DayStat(day: keys[i], gross: 1200.0 + (i * 137) % 900, orders: 2 + i % 3, b2bGross: i.isEven ? 400 : 0),
  };
  final orders = [
    fixtureOrder('1042', 'pending', createdAt: now.subtract(const Duration(days: 1))),
    fixtureOrder('1041', 'processing', createdAt: now.subtract(const Duration(days: 2))),
    fixtureOrder('1040', 'delivered', product: 'Green chillies', createdAt: now.subtract(const Duration(days: 3))),
    fixtureOrder('1039', 'cancelled', createdAt: now.subtract(const Duration(days: 4))),
  ];
  for (final (name, b) in [('insights_light', Brightness.light), ('insights_dark', Brightness.dark)]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, InsightsScreen(stats: stats, now: now), orders: orders, brightness: b, size: const Size(390, 3000));
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
  testWidgets('health', (tester) async {
    await pumpSellerApp(
      tester,
      const HealthScreen(inputs: [
        HealthScore(input: HealthInput.fulfilment, value: 0.96, target: 0.95, score: 96),
        HealthScore(input: HealthInput.cancellations, value: 0.08, target: 0.05, score: 70),
        HealthScore(input: HealthInput.rating, value: 4.5, target: 4.0, score: 90),
      ]),
      size: const Size(390, 1300),
    );
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'health');
  });
}
