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

/// DLV-N1 / DLVH1: which orders the history lists. Split from a single
/// `notDelivered` bucket into `cancelled`/`returned` — the domain model
/// (DeliveryTaskStatus) and this file's own `historyStatusText` already
/// distinguished them; only the filter itself was coarser than the data.
enum HistoryFilter { all, delivered, cancelled, returned }

/// DLVH1: a preset lower bound on `createdAt`, applied in addition to
/// [HistoryFilter]. Presets only (no custom range) for this phase.
enum HistoryDateRange { allTime, last7Days, last30Days }

extension HistoryDateRangeSince on HistoryDateRange {
  /// The cutoff for this preset, relative to [now]; null for "all time".
  DateTime? since(DateTime now) => switch (this) {
        HistoryDateRange.allTime => null,
        HistoryDateRange.last7Days => now.subtract(const Duration(days: 7)),
        HistoryDateRange.last30Days => now.subtract(const Duration(days: 30)),
      };
}

/// What to ask the server for: a status bucket and an optional `createdAt`
/// cutoff, combined.
typedef HistoryQuery = ({HistoryFilter filter, DateTime? since});

// Terminal order statuses as they may be stored (Firestore `in` is
// case-sensitive) — the spellings DeliveryTaskStatus.fromOrderStatus reads.
// Either field may carry it: seller/admin panels write only `status`.
const List<String> _deliveredStored = ['delivered', 'completed', 'Delivered', 'Completed'];
const List<String> _cancelledStored = [
  'cancelled', 'canceled', 'rejected', 'refunded',
  'Cancelled', 'Canceled', 'Rejected', 'Refunded',
];
const List<String> _returnedStored = ['returned', 'Returned'];

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
  return switch (f) {
    HistoryFilter.all => true,
    HistoryFilter.delivered => s == DeliveryTaskStatus.delivered,
    HistoryFilter.cancelled => s == DeliveryTaskStatus.cancelled,
    HistoryFilter.returned => s == DeliveryTaskStatus.returned,
  };
}

/// Fetches a page of [riderId]'s orders under [query] after [cursor] (null = first page).
typedef HistoryFetch = Future<HistoryPage> Function(String riderId, HistoryQuery query, Object? cursor, int size);

Future<HistoryPage> firestoreHistoryPage(String riderId, HistoryQuery query, Object? cursor, int size) async {
  Filter where = Filter('deliveryPartnerId', isEqualTo: riderId);
  final statusValues = switch (query.filter) {
    HistoryFilter.all => null,
    HistoryFilter.delivered => _deliveredStored,
    HistoryFilter.cancelled => _cancelledStored,
    HistoryFilter.returned => _returnedStored,
  };
  // Indexes: orders (deliveryPartnerId, orderStatus, createdAt desc) and
  // (deliveryPartnerId, status, createdAt desc). A `createdAt` lower bound
  // needs no separate index: it is a range filter on the same field the
  // query already orders by.
  if (statusValues != null) {
    where = Filter.and(
      where,
      Filter.or(Filter('orderStatus', whereIn: statusValues), Filter('status', whereIn: statusValues)),
    );
  }
  final since = query.since;
  if (since != null) {
    where = Filter.and(where, Filter('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since)));
  }
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('orders')
      .where(where)
      .orderBy('createdAt', descending: true);
  if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
  // One extra row tells whether another page exists.
  final snap = await q.limit(size + 1).get();
  final docs = snap.docs;
  final page = docs.take(size).toList();
  return (
    items: page.map((d) => historyOrder(d.id, d.data())).where((o) => historyMatches(o, query.filter)).toList(),
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
  HistoryDateRange _dateRange = HistoryDateRange.allTime;
  DateTime? _since;
  int _generation = 0;
  final List<OrderModel> _items = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  RiderDataError? _error;

  List<OrderModel> get items => List.unmodifiable(_items);
  HistoryFilter get filter => _filter;
  HistoryDateRange get dateRange => _dateRange;
  bool get hasActiveFilter => _filter != HistoryFilter.all || _dateRange != HistoryDateRange.allTime;

  /// Shows [f] from its first page.
  Future<void> setFilter(HistoryFilter f) {
    if (f == _filter) return Future.value();
    _filter = f;
    return refresh();
  }

  /// Shows [r] from its first page. The cutoff is computed once here (not
  /// re-derived from `DateTime.now()` on every page) so a session that
  /// crosses midnight mid-scroll keeps a stable window.
  Future<void> setDateRange(HistoryDateRange r) {
    if (r == _dateRange) return Future.value();
    _dateRange = r;
    _since = r.since(DateTime.now());
    return refresh();
  }

  /// Back to no status filter and no date range, in one reload.
  Future<void> clearFilters() {
    if (!hasActiveFilter) return Future.value();
    _filter = HistoryFilter.all;
    _dateRange = HistoryDateRange.allTime;
    _since = null;
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
      final page = await _fetch(riderId, (filter: _filter, since: _since), _cursor, pageSize);
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
