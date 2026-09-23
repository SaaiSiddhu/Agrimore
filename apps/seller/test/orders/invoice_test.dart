import 'dart:io';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/screens/orders/invoice_screen.dart';
import 'package:seller/screens/orders/widgets/order_invoice_card.dart';

/// SELLER-ORDERS-2: the invoice screen renders the server snapshot faithfully
/// for both document types; the app's invoiceable statuses match the server.
Map<String, dynamic> _invoice({required bool tax}) => {
      'invoiceNumber': 'INV/2026-27/000007',
      'docType': tax ? 'tax_invoice' : 'bill_of_supply',
      'orderNumber': 'ORD-42',
      'seller': {'shopName': 'Ravi Stores', 'address': 'Market St', 'gstin': tax ? '33ABCDE1234F1Z5' : null},
      'buyer': {'name': 'Priya', 'address': '4 Lake Rd, Madurai'},
      'lines': [
        {
          'name': 'Rice 5kg', 'quantity': 1, 'unitPrice': 210, 'amount': 210,
          'hsnCode': '1006', 'gstRate': 5, 'taxable': tax ? 200 : 210,
          'cgst': tax ? 5 : 0, 'sgst': tax ? 5 : 0, 'igst': 0,
        },
      ],
      'totals': {'subtotal': 210, 'discount': 0, 'deliveryCharge': 20, 'tax': tax ? 10 : 0, 'total': 230},
    };

Future<AppLocalizations> _pump(WidgetTester tester, Map<String, dynamic> data, {Brightness b = Brightness.light}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MaterialApp(
    theme: WorkspaceTheme.build(WorkspaceBrand.seller, b),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) {
      l10n = AppLocalizations.of(context);
      return InvoiceScreen(invoiceId: 'i1', data: data);
    }),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  testWidgets('tax invoice shows GSTIN, HSN and the CGST/SGST split', (tester) async {
    final l10n = await _pump(tester, _invoice(tax: true));
    expect(find.text(l10n.docTaxInvoice), findsOneWidget);
    expect(find.text('INV/2026-27/000007'), findsOneWidget);
    expect(find.text(l10n.invoiceGstin('33ABCDE1234F1Z5')), findsOneWidget);
    expect(find.text(l10n.invoiceCgst), findsOneWidget);
    expect(find.text(l10n.invoiceSgst), findsOneWidget);
    expect(find.text(l10n.invoiceIgst), findsNothing);
    expect(find.text(AgFormat.rupees(230)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bill of supply shows no tax lines and explains why', (tester) async {
    final l10n = await _pump(tester, _invoice(tax: false), b: Brightness.dark);
    expect(find.text(l10n.docBillOfSupply), findsOneWidget);
    expect(find.text(l10n.billOfSupplyNote), findsOneWidget);
    expect(find.text(l10n.invoiceCgst), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('invoiceable statuses match the server list (sellerInvoice.ts INVOICEABLE)', () {
    final src = File('../../functions/src/seller/sellerInvoice.ts').readAsStringSync();
    final match = RegExp(r'const INVOICEABLE = \[([^\]]+)\]', dotAll: true).firstMatch(src)!;
    final server = RegExp(r'"([a-z_]+)"').allMatches(match.group(1)!).map((m) => m.group(1)).toSet();
    expect(kInvoiceableStatuses, server);
    expect(kInvoiceableStatuses.contains('pending'), isFalse);
    expect(kInvoiceableStatuses.contains('cancelled'), isFalse);
  });
}
