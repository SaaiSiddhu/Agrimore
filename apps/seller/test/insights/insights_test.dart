import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/insights/insights_rules.dart';
import 'package:seller/screens/orders/order_stage.dart';

/// SELLER-HOME-1c: best sellers, stage counts and account health from
/// transparent inputs — missing data is left out, not scored as zero.
final DateTime _now = DateTime(2026, 9, 23, 12);

OrderModel _o(String id, String status, {int daysAgo = 1, List<Map<String, dynamic>>? items}) => OrderModel.fromMap({
      'userId': 'u',
      'sellerId': 's',
      'orderNumber': id,
      'orderStatus': status,
      'createdAt': _now.subtract(Duration(days: daysAgo)),
      'items': items ??
          [
            {'productId': 'rice', 'productName': 'Rice', 'productImage': '', 'price': 100, 'quantity': 2, 'userId': 'u', 'sellerId': 's'},
          ],
      'total': 200,
    }, id);

ProductModel _p(String id, {bool complete = true}) => ProductModel.fromMap({
      'name': id,
      'categoryId': 'c',
      'salePrice': 10,
      'sellerId': 's',
      'isActive': true,
      'images': complete ? ['https://x'] : <String>[],
      'description': complete ? 'desc' : '',
      'hsnCode': complete ? '1006' : null,
      'gstRate': complete ? 5 : null,
    }, id);

void main() {
  test('best sellers rank by revenue; cancelled orders do not count', () {
    final orders = [
      _o('1', 'delivered'),
      _o('2', 'delivered', items: [
        {'productId': 'dal', 'productName': 'Dal', 'productImage': '', 'price': 300, 'quantity': 1, 'userId': 'u', 'sellerId': 's'},
      ]),
      _o('3', 'cancelled', items: [
        {'productId': 'oil', 'productName': 'Oil', 'productImage': '', 'price': 999, 'quantity': 9, 'userId': 'u', 'sellerId': 's'},
      ]),
    ];
    final top = topProducts(ordersIn(orders, _now.subtract(const Duration(days: 30)), _now));
    expect(top.map((p) => p.productId), ['dal', 'rice']);
    expect(top.last.units, 2);
  });

  test('stage counts include cancelled', () {
    final c = stageCounts([_o('1', 'pending'), _o('2', 'cancelled'), _o('3', 'delivered', daysAgo: 60)],
        _now.subtract(const Duration(days: 30)), _now);
    expect(c[OrderStage.toAccept], 1);
    expect(c[OrderStage.cancelled], 1);
    expect(c[OrderStage.delivered], isNull);
  });

  test('no data → no score', () {
    final inputs = healthInputs(orders: const [], products: const [], quotes: const [], rating: null, reviewCount: 0, now: _now);
    expect(inputs, isEmpty);
    expect(overallHealth(inputs), isNull);
  });

  test('inputs, targets and the overall score', () {
    final orders = [for (var i = 0; i < 9; i++) _o('d$i', 'delivered'), _o('c', 'cancelled')];
    final inputs = healthInputs(
      orders: orders,
      products: [_p('a'), _p('b', complete: false)],
      quotes: const [],
      rating: 4.6,
      reviewCount: 5,
      now: _now,
    );
    final by = {for (final i in inputs) i.input: i};
    expect(by.keys.toSet(), {HealthInput.fulfilment, HealthInput.cancellations, HealthInput.rating, HealthInput.listings});
    expect(by[HealthInput.fulfilment]!.value, 0.9);
    expect(by[HealthInput.cancellations]!.meetsTarget, isFalse); // 10% > 5%
    expect(by[HealthInput.rating]!.score, 100);
    expect(by[HealthInput.listings]!.value, 0.5);
    final score = overallHealth(inputs)!;
    expect(score, inInclusiveRange(0, 100));
    expect(bandOf(90), HealthBand.good);
    expect(bandOf(70), HealthBand.fair);
    expect(bandOf(40), HealthBand.poor);
  });

  test('rating needs enough reviews to count', () {
    final inputs = healthInputs(orders: const [], products: const [], quotes: const [], rating: 2.0, reviewCount: 2, now: _now);
    expect(inputs.where((i) => i.input == HealthInput.rating), isEmpty);
  });
}
