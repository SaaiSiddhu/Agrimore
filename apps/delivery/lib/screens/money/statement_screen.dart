// lib/screens/money/statement_screen.dart
//
// Phase DLV-M1 — one weekly statement: what was earned, the COD cash taken
// off, what is sent (or was sent, with the reference and the destination
// admin paid), and the deliveries in it a page at a time. A statement being
// made is not money sent — the stage line says which.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import 'money_screen.dart' show EarningTile;

/// Loads the page after [after] (null: the first page).
typedef StatementLoader = Future<StatementPage> Function(DocumentSnapshot<Map<String, dynamic>>? after);

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key, required this.payout, required this.load});
  final RiderPayout payout;
  final StatementLoader load;

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
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final p = widget.payout;
    return Scaffold(
      appBar: AppBar(title: Text(l.statementTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, WsSpace.s32),
        children: [
          Text(payoutTitle(l, p), style: text.titleLarge),
          const SizedBox(height: WsSpace.s4),
          Text(l.moneyDeliveries(p.orderCount), style: text.bodySmall?.copyWith(color: t.textSecondary)),
          const SizedBox(height: WsSpace.s12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s12),
              child: Column(children: [
                _AmountRow(label: l.statementEarned, amount: p.earned),
                if (p.netted > 0) _AmountRow(label: l.statementCashOff, amount: -p.netted),
                const Divider(height: WsSpace.s16),
                _AmountRow(
                    label: p.status == 'paid' ? l.statementSent : l.statementToPay, amount: p.amount, strong: true),
                if (p.cashHeldAfter > 0) _AmountRow(label: l.statementCashAfter, amount: p.cashHeldAfter),
              ]),
            ),
          ),
          const SizedBox(height: WsSpace.s12),
          _StageBlock(payout: p),
          const SizedBox(height: WsSpace.s20),
          Text(l.statementDeliveries, style: text.titleMedium),
          const SizedBox(height: WsSpace.s8),
          for (final e in _lines) EarningTile(earning: e),
          _footer(l),
        ],
      ),
    );
  }

  Widget _footer(AppLocalizations l) {
    final text = Theme.of(context).textTheme;
    final Widget child;
    if (_loading) {
      child = const CircularProgressIndicator();
    } else if (_failed) {
      child = Column(children: [
        Text(l.statementLinesError, textAlign: TextAlign.center, style: text.bodyMedium),
        const SizedBox(height: WsSpace.s8),
        OutlinedButton(onPressed: _loadMore, child: Text(l.actionRetry)),
      ]);
    } else if (_hasMore) {
      child = OutlinedButton(onPressed: _loadMore, child: Text(l.statementLoadMore));
    } else if (_lines.isEmpty) {
      child = Text(l.statementLinesEmpty, style: text.bodyMedium?.copyWith(color: context.ws.textSecondary));
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(padding: const EdgeInsets.all(WsSpace.s16), child: Center(child: child));
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount, this.strong = false});
  final String label;
  final double amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = strong ? text.titleMedium : text.bodyMedium;
    final value = amount < 0 ? '− ${AgFormat.rupees(-amount)}' : AgFormat.rupees(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ]),
    );
  }
}

class _StageBlock extends StatelessWidget {
  const _StageBlock({required this.payout});
  final RiderPayout payout;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final p = payout;
    final stage = payoutStage(p);
    final (Color fg, Color bg, IconData icon) = switch (stage) {
      PayoutStage.paid => (t.successFg, t.successBg, AgIcons.success),
      PayoutStage.heldForReview || PayoutStage.heldNoDetails => (t.warningFg, t.warningBg, AgIcons.warning),
      _ => (t.infoFg, t.infoBg, AgIcons.clock),
    };
    final notes = <String>[
      if (stage == PayoutStage.paid && payoutDestinationText(l, p) != null) payoutDestinationText(l, p)!,
      if (stage == PayoutStage.paid && p.paidAt != null) l.statementSentOn(AgFormat.dateTime(p.paidAt!.toLocal())),
      if (p.createdAt != null) l.statementMadeOn(AgFormat.dateTime(p.createdAt!.toLocal())),
    ];
    return Container(
      padding: const EdgeInsets.all(WsSpace.s12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(WsRadius.card)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg),
        const SizedBox(width: WsSpace.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(payoutStageText(l, p), style: text.titleSmall?.copyWith(color: fg)),
            for (final n in notes) ...[
              const SizedBox(height: WsSpace.s4),
              Text(n, style: text.bodySmall?.copyWith(color: t.textSecondary)),
            ],
          ]),
        ),
      ]),
    );
  }
}
