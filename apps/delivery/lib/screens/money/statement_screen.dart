// lib/screens/money/statement_screen.dart
//
// Phase DLV-M1 / Phase 28 — one weekly statement: what was earned, the COD
// cash taken off, what is sent (or was sent, with the reference and the
// destination admin paid), and the deliveries in it a page at a time. A
// statement being made is not money sent — the stage line says which.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import 'money_screen.dart' show EarningTile;

/// Loads the page after [after] (null: the first page).
typedef StatementLoader = Future<StatementPage> Function(
  DocumentSnapshot<Map<String, dynamic>>? after,
);

/// DLVH10: true iff a page whose own cursor id is [newCursorId] represents
/// genuine progress from a page whose cursor id was [previousCursorId] --
/// pulled out as a small pure function so this specific anomaly-detection
/// decision is directly testable without needing a real Firestore
/// DocumentSnapshot. A null cursor is not itself suspicious (statementLines
/// only ever omits one when there is truly nothing to page from); only a
/// genuine repeat of the same real document id counts as no progress.
bool statementCursorAdvanced(String? previousCursorId, String? newCursorId) =>
    newCursorId == null || newCursorId != previousCursorId;

class StatementScreen extends StatefulWidget {
  const StatementScreen({
    super.key,
    required this.payout,
    required this.load,
    this.highlightOrderId,
    this.onBackToDelivery,
  });
  final RiderPayout payout;
  final StatementLoader load;

  /// DLVH4: the order a statement was opened FROM (history's own "in a
  /// weekly statement" link) -- that one line is highlighted. Null for the
  /// other two ways this screen is reached (an inbox statement notice, a
  /// plain tap from the Payouts list), where nothing needs highlighting.
  final String? highlightOrderId;

  /// DLVH4: shown as an explicit "Back to delivery" action only when set --
  /// only the history-detail call site has somewhere meaningful to return
  /// to; the other two callers leave this null and get no such button.
  final VoidCallback? onBackToDelivery;

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _lines = <RiderEarning>[];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _failed = false;

  /// DLVH10: the highlighted row is scrolled into view exactly once per
  /// screen instance -- this guard stops a later, unrelated rebuild from
  /// re-triggering the scroll animation.
  final _highlightRowKey = GlobalKey();
  final _scrollController = ScrollController();
  bool _scrolledToHighlight = false;

  /// DLVH10: a rough average row height, used ONLY to estimate a scroll
  /// offset close to the target BEFORE its own element exists -- `ListView`
  /// (even the plain, non-.builder constructor) still lazily builds Sliver
  /// children by viewport+cache extent, so `Scrollable.ensureVisible` alone
  /// cannot reach an element that was never built because it starts beyond
  /// that range. Does not need to be exact: it only has to land close enough
  /// that the real element gets built, after which [_highlightRowKey]'s own
  /// context lets a precise `ensureVisible` correction take over.
  static const double _kEstimatedRowExtent = 92.0;

  /// DLVH10: the previous call's own cursor id, to detect a backend anomaly
  /// where the cursor does not actually advance despite claiming `hasMore`
  /// (a page repeating itself) -- without this, that would recurse forever.
  String? _previousCursorId;

