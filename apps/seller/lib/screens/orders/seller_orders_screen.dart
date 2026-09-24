import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import 'order_stage.dart';
import 'seller_order_detail_screen.dart';

/// Stage label + tone, shared by the list and the detail screen.
extension OrderStageCopy on AppLocalizations {
  String stageLabel(OrderStage s) => switch (s) {
        OrderStage.toAccept => stageToAccept,
        OrderStage.toPack => stageToPack,
        OrderStage.packing => stagePacking,
        OrderStage.ready => stageReady,
        OrderStage.outForDelivery => stageOutForDelivery,
        OrderStage.delivered => stageDelivered,
        OrderStage.cancelled => stageCancelled,
        OrderStage.other => stageOther,
      };

  String filterLabel(OrderStage? s) => s == null ? filterAll : stageLabel(s);

  String stageGuide(OrderStage s) => switch (s) {
        OrderStage.toAccept => orderGuideToAccept,
        OrderStage.toPack => orderGuideToPack,
        OrderStage.packing => orderGuidePacking,
        OrderStage.ready => orderGuideReady,
        OrderStage.outForDelivery => orderGuideOut,
        OrderStage.delivered => orderGuideDelivered,
        OrderStage.cancelled || OrderStage.other => orderGuideCancelled,
      };
}

/// Each stage has its own icon shape and tone (boards 12, 24-06).
(SellerTone, IconData) orderStageStyle(OrderStage s) => switch (s) {
      OrderStage.toAccept => (SellerTone.warning, SellerIcons.pending),
      OrderStage.toPack => (SellerTone.success, SellerIcons.success),
      OrderStage.packing => (SellerTone.info, SellerIcons.packing),
      OrderStage.ready => (SellerTone.info, SellerIcons.ready),
      OrderStage.outForDelivery => (SellerTone.info, SellerIcons.delivery),
      OrderStage.delivered => (SellerTone.success, SellerIcons.success),
      OrderStage.cancelled || OrderStage.other => (SellerTone.neutral, SellerIcons.cancelled),
    };

class OrderStagePill extends StatelessWidget {
  const OrderStagePill({super.key, required this.stage});
  final OrderStage stage;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = orderStageStyle(stage);
    return SellerStatusBadge(label: AppLocalizations.of(context).stageLabel(stage), tone: tone, icon: icon);
  }
}

