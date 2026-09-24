import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/products/seller_products_screen.dart';

/// SELLER-CATALOGUE-3 (gap 17): catalogue sort.
ProductModel _p(String name, double price, int stock, int day) => ProductModel(
      id: name,
      name: name,
      description: '',
      salePrice: price,
      categoryId: 'c',
      images: const [],
      stock: stock,
      sellerId: 's',
      createdAt: DateTime(2026, 9, day),
      updatedAt: DateTime(2026, 9, day),
    );

void main() {
  final products = [_p('banana', 40, 9, 3), _p('Apple', 120, 2, 1), _p('carrot', 30, 50, 2)];
  List<String> sorted(ProductSort s) =>
      ([...products]..sort((a, b) => SellerProductProvider.compareBy(s, a, b))).map((p) => p.name).toList();

  test('each order', () {
    expect(sorted(ProductSort.newest), ['banana', 'carrot', 'Apple']);
    expect(sorted(ProductSort.nameAz), ['Apple', 'banana', 'carrot']);
    expect(sorted(ProductSort.priceLow), ['carrot', 'banana', 'Apple']);
    expect(sorted(ProductSort.priceHigh), ['Apple', 'banana', 'carrot']);
    expect(sorted(ProductSort.stockLow), ['Apple', 'banana', 'carrot']);
  });

  test('ties fall back to newest', () {
    final tie = [_p('old', 10, 1, 1), _p('new', 10, 1, 5)]..sort((a, b) => SellerProductProvider.compareBy(ProductSort.priceLow, a, b));
    expect(tie.map((p) => p.name), ['new', 'old']);
  });

  testWidgets('the Sort menu reorders the list', (tester) async {
    late AppLocalizations l10n;
    tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
        ChangeNotifierProvider<SellerProductProvider>(create: (_) => SellerProductProvider.preview(products)),
      ],
      child: MaterialApp(
        theme: SellerTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SellerProductsScreen();
        }),
      ),
    ));
    await tester.pump();
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('banana') < y('Apple'), isTrue);

    await tester.tap(find.byTooltip(l10n.sortTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sortNameAz));
    await tester.pumpAndSettle();
    expect(y('Apple') < y('banana') && y('banana') < y('carrot'), isTrue);
  });
}
