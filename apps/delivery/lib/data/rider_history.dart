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

/// Fetches a page of [riderId]'s orders after [cursor] (null = first page).
typedef HistoryFetch = Future<HistoryPage> Function(String riderId, Object? cursor, int size);

Future<HistoryPage> firestoreHistoryPage(String riderId, Object? cursor, int size) async {
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('orders')
      .where('deliveryPartnerId', isEqualTo: riderId)
      .orderBy('createdAt', descending: true);
  if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
  // One extra row tells whether another page exists.
  final snap = await q.limit(size + 1).get();
  final docs = snap.docs;
  final page = docs.take(size).toList();
  return (
    items: page.map((d) => OrderModel.fromMap(d.data(), d.id)).toList(),
    cursor: page.isEmpty ? cursor : page.last,
    hasMore: docs.length > size,
  );
}

class RiderHistory extends ChangeNotifier {
  RiderHistory({HistoryFetch? fetch, this.pageSize = kHistoryPageSize}) : _fetch = fetch ?? firestoreHistoryPage;

  final HistoryFetch _fetch;
  final int pageSize;

  String? _riderId;
  int _generation = 0;
  final List<OrderModel> _items = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  RiderDataError? _error;

  List<OrderModel> get items => List.unmodifiable(_items);
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
      final page = await _fetch(riderId, _cursor, pageSize);
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
