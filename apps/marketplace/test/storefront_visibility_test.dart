import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  test('paused store follows the server rule', () {
    final now = DateTime(2026, 9, 23);
    expect(isStorePaused({'acceptingOrders': false}, now), isTrue);
    expect(isStorePaused({'acceptingOrders': false, 'pausedUntil': Timestamp.fromDate(now.add(const Duration(days: 1)))}, now), isTrue);
    expect(isStorePaused({'acceptingOrders': false, 'pausedUntil': Timestamp.fromDate(now.subtract(const Duration(days: 1)))}, now), isFalse);
    expect(isStorePaused({}, now), isFalse);
    expect(isStorePaused(null, now), isFalse);
  });

  test('highlights: at most three, trimmed, no blanks', () {
    expect(storefrontHighlights({'highlights': [' a ', '', 1, 'b', 'c', 'd']}), ['a', 'b', 'c']);
    expect(storefrontHighlights(null), isEmpty);
  });
}
