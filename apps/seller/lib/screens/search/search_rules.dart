import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/foundation.dart';

/// H-03 search over what the seller app already holds (orders, products,
/// quotes). Pure — unit-tested.
@immutable
class SearchResults {
  const SearchResults({this.orders = const [], this.products = const [], this.quotes = const [], this.exactOrder});
  final List<OrderModel> orders;
  final List<ProductModel> products;
  final List<RfqModel> quotes;

  /// An order whose number or id equals the query — opened directly.
  final OrderModel? exactOrder;

  bool get isEmpty => orders.isEmpty && products.isEmpty && quotes.isEmpty;
}

const int kSearchMinChars = 2;
const int kSearchPerGroup = 20;

String _norm(String s) => s.toLowerCase().replaceAll('#', '').trim();

SearchResults searchSeller(
  String query, {
  required List<OrderModel> orders,
  required List<ProductModel> products,
  required List<RfqModel> quotes,
}) {
  final q = _norm(query);
  if (q.length < kSearchMinChars) return const SearchResults();
  bool has(String? s) => s != null && _norm(s).contains(q);

  OrderModel? exact;
  for (final o in orders) {
    if (_norm(o.orderNumber) == q || _norm(o.id) == q) {
      exact = o;
      break;
    }
  }
  return SearchResults(
    exactOrder: exact,
    orders: orders
        .where((o) => has(o.orderNumber) || has(o.id) || has(o.deliveryAddress.name) || o.items.any((i) => has(i.productName)))
        .take(kSearchPerGroup)
        .toList(),
    products: products.where((p) => has(p.name) || has(p.categoryName)).take(kSearchPerGroup).toList(),
    quotes: quotes
        .where((r) => has(r.productName) || has(r.buyerBusinessName) || has(r.buyerName))
        .take(kSearchPerGroup)
        .toList(),
  );
}
