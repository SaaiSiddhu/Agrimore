// lib/data/order_timeline.dart
//
// Phase DLVH2 — orders/{orderId}/timeline: a real, append-only, timestamped
// audit trail already written by createOrder.ts, dispatchCallables.ts,
// riderSteps.ts, confirmDelivery.ts, riderExceptions.ts and
// sellerTransitionOrder.ts. Read-only here; the rider app never writes to
// it. Server-authored title/description are shown as written — the same
// precedent InboxScreen already uses for RiderNotice.title/.body, not new
// per-event l10n keys.
//
// The six write sites do not all use the same shape: rider/customer paths
// write `description` + `partnerId`; sellerTransitionOrder.ts writes `actor`
// and, only for a cancellation, `reason` instead of `description`. Read
// defensively rather than assuming one shape.
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTimelineEvent {
  const OrderTimelineEvent({
    required this.id,
    required this.status,
    required this.title,
    this.detail,
    this.timestamp,
  });

  final String id;
  final String status;
  final String title;
  final String? detail;
  final DateTime? timestamp;

  factory OrderTimelineEvent.fromMap(String id, Map<String, dynamic> m) {
    final description = m['description'] as String?;
    final reason = m['reason'] as String?;
    return OrderTimelineEvent(
      id: id,
      status: (m['status'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      detail: (description != null && description.trim().isNotEmpty)
          ? description
          : (reason != null && reason.trim().isNotEmpty ? reason : null),
      timestamp: m['timestamp'] is Timestamp ? (m['timestamp'] as Timestamp).toDate() : null,
    );
  }

  /// Whether this event flags a problem (shown in a distinct tone).
  bool get isProblem => status == 'delivery_problem';
}

/// Loads one order's timeline, oldest first (a real event log, not a
/// snapshot of "now").
typedef OrderTimelineLoader = Future<List<OrderTimelineEvent>> Function(String orderId);

Future<List<OrderTimelineEvent>> firestoreOrderTimeline(String orderId) async {
  final snap = await FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .collection('timeline')
      .orderBy('timestamp')
      .get();
  return snap.docs.map((d) => OrderTimelineEvent.fromMap(d.id, d.data())).toList();
}
