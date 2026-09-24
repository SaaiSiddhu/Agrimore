// lib/data/rider_work.dart
//
// Phase DLV-C1 — what the rider is working on, derived the same way the
// server derives it. Who writes what:
//   orders/{id}            the order; its status is written by the server
//                          (acceptDeliveryOffer, advanceDeliveryStep,
//                          confirmDelivery, releaseDeliveryOrder) and by
//                          seller/admin panels. The rider app writes none.
//   delivery_tasks/{id}    a server projection of the rider leg
//                          (syncDeliveryTask); read-only everywhere. Created
//                          on the first order update after it was deployed,
//                          so older orders have none — not used here as the
//                          source of truth.
//   delivery_requests/...  offers (OfferProvider), before assignment only.
//
// Active work = orders where deliveryPartnerId == me AND orderStatus is one
// of DeliveryTaskStatus.riderActiveOrderStatuses (the server's busy-check
// query, bounded), then each result is read with fromOrderStatus so an admin
// write to `status` (delivered, cancelled) wins. More than one active order
// is shown as such — never an arbitrary first.
//
// Pure; covered by test/rider_work_test.dart.
import 'package:agrimore_core/agrimore_core.dart';

/// At most this many active orders are read (the server allows one at a
/// time; more means something needs the rider's or admin's attention).
const int kActiveWorkLimit = 10;

/// Rows per history page.
const int kHistoryPageSize = 20;

/// Why rider data could not be read.
enum RiderDataError { permission, offline, unknown }

/// Maps a Firestore/Functions error code to [RiderDataError].
RiderDataError riderDataErrorOf(String? code) => switch (code) {
      'permission-denied' || 'unauthenticated' => RiderDataError.permission,
      'unavailable' || 'deadline-exceeded' => RiderDataError.offline,
      _ => RiderDataError.unknown,
    };

/// One raw order document.
typedef OrderDoc = ({String id, Map<String, dynamic> data});

/// The leg state of an order held by [riderId], or null if it is not an
/// open leg of this rider (reassigned, finished, cancelled, unknown).
DeliveryTaskStatus? openLegOf(OrderDoc doc, String riderId) {
  if (doc.data['deliveryPartnerId'] != riderId) return null;
  final s = DeliveryTaskStatus.fromOrderStatus(
    orderStatus: doc.data['orderStatus'] as String?,
    status: doc.data['status'] as String?,
    hasPartner: true,
  );
  if (s == null || s.isTerminal || s == DeliveryTaskStatus.searching) return null;
  return s;
}

DateTime? _time(Object? v) {
  if (v is DateTime) return v;
  try {
    return (v as dynamic)?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

/// The rider's open orders, oldest assignment first (the one to finish first).
List<OrderDoc> activeDocsFor(Iterable<OrderDoc> docs, String riderId) {
  final open = docs.where((d) => openLegOf(d, riderId) != null).toList();
  DateTime at(OrderDoc d) =>
      _time(d.data['deliveryAcceptedAt']) ?? _time(d.data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
  open.sort((a, b) {
    final c = at(a).compareTo(at(b));
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return open;
}

/// The state of the active-work read.
class ActiveWork {
  const ActiveWork._(this.loaded, this.orders, this.fromCache, this.error);

  /// Before the first answer.
  const ActiveWork.loading() : this._(false, const [], false, null);

  const ActiveWork.ready(List<OrderModel> orders, {bool fromCache = false})
      : this._(true, orders, fromCache, null);

  /// A read failed; [orders] are the last known ones (possibly none).
  const ActiveWork.failed(RiderDataError error, List<OrderModel> lastKnown)
      : this._(true, lastKnown, true, error);

  final bool loaded;
  final List<OrderModel> orders;

  /// The answer came from the device cache (offline or reconnecting).
  final bool fromCache;
  final RiderDataError? error;

  bool get isEmpty => loaded && orders.isEmpty;
  bool get hasMultiple => orders.length > 1;

  /// The one active order, or null when there are none or several.
  OrderModel? get single => orders.length == 1 ? orders.first : null;
}

/// Local midnight of [now] — "today" for the rider's delivered count.
DateTime startOfLocalDay(DateTime now) => DateTime(now.year, now.month, now.day);
