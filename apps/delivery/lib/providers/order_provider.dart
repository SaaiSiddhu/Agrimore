// lib/providers/order_provider.dart
//
// Phase DLV-C1 — the rider's work, bound to one signed-in rider at a time.
// Replaces two unbounded listeners on ALL of the rider's orders (one of them
// picking `activeDocs.first` from a hand-written 5-status list) with:
//   - active work: the server's own busy-check query (bounded), read through
//     DeliveryTaskStatus.fromOrderStatus; several active orders are reported
//     as several (lib/data/rider_work.dart);
//   - today's deliveries: an aggregate count on deliveredAt since local
//     midnight (confirmDelivery stamps it), not updatedAt over a full list;
//   - history: RiderHistory, paginated.
// [bind] is called by the session gate (app/app.dart) on every sign-in,
// sign-out and account switch; an answer from a previous binding is dropped.
//
// Phase DLV-2B: riders see only offers sent to them (OfferProvider).
// Phase DLV-3C: every step goes through a callable (delivery/rider_steps.dart).
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/rider_history.dart';
import '../data/rider_work.dart';
import '../delivery/rider_steps.dart' as steps;

/// One snapshot of the active-work query.
typedef ActiveSnapshot = ({List<OrderDoc> docs, bool fromCache});

/// Streams [riderId]'s active-work candidates.
typedef ActiveWorkSource = Stream<ActiveSnapshot> Function(String riderId);

/// Counts [riderId]'s deliveries since [since].
typedef DeliveredCount = Future<int> Function(String riderId, DateTime since);

Stream<ActiveSnapshot> firestoreActiveWork(String riderId) => FirebaseFirestore.instance
    .collection('orders')
    .where('deliveryPartnerId', isEqualTo: riderId)
    .where('orderStatus', whereIn: DeliveryTaskStatus.riderActiveOrderStatuses)
    .limit(kActiveWorkLimit)
    .snapshots(includeMetadataChanges: true)
    .map((s) => (
          docs: s.docs.map((d) => (id: d.id, data: d.data())).toList(),
          fromCache: s.metadata.isFromCache,
        ));

Future<int> firestoreDeliveredCount(String riderId, DateTime since) async {
  final agg = await FirebaseFirestore.instance
      .collection('orders')
      .where('deliveryPartnerId', isEqualTo: riderId)
      .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .count()
      .get();
  return agg.count ?? 0;
}

class DeliveryOrderProvider extends ChangeNotifier {
  DeliveryOrderProvider({
    ActiveWorkSource? activeSource,
    DeliveredCount? deliveredCount,
    HistoryFetch? historyFetch,
    DateTime Function()? clock,
  })  : _activeSource = activeSource ?? firestoreActiveWork,
        _deliveredCount = deliveredCount ?? firestoreDeliveredCount,
        _clock = clock ?? DateTime.now,
        history = RiderHistory(fetch: historyFetch);

  final ActiveWorkSource _activeSource;
  final DeliveredCount _deliveredCount;
  final DateTime Function() _clock;

  /// The bound rider's order history, page by page.
  final RiderHistory history;

  String? _riderId;
  int _generation = 0;
  StreamSubscription<ActiveSnapshot>? _activeSub;
  ActiveWork _work = const ActiveWork.loading();
  int? _todayDelivered;
  Set<String> _lastActiveIds = const {};
  String? _error;

  String? get riderId => _riderId;
  ActiveWork get work => _work;

  /// Every open order of this rider, oldest assignment first.
  List<OrderModel> get activeOrders => _work.orders;

  /// The active order when there is exactly one; null for none or several
  /// (see [work].hasMultiple — never an arbitrary pick).
  OrderModel? get activeOrder => _work.single;
  bool get hasActiveOrder => _work.orders.isNotEmpty;

  /// Deliveries completed since local midnight; null until known.
  int? get todayDelivered => _todayDelivered;

  /// The last step/release refusal, as a sentence.
  String? get error => _error;

  /// Binds to [riderId] (null = signed out): drops the previous rider's data
  /// and listeners first. Calling it again with the same id does nothing.
  void bind(String? riderId) {
    if (riderId == _riderId) return;
    _activeSub?.cancel();
    _activeSub = null;
    _generation++;
    _riderId = riderId;
    _work = const ActiveWork.loading();
    _todayDelivered = null;
    _lastActiveIds = const {};
    _error = null;
    history.bind(riderId);
    if (riderId != null) {
      _listen(riderId, _generation);
      _refreshToday(riderId, _generation);
    }
    notifyListeners();
  }

  /// Re-subscribes after an error (the "Try again" button).
  void retry() {
    final id = _riderId;
    if (id == null) return;
    _activeSub?.cancel();
    _generation++;
    _work = const ActiveWork.loading();
    notifyListeners();
    _listen(id, _generation);
    _refreshToday(id, _generation);
  }

  void _listen(String riderId, int gen) {
    _activeSub = _activeSource(riderId).listen((snap) {
      if (gen != _generation) return;
      final docs = activeDocsFor(snap.docs, riderId);
      final ids = docs.map((d) => d.id).toSet();
      // An order leaving active work may have just been delivered.
      if (_lastActiveIds.difference(ids).isNotEmpty) _refreshToday(riderId, gen);
      _lastActiveIds = ids;
      _work = ActiveWork.ready(
        docs.map((d) => OrderModel.fromMap(d.data, d.id)).toList(),
        fromCache: snap.fromCache,
      );
      notifyListeners();
    }, onError: (Object e) {
      if (gen != _generation) return;
      final code = e is FirebaseException ? e.code : null;
      debugPrint('Active work listener failed: ${code ?? e}');
      _work = ActiveWork.failed(riderDataErrorOf(code), _work.orders);
      notifyListeners();
    });
  }

  Future<void> _refreshToday(String riderId, int gen) async {
    try {
      final n = await _deliveredCount(riderId, startOfLocalDay(_clock()));
      if (gen != _generation) return;
      _todayDelivered = n;
      notifyListeners();
    } catch (e) {
      debugPrint('Delivered count failed: $e');
    }
  }

  /// Phase DLV-3C: a rider step (arrived_at_store, picked_up,
  /// out_for_delivery) through advanceDeliveryStep. Returns null on success,
  /// or a sentence to show the rider.
  Future<String?> advanceStep(String orderId, String status, Map<String, dynamic> fix) async {
    try {
      await steps.advanceDeliveryStep(orderId, status, fix);
      return null;
    } on steps.RiderStepException catch (e) {
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }

  /// Phase DLV-3C: "Seller not ready" through releaseDeliveryOrder, before
  /// pickup only. The active-work listener drops the order when the server
  /// has released it — no local guess.
  Future<String?> releaseOrder(String orderId, {required String reason}) async {
    try {
      await steps.releaseDeliveryOrder(orderId, reason: reason);
      return null;
    } on steps.RiderStepException catch (e) {
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    history.dispose();
    super.dispose();
  }
}
