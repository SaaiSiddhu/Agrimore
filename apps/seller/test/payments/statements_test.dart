import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/screens/payments/payments_screen.dart';
import 'package:seller/screens/payments/statements.dart';

/// SELLER-POLISH-1 (gap 30): monthly settlement statements.
PayoutEntry _e(String id, double net, String status, DateTime? at) => PayoutEntry(
      id: id,
      orderNumber: 'ORD-$id',
      gross: net + 10,
      commission: 10,
      net: net,
      status: status,
      createdAt: at,
      reference: status == 'paid' ? 'UTR$id' : null,
    );

void main() {
  final entries = [
    _e('a', 100, 'paid', DateTime(2026, 9, 3)),
    _e('b', 50, 'pending', DateTime(2026, 9, 20)),
    _e('c', 70, 'paid', DateTime(2026, 8, 31)),
    _e('d', 5, 'paid', null),
  ];

  test('groups by month, newest first, with totals; undated left out', () {
    final s = MonthlyStatement.of(entries);
    expect(s.map((m) => m.month), [DateTime(2026, 9), DateTime(2026, 8)]);
    expect(s.first.net, 150);
    expect(s.first.gross, 170);
    expect(s.first.commission, 20);
    expect(s.first.paid, 100);
    expect(s.first.pending, 50);
    expect(s.last.entries.single.id, 'c');
  });

  testWidgets('Payments lists months; a month opens its statement', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return PaymentsScreen(entries: entries);
      }),
    ));
    await tester.pump();
    final month = find.text(AgFormat.monthYear(DateTime(2026, 9)));
    await tester.scrollUntilVisible(month, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(l10n.statementsTitle), findsOneWidget);
    await tester.tap(month);
    await tester.pumpAndSettle();
    expect(find.text(l10n.statementHeading(AgFormat.monthYear(DateTime(2026, 9)))), findsOneWidget);
    expect(find.text(l10n.paymentsForOrder('ORD-a')), findsOneWidget);
    expect(find.text(l10n.paymentsForOrder('ORD-c')), findsNothing);
  });
}