  /// DLVH10: a hard ceiling on auto-continued pages. "One rider, one week"
  /// is not itself a guarantee, only an expectation about realistic data --
  /// this is the guarantee, enforced in code, not assumed from the domain.
  /// Reaching it can only mean a genuine anomaly; manual "Load more" past it
  /// remains available, since [_hasMore] itself is untouched by the cap.
  static const int _maxAutoContinuePages = 20;
  int _autoContinuedPages = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  /// DLVH8/DLVH10: [widget.highlightOrderId] must be highlighted wherever in
  /// this statement it actually is -- not only when it happens to land on
  /// the first page, and not beyond [_maxAutoContinuePages] (a real,
  /// disclosed boundary, never a silent infinite loop).
  bool get _stillLookingForHighlight {
    final target = widget.highlightOrderId;
    if (target == null || !_hasMore) return false;
    if (_autoContinuedPages >= _maxAutoContinuePages) return false;
    return !_lines.any((e) => e.orderId == target);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.load(_cursor);
      if (!mounted) return;
      final newCursorId = page.cursor?.id;
      final cursorAdvanced = statementCursorAdvanced(_previousCursorId, newCursorId);
      if (!cursorAdvanced) debugPrint('Statement lines ${widget.payout.id}: cursor did not advance, stopping');
      setState(() {
        final seen = _lines.map((e) => e.orderId).toSet();
        _lines.addAll(page.lines.where((e) => !seen.contains(e.orderId)));
        _cursor = page.cursor;
        _hasMore = page.hasMore && cursorAdvanced;
        _loading = false;
      });
      _previousCursorId = newCursorId;
      if (cursorAdvanced) _autoContinuedPages++;
      if (_stillLookingForHighlight) {
        await _loadMore();
      } else {
        _scrollToHighlightIfFound();
      }
    } catch (e) {
      debugPrint('Statement lines ${widget.payout.id}: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// DLVH10: once genuinely found (not merely exhausted-and-absent), the
  /// highlighted row is scrolled into the visible viewport -- correct color
  /// alone is not enough if the rider still has to blindly scroll past
  /// everything else to ever see it. Two steps, since a target beyond the
  /// Sliver's own initial cache extent has no element (and so no context)
  /// to `ensureVisible` yet: (1) an estimated jump close to it, so the
  /// Sliver actually builds it; (2) a precise correction now that it exists.
  void _scrollToHighlightIfFound() {
    if (_scrolledToHighlight) return;
    final target = widget.highlightOrderId;
    if (target == null) return;
    final index = _lines.indexWhere((e) => e.orderId == target);
    if (index == -1) return;
    _scrolledToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final estimate = (index * _kEstimatedRowExtent).clamp(0.0, _scrollController.position.maxScrollExtent);
      await _scrollController.animateTo(estimate, duration: DeliveryMotion.debounce, curve: DeliveryMotion.standard);
      final ctx = _highlightRowKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, duration: DeliveryMotion.fast, alignment: 0.5);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final p = widget.payout;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.statementTitle)),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          DeliverySpace.page,
          DeliverySpace.sm,
          DeliverySpace.page,
          DeliverySpace.xxxl,
        ),
        children: [
          Text(
            payoutTitle(l, p),
            style: t.titleLarge.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.xxs),
          Text(
            l.moneyDeliveries(p.orderCount),
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DeliverySpace.md),
          DeliveryCard(
            padding: const EdgeInsets.all(DeliverySpace.md),
            child: Column(
              children: [
                _AmountRow(label: l.statementEarned, amount: p.earned),
                if (p.netted > 0)
                  _AmountRow(label: l.statementCashOff, amount: -p.netted),
                const Divider(height: DeliverySpace.lg),
                _AmountRow(
                  label: p.status == 'paid' ? l.statementSent : l.statementToPay,
                  amount: p.amount,
                  strong: true,
                ),
                if (p.cashHeldAfter > 0)
                  _AmountRow(
                    label: l.statementCashAfter,
                    amount: p.cashHeldAfter,
                  ),
              ],
            ),
          ),
          const SizedBox(height: DeliverySpace.md),
          _StageBlock(payout: p),
          const SizedBox(height: DeliverySpace.xl),
          Text(
            l.statementDeliveries,
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.sm),
          for (final e in _lines)
            KeyedSubtree(
              key: e.orderId == widget.highlightOrderId ? _highlightRowKey : null,
              child: EarningTile(earning: e, highlighted: e.orderId == widget.highlightOrderId),
            ),
          _footer(l),
          if (widget.onBackToDelivery != null) ...[
            const SizedBox(height: DeliverySpace.md),
            DeliveryButton.secondary(
              key: const ValueKey('back-to-delivery'),
              label: l.statementBackToDelivery,
              onPressed: widget.onBackToDelivery,
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer(AppLocalizations l) {
    final c = context.colors;
    final t = context.text;
    final Widget child;
    if (_loading) {
      child = const CircularProgressIndicator();
    } else if (_failed) {
      child = Column(
        children: [
          Text(
            l.statementLinesError,
            textAlign: TextAlign.center,
            style: t.bodyMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.sm),
          DeliveryButton.secondary(
            label: l.actionRetry,
            fullWidth: false,
            onPressed: _loadMore,
          ),
        ],
      );
    } else if (_hasMore) {
      child = DeliveryButton.secondary(
        label: l.statementLoadMore,
        fullWidth: false,
        onPressed: _loadMore,
      );
    } else if (_lines.isEmpty) {
      child = Text(
        l.statementLinesEmpty,
        style: t.bodyMedium.copyWith(color: c.textSecondary),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(DeliverySpace.lg),
      child: Center(child: child),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });
  final String label;
  final double amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final style =
        (strong ? t.titleMedium : t.bodyMedium).copyWith(color: c.textPrimary);
    final value = amount < 0
        ? '− ${DeliveryFormat.rupees(-amount)}'
        : DeliveryFormat.rupees(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DeliverySpace.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _StageBlock extends StatelessWidget {
  const _StageBlock({required this.payout});
  final RiderPayout payout;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final p = payout;
    final stage = payoutStage(p);
    final (Color fg, Color bg, IconData icon) = switch (stage) {
      PayoutStage.paid => (
          c.success.text,
          c.success.container,
          DeliveryIcons.checkCircle,
        ),
      PayoutStage.heldForReview || PayoutStage.heldNoDetails => (
          c.warning.text,
          c.warning.container,
          DeliveryIcons.warning,
        ),
      _ => (c.info.text, c.info.container, DeliveryIcons.clock),
    };
    final notes = <String>[
      if (stage == PayoutStage.paid && payoutDestinationText(l, p) != null)
        payoutDestinationText(l, p)!,
      if (stage == PayoutStage.paid && p.paidAt != null)
        l.statementSentOn(DeliveryFormat.dateTime(p.paidAt!.toLocal())),
      if (p.createdAt != null)
        l.statementMadeOn(DeliveryFormat.dateTime(p.createdAt!.toLocal())),
    ];
    return Container(
      padding: const EdgeInsets.all(DeliverySpace.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DeliveryRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: DeliverySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payoutStageText(l, p),
                  style: t.titleSmall.copyWith(color: fg),
                ),
                for (final n in notes) ...[
                  const SizedBox(height: DeliverySpace.xxs),
                  Text(
                    n,
                    style: t.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
