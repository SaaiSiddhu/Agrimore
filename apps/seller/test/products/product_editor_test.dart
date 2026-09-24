import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/screens/home/add_product_screen.dart';

import '../support/seller_fixtures.dart';

/// Board 18-04 / decision D6: one form, sub-screens that only keep changes
/// on "Apply changes", error summary + focus, discard guard.
void main() {
  testWidgets('publishing an empty form lists the fields and focuses the first', (tester) async {
    final l10n = await pumpSellerApp(tester, const AddProductScreen(), size: const Size(390, 1600));
    await tester.tap(find.text(l10n.editorSave));
    await tester.pumpAndSettle();
    expect(find.byType(SellerFormErrorSummary), findsOneWidget);
    expect(find.text(l10n.editorRequired), findsWidgets);
    expect(FocusManager.instance.primaryFocus?.debugLabel, l10n.editorName);
  });

  testWidgets('leaving a sub-screen without Apply restores the old values', (tester) async {
    final l10n = await pumpSellerApp(tester, const AddProductScreen(), size: const Size(390, 1600));
    await tester.tap(find.text(l10n.editorWholesale));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining(l10n.editorB2bPrice, findRichText: true), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Back on the form: wholesale is still off, so the row shows its hint.
    expect(find.text(l10n.editorWholesaleRowHint), findsOneWidget);

    await tester.tap(find.text(l10n.editorCoverage));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorCoverageRadius));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorApply));
    await tester.pumpAndSettle();
    // No coordinates: Apply refuses and stays on the sub-screen.
    expect(find.text(l10n.editorApply), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsaved changes ask before leaving', (tester) async {
    final l10n = await pumpSellerApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddProductScreen())),
            child: const Text('open'),
          ),
        ),
      ),
      size: const Size(390, 1600),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fresh tomatoes');
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.back));
    await tester.pumpAndSettle();
    expect(find.text(l10n.dsDiscardTitle), findsOneWidget);
    await tester.tap(find.text(l10n.dsKeepEditing));
    await tester.pumpAndSettle();
    expect(find.text('Fresh tomatoes'), findsOneWidget);
  });

  testWidgets('editing shows stock details and the product name', (tester) async {
    final l10n = await pumpSellerApp(tester, AddProductScreen(existingProduct: fixtureProduct('p', stock: 25)), size: const Size(390, 1600));
    expect(find.text(l10n.editorEditTitle), findsOneWidget);
    expect(find.text(l10n.searchStock('25')), findsOneWidget);
    expect(find.text('Fresh tomatoes'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
