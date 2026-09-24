// lib/screens/history/rider_history_screen.dart
//
// Phase DLV-C1 — the rider's orders, newest first, page by page
// (data/rider_history.dart). Replaces a bottom sheet whose query needed an
// index that was never created, so in production it always said
// "No deliveries yet". Shows no customer details: order number, date,
// state, amount.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/rider_history.dart';
import '../../l10n/app_localizations.dart';
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

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key});

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
          if (items.isEmpty && !_history.hasMore) return _Empty(text: l10n.historyEmpty);
          return RefreshIndicator(
            onRefresh: _history.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
              itemCount: items.length + 2,
              separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: WsSize.hairline),
              itemBuilder: (context, i) {
                if (i == 0) return _Hint(text: l10n.historyHint);
                if (i == items.length + 1) return _Footer(history: _history);
                return _HistoryRow(order: items[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order});
  final OrderModel order;

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
