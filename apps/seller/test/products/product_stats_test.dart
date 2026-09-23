import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/products/product_stats.dart';

/// SELLER-POLISH-1 (gap 18): per-product sales in the editor.
OrderModel _o(String id, DateTime at, List<Map<String, Object>> items, {String status = 'delivered'}) => OrderModel.fromMap({
      'userId': 'u',
      'sellerId': 's',
      'orderNumber': id,
      'items': [
        for (final i in items) {'productImage': '', 'productName': 'x', 'userId': 'u', 'sellerId': 's', ...i},
      ],
      'deliveryAddress': {'name': 'P', 'phone': '9999999999'},
      'subtotal': 0,
      'total': 0,
      'orderStatus': status,
      'paymentMethod': 'cod',
      'createdAt': Timestamp.fromDate(at),
    }, id);

void main() {
  final now = DateTime(2026, 9, 23);
  final orders = [
    _o('1', now.subtract(const Duration(days: 2)), [
      {'productId': 'p', 'price': 50, 'quantity': 3},
      {'productId': 'q', 'price': 10, 'quantity': 1},
    ]),
    _o('2', now.subtract(const Duration(days: 5)), [
      {'productId': 'p', 'price': 40, 'quantity': 2},
    ]),
    _o('3', now.subtract(const Duration(days: 1)), [
      {'productId': 'p', 'price': 999, 'quantity': 9},
    ], status: 'cancelled'),
    _o('4', now.subtract(const Duration(days: 45)), [
      {'productId': 'p', 'price': 1, 'quantity': 100},
    ]),
  ];

  test('last 30 days: units, revenue, orders; cancelled and old excluded', () {
    final s = ProductSalesStats.of(orders, 'p', now);
    expect(s.units, 5);
    expect(s.revenue, 230);
    expect(s.orders, 2);
    expect(s.lastSold, now.subtract(const Duration(days: 2)));
  });

  test('last sold looks past the window; never sold is null', () {
    final old = ProductSalesStats.of([orders[3]], 'p', now);
    expect(old.units, 0);
    expect(old.lastSold, now.subtract(const Duration(days: 45)));
    expect(ProductSalesStats.of(orders, 'zzz', now).lastSold, isNull);
  });
}
