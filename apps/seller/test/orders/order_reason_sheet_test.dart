import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/screens/orders/widgets/order_reason_sheet.dart';

/// SELLER-ORDERS-1: the reject/cancel sheet requires a reason, returns it with
/// the note, states the consequence, and its reason keys match the server.
void main() {
  late AppLocalizations l10n;
  OrderReasonChoice? result;
  bool closed = false;

  Future<void> open(WidgetTester tester, {required bool isCancel, required bool prepaid}) async {
    result = null;
    closed = false;
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
        return Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showOrderReasonSheet(context, isCancel: isCancel, prepaid: prepaid);
              closed = true;
            },
            child: const Text('open'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('reject needs a reason before it can be confirmed', (tester) async {
    await open(tester, isCancel: false, prepaid: false);
    expect(find.text(l10n.rejectOrderTitle), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, l10n.rejectOrderCta);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.text(l10n.reasonOutOfStock));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'Tomatoes finished');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result?.reason, 'out_of_stock');
    expect(result?.note, 'Tomatoes finished');
  });

  testWidgets('cancel copy and the prepaid refund consequence', (tester) async {
    await open(tester, isCancel: true, prepaid: true);
    expect(find.text(l10n.cancelOrderTitle), findsOneWidget);
    expect(find.text(l10n.rejectConsequencePrepaid), findsOneWidget);
  });

  testWidgets('keep order closes without a choice', (tester) async {
    await open(tester, isCancel: false, prepaid: false);
    final keep = find.text(l10n.keepOrder);
    await tester.ensureVisible(keep);
    await tester.tap(keep);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  test('reason keys match the server list (sellerTransitionOrder.ts REJECT_REASONS)', () {
    expect(kOrderReasons, ['out_of_stock', 'cannot_deliver_area', 'price_error', 'shop_closed', 'other']);
  });
}
