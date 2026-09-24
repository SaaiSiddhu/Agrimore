import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/payments/payments_screen.dart';
import 'package:seller/screens/payments/wallet.dart';

import '../support/fake_wallet.dart';
import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

/// SELLER-WALLET-1 renders: wallet, open withdrawal + history, pending change, form.
void main() {
  setUpAll(loadSellerFonts);
  final now = DateTime(2026, 9, 24);
  final entries = [
    PayoutEntry(id: 'a', orderNumber: '1042', gross: 580, commission: 29, net: 551, status: 'requested', createdAt: now),
    PayoutEntry(id: 'b', orderNumber: '1041', gross: 320, commission: 16, net: 304, status: 'paid', createdAt: now, paidAt: now, reference: 'UTR998877'),
  ];
  const bank = {'payoutMethod': 'bank', 'bankName': 'Example Bank', 'accountNumber': '123456784821'};
  final history = [
    SellerWithdrawal(id: 'w2', amount: 551, status: 'requested', orderCount: 1, createdAt: now,
        destination: const {'method': 'bank', 'bankName': 'Example Bank', 'accountLast4': '4821'}),
    SellerWithdrawal(id: 'w1', amount: 1204, status: 'paid', orderCount: 4, reference: 'UTR998877', paidAt: now.subtract(const Duration(days: 6)),
        destination: const {'method': 'bank', 'bankName': 'Example Bank', 'accountLast4': '4821'}),
  ];
  final cases = <(String, Widget, Brightness)>[
    ('wallet_light', PaymentsScreen(entries: entries, payoutDetails: bank, wallet: FakeWalletSource()), Brightness.light),
    ('wallet_dark', PaymentsScreen(entries: entries, payoutDetails: bank, wallet: FakeWalletSource()), Brightness.dark),
    (
      'wallet_open_history',
      PaymentsScreen(
        entries: entries,
        payoutDetails: bank,
        wallet: FakeWalletSource(
          balance: const WalletSummary(available: 0, held: 0, minimum: 100, holdDays: 0, hasDestination: true, openWithdrawalId: 'w2'),
          history: history,
        ),
      ),
      Brightness.light,
    ),
    (
      'wallet_change_pending',
      PaymentsScreen(
        entries: entries,
        payoutDetails: bank,
        wallet: FakeWalletSource(
          balance: const WalletSummary(available: 820, held: 0, minimum: 100, holdDays: 0, hasDestination: true, payoutChangePendingId: 'c1'),
          change: const PayoutChange(id: 'c1', details: {'payoutMethod': 'upi', 'upiId': 'kaveri@okbank'}),
        ),
      ),
      Brightness.light,
    ),
    (
      'wallet_no_account',
      PaymentsScreen(
        entries: const [],
        wallet: FakeWalletSource(balance: const WalletSummary(available: 551, held: 0, minimum: 100, holdDays: 0, hasDestination: false)),
      ),
      Brightness.light,
    ),
    ('payout_form', PayoutAccountScreen(source: FakeWalletSource(), changing: true), Brightness.light),
  ];
  for (final (name, screen, b) in cases) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, screen, brightness: b, size: const Size(390, 1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
}
