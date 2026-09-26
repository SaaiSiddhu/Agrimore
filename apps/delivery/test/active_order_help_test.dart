// DLV-R1 — the active-delivery Help entry point (phase 20 image 07,
// "support-access"). Renders the REAL ActiveOrderScreen and taps the REAL
// AppBar action, closing the exact kind of integration-test gap DLV-Q1 found
// for the delivery-code field: a component can be correct in isolation while
// the screen that wires it up is never exercised at all.
import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

OrderModel _order({required String status}) => OrderModel.fromMap({
      'orderNumber': 'AGM-1042',
      'userId': 'cust-1',
      'userName': 'Meenakshi Sundaram',
      'userPhone': '+91 98421 55120',
      'sellerId': 'sel-1',
      'deliveryPartnerId': 'r-tour',
      'orderStatus': status,
      'status': 'processing',
      'paymentMethod': 'cod',
      'paymentStatus': 'pending',
      'subtotal': 420.0,
      'deliveryFee': 48.0,
      'total': 468.0,
      'deliveryEarning': 54.0,
      'deliveryAddress': {
        'name': 'Meenakshi Sundaram',
        'phone': '+91 98421 55120',
        'addressLine1': '44, West Masi Street',
        'city': 'Madurai',
        'state': 'Tamil Nadu',
        'pincode': '625001',
      },
      'items': [
        {
          'productId': 'p1',
          'productName': 'Organic Tomatoes',
          'price': 210.0,
          'quantity': 2,
          'unit': 'kg',
        },
      ],
    }, 'ord-1042');

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  testWidgets('Help sheet: after pickup shows report-problem and emergency',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ActiveOrderScreen(order: _order(status: 'out_for_delivery')),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip(l.activeHelpTooltip), findsOneWidget);
    await tester.tap(find.byTooltip(l.activeHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.text(l.activeHelpSheetTitle), findsOneWidget);
    expect(find.text(l.activeHelpSheetSubtitle), findsOneWidget);
    expect(find.byKey(const ValueKey('help-report-problem')), findsOneWidget);
    expect(find.byKey(const ValueKey('help-emergency')), findsOneWidget);
    expect(find.text(l.verifyContactSupport), findsOneWidget);
  });

  testWidgets(
      'Help sheet: before pickup hides report-problem but keeps emergency',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ActiveOrderScreen(order: _order(status: 'delivery_accepted')),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip(l.activeHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('help-report-problem')), findsNothing);
    expect(find.byKey(const ValueKey('help-emergency')), findsOneWidget);
  });

  testWidgets('Help sheet: emergency help opens the real EmergencySheet',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ActiveOrderScreen(order: _order(status: 'out_for_delivery')),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip(l.activeHelpTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-emergency')));
    await tester.pumpAndSettle();

    // Unique to EmergencySheet's own body -- not present in _HelpSheet --
    // so this proves the real sheet opened, not just that the menu closed.
    expect(find.textContaining(l.emergencyCallSupport), findsOneWidget);
    expect(find.text(l.activeHelpSheetTitle), findsNothing);
  });

  testWidgets('Help sheet: report a problem opens the real ProblemReportSheet',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ActiveOrderScreen(order: _order(status: 'out_for_delivery')),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip(l.activeHelpTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-report-problem')));
    await tester.pumpAndSettle();

    expect(find.text(l.problemSheetTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('problem-send')), findsOneWidget);
  });

  testWidgets('Help sheet: back to delivery dismisses without side effects',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ActiveOrderScreen(order: _order(status: 'out_for_delivery')),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip(l.activeHelpTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.activeHelpBackToDelivery));
    await tester.pumpAndSettle();

    expect(find.text(l.activeHelpSheetTitle), findsNothing);
    expect(find.text('Order #AGM-1042'), findsOneWidget);
  });
}
