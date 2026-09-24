/// Phase DLV-1A — the state of one delivery leg (delivery_tasks/{orderId}).
///
/// `orders.orderStatus` stays the customer-facing summary; this is the rider
/// leg. Stored as [wire] (snake_case). The TypeScript mirror is
/// functions/src/delivery/states.ts; both are tested against
/// test/fixtures/delivery_status_table.json, so change all three together.
enum DeliveryTaskStatus {
  /// Packed and waiting for a rider (order `ready_for_pickup`, no partner).
  searching('searching'),

  /// A rider holds the order (`delivery_accepted`, or an admin assignment
  /// while still `ready_for_pickup`).
  assigned('assigned'),

  /// Rider at the seller (`arrived_at_store` / `reached_pickup`).
  atPickup('at_pickup'),

  /// Goods collected (`picked_up` / `parcel_picked`).
  pickedUp('picked_up'),

  /// On the way (`out_for_delivery` and its spellings; `shipped` with a rider).
  enRoute('en_route'),

  /// At the customer. No legacy status maps here — introduced for DLV-3's
  /// geofence.
  atDrop('at_drop'),

  delivered('delivered'),

  /// Delivery attempted and failed (customer unreachable, refused …). New.
  failedAttempt('failed_attempt'),

  /// Taking the goods back to the seller. New.
  returningToSeller('returning_to_seller'),

  returned('returned'),
  cancelled('cancelled');

  const DeliveryTaskStatus(this.wire);

  /// The string stored in Firestore.
  final String wire;

  bool get isTerminal =>
      this == delivered || this == returned || this == cancelled;

  /// Whether a rider leg may move from this state to [next]. The projection
  /// (syncDeliveryTask) RECORDS legacy jumps rather than refusing them —
  /// admins and old clients can write any status — and flags them via
  /// `lastTransitionAllowed`; the DLV-2 transition callables enforce this.
  bool canTransitionTo(DeliveryTaskStatus next) =>
      _transitions[this]!.contains(next);

  static const Map<DeliveryTaskStatus, Set<DeliveryTaskStatus>> _transitions = {
    searching: {assigned, cancelled},
    // Back to searching = the rider released it ("Seller Not Ready").
    assigned: {atPickup, pickedUp, searching, cancelled},
    atPickup: {pickedUp, searching, cancelled},
    // After pickup a cancellation is a return, not a cancel.
    pickedUp: {enRoute, atDrop, delivered, failedAttempt, returningToSeller},
    enRoute: {atDrop, delivered, failedAttempt, returningToSeller},
    atDrop: {delivered, failedAttempt, returningToSeller},
    failedAttempt: {enRoute, atDrop, delivered, returningToSeller},
    returningToSeller: {returned},
    delivered: {},
    returned: {},
    cancelled: {},
  };

  /// `orders.orderStatus` values in which a rider holds an order, exactly
  /// as stored (Firestore `in` is case-sensitive). The server's busy check
  /// (functions/src/delivery/dispatch.ts RIDER_ACTIVE_ORDER_STATUSES) and the
  /// rider app's active-work query use this list; both are tested against
  /// test/fixtures/delivery_status_table.json. A query on it returns
  /// candidates only — read each result with [fromOrderStatus], which also
  /// weighs `status` (an admin may have delivered or cancelled it there).
  static const List<String> riderActiveOrderStatuses = [
    'delivery_accepted',
    'arrived_at_store',
    'reached_pickup',
    'picked_up',
    'parcel_picked',
    'out_for_delivery',
    'outfordelivery',
    'outForDelivery',
  ];

  static DeliveryTaskStatus? fromWire(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    for (final s in DeliveryTaskStatus.values) {
      if (s.wire == v) return s;
    }
    return null;
  }

  // Legacy order statuses, lower-cased. Every spelling found in apps/,
  // packages/ and functions/src/ at 71630df.
  static const Set<String> _delivered = {'delivered', 'completed'};
  static const Set<String> _cancelled = {
    'cancelled',
    'canceled',
    'rejected',
    'refunded',
  };
  static const Set<String> _returned = {'returned'};
  static const Map<String, DeliveryTaskStatus> _active = {
    'delivery_accepted': assigned,
    'arrived_at_store': atPickup,
    'reached_pickup': atPickup,
    'picked_up': pickedUp,
    'parcel_picked': pickedUp,
    'out_for_delivery': enRoute,
    'outfordelivery': enRoute,
  };

  /// Derives the leg state from an order's two status fields.
  ///
  /// Seller/admin panels write only `status`, the customer cancel path only
  /// `orderStatus` (confirmDelivery.ts statusIsIn), so both are read:
  /// a terminal value in EITHER wins (returned, then delivered, then
  /// cancelled/refunded); otherwise the more advanced of the two.
  /// Returns null when the order has no rider leg yet (pending … processing,
  /// seller-only statuses, `shipped` without a rider, unknown values).
  static DeliveryTaskStatus? fromOrderStatus({
    required String? orderStatus,
    required String? status,
    required bool hasPartner,
  }) {
    final values = [orderStatus, status]
        .whereType<String>()
        .map((v) => v.trim().toLowerCase())
        .toList();
    // A return only ever follows a delivery, so it outranks it; delivered
    // outranks cancelled to agree with confirmDelivery, which answers
    // "already delivered" whenever either field says so.
    if (values.any(_returned.contains)) return returned;
    if (values.any(_delivered.contains)) return delivered;
    if (values.any(_cancelled.contains)) return cancelled;

    DeliveryTaskStatus? best;
    for (final v in values) {
      final DeliveryTaskStatus? s;
      if (v == 'ready_for_pickup') {
        s = hasPartner ? assigned : searching;
      } else if (v == 'shipped') {
        s = hasPartner ? enRoute : null;
      } else {
        s = _active[v];
      }
      if (s != null && (best == null || s.index > best.index)) best = s;
    }
    return best;
  }
}
