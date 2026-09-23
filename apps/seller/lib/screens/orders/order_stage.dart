import 'package:agrimore_core/agrimore_core.dart';

/// Where an order is, from the seller's side, per the server state machine
/// (functions/src/seller/sellerTransitionOrder.ts TRANSITIONS):
/// pending →accept→ confirmed →pack→ processing →ready→ ready_for_pickup.
/// `confirmed` is ACCEPTED (waiting to be packed), not "to accept".
/// Pure — unit-tested.
enum OrderStage { toAccept, toPack, packing, ready, outForDelivery, delivered, cancelled, other }

OrderStage orderStageOf(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return OrderStage.toAccept;
    case 'confirmed':
    case 'accepted':
      return OrderStage.toPack;
    case 'processing':
    case 'packing':
      return OrderStage.packing;
    case 'ready_for_pickup':
      return OrderStage.ready;
    case 'shipped':
    case 'out_for_delivery':
    case 'outfordelivery':
      return OrderStage.outForDelivery;
    case 'delivered':
    case 'completed':
      return OrderStage.delivered;
    case 'cancelled':
    case 'canceled':
    case 'rejected':
    case 'refunded':
      return OrderStage.cancelled;
    default:
      return OrderStage.other;
  }
}

/// Filter chips, in order: provider filter key → stage (null = all).
const List<(String, OrderStage?)> kOrderFilters = [
  ('all', null),
  ('pending', OrderStage.toAccept),
  ('confirmed', OrderStage.toPack),
  ('processing', OrderStage.packing),
  ('ready_for_pickup', OrderStage.ready),
  ('shipped', OrderStage.outForDelivery),
  ('delivered', OrderStage.delivered),
  ('cancelled', OrderStage.cancelled),
];

/// The seller's next step, if any (server action name).
String? nextSellerAction(OrderStage s) => switch (s) {
      OrderStage.toAccept => 'accept',
      OrderStage.toPack => 'pack',
      OrderStage.packing => 'ready',
      _ => null,
    };

/// Orders that need the seller to do something now.
bool needsSellerAction(OrderModel o) => nextSellerAction(orderStageOf(o.orderStatus)) != null;

/// Date windows for the order list (SELLER-POLISH-1, gap 21).
enum OrderPeriod { all, today, days7, days30 }

/// [today] is the Indian calendar day, like the server's stats.
bool inPeriod(OrderModel o, OrderPeriod p, DateTime now) {
  if (p == OrderPeriod.all) return true;
  if (p == OrderPeriod.today) {
    final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
    final start = DateTime.utc(ist.year, ist.month, ist.day).subtract(const Duration(hours: 5, minutes: 30));
    return !o.createdAt.toUtc().isBefore(start);
  }
  final days = p == OrderPeriod.days7 ? 7 : 30;
  return !o.createdAt.isBefore(now.subtract(Duration(days: days)));
}

/// Business orders: placed as B2B (incl. every order from an accepted quote).
bool isB2bOrder(OrderModel o) => o.orderMode.toUpperCase() == 'B2B';

bool isPrepaid(OrderModel o) {
  final m = o.paymentMethod.toLowerCase();
  return !m.contains('cod') && !m.contains('cash');
}

/// Search over order number, id, customer name and item names.
bool orderMatches(OrderModel o, String query) {
  final q = query.trim().toLowerCase().replaceAll('#', '');
  if (q.isEmpty) return true;
  bool has(String s) => s.toLowerCase().contains(q);
  return has(o.orderNumber) || has(o.id) || has(o.deliveryAddress.name) || o.items.any((i) => has(i.productName));
}
