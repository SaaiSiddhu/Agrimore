// lib/data/rider_history.dart
//
// Phase DLV-C1 — the rider's orders, newest first, one page at a time. The
// old history sheet read `orderStatus == delivered` ordered by `updatedAt`,
// an index that does not exist in firestore.indexes.json: in production the
// query failed and the sheet said "No deliveries yet". This reads
// deliveryPartnerId + createdAt DESC (an existing index) with a document
// cursor, so later pages continue exactly after the last row shown.
//
// A page result from an older session (signed out, another rider signed in)
// is dropped. Covered by test/rider_history_test.dart.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'rider_work.dart';

/// One page: [cursor] continues after the last item; [hasMore] if a next
/// page exists.
typedef HistoryPage = ({List<OrderModel> items, Object? cursor, bool hasMore});

/// DLV-N1: which orders the history lists.
enum HistoryFilter { all, delivered, notDelivered }

// Terminal order statuses as they may be stored (Firestore `in` is
// case-sensitive) — the spellings DeliveryTaskStatus.fromOrderStatus reads.
// Either field may carry it: seller/admin panels write only `status`.
const List<String> _deliveredStored = ['delivered', 'completed', 'Delivered', 'Completed'];
const List<String> _notDeliveredStored = [
  'cancelled', 'canceled', 'rejected', 'refunded', 'returned',
  'Cancelled', 'Canceled', 'Rejected', 'Refunded', 'Returned',
];

/// An order read for history. OrderModel keeps one status (`orderStatus`,
/// else `status`); an order an admin delivered or cancelled through `status`
/// alone would read as still active. The leg state is taken from BOTH raw
/// fields (DeliveryTaskStatus.fromOrderStatus) and, when `status` decides it,
/// that value is the one the model carries.
OrderModel historyOrder(String id, Map<String, dynamic> raw) {
  final os = raw['orderStatus'] as String?, st = raw['status'] as String?;
  final both = DeliveryTaskStatus.fromOrderStatus(orderStatus: os, status: st, hasPartner: true);
  final alone = DeliveryTaskStatus.fromOrderStatus(orderStatus: os, status: null, hasPartner: true);
  final useStatus = st != null && both != alone &&
      DeliveryTaskStatus.fromOrderStatus(orderStatus: st, status: null, hasPartner: true) == both;
  return OrderModel.fromMap(useStatus ? {...raw, 'orderStatus': st} : raw, id);
}

/// Whether [o] (read with [historyOrder]) belongs under [f]. A filtered query
/// returns candidates only — `status` may say delivered while `orderStatus`
/// says returned, and returned wins.
bool historyMatches(OrderModel o, HistoryFilter f) {
  if (f == HistoryFilter.all) return true;
  final s = DeliveryTaskStatus.fromOrderStatus(orderStatus: o.orderStatus, status: null, hasPartner: true);
  return f == HistoryFilter.delivered
      ? s == DeliveryTaskStatus.delivered
      : s == DeliveryTaskStatus.cancelled || s == DeliveryTaskStatus.returned;
}

/// Fetches a page of [riderId]'s orders under [filter] after [cursor] (null = first page).
typedef HistoryFetch = Future<HistoryPage> Function(String riderId, HistoryFilter filter, Object? cursor, int size);

Future<HistoryPage> firestoreHistoryPage(String riderId, HistoryFilter filter, Object? cursor, int size) async {
  final mine = Filter('deliveryPartnerId', isEqualTo: riderId);
  final values = filter == HistoryFilter.delivered ? _deliveredStored : _notDeliveredStored;
  // Indexes: orders (deliveryPartnerId, orderStatus, createdAt desc) and
  // (deliveryPartnerId, status, createdAt desc).
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('orders')
      .where(filter == HistoryFilter.all
          ? mine
          : Filter.and(mine, Filter.or(Filter('orderStatus', whereIn: values), Filter('status', whereIn: values))))
      .orderBy('createdAt', descending: true);
  if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
  // One extra row tells whether another page exists.
  final snap = await q.limit(size + 1).get();
  final docs = snap.docs;
  final page = docs.take(size).toList();
  return (
    items: page.map((d) => historyOrder(d.id, d.data())).where((o) => historyMatches(o, filter)).toList(),
    cursor: page.isEmpty ? cursor : page.last,
    hasMore: docs.length > size,
  );
}

class RiderHistory extends ChangeNotifier {
  RiderHistory({HistoryFetch? fetch, this.pageSize = kHistoryPageSize}) : _fetch = fetch ?? firestoreHistoryPage;

  final HistoryFetch _fetch;
  final int pageSize;

  String? _riderId;
  HistoryFilter _filter = HistoryFilter.all;
  int _generation = 0;
  final List<OrderModel> _items = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  RiderDataError? _error;

  List<OrderModel> get items => List.unmodifiable(_items);
  HistoryFilter get filter => _filter;

  /// Shows [f] from its first page.
  Future<void> setFilter(HistoryFilter f) {
    if (f == _filter) return Future.value();
    _filter = f;
    return refresh();
  }
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  RiderDataError? get error => _error;

  /// Nothing loaded yet and nothing failed.
  bool get notStarted => _items.isEmpty && !_loading && _error == null && _hasMore;

  /// Binds to [riderId] (null = signed out) and forgets everything else.
  void bind(String? riderId) {
    if (riderId == _riderId) return;
    _riderId = riderId;
    _generation++;
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  /// Reloads from the first page.
  Future<void> refresh() {
    final id = _riderId;
    bind(null);
    bind(id);
    return loadMore();
  }

  /// Loads the next page. A second call while one is in flight does nothing.
  Future<void> loadMore() async {
    final riderId = _riderId;
    if (riderId == null || _loading || !_hasMore) return;
    final gen = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _fetch(riderId, _filter, _cursor, pageSize);
      if (gen != _generation) return; // another session since
      final seen = _items.map((o) => o.id).toSet();
      _items.addAll(page.items.where((o) => !seen.contains(o.id)));
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } on FirebaseException catch (e) {
      if (gen != _generation) return;
      debugPrint('History page failed: ${e.code}');
      _error = riderDataErrorOf(e.code);
    } catch (e) {
      if (gen != _generation) return;
      debugPrint('History page failed: $e');
      _error = RiderDataError.unknown;
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }
}
