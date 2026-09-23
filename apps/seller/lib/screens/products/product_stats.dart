import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/foundation.dart';

import '../orders/order_stage.dart';

/// C-02 product stats (ADR gap 18, SELLER-POLISH-1): what one product sold
/// in a window, from the seller's own orders. Cancelled orders don't count.
@immutable
class ProductSalesStats {
  const ProductSalesStats({required this.units, required this.revenue, required this.orders, this.lastSold});
  final int units;
  final double revenue;
  final int orders;
  final DateTime? lastSold;

  static ProductSalesStats of(Iterable<OrderModel> all, String productId, DateTime now, {Duration window = const Duration(days: 30)}) {
    final from = now.subtract(window);
    var units = 0;
    var revenue = 0.0;
    var orders = 0;
    DateTime? last;
    for (final o in all) {
      if (orderStageOf(o.orderStatus) == OrderStage.cancelled) continue;
      final lines = o.items.where((i) => i.productId == productId).toList();
      if (lines.isEmpty) continue;
      if (last == null || o.createdAt.isAfter(last)) last = o.createdAt;
      if (o.createdAt.isBefore(from)) continue;
      orders++;
      for (final i in lines) {
        units += i.quantity;
        revenue += i.price * i.quantity;
      }
    }
    return ProductSalesStats(units: units, revenue: revenue, orders: orders, lastSold: last);
  }
}
