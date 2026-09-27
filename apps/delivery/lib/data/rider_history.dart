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
// is dropped. Covered by test/rider_inbox_history_test.dart's 'history' group.
import 'dart:async';

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

/// The [deliveryPartnerId] + optional status + optional `createdAt` cutoff
/// filter `firestoreHistoryPage` and `firestoreHistoryCounts` both need,
/// shared so the count queries can never drift from what the list actually
/// fetches.
Filter _historyWhere(String riderId, HistoryFilter filter, DateTime? since) {
  Filter where = Filter('deliveryPartnerId', isEqualTo: riderId);
  final statusValues = switch (filter) {
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
  if (since != null) {
    where = Filter.and(where, Filter('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since)));
  }
  return where;
}

Future<HistoryPage> firestoreHistoryPage(String riderId, HistoryQuery query, Object? cursor, int size) async {
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('orders')
      .where(_historyWhere(riderId, query.filter, query.since))
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

/// DLVH7: how many of [riderId]'s orders fall under each status, scoped by
/// the same `createdAt` cutoff the list itself uses -- one count per bucket,
/// shown together regardless of which chip is selected (the mockup's own
/// panel always shows all four side by side).
typedef HistoryCounts = ({int all, int delivered, int cancelled, int returned});

/// Loads [HistoryCounts] for [riderId] as of [since] (null = all time).
typedef CountsFetch = Future<HistoryCounts> Function(String riderId, DateTime? since);

Future<HistoryCounts> firestoreHistoryCounts(String riderId, DateTime? since) async {
  Future<int> count(HistoryFilter f) async {
    final agg = await FirebaseFirestore.instance
        .collection('orders')
        .where(_historyWhere(riderId, f, since))
        .count()
        .get();
    return agg.count ?? 0;
  }

  final results = await Future.wait([
    count(HistoryFilter.all),
    count(HistoryFilter.delivered),
    count(HistoryFilter.cancelled),
    count(HistoryFilter.returned),
  ]);
  return (all: results[0], delivered: results[1], cancelled: results[2], returned: results[3]);
}

/// DLVH7: looks up exactly one of [riderId]'s orders by its human-facing
/// Order ID (`orderNumber`, always present -- not the raw Firestore document
/// id). Ownership-scoped only: independent of whatever status/date filters
/// happen to be active, so a correct Order ID always finds its order. Null
/// when no such order exists, or it belongs to another rider.
typedef SearchFetch = Future<OrderModel?> Function(String riderId, String orderNumber);

Future<OrderModel?> firestoreOrderBySearchId(String riderId, String orderNumber) async {
  final snap = await FirebaseFirestore.instance
      .collection('orders')
      .where('deliveryPartnerId', isEqualTo: riderId)
      .where('orderNumber', isEqualTo: orderNumber)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  final d = snap.docs.first;
  return historyOrder(d.id, d.data());
}

class RiderHistory extends ChangeNotifier {
  RiderHistory({
    HistoryFetch? fetch,
    CountsFetch? counts,
    SearchFetch? search,
    this.pageSize = kHistoryPageSize,
  })  : _fetch = fetch ?? firestoreHistoryPage,
        _countsFetch = counts ?? firestoreHistoryCounts,
        _searchFetch = search ?? firestoreOrderBySearchId;

  final HistoryFetch _fetch;
  final CountsFetch _countsFetch;
  final SearchFetch _searchFetch;
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

  /// DLVH7: per-status counts scoped to [_since] only -- independent of
  /// [_filter], since the mockup shows all four together regardless of
  /// which chip is selected. Null while loading or unavailable (chips fall
  /// back to their plain label rather than showing a stale/fabricated
  /// number).
  HistoryCounts? _counts;

  /// True exactly when [_counts] needs recomputing before it is trusted
  /// again: on a rider (re)bind and on a date-range change, never on a
  /// plain status-chip tap alone. NOT the same signal as "first page of
  /// this pagination sequence" ([_cursor] == null) -- [refresh] resets
  /// [_cursor] on every filter change too, so gating on that would recompute
  /// counts on a status-chip tap as well, which the mockup does not.
  bool _countsStale = true;

  /// DLVH7: an exact Order ID lookup, independent of [_filter]/[_dateRange].
  String _searchText = '';
  bool _searching = false;
  OrderModel? _searchResult;
  bool _searchNotFound = false;
  int _searchToken = 0;

  List<OrderModel> get items => List.unmodifiable(_items);
  HistoryFilter get filter => _filter;
  HistoryDateRange get dateRange => _dateRange;
  bool get hasActiveFilter => _filter != HistoryFilter.all || _dateRange != HistoryDateRange.allTime;
  HistoryCounts? get counts => _counts;

  bool get isSearchActive => _searchText.isNotEmpty;
  String get searchText => _searchText;
  bool get searching => _searching;
  OrderModel? get searchResult => _searchResult;
  bool get searchNotFound => _searchNotFound;

  /// Looks up exactly one order by its exact Order ID (`orderNumber`),
  /// scoped only by rider ownership -- independent of the current status/
  /// date filters, which stay untouched underneath. The newest call always
  /// wins over a slower, still-in-flight earlier one.
  Future<void> search(String orderNumber) async {
    final trimmed = orderNumber.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }
    final riderId = _riderId;
    final token = ++_searchToken;
    _searchText = trimmed;
    _searching = true;
    _searchResult = null;
    _searchNotFound = false;
    notifyListeners();
    if (riderId == null) {
      _searching = false;
      _searchNotFound = true;
      notifyListeners();
      return;
    }
    try {
      final found = await _searchFetch(riderId, trimmed);
      if (token != _searchToken) return; // superseded by a newer search/clear
      _searchResult = found;
      _searchNotFound = found == null;
    } catch (e) {
      if (token != _searchToken) return;
      debugPrint('History search failed: $e');
      _searchResult = null;
      _searchNotFound = true;
    } finally {
      if (token == _searchToken) {
        _searching = false;
        notifyListeners();
      }
    }
  }

  /// Back to the normal filtered/paginated list already loaded.
  void clearSearch() {
    if (_searchText.isEmpty && !_searching) return;
    _searchToken++;
    _searchText = '';
    _searching = false;
    _searchResult = null;
    _searchNotFound = false;
    notifyListeners();
  }

  /// Recomputes [counts] for the currently-bound rider and [_since]. Errors
  /// clear [counts] to unavailable rather than showing a stale number.
  Future<void> _loadCounts() async {
    final riderId = _riderId;
    if (riderId == null) return;
    final gen = _generation;
    HistoryCounts? result;
    try {
      result = await _countsFetch(riderId, _since);
    } catch (e) {
      debugPrint('History counts failed: $e');
      result = null;
    }
    if (gen != _generation) return;
    _counts = result;
    notifyListeners();
  }

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
    _countsStale = true;
    return refresh();
  }

  /// Back to no status filter and no date range, in one reload.
  Future<void> clearFilters() {
    if (!hasActiveFilter) return Future.value();
    _filter = HistoryFilter.all;
    _dateRange = HistoryDateRange.allTime;
    _since = null;
    _countsStale = true;
    return refresh();
  }

  bool get hasMore => _hasMore;
  bool get loading => _loading;
  RiderDataError? get error => _error;

  /// Nothing loaded yet and nothing failed.
  bool get notStarted => _items.isEmpty && !_loading && _error == null && _hasMore;

  void _resetPagination() {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _error = null;
  }

  /// Binds to [riderId] (null = signed out) and forgets everything else,
  /// including counts and search -- a genuinely different rider (or signing
  /// out) invalidates both, unlike [refresh] below.
  void bind(String? riderId) {
    if (riderId == _riderId) return;
    _riderId = riderId;
    _generation++;
    _resetPagination();
    _counts = null;
    _countsStale = true;
    _searchToken++;
    _searchText = '';
    _searching = false;
    _searchResult = null;
    _searchNotFound = false;
    notifyListeners();
  }

  /// Reloads from the first page, for the SAME rider. Deliberately does not
  /// go through [bind] (which would also invalidate [counts] as if this
  /// were a different rider) -- every filter-changing setter calls this, and
  /// only [setDateRange]/[clearFilters] mark counts stale themselves.
  /// Also clears any active search: a status/date filter change while
  /// viewing one search result is read as "show me the filtered list",
  /// not as a silent change underneath an unrelated result still on screen.
  Future<void> refresh() {
    clearSearch();
    _generation++;
    _resetPagination();
    notifyListeners();
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
    // Deliberately not awaited: counts are supplementary (they only
    // annotate the status chips), so a slow or stuck count query must never
    // hold up the main list from rendering. It settles on its own and
    // notifies again when it does.
    if (_countsStale) {
      _countsStale = false;
      unawaited(_loadCounts());
    }
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
