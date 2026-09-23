import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../payments/payments_screen.dart';
import '../rfq/quote_rules.dart';
import '../rfq/seller_rfq_inbox_screen.dart';
import '../shell/seller_shell.dart';
import 'add_product_screen.dart';
import 'home_stats.dart';
import 'widgets/home_widgets.dart';

/// H-01 Command centre (ADR §10.2, SELLER-HOME-1a): what needs the seller
/// now, how the business is doing against the previous period, and the
/// next settlement. KPIs come from the server rollup `seller_stats_daily`.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.stats, this.pendingPayout, this.now});

  /// Injected in tests; otherwise streamed.
  final Map<String, DayStat>? stats;
  final double? pendingPayout;
  final DateTime? now;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Enough history for a 30-day period and the 30 days before it.
  static const int _historyDays = 60;
  static const int _payoutLimit = 200;
  static const Duration _quoteSoon = Duration(hours: 24);

  KpiPeriod _period = KpiPeriod.today;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _payoutSub;
  Map<String, DayStat> _stats = const {};
  bool _statsLoaded = false;
  bool _statsFailed = false;
  bool _rebuildRequested = false;
  double? _pendingPayout;

  bool get _injected => widget.stats != null;

  @override
  void initState() {
    super.initState();
    if (_injected) {
      _stats = widget.stats!;
      _statsLoaded = true;
      _pendingPayout = widget.pendingPayout;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    if (!mounted) return;
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    if (uid == null) return;
    context.read<RfqProvider>().loadMyRfqs();
    final db = FirebaseFirestore.instance;
    _statsSub = db
        .collection('seller_stats_daily')
        .where('sellerId', isEqualTo: uid)
        .where('day', isGreaterThanOrEqualTo: istDayKeys(DateTime.now(), _historyDays).first)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _stats = {for (final d in snap.docs) (d.data()['day'] ?? '').toString(): DayStat.fromMap(d.data())};
        _statsLoaded = true;
        _statsFailed = false;
      });
      _maybeRebuild();
    }, onError: (Object e) {
      debugPrint('Home stats failed: $e');
      if (mounted) setState(() => _statsFailed = true);
    });
    _payoutSub = db
        .collection('seller_payouts')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(_payoutLimit)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final entries = snap.docs.map((d) => PayoutEntry.fromMap(d.id, d.data())).toList();
      setState(() => _pendingPayout = PayoutSummary.of(entries, DateTime.now()).pending);
    }, onError: (Object e) => debugPrint('Home payouts failed: $e'));
  }

  /// Orders placed before the rollup existed have no stats yet: recompute
  /// once, server-side, when the seller has orders but no rollup at all.
  void _maybeRebuild() {
    if (_rebuildRequested || _stats.isNotEmpty) return;
    if (context.read<SellerOrderProvider>().allOrders.isEmpty) return;
    _rebuildRequested = true;
    unawaited(FirebaseFunctions.instance
        .httpsCallable('rebuildMySellerStats')
        .call<Map<String, dynamic>>()
        .then((_) {}, onError: (Object e) => debugPrint('rebuildMySellerStats failed: $e')));
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _payoutSub?.cancel();
    super.dispose();
  }

  String _greeting(AppLocalizations l10n, DateTime now) {
    final hour = now.toUtc().add(kIstOffset).hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 17) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  String? _pct(double? d) => d == null ? null : '${(d.abs() * 100).round()}%';

  List<ActionItem> _actions(BuildContext context, AppLocalizations l10n, DateTime now) {
    final orders = context.watch<SellerOrderProvider>();
    final products = context.watch<SellerProductProvider>();
    final quotes = context.watch<RfqProvider>().myRfqs;
    final items = <ActionItem>[];

    final waiting = orders.allOrders
        .where((o) => o.orderStatus == 'pending' || o.orderStatus == 'confirmed')
        .toList();
    if (waiting.isNotEmpty) {
      final oldest = waiting.map((o) => o.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
      items.add(ActionItem(
        icon: AgIcons.orders,
        label: l10n.homeOrdersToAccept(waiting.length),
        detail: l10n.homeOldestWaiting(AgFormat.dateTime(oldest)),
        tone: ActionTone.urgent,
        onTap: () {
          orders.setFilter('pending');
          SellerShell.goToTab(context, SellerTab.orders);
        },
      ));
    }

    final mine = quotes.where((q) => quoteBucketOf(q, now) == QuoteBucket.needsResponse).toList();
    if (mine.isNotEmpty) {
      final soon = mine.where((q) {
        final at = q.lastOffer?.expiresAt;
        return at != null && at.isAfter(now) && at.difference(now) <= _quoteSoon;
      }).length;
      items.add(ActionItem(
        icon: AgIcons.quote,
        label: l10n.homeQuotesToAnswer(mine.length),
        detail: soon > 0 ? l10n.homeQuotesExpiringSoon(soon) : null,
        tone: soon > 0 ? ActionTone.attention : ActionTone.neutral,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerRfqInboxScreen())),
      ));
    }

    final out = products.outOfStockProducts;
    final low = products.lowStockProducts;
    if (out + low > 0) {
      items.add(ActionItem(
        icon: AgIcons.inventory,
        label: out > 0 ? l10n.homeOutOfStock(out) : l10n.homeLowStock(low),
        detail: out > 0 && low > 0 ? l10n.homeLowStock(low) : null,
        tone: out > 0 ? ActionTone.attention : ActionTone.neutral,
        onTap: () {
          products.setFilter(ProductListFilter.outOfStock);
          SellerShell.goToTab(context, SellerTab.catalogue);
        },
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final now = widget.now ?? DateTime.now();
    final user = context.watch<SellerAuthProvider>().currentUser;
    final actions = _actions(context, l10n, now);
    final kpi = KpiSummary.of(_stats, _period, now);
    final pending = _pendingPayout;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting(l10n, now), style: text.bodySmall!.copyWith(color: t.textSecondary)),
          Text(user?.name.isNotEmpty == true ? user!.name : l10n.homeTitle,
              style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          HomeSectionHeader(
            title: l10n.homeNeedsYou,
            trailing: actions.isEmpty ? null : Text(AgFormat.count(actions.length), style: text.labelLarge),
          ),
          ActionQueueCard(items: actions),
          const SizedBox(height: WsSpace.s24),
          HomeSectionHeader(title: l10n.homePerformance),
          SegmentedButton<KpiPeriod>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: KpiPeriod.today, label: Text(l10n.periodToday)),
              ButtonSegment(value: KpiPeriod.days7, label: Text(l10n.period7d)),
              ButtonSegment(value: KpiPeriod.days30, label: Text(l10n.period30d)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: WsSpace.s12),
          if (_statsFailed)
            SaInfoBanner(variant: SaBannerVariant.error, message: l10n.homeStatsFailed)
          else if (!_statsLoaded)
            const Padding(
              padding: EdgeInsets.all(WsSpace.s24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            KpiCard(
              label: l10n.kpiSales,
              value: AgFormat.rupeesWhole(kpi.current.gross),
              delta: _pct(kpi.grossDelta) == null
                  ? l10n.kpiNoComparison
                  : (kpi.grossDelta! >= 0 ? l10n.kpiUpVsPrevious(_pct(kpi.grossDelta)!) : l10n.kpiDownVsPrevious(_pct(kpi.grossDelta)!)),
              deltaUp: kpi.grossDelta == null ? null : kpi.grossDelta! >= 0,
              series: kpi.series,
            ),
            const SizedBox(height: WsSpace.s8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: KpiCard(
                  label: l10n.kpiOrders,
                  value: AgFormat.count(kpi.current.orders),
                  delta: kpi.previous.orders == 0 && kpi.current.orders == 0
                      ? null
                      : kpi.ordersDelta > 0
                          ? l10n.kpiOrdersMore(kpi.ordersDelta)
                          : kpi.ordersDelta < 0
                              ? l10n.kpiOrdersFewer(-kpi.ordersDelta)
                              : l10n.kpiOrdersSame,
                  deltaUp: kpi.ordersDelta == 0 ? null : kpi.ordersDelta > 0,
                ),
              ),
              const SizedBox(width: WsSpace.s8),
              Expanded(
                child: KpiCard(
                  label: l10n.kpiAov,
                  value: kpi.current.aov == null ? '—' : AgFormat.rupeesWhole(kpi.current.aov!),
                  delta: _pct(kpi.aovDelta) == null
                      ? null
                      : (kpi.aovDelta! >= 0 ? l10n.kpiUpVsPrevious(_pct(kpi.aovDelta)!) : l10n.kpiDownVsPrevious(_pct(kpi.aovDelta)!)),
                  deltaUp: kpi.aovDelta == null ? null : kpi.aovDelta! >= 0,
                ),
              ),
            ]),
          ],
          const SizedBox(height: WsSpace.s24),
          Card(
            child: ListTile(
              onTap: () => SellerShell.goToTab(context, SellerTab.payments),
              leading: Icon(AgIcons.wallet, color: t.primary),
              title: Text(l10n.homeNextSettlement, style: text.titleSmall),
              subtitle: Text(pending == null ? '—' : AgFormat.rupees(pending),
                  style: text.titleMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
              trailing: Icon(AgIcons.chevronRight, color: t.textTertiary),
            ),
          ),
          const SizedBox(height: WsSpace.s24),
          HomeSectionHeader(title: l10n.homeQuickActions),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddProductScreen())),
                icon: const Icon(AgIcons.add),
                label: Text(l10n.homeAddProduct),
              ),
            ),
            const SizedBox(width: WsSpace.s8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerRfqInboxScreen())),
                icon: const Icon(AgIcons.quote),
                label: Text(l10n.quotesTitle),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
