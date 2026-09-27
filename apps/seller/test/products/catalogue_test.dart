import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/products/seller_products_screen.dart';
import 'package:seller/screens/products/widgets/product_tax_section.dart';

/// SELLER-CATALOGUE-1: listing tabs, tax fields and draft semantics.
ProductModel _p({
  bool isActive = true,
  bool isDraft = false,
  int stock = 5,
  String? hsn,
  double? gst,
  List<ProductVariant> variants = const [],
}) =>
    ProductModel(
      id: 'p',
      name: 'Tomato',
      description: 'Fresh',
      salePrice: 40,
      categoryId: 'veg',
      images: const [],
      stock: stock,
      variants: variants,
      sellerId: 's1',
      isActive: isActive,
      isDraft: isDraft,
      hsnCode: hsn,
      gstRate: gst,
      createdAt: DateTime(2026, 9, 23),
      updatedAt: DateTime(2026, 9, 23),
    );

/// ADMR-4: a minimal variant fixture — only `stock` varies across tests.
ProductVariant _variant(String id, int stock) => ProductVariant(
      id: id,
      name: id,
      salePrice: 40,
      stock: stock,
      options: const {},
    );

void main() {
  group('listing tabs (matchesFilter)', () {
    bool m(ProductModel p, ProductListFilter f) => SellerProductProvider.matchesFilter(p, f);

    test('a live product with stock is Active only', () {
      final p = _p();
      expect(m(p, ProductListFilter.active), isTrue);
      expect(m(p, ProductListFilter.outOfStock), isFalse);
      expect(m(p, ProductListFilter.inactive), isFalse);
      expect(m(p, ProductListFilter.draft), isFalse);
      expect(m(p, ProductListFilter.all), isTrue);
    });
    test('a live product without stock is Out of stock, not Active', () {
      final p = _p(stock: 0);
      expect(m(p, ProductListFilter.outOfStock), isTrue);
      expect(m(p, ProductListFilter.active), isFalse);
    });
    test('a hidden product is Inactive', () {
      expect(m(_p(isActive: false), ProductListFilter.inactive), isTrue);
    });
    test('a draft is only a Draft, whatever its stock', () {
      final d = _p(isActive: false, isDraft: true, stock: 0);
      expect(m(d, ProductListFilter.draft), isTrue);
      expect(m(d, ProductListFilter.inactive), isFalse);
      expect(m(d, ProductListFilter.outOfStock), isFalse);
      expect(m(d, ProductListFilter.active), isFalse);
    });
    test('every product falls in exactly one status tab', () {
      // Status tabs partition the catalogue; Low stock (SELLER-OPS-1) is a
      // lens over live stock, checked separately below.
      const status = {ProductListFilter.active, ProductListFilter.draft, ProductListFilter.outOfStock, ProductListFilter.inactive};
      for (final p in [_p(), _p(stock: 0), _p(isActive: false), _p(isActive: false, isDraft: true)]) {
        final tabs = status.where((f) => m(p, f));
        expect(tabs.length, 1, reason: '$p');
      }
    });

    test('low stock is live stock at or under the product alert level', () {
      expect(m(_p(stock: 3), ProductListFilter.lowStock), isTrue);
      expect(m(_p(stock: 3), ProductListFilter.active), isTrue);
      expect(m(_p(stock: 50), ProductListFilter.lowStock), isFalse);
      expect(m(_p(stock: 0), ProductListFilter.lowStock), isFalse);
      expect(m(_p(stock: 3, isActive: false), ProductListFilter.lowStock), isFalse);
    });

    // ADMR-4: isLowStock previously read only the base `stock` field, so a
    // product whose stock lives entirely in its variants never matched this
    // filter, however low any variant actually was.
    test('low stock is true when a VARIANT is low, even if base stock is not', () {
      final p = _p(stock: 50, variants: [_variant('v1', 40), _variant('v2', 2)]);
      expect(m(p, ProductListFilter.lowStock), isTrue);
    });
    test('low stock is false when neither base nor any variant is low', () {
      final p = _p(stock: 50, variants: [_variant('v1', 40), _variant('v2', 30)]);
      expect(m(p, ProductListFilter.lowStock), isFalse);
    });
    test('a variant at exactly zero does not count as low (matches the base-stock semantics above)', () {
      final p = _p(stock: 50, variants: [_variant('v1', 0)]);
      expect(m(p, ProductListFilter.lowStock), isFalse);
    });
    test('an inactive product with a low variant is still not low stock', () {
      final p = _p(stock: 50, isActive: false, variants: [_variant('v1', 2)]);
      expect(m(p, ProductListFilter.lowStock), isFalse);
    });

    // ADMR-32: the symmetric out-of-stock gap — active/outOfStock previously
    // read only the base `stock` field too, so a product sellable purely via
    // a variant (base at 0) was wrongly filed as Out of Stock, not Active.
    test('Active when the base is empty but a variant still has stock', () {
      final p = _p(stock: 0, variants: [_variant('v1', 5)]);
      expect(m(p, ProductListFilter.active), isTrue);
      expect(m(p, ProductListFilter.outOfStock), isFalse);
    });
    test('Out of Stock only when the base AND every variant are empty', () {
      final p = _p(stock: 0, variants: [_variant('v1', 0), _variant('v2', 0)]);
      expect(m(p, ProductListFilter.outOfStock), isTrue);
      expect(m(p, ProductListFilter.active), isFalse);
    });
    test('a healthy base with an empty variant is still Active (mirrors the low-stock case above)', () {
      final p = _p(stock: 50, variants: [_variant('v1', 0)]);
      expect(m(p, ProductListFilter.active), isTrue);
      expect(m(p, ProductListFilter.outOfStock), isFalse);
    });
  });

  group('productStockBadge (ADMR-32)', () {
    late AppLocalizations l10n;
    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    SellerTone tone(ProductModel p) => (productStockBadge(l10n, p) as SellerStatusBadge).tone;

    test('a product sellable only via a variant (base empty) is not danger-toned', () {
      final p = _p(stock: 0, variants: [_variant('v1', 40)]);
      expect(tone(p), isNot(SellerTone.danger));
    });
    test('a product truly out of stock everywhere is danger-toned', () {
      final p = _p(stock: 0, variants: [_variant('v1', 0)]);
      expect(tone(p), SellerTone.danger);
    });
    test('a healthy base with a low variant is warning-toned, not success', () {
      final p = _p(stock: 50, variants: [_variant('v1', 2)]);
      expect(tone(p), SellerTone.warning);
    });
  });

  group('ProductModel tax + draft fields', () {
    test('round-trip through toMap / fromMap', () {
      final original = _p(isActive: false, isDraft: true, hsn: '0702', gst: 5);
      final back = ProductModel.fromMap(original.toMap(), 'p');
      expect(back.hsnCode, '0702');
      expect(back.gstRate, 5);
      expect(back.isDraft, isTrue);
      expect(back.isActive, isFalse);
    });
    test('an empty HSN reads back as not declared', () {
      final map = _p().toMap()..['hsnCode'] = '  ';
      expect(ProductModel.fromMap(map, 'p').hsnCode, isNull);
    });
    test('legacy documents without the fields default safely', () {
      final map = _p().toMap()
        ..remove('hsnCode')
        ..remove('gstRate')
        ..remove('isDraft');
      final p = ProductModel.fromMap(map, 'p');
      expect(p.hsnCode, isNull);
      expect(p.gstRate, isNull);
      expect(p.isDraft, isFalse);
    });
    test('copyWith keeps and changes the new fields', () {
      final p = _p(hsn: '0702', gst: 5).copyWith(isDraft: true);
      expect(p.isDraft, isTrue);
      expect(p.hsnCode, '0702');
      expect(p.copyWith(gstRate: 12).gstRate, 12);
    });
  });

  group('HSN / GST section', () {
    test('HSN codes are 4, 6 or 8 digits', () {
      for (final ok in ['0702', '070200', '07020000']) {
        expect(kHsnPattern.hasMatch(ok), isTrue, reason: ok);
      }
      for (final bad in ['07', '07020', '0702000', 'ABCD', '070200001']) {
        expect(kHsnPattern.hasMatch(bad), isFalse, reason: bad);
      }
    });
    test('GST slabs', () => expect(kGstRates, [0, 5, 12, 18, 28]));

    testWidgets('renders, validates a bad HSN, and offers "not declared"', (tester) async {
      final hsn = TextEditingController();
      final form = GlobalKey<FormState>();
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
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
          return Scaffold(
            body: Form(
              key: form,
              child: ProductTaxSection(hsnController: hsn, gstRate: null, onGstRateChanged: (_) {}),
            ),
          );
        }),
      ));
      expect(find.text(l10n.gstNotDeclared), findsOneWidget);
      hsn.text = '12345';
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text(l10n.errHsn), findsOneWidget);
      hsn.text = '';
      expect(form.currentState!.validate(), isTrue, reason: 'HSN is optional');
      expect(tester.takeException(), isNull);
    });
  });
}
