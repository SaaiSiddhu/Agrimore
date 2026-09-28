// lib/screens/history/rider_history_screen.dart
//
// Phase DLV-N1 / Phase 29 — the rider's past orders with filter chips
// (All / Delivered / Not delivered), paged loading, and order detail sheet.
import 'package:agrimore_core/agrimore_core.dart'
    show DeliveryTaskStatus, OrderModel;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/support_card.dart';
import '../../data/order_timeline.dart';
import '../../data/rider_history.dart';
import '../../data/rider_work.dart' show RiderDataError;
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import '../../providers/order_provider.dart';
import '../home/active_work_states.dart';
import '../money/statement_screen.dart';
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

/// Loads one weekly statement by id (null: missing, deleted, or not this
/// rider's own).
typedef PayoutLoader = Future<RiderPayout?> Function(String statementId);

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({
    super.key,
    this.loadEarning,
    this.loadTimeline,
    this.loadPayout,
  });

  /// DLV-N1: injectable for tests; defaults to rider_earnings/{orderId}.
  final EarningLoader? loadEarning;

  /// DLVH2: injectable for tests; defaults to orders/{orderId}/timeline.
  final OrderTimelineLoader? loadTimeline;

  /// DLVH3: injectable for tests; defaults to rider_payouts/{statementId}.
  final PayoutLoader? loadPayout;

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

  PayoutLoader _payoutLoader() {
    final own = widget.loadPayout;
    if (own != null) return own;
    final uid = context.read<DeliveryOrderProvider>().riderId;
    final money = uid == null ? null : RiderMoneyService(uid);
    return (statementId) async => money?.payoutById(statementId);
  }

  void _openDetail(OrderModel order) {
    final load = _earningLoader();
    final timeline = widget.loadTimeline ?? firestoreOrderTimeline;
    final payout = _payoutLoader();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => HistoryDetail(
        order: order,
        loadEarning: load,
        loadTimeline: timeline,
        loadPayout: payout,
      ),
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
                if (_history.isSearchActive) {
                  return Column(
                    children: [
                      _Filters(history: _history),
                      Expanded(child: _SearchResult(history: _history, onTap: _openDetail)),
                    ],
                  );
                }
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

class _Filters extends StatefulWidget {
  const _Filters({required this.history});
  final RiderHistory history;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late final TextEditingController _searchController =
      TextEditingController(text: widget.history.searchText);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final history = widget.history;
    final counts = history.counts;
    final countFor = {
      HistoryFilter.all: counts?.all,
      HistoryFilter.delivered: counts?.delivered,
      HistoryFilter.cancelled: counts?.cancelled,
      HistoryFilter.returned: counts?.returned,
    };
    final statusLabels = {
      HistoryFilter.all: l10n.historyFilterAll,
      HistoryFilter.delivered: l10n.historyFilterDelivered,
      HistoryFilter.cancelled: l10n.historyFilterCancelled,
      HistoryFilter.returned: l10n.historyFilterReturned,
    };
    final rangeLabels = {
      HistoryDateRange.allTime: l10n.historyRangeAllTime,
      HistoryDateRange.last7Days: l10n.historyRangeLast7Days,
      HistoryDateRange.last30Days: l10n.historyRangeLast30Days,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.sm,
        DeliverySpace.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeliverySearchField(
            key: const ValueKey('history-search-field'),
            controller: _searchController,
            hintText: l10n.historyOrderIdSearchHint,
            onChanged: history.search,
            clearTooltip: l10n.historyOrderIdSearchClear,
          ),
          const SizedBox(height: DeliverySpace.sm),
          Wrap(
            spacing: DeliverySpace.sm,
            runSpacing: DeliverySpace.sm,
            children: [
              for (final f in HistoryFilter.values)
                ChoiceChip(
                  key: ValueKey('history-filter-${f.name}'),
                  label: Text(
                    countFor[f] == null ? statusLabels[f]! : '${statusLabels[f]} (${countFor[f]})',
                  ),
                  selected: history.filter == f,
                  onSelected: (_) => history.setFilter(f),
                ),
            ],
          ),
          const SizedBox(height: DeliverySpace.sm),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: DeliverySpace.sm,
                  runSpacing: DeliverySpace.sm,
                  children: [
                    for (final r in HistoryDateRange.values)
                      ChoiceChip(
                        key: ValueKey('history-range-${r.name}'),
                        label: Text(rangeLabels[r]!),
                        selected: history.dateRange == r,
                        onSelected: (_) => history.setDateRange(r),
                      ),
                  ],
                ),
              ),
              if (history.hasActiveFilter)
                TextButton.icon(
                  key: const ValueKey('history-clear-filters'),
                  onPressed: history.clearFilters,
                  icon: Icon(DeliveryIcons.close, size: DeliveryIconSize.sm, color: c.textSecondary),
                  label: Text(l10n.historyClearFilters, style: t.bodyMedium.copyWith(color: c.textSecondary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DLVH7: shown instead of the normal paginated list while a search is
/// active -- an exact match is at most one order, regardless of the current
/// status/date filters (see this phase's own ledger row for why those
/// cannot be combined with the search in one Firestore query).
class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.history, required this.onTap});
  final RiderHistory history;
  final ValueChanged<OrderModel> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (history.searching) return const ActiveWorkLoading();
    // DLVH9: a query FAILURE is not the same fact as a genuine no-match --
    // shown distinctly, with a retry, rather than the not-found message.
    final error = history.searchError;
    if (error != null) {
      return DeliveryErrorState(
        title: switch (error) {
          RiderDataError.permission => l10n.activeWorkErrorPermission,
          RiderDataError.offline => l10n.activeWorkErrorOffline,
          RiderDataError.unknown => l10n.historySearchError,
        },
        retryLabel: l10n.actionRetry,
        onRetry: () => history.search(history.searchText),
      );
    }
    final result = history.searchResult;
    if (result != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: DeliverySpace.sm),
        children: [_HistoryRow(order: result, onTap: () => onTap(result))],
      );
    }
    return DeliveryEmptyState(
      kind: DeliveryIllustrationKind.empty,
      title: l10n.historySearchNotFound,
    );
  }
}

