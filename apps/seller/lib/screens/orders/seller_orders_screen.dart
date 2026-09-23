import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
}

class OrderStagePill extends StatelessWidget {
  const OrderStagePill({super.key, required this.stage});
  final OrderStage stage;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final (Color fg, Color bg) = switch (stage) {
      OrderStage.toAccept => (t.warningFg, t.warningBg),
      OrderStage.toPack || OrderStage.packing || OrderStage.ready || OrderStage.outForDelivery => (t.infoFg, t.infoBg),
      OrderStage.delivered => (t.successFg, t.successBg),
      OrderStage.cancelled || OrderStage.other => (t.textSecondary, t.surfaceSunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WsSpace.s8, vertical: WsSpace.s2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(WsRadius.pill)),
      child: Text(AppLocalizations.of(context).stageLabel(stage), style: context.wsText.labelMedium!.copyWith(color: fg)),
    );
  }
}

/// O-01 Orders (ADR §10.3, SELLER-UI-1b): search, stage filters with
/// counts, and one card per order.
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final _query = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final provider = context.watch<SellerOrderProvider>();
    final all = provider.allOrders;
    final counts = <OrderStage, int>{};
    for (final o in all) {
      final s = orderStageOf(o.orderStatus);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final selected = kOrderFilters.firstWhere((f) => f.$1 == provider.selectedFilter, orElse: () => kOrderFilters.first).$2;
    final shown = all
        .where((o) => selected == null || orderStageOf(o.orderStatus) == selected)
        .where((o) => orderMatches(o, _query.text))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.navOrders)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, 0),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(AgIcons.search),
              hintText: l10n.ordersSearchHint,
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.searchClear,
                      icon: const Icon(AgIcons.close),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: WsSize.chipHeight + WsSpace.s24,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s12),
            children: [
              for (final (key, stage) in kOrderFilters)
                Padding(
                  padding: const EdgeInsets.only(right: WsSpace.s8),
                  child: ChoiceChip(
                    label: Text(l10n.filterWithCount(l10n.filterLabel(stage), AgFormat.count(stage == null ? all.length : counts[stage] ?? 0))),
                    selected: provider.selectedFilter == key,
                    onSelected: (_) => provider.setFilter(key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: provider.error != null
              ? Padding(
                  padding: const EdgeInsets.all(WsSpace.page),
                  child: SaInfoBanner(
                    variant: SaBannerVariant.error,
                    message: l10n.ordersLoadFailed,
                    actionLabel: l10n.statusRefresh,
                    onAction: _reload,
                  ),
                )
              : provider.isLoading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : shown.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(WsSpace.s32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(AgIcons.orders, size: WsIconSize.empty, color: t.textTertiary),
                              const SizedBox(height: WsSpace.s12),
                              Text(
                                all.isEmpty ? l10n.ordersEmpty : l10n.ordersNoneMatch,
                                style: text.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ]),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _reload(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: WsSpace.s8),
                            itemBuilder: (context, i) => _OrderCard(order: shown[i]),
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final o = order;
    final units = o.items.fold<int>(0, (n, i) => n + i.quantity);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(WsRadius.card),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerOrderDetailScreen(order: o))),
        child: Padding(
          padding: const EdgeInsets.all(WsSpace.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l10n.paymentsForOrder(o.orderNumber), style: text.titleSmall)),
              OrderStagePill(stage: orderStageOf(o.orderStatus)),
            ]),
            const SizedBox(height: WsSpace.s4),
            Text(
              l10n.searchOrderLine(o.deliveryAddress.name.isEmpty ? l10n.ordersCustomer : o.deliveryAddress.name, AgFormat.dateTime(o.createdAt)),
              style: text.bodySmall!.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: WsSpace.s8),
            Row(children: [
              Expanded(child: Text(l10n.ordersItems(units), style: text.bodyMedium)),
              Text(isPrepaid(o) ? l10n.ordersPrepaid : l10n.ordersCod, style: text.labelMedium!.copyWith(color: t.textSecondary)),
              const SizedBox(width: WsSpace.s12),
              Text(AgFormat.rupees(o.total), style: text.titleSmall!.copyWith(fontFeatures: WsType.tabularFigures)),
            ]),
          ]),
        ),
      ),
    );
  }
}
