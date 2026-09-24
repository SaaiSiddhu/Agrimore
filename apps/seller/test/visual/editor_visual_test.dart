import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/home/add_product_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  for (final (name, b, editing) in [
    ('editor_new_light', Brightness.light, false),
    ('editor_edit_dark', Brightness.dark, true),
  ]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(
        tester,
        AddProductScreen(existingProduct: editing ? fixtureProduct('p', stock: 25) : null),
        brightness: b,
        size: const Size(390, 1500),
      );
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
  testWidgets('editor_wholesale_on', (tester) async {
    final l10n = await pumpSellerApp(tester, AddProductScreen(existingProduct: fixtureProduct('p')), size: const Size(390, 1000));
    await tester.ensureVisible(find.text(l10n.editorWholesale));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorWholesale));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'editor_wholesale_on');
  });
}
