import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../notifications/notifications_screen.dart';
import '../account/store_schedule.dart';
import '../account/store_status.dart';
import '../insights/health_screen.dart';
import '../insights/insights_rules.dart';
import '../insights/insights_screen.dart';
import '../orders/order_stage.dart';
import '../payments/payments_screen.dart';
import '../rfq/quote_rules.dart';
import '../rfq/seller_rfq_inbox_screen.dart';
import '../search/search_screen.dart';
import '../shell/seller_shell.dart';
import 'add_product_screen.dart';
import 'home_stats.dart';
import 'widgets/home_widgets.dart';

/// H-01 Command centre (ADR §10.2, SELLER-HOME-1a): what needs the seller
/// now, how the business is doing against the previous period, and the
/// next settlement. KPIs come from the server rollup `seller_stats_daily`.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.stats, this.pendingPayout, this.now, this.unreadOverride, this.rating, this.reviewCount = 0, this.schedule});

  /// Injected in tests; otherwise streamed.
  final Map<String, DayStat>? stats;
  final double? pendingPayout;
  final DateTime? now;

  /// Fixed unread count for the bell in tests.
  final int? unreadOverride;

  /// Server rating (sellers/{uid}); injected in tests, otherwise read once.
  final double? rating;
  final int reviewCount;

  /// Injected in tests; otherwise read from sellers/{uid}.
  final StoreSchedule? schedule;

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
  double? _rating;
  int _reviewCount = 0;
  StoreStatus _store = const StoreStatus();
  late StoreSchedule _schedule = widget.schedule ?? const StoreSchedule();

  bool get _injected => widget.stats != null;

  @override
  void initState() {
    super.initState();
    if (_injected) {
      _stats = widget.stats!;
      _statsLoaded = true;
      _pendingPayout = widget.pendingPayout;
      _rating = widget.rating;
      _reviewCount = widget.reviewCount;
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
    db.collection('sellers').doc(uid).get().then((snap) {
      if (!mounted) return;
      setState(() {
        _rating = (snap.data()?['rating'] as num?)?.toDouble();
        _reviewCount = (snap.data()?['reviewCount'] as num?)?.toInt() ?? 0;
        _store = StoreStatus.fromSeller(snap.data());
        _schedule = StoreSchedule.fromSeller(snap.data());
      });
    }, onError: (Object e) => debugPrint('Home rating failed: $e'));
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

  Future<void> _setStore(StoreStatus status) async {
    final l10n = AppLocalizations.of(context);
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('sellers').doc(uid).update({...status.toUpdate(), 'updatedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      setState(() => _store = status);
      SellerToast.show(context, status.accepting ? l10n.storeResumed : l10n.storePausedToast, tone: SellerToastTone.success);
    } catch (e) {
      debugPrint('Store status failed: $e');
      if (mounted) SellerToast.show(context, l10n.profileSaveFailed, tone: SellerToastTone.danger);
    }
  }

  /// Account health + a link to Insights (SELLER-HOME-1c, board 12).
  Widget _healthCard(BuildContext context, DateTime now) {
    final l10n = AppLocalizations.of(context);
    final inputs = healthInputs(
      orders: context.watch<SellerOrderProvider>().allOrders,
      products: context.watch<SellerProductProvider>().allProducts,
      quotes: context.watch<RfqProvider>().myRfqs,
      rating: _rating,
      reviewCount: _reviewCount,
      now: now,
    );
    final score = overallHealth(inputs);
    return SellerMenuGroup(children: [
      SellerListRow(
        title: l10n.healthTitle,
        subtitle: score == null ? l10n.healthNotEnoughDataShort : l10n.healthBand(bandOf(score)),
        leading: score == null
            ? const SellerIconTile(icon: SellerIcons.health, tone: SellerTone.neutral)
            : SellerDonut(
                fraction: score / 100,
                centerLabel: SellerFormat.count(score),
                size: SellerSize.avatarLg,
                semanticLabel: l10n.healthScoreLabel(score),
              ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HealthScreen(inputs: inputs))),
      ),
      SellerListRow(
        title: l10n.insightsTitle,
        subtitle: l10n.insightsHint,
        icon: SellerIcons.chartLine,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InsightsScreen())),
      ),
    ]);
  }

  String _greeting(AppLocalizations l10n, DateTime now) {
    final hour = now.toUtc().add(kIstOffset).hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 17) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  String? _pct(double? d) => d == null ? null : '${(d.abs() * 100).round()}%';

  SellerTrend _trend(double? d) => d == null ? SellerTrend.none : (d > 0 ? SellerTrend.up : (d < 0 ? SellerTrend.down : SellerTrend.flat));

  List<ActionItem> _actions(BuildContext context, AppLocalizations l10n, DateTime now) {
    final orders = context.watch<SellerOrderProvider>();
    final products = context.watch<SellerProductProvider>();
    final quotes = context.watch<RfqProvider>().myRfqs;
    final items = <ActionItem>[];

    // SELLER-UI-1b: only `pending` is "to accept" — `confirmed` means the
    // seller already accepted it and it is waiting to be packed.
    final waiting = orders.allOrders.where((o) => orderStageOf(o.orderStatus) == OrderStage.toAccept).toList();
    final toPack = orders.allOrders.where((o) => orderStageOf(o.orderStatus) == OrderStage.toPack).length;
    if (waiting.isNotEmpty) {
      final oldest = waiting.map((o) => o.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
      items.add(ActionItem(
        icon: SellerIcons.orders,
        label: l10n.homeOrdersToAccept(waiting.length),
        detail: l10n.homeOldestWaiting(SellerFormat.dateTime(oldest)),
        tone: ActionTone.urgent,
        onTap: () {
          orders.setFilter('pending');
          SellerShell.goToTab(context, SellerTab.orders);
        },
      ));
    }

    if (toPack > 0) {
      items.add(ActionItem(
        icon: SellerIcons.packing,
        label: l10n.homeOrdersToPack(toPack),
        tone: ActionTone.attention,
        onTap: () {
          orders.setFilter('confirmed');
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
        icon: SellerIcons.quote,
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
        icon: SellerIcons.inventory,
        label: out > 0 ? l10n.homeOutOfStock(out) : l10n.homeLowStock(low),
        detail: out > 0 && low > 0 ? l10n.homeLowStock(low) : null,
        tone: out > 0 ? ActionTone.attention : ActionTone.neutral,
        onTap: () {
          products.setFilter(out > 0 ? ProductListFilter.outOfStock : ProductListFilter.lowStock);
          SellerShell.goToTab(context, SellerTab.catalogue);
        },
      ));
    }
    return items;
  }

  Widget _kpis(BuildContext context, AppLocalizations l10n, KpiSummary kpi) {
    if (_statsFailed) {
      return SellerBanner(message: l10n.homeStatsFailed, tone: SellerTone.danger);
    }
    if (!_statsLoaded) return const SellerSkeletonList(count: 2, thumbnail: false);

    String change(double? d) => _pct(d) == null
        ? l10n.kpiNoComparison
        : (d! >= 0 ? l10n.kpiUpVsPrevious(_pct(d)!) : l10n.kpiDownVsPrevious(_pct(d)!));

    final sales = SellerMetricCard(
      label: l10n.kpiSales,
      icon: SellerIcons.chartBar,
      value: SellerFormat.moneyWhole(kpi.current.gross),
      large: true,
      delta: SellerDelta(trend: _trend(kpi.grossDelta), label: change(kpi.grossDelta)),
      chart: kpi.series.length > 1 ? SellerSparkline(values: kpi.series) : null,
    );
    final orders = SellerMetricCard(
      label: l10n.kpiOrders,
      icon: SellerIcons.orders,
      value: SellerFormat.count(kpi.current.orders),
      delta: kpi.previous.orders == 0 && kpi.current.orders == 0
          ? null
          : SellerDelta(
              trend: kpi.ordersDelta > 0 ? SellerTrend.up : (kpi.ordersDelta < 0 ? SellerTrend.down : SellerTrend.flat),
              label: kpi.ordersDelta > 0
                  ? l10n.kpiOrdersMore(kpi.ordersDelta)
                  : kpi.ordersDelta < 0
                      ? l10n.kpiOrdersFewer(-kpi.ordersDelta)
                      : l10n.kpiOrdersSame,
            ),
    );
    final aov = SellerMetricCard(
      label: l10n.kpiAov,
      icon: SellerIcons.receipt,
      value: kpi.current.aov == null ? '—' : SellerFormat.moneyWhole(kpi.current.aov!),
      delta: _pct(kpi.aovDelta) == null ? null : SellerDelta(trend: _trend(kpi.aovDelta), label: change(kpi.aovDelta)),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sales,
      const SizedBox(height: SellerSpace.s12),
      // Side by side on a normal phone; stacked at large text sizes.
      if (context.largeText) ...[
        orders,
        const SizedBox(height: SellerSpace.s12),
        aov,
      ] else
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: orders),
            const SizedBox(width: SellerSpace.s12),
            Expanded(child: aov),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final now = widget.now ?? DateTime.now();
    final user = context.watch<SellerAuthProvider>().currentUser;
    final actions = _actions(context, l10n, now);
    final kpi = KpiSummary.of(_stats, _period, now);
    final pending = _pendingPayout;
    final name = user?.name.trim() ?? '';

    return Scaffold(
      appBar: SellerAppBar.actionsOnly(
        context,
        actions: [
          SellerIconButton(
            icon: SellerIcons.search,
            label: l10n.homeSearch,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerSearchScreen())),
          ),
          NotificationBell(unreadOverride: widget.unreadOverride ?? (_injected ? 0 : null)),
        ],
      ),
      body: SellerPage(
        maxWidth: SellerSize.contentMaxWidth,
        gap: SellerSpace.section,
        children: [
          // Board 03: "Good morning, Kaveri" + "Here's what needs your
          // attention today." as the page header; it wraps at any text size.
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              header: true,
              child: Text(
                name.isEmpty ? l10n.homeTitle : l10n.homeGreetingName(_greeting(l10n, now), name.split(' ').first),
                style: text.headlineMedium,
              ),
            ),
            const SizedBox(height: SellerSpace.s4),
            Text(l10n.homeAttentionToday, style: text.bodyLarge!.copyWith(color: c.textSecondary)),
          ]),
          if (_store.isPaused(now))
            SellerBanner(
              tone: SellerTone.warning,
              icon: SellerIcons.paused,
              title: l10n.storePausedTitle,
              message: _store.pausedUntil == null ? l10n.storePausedBody : l10n.storePausedUntil(SellerFormat.date(_store.pausedUntil!)),
              actionLabel: l10n.storeResume,
              onAction: () => _setStore(const StoreStatus()),
            )
          else if (_schedule.closedOn(now) != null)
            SellerBanner(
              tone: SellerTone.info,
              icon: SellerIcons.calendar,
              title: l10n.scheduleClosedToday,
              message: _schedule.closedOn(now) == ClosedToday.holiday ? l10n.scheduleClosedHoliday : l10n.scheduleClosedWeeklyOff,
            ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SellerSectionHeader(title: l10n.homeNeedsYou, count: actions.isEmpty ? null : actions.length),
            ActionQueueCard(items: actions),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SellerSectionHeader(title: l10n.homePerformance),
            SellerSegmented<KpiPeriod>(
              semanticLabel: l10n.homePerformance,
              segments: [
                SellerSegment(KpiPeriod.today, l10n.periodToday),
                SellerSegment(KpiPeriod.days7, l10n.period7d),
                SellerSegment(KpiPeriod.days30, l10n.period30d),
              ],
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: SellerSpace.s12),
            _kpis(context, l10n, kpi),
            const SizedBox(height: SellerSpace.s12),
            _healthCard(context, now),
          ]),
          // "To be paid to you ₹3,840 >" (board 11).
          SellerCard(
            onTap: () => SellerShell.goToTab(context, SellerTab.payments),
            semanticLabel: '${l10n.homeNextSettlement}, ${pending == null ? '—' : SellerFormat.money(pending)}, ${l10n.homePaidTo}',
            child: Row(children: [
              const SellerIconTile(icon: SellerIcons.payments),
              const SizedBox(width: SellerSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.homeNextSettlement, style: text.bodyMedium),
                  Text(pending == null ? '—' : SellerFormat.money(pending), style: text.headlineMedium!.tabular),
                ]),
              ),
              Icon(SellerIcons.chevronRight, color: c.textTertiary),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SellerSectionHeader(title: l10n.homeQuickActions),
            SellerButtonBar(children: [
              SellerButton.secondary(
                label: l10n.quotesTitle,
                icon: SellerIcons.quote,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerRfqInboxScreen())),
              ),
              SellerButton(
                label: l10n.homeAddProduct,
                icon: SellerIcons.add,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddProductScreen())),
              ),
            ]),
          ]),
        ],
      ),
    );
  }
}
