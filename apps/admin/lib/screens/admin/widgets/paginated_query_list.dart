// ADMR-57 — extracted from ADMR-56's customer_detail_screen.dart so every
// People-360 workspace (Customer, Seller, Delivery Partner, Sales
// Associate) shares one implementation instead of four private copies.
// No behavior change from the original.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A generic "couldn't load / nothing here" panel, used for empty and
/// error states across every 360 workspace so they look and read the same.
/// Pass [onRetry] to add a working "Try again" action -- ADMR-60: an error
/// state with no way back in wasn't just cosmetic, it was a dead end an
/// admin could only escape by leaving and reopening the whole screen.
class SectionMessage extends StatelessWidget {
  const SectionMessage({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
  });
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// A cursor-based (startAfterDocument), stale-response-guarded paginated
/// list over any already-ordered query. One section's failure never
/// affects a sibling section because each owns its own instance and its
/// own error state.
class PaginatedQueryList extends StatefulWidget {
  const PaginatedQueryList({
    super.key,
    required this.baseQuery,
    required this.itemBuilder,
    required this.emptyLabel,
    this.pageSize = 20,
    this.shrinkWrapInList = false,
    this.resetKey,
  });

  final Query<Map<String, dynamic>> baseQuery;
  final Widget Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>)
      itemBuilder;
  final String emptyLabel;
  final int pageSize;

  /// True when this list is itself placed inside another scrollable
  /// (e.g. a tab's outer ListView) and must size itself instead of
  /// trying to scroll independently.
  final bool shrinkWrapInList;

  /// ADMR-60: identifies the semantic query (e.g. a status/assignee filter
  /// value), not the [baseQuery] object itself -- Query has no stable
  /// equality, and every rebuild constructs a new instance regardless of
  /// whether the filter actually changed, so comparing it directly would
  /// either never fire or fire every frame. When [resetKey] changes between
  /// one build and the next, all loaded state clears and a fresh fetch
  /// starts; any in-flight request tied to the old query is invalidated via
  /// the existing request-id guard. Every People-360 caller today keys this
  /// whole widget by entity id instead (a fresh element per entity, so there
  /// is nothing to reset) and can safely leave this null; a filterable
  /// queue that reuses the same widget instance across filter changes must
  /// pass one.
  final Object? resetKey;

  @override
  State<PaginatedQueryList> createState() => _PaginatedQueryListState();
}

class _PaginatedQueryListState extends State<PaginatedQueryList> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  bool _initialLoadDone = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant PaginatedQueryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) {
      _docs.clear();
      _cursor = null;
      _hasMore = true;
      _initialLoadDone = false;
      _error = null;
      _loading = false; // an old in-flight request must not block the new fetch
      _requestId++; // invalidates any in-flight request from the old query
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final myRequest = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = widget.baseQuery.limit(widget.pageSize);
      final cursor = _cursor;
      if (cursor != null) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      if (!mounted || myRequest != _requestId) return;
      setState(() {
        _docs.addAll(snap.docs);
        _hasMore = snap.docs.length == widget.pageSize;
        if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
        _initialLoadDone = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || myRequest != _requestId) return;
      setState(() {
        _error = e;
        _loading = false;
        _initialLoadDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoadDone && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _docs.isEmpty) {
      return SectionMessage(
        icon: Icons.error_outline,
        message: "Couldn't load this. Check your connection and try again.",
        onRetry: _loadMore,
      );
    }
    if (_docs.isEmpty) {
      return SectionMessage(
          icon: Icons.inbox_outlined, message: widget.emptyLabel);
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final d in _docs) widget.itemBuilder(context, d),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _loading
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: _loadMore, child: const Text('Load more')),
          ),
        if (_error != null && _docs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Could not load more -- retry above',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ),
      ],
    );

    if (widget.shrinkWrapInList) return content;
    return ListView(padding: const EdgeInsets.only(top: 8), children: [content]);
  }
}
