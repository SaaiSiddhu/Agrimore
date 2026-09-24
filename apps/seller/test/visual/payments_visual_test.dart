import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/payments/payments_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  final now = DateTime.now();
  final entries = [
    PayoutEntry(id: 'a', orderNumber: '1042', gross: 580, commission: 29, net: 551, status: 'pending', createdAt: now.subtract(const Duration(days: 1))),
    PayoutEntry(id: 'b', orderNumber: '1041', gross: 320, commission: 16, net: 304, status: 'paid',
        createdAt: now.subtract(const Duration(days: 2)), paidAt: now.subtract(const Duration(days: 1)), reference: 'UTR 2026 0923 7781'),
  ];
  const details = {'payoutMethod': 'bank', 'bankName': 'Example Bank', 'accountNumber': '123456784821'};
  for (final (name, b) in [('payments_light', Brightness.light), ('payments_dark', Brightness.dark)]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, PaymentsScreen(entries: entries, payoutDetails: details), brightness: b, size: const Size(390, 1200));
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
  testWidgets('payments_empty', (tester) async {
    await pumpSellerApp(tester, const PaymentsScreen(entries: []), size: const Size(390, 1000));
    await qaCapture(tester, 'payments_empty');
  });
  testWidgets('settlement_paid', (tester) async {
    await pumpSellerApp(tester, SettlementDetailScreen(entry: entries[1]), size: const Size(390, 1100));
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'settlement_paid');
  });
}
