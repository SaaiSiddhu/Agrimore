import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/products/widgets/product_tax_section.dart';

/// SELLER-CATALOGUE-1: listing tabs, tax fields and draft semantics.
ProductModel _p({bool isActive = true, bool isDraft = false, int stock = 5, String? hsn, double? gst}) =>
    ProductModel(
      id: 'p',
      name: 'Tomato',
      description: 'Fresh',
      salePrice: 40,
      categoryId: 'veg',
      images: const [],
      stock: stock,
      sellerId: 's1',
      isActive: isActive,
      isDraft: isDraft,
      hsnCode: hsn,
      gstRate: gst,
      createdAt: DateTime(2026, 9, 23),
      updatedAt: DateTime(2026, 9, 23),
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
    test('every product falls in exactly one non-All tab', () {
      for (final p in [_p(), _p(stock: 0), _p(isActive: false), _p(isActive: false, isDraft: true)]) {
        final tabs = ProductListFilter.values.where((f) => f != ProductListFilter.all && m(p, f));
        expect(tabs.length, 1, reason: '$p');
      }
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