/// O-01 Orders (board 17-01): search, stage chips with counts, period and
/// B2B chips, one card per order; list + detail side by side from 840 dp.
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key, this.now});

  /// Fixed clock for tests.
  final DateTime? now;

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final _query = TextEditingController();
  OrderPeriod _period = OrderPeriod.all;
  bool _b2bOnly = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    if (uid != null) context.read<SellerOrderProvider>().loadSellerOrders(uid);
  }

  void _open(OrderModel o, bool split) {
    if (split) {
      setState(() => _selectedId = o.id);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerOrderDetailScreen(order: o)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<SellerOrderProvider>();
    final all = provider.allOrders;
    final counts = <OrderStage, int>{};
    for (final o in all) {
      final s = orderStageOf(o.orderStatus);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final now = widget.now ?? DateTime.now();
    final selected = kOrderFilters.firstWhere((f) => f.$1 == provider.selectedFilter, orElse: () => kOrderFilters.first).$2;
    final shown = all
        .where((o) => selected == null || orderStageOf(o.orderStatus) == selected)
        .where((o) => orderMatches(o, _query.text))
        .where((o) => inPeriod(o, _period, now))
        .where((o) => !_b2bOnly || isB2bOrder(o))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final split = context.layout.index >= SellerLayout.expanded.index;

    Widget body;
    if (provider.error != null) {
      body = SellerErrorState(title: l10n.ordersLoadFailed, onRetry: _reload, retryLabel: l10n.statusRefresh);
    } else if (provider.isLoading && all.isEmpty) {
      body = SellerSkeletonList(label: l10n.dsLoading, thumbnail: false);
    } else if (shown.isEmpty) {
      body = SellerEmptyState(
        icon: SellerIcons.packageOpen,
        title: all.isEmpty ? l10n.ordersEmpty : l10n.ordersNoneMatch,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s4, context.pageInset, SellerSpace.s24),
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(height: SellerSpace.s12),
          itemBuilder: (context, i) => OrderCard(
            order: shown[i],
            selected: split && shown[i].id == _selectedId,
            onTap: () => _open(shown[i], split),
          ),
        ),
      );
    }

    final list = Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s4, context.pageInset, SellerSpace.s8),
        child: SellerSearchField(controller: _query, hint: l10n.ordersSearchHint, onChanged: (_) => setState(() {})),
      ),
      SellerChipBar(padding: EdgeInsets.symmetric(horizontal: context.pageInset), children: [
        for (final (key, stage) in kOrderFilters)
          SellerChip(
            label: l10n.filterLabel(stage),
            count: stage == null ? all.length : counts[stage] ?? 0,
            selected: provider.selectedFilter == key,
            onSelected: (_) => provider.setFilter(key),
          ),
      ]),
      SellerChipBar(padding: EdgeInsets.fromLTRB(context.pageInset, 0, context.pageInset, SellerSpace.s4), children: [
        for (final (p, label) in [
          (OrderPeriod.all, l10n.periodAll),
          (OrderPeriod.today, l10n.periodToday),
          (OrderPeriod.days7, l10n.period7d),
          (OrderPeriod.days30, l10n.period30d),
        ])
          SellerChip(label: label, selected: _period == p, onSelected: (_) => setState(() => _period = p)),
        SellerChip(
          label: l10n.ordersB2bOnly,
          icon: SellerIcons.business,
          style: SellerChipStyle.toggle,
          selected: _b2bOnly,
          onSelected: (v) => setState(() => _b2bOnly = v),
        ),
      ]),
      Expanded(child: body),
    ]);

    final chosen = all.where((o) => o.id == _selectedId).firstOrNull;
    return Scaffold(
      appBar: SellerAppBar.root(context, title: l10n.navOrders),
      body: split
          ? SellerListDetail(
              list: list,
              detail: chosen == null
                  ? SellerEmptyState(icon: SellerIcons.orders, title: l10n.orderSelectPrompt)
                  : SellerOrderDetailScreen(key: ValueKey(chosen.id), order: chosen, embedded: true),
            )
          : list,
    );
  }
}

/// Order card (board 17-01): identity + stage, customer · time, items ·
/// payment, total. Read as one sentence by screen readers.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap, this.selected = false});
  final OrderModel order;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final o = order;
    final units = o.items.fold<int>(0, (n, i) => n + i.quantity);
    final customer = o.deliveryAddress.name.isEmpty ? l10n.ordersCustomer : o.deliveryAddress.name;
    final payment = isPrepaid(o) ? l10n.ordersPrepaid : l10n.ordersCod;
    final stage = orderStageOf(o.orderStatus);
    return SellerCard(
      onTap: onTap,
      selected: selected,
      semanticLabel: [
        l10n.orderNumberTitle(o.orderNumber),
        l10n.stageLabel(stage),
        customer,
        SellerFormat.dateTime(o.createdAt),
        l10n.ordersItems(units),
        payment,
        SellerFormat.money(o.total),
      ].join(', '),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l10n.orderNumberShort(o.orderNumber), style: text.titleMedium!.tabular)),
          OrderStagePill(stage: stage),
          const SizedBox(width: SellerSpace.s4),
          Icon(SellerIcons.chevronRight, size: SellerIconSize.md, color: c.textTertiary),
        ]),
        const SizedBox(height: SellerSpace.s8),
        Text(l10n.searchOrderLine(customer, SellerFormat.dateTime(o.createdAt)), style: text.bodyMedium!.copyWith(color: c.textPrimary)),
        const SizedBox(height: SellerSpace.s4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(l10n.orderCardSummary(l10n.ordersItems(units), payment), style: text.bodyMedium)),
          const SizedBox(width: SellerSpace.s12),
          Text(SellerFormat.money(o.total), style: text.titleMedium!.tabular),
        ]),
      ]),
    );
  }
}
