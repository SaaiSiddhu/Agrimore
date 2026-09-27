import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';

// ADMR-31: the canonical low-stock definition, relocated here from
// apps/seller so the admin app can share it instead of reimplementing a
// cruder version — which is precisely how this phase's own finding (a
// third, independently-drifted low-stock check in the admin dashboard)
// came to exist.
ProductModel _product({
  int stock = 20,
  List<ProductVariant> variants = const [],
  int? lowStockThreshold,
  bool isDraft = false,
  bool isActive = true,
}) =>
    ProductModel(
      id: 'p1',
      name: 'Test Product',
      description: 'd',
      salePrice: 100,
      categoryId: 'c1',
      images: const [],
      stock: stock,
      variants: variants,
      lowStockThreshold: lowStockThreshold,
      isDraft: isDraft,
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

ProductVariant _variant({required int stock}) => ProductVariant(
      id: 'v1',
      name: 'Variant',
      salePrice: 100,
      stock: stock,
      options: const {},
    );

void main() {
  group('isLowStock', () {
    test('a healthy base stock, no variants, is not low', () {
      expect(isLowStock(_product(stock: 50)), isFalse);
    });

    test('base stock at or below the default threshold is low', () {
      expect(isLowStock(_product(stock: 10)), isTrue);
      expect(isLowStock(_product(stock: 3)), isTrue);
    });

    test('zero base stock is out-of-stock, not low — a distinct state', () {
      expect(isLowStock(_product(stock: 0)), isFalse);
    });

    test('ADMR-4 case: healthy base stock but a low variant is still low', () {
      final p = _product(stock: 50, variants: [_variant(stock: 2)]);
      expect(isLowStock(p), isTrue);
    });

    test('healthy base stock and healthy variants is not low', () {
      final p = _product(stock: 50, variants: [_variant(stock: 40)]);
      expect(isLowStock(p), isFalse);
    });

    test('a per-product lowStockThreshold overrides the default', () {
      final p = _product(stock: 15, lowStockThreshold: 20);
      expect(isLowStock(p), isTrue); // 15 <= 20, low under this product's own threshold
      expect(isLowStock(_product(stock: 15)), isFalse); // but not under the default of 10
    });

    test('a draft product is never low, regardless of stock', () {
      expect(isLowStock(_product(stock: 1, isDraft: true)), isFalse);
    });

    test('an inactive product is never low, regardless of stock', () {
      expect(isLowStock(_product(stock: 1, isActive: false)), isFalse);
    });
  });

  group('isOutOfStock (ADMR-32)', () {
    test('a healthy base stock, no variants, is not out of stock', () {
      expect(isOutOfStock(_product(stock: 20)), isFalse);
    });

    test('zero base stock, no variants, is out of stock', () {
      expect(isOutOfStock(_product(stock: 0)), isTrue);
    });

    test('empty base but a variant still has stock is NOT out of stock — '
        'sellable via that variant', () {
      final p = _product(stock: 0, variants: [_variant(stock: 5)]);
      expect(isOutOfStock(p), isFalse);
    });

    test('empty base and every variant also empty IS out of stock', () {
      final p = _product(stock: 0, variants: [_variant(stock: 0), _variant(stock: 0)]);
      expect(isOutOfStock(p), isTrue);
    });

    test('a healthy base with an empty variant is not out of stock — '
        'mirrors isLowStock\'s own base-OR-variant semantics', () {
      final p = _product(stock: 50, variants: [_variant(stock: 0)]);
      expect(isOutOfStock(p), isFalse);
    });
  });
}