/// DLV-N1 / DLVH2: one order from the rider's side — read-only, no active
/// delivery actions (matches the mockup's own "No active delivery actions
/// are available for completed records"): the delivery timeline, the
/// customer's contact details, recorded earnings and a way to get help.
class HistoryDetail extends StatelessWidget {
  const HistoryDetail({
    super.key,
    required this.order,
    required this.loadEarning,
    required this.loadTimeline,
    required this.loadPayout,
    this.fetchStoreName,
  });
  final OrderModel order;
  final EarningLoader loadEarning;
  final OrderTimelineLoader loadTimeline;
  final PayoutLoader loadPayout;

  /// DLVH6: injectable for tests; defaults to the real `sellers/{id}` read
  /// `ActiveOrderScreen` already established (same name/signature, reused
  /// verbatim, not reimplemented).
  final Future<String?> Function(String sellerId)? fetchStoreName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final status = DeliveryTaskStatus.fromOrderStatus(
      orderStatus: order.orderStatus,
      status: null,
      hasPartner: true,
    );
    final address = order.deliveryAddress;
    return SafeArea(
      child: SingleChildScrollView(
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
              _Line(
                label: l10n.historyDetailPaymentMethod,
                value: order.paymentMethod == 'cod'
                    ? l10n.historyDetailPaymentMethodCod
                    : l10n.historyDetailPaymentMethodOnline,
              ),
              const Divider(height: DeliverySpace.xxl),
              // Cancelled structurally never has a rider_earnings record
              // (recordDeliveryEarningCore is delivered-only) — shown
              // directly, no read attempted. Returned STILL attempts the
              // read: it has none today either, but if the owner later
              // approves paying for a return, this starts working with no
              // client change. Delivered is unchanged.
              if (status == DeliveryTaskStatus.cancelled)
                Text(
                  l10n.historyDetailNoEarningsCancelled,
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
                        status == DeliveryTaskStatus.returned
                            ? l10n.historyDetailNoEarningsReturned
                            : l10n.historyDetailPayPending,
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
                        if (e.statementId == null)
                          Text(
                            l10n.historyDetailNotInStatement,
                            style: t.bodySmall.copyWith(color: c.textSecondary),
                          )
                        else
                          _StatementLink(
                            riderId: order.deliveryPartnerId!,
                            orderId: order.id,
                            statementId: e.statementId!,
                            loadPayout: loadPayout,
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: DeliverySpace.xl),
              _SectionHeading(l10n.historyDetailTimelineTitle),
              const SizedBox(height: DeliverySpace.md),
              FutureBuilder<List<OrderTimelineEvent>>(
                future: loadTimeline(order.id),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      l10n.historyDetailTimelineError,
                      style: t.bodySmall.copyWith(color: c.danger.text),
                    );
                  }
                  if (snap.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  final events = snap.data ?? const <OrderTimelineEvent>[];
                  if (events.isEmpty) {
                    return Text(
                      l10n.historyDetailTimelineEmpty,
                      style: t.bodySmall.copyWith(color: c.textSecondary),
                    );
                  }
                  return DeliveryRouteTimeline(
                    steps: [
                      for (final ev in events)
                        DeliveryTimelineStep(
                          title: ev.title,
                          subtitle: [
                            if (ev.timestamp != null)
                              DeliveryFormat.dateTime(ev.timestamp!),
                            if (ev.detail != null) ev.detail!,
                          ].join('\n'),
                          state: ev.isProblem
                              ? DeliveryTimelineStepState.error
                              : DeliveryTimelineStepState.completed,
                        ),
                    ],
                  );
                },
              ),
              if (order.sellerId != null)
                FutureBuilder<String?>(
                  future: (fetchStoreName ?? defaultFetchStoreName)(order.sellerId!),
                  builder: (context, snap) {
                    final name = snap.data?.trim();
                    if (name == null || name.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeading(l10n.historyDetailMerchantTitle),
                        const SizedBox(height: DeliverySpace.sm),
                        Text(
                          name,
                          style: t.bodyMedium.copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: DeliverySpace.xl),
                      ],
                    );
                  },
                ),
              _SectionHeading(l10n.historyDetailCustomerTitle),
              const SizedBox(height: DeliverySpace.sm),
              if (address.name.isNotEmpty)
                Text(
                  address.name,
                  style: t.bodyMedium.copyWith(color: c.textPrimary),
                ),
              if (address.phone.isNotEmpty)
                Text(
                  address.phone,
                  style: t.bodySmall.copyWith(color: c.textSecondary),
                ),
              Text(
                [
                  address.addressLine1,
                  address.addressLine2,
                  address.city,
                  address.zipcode,
                ].where((s) => s.isNotEmpty).join(', '),
                style: t.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DeliverySpace.xl),
              _SectionHeading(l10n.historyDetailGetHelpTitle),
              const SizedBox(height: DeliverySpace.sm),
              const SupportContactButtons(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.text.titleMedium.copyWith(color: context.colors.textPrimary),
      );
}

