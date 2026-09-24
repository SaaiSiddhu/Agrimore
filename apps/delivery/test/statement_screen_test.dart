// DLV-M1 — the statement screen at phone width: amounts, the stage (a made
// statement is not money sent), the paid destination, and paging.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/screens/money/statement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester t, RiderPayout p, StatementLoader load) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatementScreen(payout: p, load: load),
    ));
    await t.pumpAndSettle();
  }

  RiderPayout payout(Map<String, dynamic> m) => RiderPayout.fromMap('r_2026-W39', {
        'weekKey': '2026-W39', 'orderCount': 51, 'earnedPaise': 160000, 'nettedPaise': 40000, 'amountPaise': 120000,
        'cashHeldAfterPaise': 0, ...m,
      });
  List<RiderEarning> lines(int n, int from) =>
      [for (var i = from; i < from + n; i++) RiderEarning(orderId: 'o$i', orderNumber: 'ORD-$i', total: 31.37, basePay: 25)];

  testWidgets('a made statement is not money sent; lines page', (t) async {
    var calls = 0;
    await pump(t, payout({'status': 'pending'}), (after) async {
      calls++;
      return calls == 1 ? StatementPage(lines(50, 0), null, true) : StatementPage(lines(1, 50), null, false);
    });
    expect(t.takeException(), isNull);
    expect(find.text('To be sent to you'), findsOneWidget);
    expect(find.textContaining('will send the money'), findsOneWidget);
    expect(find.text('− ₹400.00'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Load more'), 400);
    await t.tap(find.text('Load more'));
    await t.pumpAndSettle();
    expect(calls, 2);
    await t.scrollUntilVisible(find.text('Order #ORD-50'), 400);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a paid statement shows the reference and where it went', (t) async {
    await pump(
        t,
        payout({'status': 'paid', 'paymentReference': 'UTR777777', 'paidTo': {'method': 'bank', 'accountLast4': '7777'}}),
        (after) async => const StatementPage([], null, false));
    expect(t.takeException(), isNull);
    expect(find.text('Sent to you'), findsOneWidget);
    expect(find.text('Money sent · Ref UTR777777'), findsOneWidget);
    expect(find.text('Sent to bank account ending 7777'), findsOneWidget);
    expect(find.text('No deliveries in this statement.'), findsOneWidget);
  });

  testWidgets('a failed page offers retry', (t) async {
    var fail = true;
    await pump(t, payout({'status': 'pending'}), (after) async {
      if (fail) throw StateError('offline');
      return StatementPage(lines(2, 0), null, false);
    });
    expect(find.text('Could not load the deliveries. Check your connection.'), findsOneWidget);
    fail = false;
    await t.scrollUntilVisible(find.text('Try again'), 400);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Order #ORD-1'), findsOneWidget);
  });
}
