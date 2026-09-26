// lib/screens/history/rider_history_screen.dart
//
// Phase DLV-N1 / Phase 29 — the rider's past orders with filter chips
// (All / Delivered / Not delivered), paged loading, and order detail sheet.
import 'package:agrimore_core/agrimore_core.dart'
    show DeliveryTaskStatus, OrderModel;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/rider_history.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import '../../providers/order_provider.dart';
import '../home/active_work_states.dart';
import '../orders/active_order_screen.dart';

String historyStatusText(AppLocalizations l, String orderStatus) {
  final s = DeliveryTaskStatus.fromOrderStatus(
    orderStatus: orderStatus,
    status: null,
    hasPartner: true,
  );
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
  late final RiderHistory _history =
      context.read<DeliveryOrderProvider>().history;

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

  void _openOrder(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ActiveOrderScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    // DLVNAV1: this is the shell's Deliveries tab — "active work and
    // delivery history" (brief §4) — so active work leads, independent of
    // whatever state the history list below is in.
    final work = context.watch<DeliveryOrderProvider>().work;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: Column(
        children: [
          if (work.hasMultiple)
            MultipleActiveOrders(orders: work.orders, onOpen: _openOrder)
          else if (work.single != null)
            ActiveOrderSummaryCard(order: work.single!, onOpen: _openOrder),
          Expanded(
            child: ListenableBuilder(
              listenable: _history,
              builder: (context, _) {
                final items = _history.items;
                if (items.isEmpty && _history.loading) {
                  return const ActiveWorkLoading();
                }
                if (items.isEmpty && _history.error != null) {
                  return ActiveWorkError(
                    error: _history.error!,
                    onRetry: _history.refresh,
                  );
                }
                if (items.isEmpty && !_history.hasMore) {
                  return Column(
                    children: [
                      _Filters(history: _history),
                      Expanded(
                        child: _Empty(
                          text: _history.filter == HistoryFilter.all
                              ? l10n.historyEmpty
                              : l10n.historyEmptyFiltered,
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: _history.refresh,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: DeliverySpace.sm),
                    itemCount: items.length + 2,
                    separatorBuilder: (_, i) => i == 0
                        ? const SizedBox.shrink()
                        : const Divider(height: DeliverySize.hairline),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Column(
                          children: [
                            _Filters(history: _history),
                            _Hint(text: l10n.historyHint),
                          ],
                        );
                      }
                      if (i == items.length + 1) {
                        return _Footer(history: _history);
                      }
                      return _HistoryRow(
                        order: items[i - 1],
                        onTap: () => _openDetail(items[i - 1]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
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
    final c = context.colors;
    final t = context.text;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.page,
        vertical: DeliverySpace.xxs,
      ),
      title: Text(
        l10n.historyOrderNumber(order.orderNumber),
        style: t.titleSmall.copyWith(color: c.textPrimary),
      ),
      subtitle: Text(
        '${DeliveryFormat.dateTime(order.createdAt)} · ${historyStatusText(l10n, order.orderStatus)}',
        style: t.bodySmall.copyWith(color: c.textSecondary),
      ),
      trailing: Text(
        DeliveryFormat.rupees(order.total),
        style: t.titleSmall.copyWith(color: c.textPrimary),
      ),
      onTap: onTap,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          DeliverySpace.page,
          DeliverySpace.xxs,
          DeliverySpace.page,
          DeliverySpace.sm,
        ),
        child: Text(
          text,
          style: context.text.bodySmall.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.history});
  final RiderHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final Widget child;
    if (history.loading) {
      child = const CircularProgressIndicator();
    } else if (history.error != null) {
      child = Column(
        children: [
          Text(
            riderDataErrorText(l10n, history.error!),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DeliverySpace.sm),
          DeliveryButton.secondary(
            label: l10n.actionRetry,
            fullWidth: false,
            onPressed: history.loadMore,
          ),
        ],
      );
    } else if (history.hasMore) {
      child = DeliveryButton.secondary(
        label: l10n.historyLoadMore,
        fullWidth: false,
        onPressed: history.loadMore,
      );
    } else {
      child = Text(
        l10n.historyEnd,
        style: t.bodySmall.copyWith(color: c.textTertiary),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(DeliverySpace.lg),
      child: Center(child: child),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return DeliveryEmptyState(
      kind: DeliveryIllustrationKind.emptyHistory,
      title: text,
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
      padding: const EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.sm,
        DeliverySpace.page,
        0,
      ),
      child: Wrap(
        spacing: DeliverySpace.sm,
        runSpacing: DeliverySpace.sm,
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
  const HistoryDetail({
    super.key,
    required this.order,
    required this.loadEarning,
  });
  final OrderModel order;
  final EarningLoader loadEarning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final delivered = DeliveryTaskStatus.fromOrderStatus(
          orderStatus: order.orderStatus,
          status: null,
          hasPartner: true,
        ) ==
        DeliveryTaskStatus.delivered;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DeliverySpace.page,
          0,
          DeliverySpace.page,
          DeliverySpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.historyOrderNumber(order.orderNumber),
              style: t.titleLarge.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DeliverySpace.xxs),
            Text(
              [
                DeliveryFormat.dateTime(order.createdAt),
                historyStatusText(l10n, order.orderStatus),
              ].join(' · '),
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.lg),
            _Line(
              label: l10n.historyDetailOrderTotal,
              value: DeliveryFormat.rupees(order.total),
            ),
            const Divider(height: DeliverySpace.xxl),
            if (!delivered)
              Text(
                l10n.historyDetailPayPending,
                style: t.bodyMedium.copyWith(color: c.textSecondary),
              )
            else
              FutureBuilder<RiderEarning?>(
                future: loadEarning(order.id),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      l10n.historyDetailPayError,
                      style: t.bodyMedium.copyWith(color: c.danger.text),
                    );
                  }
                  if (snap.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  final e = snap.data;
                  if (e == null) {
                    return Text(
                      l10n.historyDetailPayPending,
                      style: t.bodyMedium.copyWith(color: c.textSecondary),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Line(
                        label: l10n.historyDetailPay,
                        value: DeliveryFormat.rupees(e.total),
                        strong: true,
                      ),
                      Text(
                        earningBreakdown(l10n, e),
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                      if (e.codCollected > 0)
                        _Line(
                          label: l10n.historyDetailCash,
                          value: DeliveryFormat.rupees(e.codCollected),
                        ),
                      const SizedBox(height: DeliverySpace.sm),
                      Text(
                        e.statementId == null
                            ? l10n.historyDetailNotInStatement
                            : l10n.historyDetailInStatement,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final style =
        (strong ? t.titleMedium : t.bodyMedium).copyWith(color: c.textPrimary);
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
