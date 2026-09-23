import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_marketplace/screens/business/storefront_visibility.dart';

/// SELLER-STOREFRONT-EDIT-1: a buyer never sees a hidden or draft product on
/// a seller's storefront; legacy products without `isActive` stay visible.
void main() {
  ProductModel p(Map<String, dynamic> extra) =>
      ProductModel.fromMap({'name': 'Rice', 'categoryId': 'c', 'salePrice': 10, 'sellerId': 's', ...extra}, 'p');

  test('active products are visible', () {
    expect(isVisibleOnStorefront(p({'isActive': true})), isTrue);
  });

  test('hidden products are not', () {
    expect(isVisibleOnStorefront(p({'isActive': false})), isFalse);
  });

  test('drafts are not, even if a stale isActive says otherwise', () {
    expect(isVisibleOnStorefront(p({'isActive': true, 'isDraft': true})), isFalse);
  });

  test('legacy products without isActive stay visible (catalogue rule)', () {
    expect(isVisibleOnStorefront(p({})), isTrue);
  });

  test('highlights: at most three, trimmed, no blanks', () {
    expect(storefrontHighlights({'highlights': [' a ', '', 1, 'b', 'c', 'd']}), ['a', 'b', 'c']);
    expect(storefrontHighlights(null), isEmpty);
  });
}