/// DLVH3: "In a weekly statement" used to be static text — `statementId`
/// was read only as a boolean (is it null), never as a navigable
/// identifier. Resolves the real statement on tap and opens it; a missing/
/// inaccessible statement or a network failure each say so distinctly
/// rather than doing nothing or crashing, and the row is tappable again
/// either way (a retry needs no dedicated affordance beyond that).
class _StatementLink extends StatefulWidget {
  const _StatementLink({
    required this.riderId,
    required this.orderId,
    required this.statementId,
    required this.loadPayout,
  });
  final String riderId;
  final String orderId;
  final String statementId;
  final PayoutLoader loadPayout;

  @override
  State<_StatementLink> createState() => _StatementLinkState();
}

class _StatementLinkState extends State<_StatementLink> {
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    RiderPayout? payout;
    var failed = false;
    try {
      payout = await widget.loadPayout(widget.statementId);
    } catch (e) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    final l = AppLocalizations.of(context);
    if (failed) {
      showDeliveryToast(
        context,
        message: l.historyDetailStatementNetworkError,
        tone: DeliveryBannerTone.danger,
      );
      return;
    }
    if (payout == null) {
      showDeliveryToast(
        context,
        message: l.historyDetailStatementUnavailable,
        tone: DeliveryBannerTone.danger,
      );
      return;
    }
    final resolved = payout;
    final riderId = widget.riderId;
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => StatementScreen(
          payout: resolved,
          load: (after) =>
              RiderMoneyService(riderId).statementLines(resolved.id, after: after),
          highlightOrderId: widget.orderId,
          onBackToDelivery: () => navigator.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return InkWell(
      key: const ValueKey('history-open-statement'),
      onTap: _open,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.historyDetailInStatement,
              style: t.bodySmall.copyWith(color: c.brand),
            ),
          ),
          const SizedBox(width: DeliverySpace.xxs),
          if (_loading)
            SizedBox(
              width: DeliveryIconSize.sm,
              height: DeliveryIconSize.sm,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.brand),
            )
          else
            Icon(DeliveryIcons.chevronRight, size: DeliveryIconSize.sm, color: c.brand),
        ],
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
