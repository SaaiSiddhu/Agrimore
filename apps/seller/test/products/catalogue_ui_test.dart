import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/products/seller_products_screen.dart';

/// SELLER-UI-1c: the catalogue shows stock levels with the right tone and
/// asks before deleting.
ProductModel _p(String id, {int stock = 20, bool active = true, bool draft = false}) => ProductModel.fromMap({
      'name': 'Product $id',
      'categoryId': 'c',
      'salePrice': 120,
      'originalPrice': 150,
      'sellerId': 's',
      'stock': stock,
      'isActive': active,
      'isDraft': draft,
    }, id);

Future<AppLocalizations> _pump(WidgetTester tester, List<ProductModel> products) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
      ChangeNotifierProvider<SellerProductProvider>(create: (_) => SellerProductProvider.preview(products)),
    ],
    child: MaterialApp(
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
        return const SellerProductsScreen();
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  testWidgets('stock levels, prices and an empty catalogue', (tester) async {
    final l10n = await _pump(tester, [_p('1'), _p('2', stock: 0), _p('3', stock: 4)]);
    expect(find.text(l10n.searchStock(AgFormat.count(20))), findsOneWidget);
    expect(find.text(l10n.productOutOfStock), findsOneWidget);
    expect(find.text(l10n.productLowStock(AgFormat.count(4))), findsOneWidget);
    expect(find.text(AgFormat.rupees(150)), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty catalogue says what to do', (tester) async {
    final l10n = await _pump(tester, const []);
    expect(find.text(l10n.productsEmpty), findsOneWidget);
    expect(find.text(l10n.homeAddProduct), findsOneWidget);
  });

  testWidgets('delete asks first; cancelling keeps the product', (tester) async {
    final l10n = await _pump(tester, [_p('1')]);
    await tester.tap(find.text(l10n.productDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.productDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('stock sheet rejects an empty value', (tester) async {
    final l10n = await _pump(tester, [_p('1')]);
    await tester.tap(find.text(l10n.productStock));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('stockValue')), '');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pump();
    expect(find.text(l10n.counterQtyInvalid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
