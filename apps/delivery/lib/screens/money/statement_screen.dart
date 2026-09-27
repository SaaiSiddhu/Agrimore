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

  @override
  void initState() {
    super.initState();
    _loadMore();
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
      setState(() {
        _lines.addAll(page.lines);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
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
            EarningTile(earning: e, highlighted: e.orderId == widget.highlightOrderId),
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
