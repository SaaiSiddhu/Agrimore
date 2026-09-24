// lib/screens/history/rider_history_screen.dart
//
// Phase DLV-C1 — the rider's orders, newest first, page by page
// (data/rider_history.dart). Replaces a bottom sheet whose query needed an
// index that was never created, so in production it always said
// "No deliveries yet". Shows no customer details: order number, date,
// state, amount.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/rider_history.dart';
import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import '../../providers/order_provider.dart';
import '../home/active_work_states.dart';

String historyStatusText(AppLocalizations l, String orderStatus) {
  final s = DeliveryTaskStatus.fromOrderStatus(orderStatus: orderStatus, status: null, hasPartner: true);
  return switch (s) {
    DeliveryTaskStatus.delivered => l.historyStatusDelivered,
    DeliveryTaskStatus.cancelled => l.historyStatusCancelled,
    DeliveryTaskStatus.returned => l.historyStatusReturned,
    null || DeliveryTaskStatus.searching => l.historyStatusOther,
    _ => l.historyStatusActive,
  };
}

/// Loads this rider's pay for an order (null: none yet).
typedef EarningLoader = Future<RiderEarning?> Function(String orderId);

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key, this.loadEarning});

  /// DLV-N1: injectable for tests; defaults to rider_earnings/{orderId}.
  final EarningLoader? loadEarning;

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  late final RiderHistory _history = context.read<DeliveryOrderProvider>().history;

  @override
  void initState() {
    super.initState();
    if (_history.notStarted) _history.loadMore();
  }

  EarningLoader _earningLoader() {
    final own = widget.loadEarning;
    if (own != null) return own;
    final uid = context.read<DeliveryOrderProvider>().riderId;
    final money = uid == null ? null : RiderMoneyService(uid);
    return (orderId) async => money?.earningFor(orderId);
  }

  void _openDetail(OrderModel order) {
    final load = _earningLoader();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => HistoryDetail(order: order, loadEarning: load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: ListenableBuilder(
        listenable: _history,
        builder: (context, _) {
          final items = _history.items;
          if (items.isEmpty && _history.loading) return const ActiveWorkLoading();
          if (items.isEmpty && _history.error != null) {
            return ActiveWorkError(error: _history.error!, onRetry: _history.refresh);
          }
          if (items.isEmpty && !_history.hasMore) {
            return Column(children: [
              _Filters(history: _history),
              Expanded(
                  child: _Empty(
                      text: _history.filter == HistoryFilter.all ? l10n.historyEmpty : l10n.historyEmptyFiltered)),
            ]);
          }
          return RefreshIndicator(
            onRefresh: _history.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
              itemCount: items.length + 2,
              separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: WsSize.hairline),
              itemBuilder: (context, i) {
                if (i == 0) return Column(children: [_Filters(history: _history), _Hint(text: l10n.historyHint)]);
                if (i == items.length + 1) return _Footer(history: _history);
                return _HistoryRow(order: items[i - 1], onTap: () => _openDetail(items[i - 1]));
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s4),
      title: Text(l10n.historyOrderNumber(order.orderNumber), style: text.titleSmall),
      subtitle: Text(
        '${AgFormat.dateTime(order.createdAt)} · ${historyStatusText(l10n, order.orderStatus)}',
        style: text.bodySmall?.copyWith(color: t.textSecondary),
      ),
      trailing: Text(AgFormat.rupees(order.total), style: text.titleSmall),
      onTap: onTap,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s4, WsSpace.page, WsSpace.s8),
        child: Text(text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.ws.textTertiary)),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.history});
  final RiderHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget child;
    if (history.loading) {
      child = const CircularProgressIndicator();
    } else if (history.error != null) {
      child = Column(children: [
        Text(riderDataErrorText(l10n, history.error!), textAlign: TextAlign.center),
        const SizedBox(height: WsSpace.s8),
        OutlinedButton(onPressed: history.loadMore, child: Text(l10n.actionRetry)),
      ]);
    } else if (history.hasMore) {
      child = OutlinedButton(onPressed: history.loadMore, child: Text(l10n.historyLoadMore));
    } else {
      child = Text(l10n.historyEnd,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.ws.textTertiary));
    }
    return Padding(padding: const EdgeInsets.all(WsSpace.s16), child: Center(child: child));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(AgIcons.orders, size: WsIconSize.empty, color: t.textTertiary),
        const SizedBox(height: WsSpace.s12),
        Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.textSecondary)),
      ]),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.history});
  final RiderHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      HistoryFilter.all: l10n.historyFilterAll,
      HistoryFilter.delivered: l10n.historyFilterDelivered,
      HistoryFilter.notDelivered: l10n.historyFilterNotDelivered,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, 0),
      child: Wrap(
        spacing: WsSpace.s8,
        runSpacing: WsSpace.s8,
        children: [
          for (final f in HistoryFilter.values)
            ChoiceChip(
              key: ValueKey('history-filter-${f.name}'),
              label: Text(labels[f]!),
              selected: history.filter == f,
              onSelected: (_) => history.setFilter(f),
            ),
        ],
      ),
    );
  }
}

/// DLV-N1: one order from the rider's side — no customer details.
class HistoryDetail extends StatelessWidget {
  const HistoryDetail({super.key, required this.order, required this.loadEarning});
  final OrderModel order;
  final EarningLoader loadEarning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final delivered = DeliveryTaskStatus.fromOrderStatus(orderStatus: order.orderStatus, status: null, hasPartner: true) ==
        DeliveryTaskStatus.delivered;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.historyOrderNumber(order.orderNumber), style: text.titleLarge),
            const SizedBox(height: WsSpace.s4),
            Text([AgFormat.dateTime(order.createdAt), historyStatusText(l10n, order.orderStatus)].join(' · '),
                style: text.bodySmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: WsSpace.s16),
            _Line(label: l10n.historyDetailOrderTotal, value: AgFormat.rupees(order.total)),
            const Divider(height: WsSpace.s24),
            if (!delivered)
              Text(l10n.historyDetailPayPending, style: text.bodyMedium?.copyWith(color: t.textSecondary))
            else
              FutureBuilder<RiderEarning?>(
                future: loadEarning(order.id),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(l10n.historyDetailPayError, style: text.bodyMedium?.copyWith(color: t.errorFg));
                  }
                  if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
                  final e = snap.data;
                  if (e == null) {
                    return Text(l10n.historyDetailPayPending, style: text.bodyMedium?.copyWith(color: t.textSecondary));
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Line(label: l10n.historyDetailPay, value: AgFormat.rupees(e.total), strong: true),
                    Text(earningBreakdown(l10n, e), style: text.bodySmall?.copyWith(color: t.textSecondary)),
                    if (e.codCollected > 0) _Line(label: l10n.historyDetailCash, value: AgFormat.rupees(e.codCollected)),
                    const SizedBox(height: WsSpace.s8),
                    Text(e.statementId == null ? l10n.historyDetailNotInStatement : l10n.historyDetailInStatement,
                        style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ]);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = strong ? text.titleMedium : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}
