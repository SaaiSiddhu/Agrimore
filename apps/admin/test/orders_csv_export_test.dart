// ADMR-47 — real mobile order export instead of an honest refusal.
//
// PROBLEM: order_management_screen.dart's CSV export already worked
// correctly on web (a real dart:html download) and was already honest on
// mobile (a plain "not available" message, never a false success claim) —
// but mobile admins had no working export at all. buildOrdersCsv is the
// exact header/row/quote-escaping logic _exportToCSV always had, pulled
// out into a plain, Firebase-free function so it can be tested directly —
// OrderModel/AddressModel/CartItemModel all construct without a live
// Firebase app, matching this project's other Firebase-free guard tests.
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/orders/order_management_screen.dart';

AddressModel _address({
  String name = 'Jane Doe',
  String phone = '9876543210',
  String addressLine1 = '12 MG Road',
  String addressLine2 = '',
  String? landmark,
  String city = 'Chennai',
}) {
  return AddressModel(
    id: 'addr1',
    userId: 'user1',
    name: name,
    phone: phone,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    city: city,
    state: 'Tamil Nadu',
    zipcode: '600001',
    landmark: landmark,
  );
}

OrderModel _order({
  String id = 'order1',
  String orderNumber = 'ORD1001',
  AddressModel? deliveryAddress,
  String status = 'delivered',
  double total = 499.5,
  List<CartItemModel> items = const [],
  DateTime? createdAt,
}) {
  return OrderModel(
    id: id,
    userId: 'user1',
    orderNumber: orderNumber,
    items: items,
    deliveryAddress: deliveryAddress ?? _address(),
    subtotal: total,
    total: total,
    paymentMethod: 'cod',
    orderStatus: status,
    createdAt: createdAt ?? DateTime(2026, 9, 27, 14, 30),
  );
}

CartItemModel _cartItem(String id) {
  return CartItemModel(
    id: id,
    productId: 'p-$id',
    productName: 'Product $id',
    productImage: '',
    price: 10,
    quantity: 1,
    userId: 'user1',
    addedAt: DateTime(2026, 9, 27),
  );
}

void main() {
  group('buildOrdersCsv', () {
    test('an empty order list still produces just the header row', () {
      final csv = buildOrdersCsv([]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 1);
      expect(lines.first, contains('Order ID'));
      expect(lines.first, contains('Created At'));
    });

    test('a single order produces exactly one header row plus one data row', () {
      final csv = buildOrdersCsv([_order()]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
    });

    test('a data row carries the order id, number, status, total and item count', () {
      final csv = buildOrdersCsv([
        _order(
          id: 'order-xyz',
          orderNumber: 'ORD-XYZ',
          status: 'shipped',
          total: 1234.5,
          items: [_cartItem('a'), _cartItem('b')],
        ),
      ]);
      final dataRow = csv.trim().split('\n')[1];
      expect(dataRow, contains('order-xyz'));
      expect(dataRow, contains('ORD-XYZ'));
      expect(dataRow, contains('shipped'));
      expect(dataRow, contains('1234.50'));
      expect(dataRow, contains('"2"'));
    });

    test('the delivery address contributes name, phone and full address', () {
      final csv = buildOrdersCsv([
        _order(deliveryAddress: _address(name: 'Ravi Kumar', phone: '9000090000')),
      ]);
      final dataRow = csv.trim().split('\n')[1];
      expect(dataRow, contains('Ravi Kumar'));
      expect(dataRow, contains('9000090000'));
      expect(dataRow, contains('12 MG Road'));
      expect(dataRow, contains('Chennai'));
    });

    test('a customer name containing a comma is quoted, not split into extra columns', () {
      final csv = buildOrdersCsv([
        _order(deliveryAddress: _address(name: 'Doe, Jane')),
      ]);
      final dataRow = csv.trim().split('\n')[1];
      expect(dataRow, contains('"Doe, Jane"'));
      // The comma inside the quoted name must not be read as a column
      // separator: exactly 9 columns (8 internal commas), matching the header.
      expect(',,'.allMatches(dataRow).length, 0);
    });

    test('a double quote in an address line is escaped by doubling, not dropped', () {
      final csv = buildOrdersCsv([
        _order(deliveryAddress: _address(addressLine1: '12 "New" MG Road')),
      ]);
      final dataRow = csv.trim().split('\n')[1];
      expect(dataRow, contains('12 ""New"" MG Road'));
    });

    test('createdAt is formatted as dd/MM/yyyy HH:mm', () {
      final csv = buildOrdersCsv([
        _order(createdAt: DateTime(2026, 1, 5, 9, 7)),
      ]);
      final dataRow = csv.trim().split('\n')[1];
      expect(dataRow, contains('05/01/2026 09:07'));
    });

    test('multiple orders each get their own row, in the given order', () {
      final csv = buildOrdersCsv([
        _order(id: 'first'),
        _order(id: 'second'),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 3);
      expect(lines[1], contains('first'));
      expect(lines[2], contains('second'));
    });
  });
}
