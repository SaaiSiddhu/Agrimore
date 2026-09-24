import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/payments/payments_screen.dart';
import 'package:seller/screens/payments/wallet.dart';

import '../support/fake_wallet.dart';
import '../support/seller_fixtures.dart';

/// SELLER-WALLET-1: the wallet on Payments — balance, Withdraw, the open
/// withdrawal, the payout account (add / change / pending) and history.
const _bank = {'payoutMethod': 'bank', 'bankName': 'Example Bank', 'accountNumber': '123456784821'};

Future<void> _open(WidgetTester tester, FakeWalletSource w, {Map<String, dynamic>? details = _bank, double textScale = 1}) async {
  await pumpSellerApp(tester, PaymentsScreen(entries: const [], payoutDetails: details, wallet: w), size: const Size(390, 1400), textScale: textScale);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('withdraw asks first, then requests the whole balance once', (tester) async {
    final w = FakeWalletSource();
    await _open(tester, w);
    expect(find.text('Wallet balance'), findsOneWidget);
    await tester.tap(find.text('Withdraw ₹3,840'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw ₹3,840?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print(find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList());
    expect(w.withdrawn, hasLength(1));
    expect(w.withdrawn.single.length, 20);
    expect(find.text('Withdrawal requested'), findsWidgets);
    expect(find.text('Cancel withdrawal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the confirmation withdraws nothing', (tester) async {
    final w = FakeWalletSource();
    await _open(tester, w);
    await tester.tap(find.text('Withdraw ₹3,840'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(w.withdrawn, isEmpty);
  });

  testWidgets('below the minimum: says so and Withdraw is off', (tester) async {
    final w = FakeWalletSource(balance: const WalletSummary(available: 40, held: 0, minimum: 100, holdDays: 0, hasDestination: true));
    await _open(tester, w);
    expect(find.text('Minimum withdrawal is ₹100.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Withdraw'));
    expect(button.onPressed, isNull);
  });

  testWidgets('no account: explains and offers Add', (tester) async {
    final w = FakeWalletSource(balance: const WalletSummary(available: 500, held: 0, minimum: 100, holdDays: 0, hasDestination: false));
    await _open(tester, w, details: null);
    expect(find.text('Add a bank account or UPI ID to withdraw.'), findsOneWidget);
    expect(find.text('Add bank account or UPI'), findsOneWidget);
  });

  testWidgets('a pending change blocks Withdraw and can be cancelled', (tester) async {
    final w = FakeWalletSource(
      balance: const WalletSummary(available: 500, held: 0, minimum: 100, holdDays: 0, hasDestination: true, payoutChangePendingId: 'c1'),
      change: const PayoutChange(id: 'c1', details: {'payoutMethod': 'upi', 'upiId': 'kaveri@okbank'}),
    );
    await _open(tester, w);
    expect(find.text('You can withdraw once your new bank/UPI details are verified.'), findsOneWidget);
    expect(find.text('New details waiting for review'), findsOneWidget);
    expect(find.text('Change'), findsNothing, reason: 'one change at a time');
    await tester.tap(find.text('Cancel change'));
    await tester.pumpAndSettle();
    expect(w.cancelled, ['c1']);
  });

  testWidgets('history shows each withdrawal with its status and reference', (tester) async {
    final w = FakeWalletSource(history: [
      SellerWithdrawal(id: 'a', amount: 1200, status: 'paid', orderCount: 4, reference: 'UTR998877',
          destination: const {'method': 'upi', 'upiId': 'kaveri@okbank'}, paidAt: DateTime(2026, 9, 20)),
      SellerWithdrawal(id: 'b', amount: 300, status: 'rejected', orderCount: 1, reason: 'Name does not match',
          destination: const {'method': 'bank', 'bankName': 'Example Bank', 'accountLast4': '4821'}, createdAt: DateTime(2026, 9, 18)),
    ]);
    await _open(tester, w);
    expect(find.text('Withdrawals'), findsOneWidget);
    expect(find.textContaining('Ref UTR998877'), findsOneWidget);
    expect(find.textContaining('Reason: Name does not match'), findsOneWidget);
    expect(find.text('Not paid'), findsOneWidget);
  });

  testWidgets('a server refusal is said in plain words', (tester) async {
    final w = FakeWalletSource(refuseWith: 'withdrawal_open');
    await _open(tester, w);
    await tester.tap(find.text('Withdraw ₹3,840'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('A withdrawal is already waiting to be paid.'), findsOneWidget);
  });

  testWidgets('works at 200% text without overflow', (tester) async {
    await _open(tester, FakeWalletSource(), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  group('payout account form', () {
    Future<void> openForm(WidgetTester tester, FakeWalletSource w) async {
      await pumpSellerApp(tester, PayoutAccountScreen(source: w, changing: true), size: const Size(390, 1200));
      await tester.pumpAndSettle();
    }

    testWidgets('bank: checks every field before sending', (tester) async {
      final w = FakeWalletSource();
      await openForm(tester, w);
      await tester.tap(find.text('Send for verification'));
      await tester.pumpAndSettle();
      expect(w.requested, isEmpty);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Kaveri');
      await tester.enterText(fields.at(1), 'Example Bank');
      await tester.enterText(fields.at(2), '123456784821');
      await tester.enterText(fields.at(3), '123456784820');
      await tester.enterText(fields.at(4), 'EXMP0001234');
      await tester.tap(find.text('Send for verification'));
      await tester.pumpAndSettle();
      expect(w.requested, isEmpty, reason: 'account numbers differ');
      await tester.enterText(fields.at(3), '123456784821');
      await tester.tap(find.text('Send for verification'));
      await tester.pumpAndSettle();
      expect(w.requested.single, {
        'payoutMethod': 'bank', 'accountHolder': 'Kaveri', 'bankName': 'Example Bank', 'accountNumber': '123456784821', 'ifsc': 'EXMP0001234',
      });
    });

    testWidgets('UPI: only the UPI id (and optional name) is sent', (tester) async {
      final w = FakeWalletSource();
      await openForm(tester, w);
      await tester.tap(find.text('UPI ID').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'kaveri@okbank');
      await tester.tap(find.text('Send for verification'));
      await tester.pumpAndSettle();
      expect(w.requested.single, {'payoutMethod': 'upi', 'upiId': 'kaveri@okbank'});
    });
  });
}
