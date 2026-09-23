import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/screens/products/widgets/product_variants_section.dart';

/// SELLER-CATALOGUE-2: options get a price and stock, names are unique, and
/// an existing option keeps its id when edited (checkout matches by id).
ProductVariant _v(String id, String name, double price, int stock) =>
    ProductVariant(id: id, name: name, salePrice: price, stock: stock, options: const {});

void main() {
  late List<ProductVariant> current;

  Future<AppLocalizations> pump(WidgetTester tester, List<ProductVariant> initial) async {
    current = initial;
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
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          l10n = AppLocalizations.of(context);
          return SingleChildScrollView(
            child: ProductVariantsSection(variants: current, onChanged: (v) => setState(() => current = v)),
          );
        }),
      ),
    ));
    await tester.pump();
    return l10n;
  }

  testWidgets('add an option with price and stock', (tester) async {
    final l10n = await pump(tester, const []);
    await tester.tap(find.text(l10n.variantsAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('variantName')), '5 kg');
    await tester.enterText(find.byKey(const ValueKey('variantPrice')), '450');
    await tester.enterText(find.byKey(const ValueKey('variantStock')), '3');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pumpAndSettle();
    expect(current.single.name, '5 kg');
    expect(current.single.salePrice, 450);
    expect(current.single.stock, 3);
    expect(current.single.id, isNotEmpty);
  });

  testWidgets('duplicate names are refused; editing keeps the id', (tester) async {
    final l10n = await pump(tester, [_v('v1', '1 kg', 100, 10), _v('v5', '5 kg', 450, 3)]);
    await tester.tap(find.text('5 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('variantName')), '1 KG');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pump();
    expect(find.text(l10n.variantsDuplicate), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('variantName')), '5 kg bag');
    await tester.enterText(find.byKey(const ValueKey('variantPrice')), '440');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pumpAndSettle();
    expect(current[1].id, 'v5');
    expect(current[1].name, '5 kg bag');
    expect(current[1].salePrice, 440);
  });

  testWidgets('remove an option', (tester) async {
    final l10n = await pump(tester, [_v('v1', '1 kg', 100, 10)]);
    await tester.tap(find.byTooltip(l10n.variantsRemove('1 kg')));
    await tester.pump();
    expect(current, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
