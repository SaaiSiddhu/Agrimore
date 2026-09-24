import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/screens/payments/payments_screen.dart';

/// SELLER-MONEY-1: the seller sees what they are owed and what was paid,
/// computed from `seller_payouts` rows exactly as the server writes them.
final DateTime _now = DateTime(2026, 9, 23, 12);

PayoutEntry _e(String id, double net, String status, {int daysAgo = 1, String? ref}) => PayoutEntry(
      id: id,
      orderNumber: 'ORD-$id',
      gross: net + 10,
      commission: 10,
      net: net,
      status: status,
      createdAt: _now.subtract(Duration(days: daysAgo)),
      paidAt: status == 'paid' ? _now.subtract(Duration(days: daysAgo)) : null,
      reference: ref,
    );

Future<AppLocalizations> _pump(WidgetTester tester, Widget child, {Brightness b = Brightness.light}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MaterialApp(
    theme: (b == Brightness.dark ? SellerTheme.dark : SellerTheme.light),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) {
      l10n = AppLocalizations.of(context);
      return child;
    }),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  group('PayoutSummary', () {
    test('pending, paid in the last 30 days and all-time are separate totals', () {
      final s = PayoutSummary.of([
        _e('1', 100, 'pending'),
        _e('2', 50, 'pending'),
        _e('3', 200, 'paid', daysAgo: 5),
        _e('4', 300, 'paid', daysAgo: 45),
      ], _now);
      expect(s.pending, 150);
      expect(s.paid30d, 200);
      expect(s.paidAll, 500);
    });

    test('an unknown status is neither pending nor paid', () {
      final s = PayoutSummary.of([_e('1', 100, 'on_hold')], _now);
      expect(s.pending, 0);
      expect(s.paidAll, 0);
    });

    test('fromMap reads the server fields and falls back to the amount alias', () {
      final e = PayoutEntry.fromMap('o1_s1', {
        'orderId': 'o1',
        'grossAmount': 500,
        'commissionAmount': 50,
        'amount': 450,
        'status': 'paid',
        'paymentReference': 'UTR123456',
        'createdAt': Timestamp.fromDate(_now),
      });
      expect(e.orderNumber, 'o1');
      expect(e.net, 450);
      expect(e.isPaid, isTrue);
      expect(e.reference, 'UTR123456');
      expect(e.createdAt, _now);
    });
  });

  testWidgets('payments shows totals, the masked bank account and each settlement', (tester) async {
    final l10n = await _pump(
      tester,
      PaymentsScreen(
        entries: [_e('1', 450, 'pending'), _e('2', 200, 'paid', ref: 'UTR1234')],
        payoutDetails: const {'payoutMethod': 'bank', 'bankName': 'SBI', 'accountNumber': '123456789012'},
      ),
    );
    expect(find.text(l10n.paymentsTitle), findsOneWidget);
    expect(find.text(SellerFormat.moneyWhole(450)), findsWidgets);
    expect(find.text(l10n.payoutAccountBank('SBI', SellerFormat.maskAccount('123456789012'))), findsOneWidget);
    expect(find.textContaining('123456789012'), findsNothing);
    expect(find.text(l10n.paymentsForOrder('ORD-1')), findsOneWidget);
    expect(find.text(l10n.payoutPending), findsOneWidget);
    expect(find.text(l10n.payoutPaid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history and missing payout account explain what to do (dark)', (tester) async {
    final l10n = await _pump(tester, const PaymentsScreen(entries: []), b: Brightness.dark);
    expect(find.text(l10n.paymentsEmptyTitle), findsWidgets);
    expect(find.text(l10n.payoutAccountMissing), findsOneWidget);
    expect(find.text(l10n.payoutAccountMissingHelp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a settlement opens its breakdown with the payment reference', (tester) async {
    final l10n = await _pump(
      tester,
      PaymentsScreen(entries: [_e('2', 200, 'paid', ref: 'UTR1234')], payoutDetails: const {'payoutMethod': 'upi', 'upiId': 'ravi@upi'}),
    );
    expect(find.text(l10n.payoutAccountUpi(SellerFormat.maskUpi('ravi@upi'))), findsOneWidget);
    expect(find.textContaining('ravi@upi'), findsNothing);
    await tester.tap(find.text(l10n.paymentsForOrder('ORD-2')));
    await tester.pumpAndSettle();
    expect(find.byType(SettlementDetailScreen), findsOneWidget);
    expect(find.text(l10n.settlementNet), findsOneWidget);
    expect(find.text(SellerFormat.money(210)), findsWidgets);
    expect(find.text(SellerFormat.money(-10)), findsOneWidget);
    expect(find.text('UTR1234'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending settlement shows no reference', (tester) async {
    final l10n = await _pump(tester, SettlementDetailScreen(entry: _e('1', 450, 'pending')));
    expect(find.text(l10n.settlementReference), findsNothing);
    expect(find.text(l10n.settlementPaymentPending), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
