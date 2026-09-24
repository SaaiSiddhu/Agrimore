import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../home/home_stats.dart';
import '../orders/order_stage.dart';
import '../orders/seller_orders_screen.dart';
import 'insights_rules.dart';

const List<int> kInsightPeriods = [7, 30, 90];

/// H-04 Insights (ADR §10.2, SELLER-HOME-1c): sales against the previous
/// period (seller_stats_daily), orders by stage, best sellers, B2B share.
/// Every chart has a text summary for screen readers.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.stats, this.now});

  /// Injected in tests; otherwise streamed (two periods of the longest range).
  final Map<String, DayStat>? stats;
  final DateTime? now;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _days = kInsightPeriods[1];
  Map<String, DayStat> _stats = const {};
  bool _failed = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.stats != null) {
      _stats = widget.stats!;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<SellerAuthProvider>().currentUser?.uid;
      if (uid == null) return;
      _sub = FirebaseFirestore.instance
          .collection('seller_stats_daily')
          .where('sellerId', isEqualTo: uid)
          .where('day', isGreaterThanOrEqualTo: istDayKeys(DateTime.now(), kInsightPeriods.last * 2).first)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        setState(() => _stats = {for (final d in snap.docs) (d.data()['day'] ?? '').toString(): DayStat.fromMap(d.data())});
      }, onError: (Object e) {
        debugPrint('Insights stats failed: $e');
        if (mounted) setState(() => _failed = true);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  DateTime _dayOf(String key) => DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(4, 6)), int.parse(key.substring(6, 8)));

  String _range(List<String> keys) => keys.isEmpty ? '' : SellerFormat.dateRange(_dayOf(keys.first), _dayOf(keys.last));

  SellerTrend _trend(double? d) => d == null ? SellerTrend.none : (d > 0 ? SellerTrend.up : (d < 0 ? SellerTrend.down : SellerTrend.flat));

  String _change(AppLocalizations l10n, double? d) => d == null ? l10n.kpiNoComparison : SellerFormat.percentChange(d);

  void _explain(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showSellerSheet<void>(
      context,
      title: l10n.insightsInfo,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final line in [l10n.insightsDefSales, l10n.insightsDefOrders, l10n.insightsDefAov, l10n.insightsDefB2b, l10n.insightsDefCompare])
          Padding(padding: const EdgeInsets.only(bottom: SellerSpace.s12), child: Text(line, style: ctx.text.bodyLarge)),
      ]),
      footer: (ctx) => SellerButton(label: l10n.insightsGotIt, expand: true, onPressed: () => Navigator.of(ctx).pop()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final now = widget.now ?? DateTime.now();
    final cur = istDayKeys(now, _days);
    final prev = istDayKeys(now, _days, endOffsetDays: _days);
    double sum(Iterable<double> v) => v.fold<double>(0, (a, b) => a + b);
    final curTotal = sum([for (final k in cur) _stats[k]?.gross ?? 0.0]);
    final prevTotal = sum([for (final k in prev) _stats[k]?.gross ?? 0.0]);
    final curOrders = [for (final k in cur) _stats[k]?.orders ?? 0].fold<int>(0, (a, b) => a + b);
    final prevOrders = [for (final k in prev) _stats[k]?.orders ?? 0].fold<int>(0, (a, b) => a + b);
    final b2b = sum([for (final k in cur) _stats[k]?.b2bGross ?? 0.0]);
    final delta = KpiSummary.delta(curTotal, prevTotal);
    final aov = curOrders == 0 ? null : curTotal / curOrders;
    final prevAov = prevOrders == 0 ? null : prevTotal / prevOrders;
    final aovDelta = aov == null || prevAov == null ? null : KpiSummary.delta(aov, prevAov);

    final orders = context.watch<SellerOrderProvider>().allOrders;
    final from = now.subtract(Duration(days: _days));
    final top = topProducts(ordersIn(orders, from, now));
    final stages = stageCounts(orders, from, now);
    final stageTotal = stages.values.fold<int>(0, (a, b) => a + b);

    SellerChartPoint point(String k) => SellerChartPoint(
          SellerFormat.dayMonth(_dayOf(k)),
          _stats[k]?.gross ?? 0,
          SellerFormat.moneyWhole(_stats[k]?.gross ?? 0),
        );
    final curPoints = [for (final k in cur) point(k)];
    // The previous series is drawn against this period's days.
    final prevPoints = [
      for (var i = 0; i < prev.length; i++) SellerChartPoint(curPoints[i].label, _stats[prev[i]]?.gross ?? 0, SellerFormat.moneyWhole(_stats[prev[i]]?.gross ?? 0)),
    ];
    final summary = l10n.insightsChartSummary(SellerFormat.moneyWhole(curTotal), SellerFormat.moneyWhole(prevTotal), _days);

    final ordersCard = SellerMetricCard(
      label: l10n.kpiOrders,
      icon: SellerIcons.orders,
      value: SellerFormat.count(curOrders),
      delta: curOrders == 0 && prevOrders == 0
          ? null
          : SellerDelta(
              trend: curOrders > prevOrders ? SellerTrend.up : (curOrders < prevOrders ? SellerTrend.down : SellerTrend.flat),
              label: curOrders > prevOrders
                  ? l10n.kpiOrdersMore(curOrders - prevOrders)
                  : curOrders < prevOrders
                      ? l10n.kpiOrdersFewer(prevOrders - curOrders)
                      : l10n.kpiOrdersSame,
            ),
    );
    final aovCard = SellerMetricCard(
      label: l10n.kpiAov,
      icon: SellerIcons.receipt,
      value: aov == null ? '—' : SellerFormat.moneyWhole(aov),
      delta: aovDelta == null ? null : SellerDelta(trend: _trend(aovDelta), label: _change(l10n, aovDelta)),
    );

    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.insightsTitle, actions: [
        SellerIconButton(icon: SellerIcons.info, label: l10n.insightsInfo, onPressed: () => _explain(context)),
      ]),
      body: SellerPage(
        maxWidth: SellerSize.contentMaxWidth,
        gap: SellerSpace.s16,
        children: [
          SellerSegmented<int>(
            semanticLabel: l10n.insightsTitle,
            segments: [for (final d in kInsightPeriods) SellerSegment(d, l10n.insightsDays(d))],
            selected: _days,
            onChanged: (d) => setState(() => _days = d),
          ),
          Row(children: [
            const Icon(SellerIcons.calendar, size: SellerIconSize.md),
            const SizedBox(width: SellerSpace.s8),
            Expanded(child: Text(l10n.insightsRange(_range(cur), _range(prev)), style: text.bodyMedium)),
          ]),
          if (_failed) SellerBanner(tone: SellerTone.danger, message: l10n.homeStatsFailed),
          SellerMetricCard(
            label: l10n.kpiSales,
            icon: SellerIcons.chartBar,
            value: SellerFormat.moneyWhole(curTotal),
            large: true,
            delta: SellerDelta(trend: _trend(delta), label: _change(l10n, delta), pill: true),
            caption: l10n.insightsVsPrevious(_change(l10n, delta), SellerFormat.moneyWhole(prevTotal)),
          ),
          SellerChartCard(
            title: l10n.insightsSalesTrend,
            summary: summary,
            chart: _failed
                ? SellerChartUnavailable(message: l10n.insightsSalesUnavailable)
                : SellerLineChart(
                    series: [
                      SellerChartSeries(name: l10n.insightsThisPeriod, points: curPoints),
                      SellerChartSeries(name: l10n.insightsPreviousPeriod, points: prevPoints, previous: true),
                    ],
                    axisLabel: SellerFormat.moneyCompact,
                    semanticSummary: summary,
                  ),
            legend: SellerChartLegend(items: [
              SellerLegendItem(l10n.insightsThisPeriod, SellerLegendKind.line),
              SellerLegendItem(l10n.insightsPreviousPeriod, SellerLegendKind.dashedLine),
            ]),
            table: SellerDataTable(
              columns: [
                SellerTableColumn(l10n.insightsTableDay, flex: 2),
                SellerTableColumn(l10n.insightsThisPeriod, numeric: true, flex: 2),
                SellerTableColumn(l10n.insightsPreviousPeriod, numeric: true, flex: 2),
              ],
              rows: [for (var i = 0; i < curPoints.length; i++) [curPoints[i].label, curPoints[i].valueLabel, prevPoints[i].valueLabel]],
            ),
          ),
          if (context.largeText) ...[ordersCard, aovCard]
          else
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: ordersCard),
                const SizedBox(width: SellerSpace.s12),
                Expanded(child: aovCard),
              ]),
            ),
          if (curTotal > 0)
            SellerCard(
              child: Row(children: [
                SellerDonut(fraction: b2b / curTotal, centerLabel: SellerFormat.percent(b2b / curTotal)),
                const SizedBox(width: SellerSpace.s16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.insightsB2bTitle, style: text.titleSmall),
                    Text(l10n.dsShare(SellerFormat.moneyWhole(b2b), SellerFormat.moneyWhole(curTotal)), style: text.bodyMedium!.tabular),
                    Text(l10n.insightsB2bShare(SellerFormat.percent(b2b / curTotal)), style: text.bodySmall),
                  ]),
                ),
              ]),
            ),
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SellerSectionHeader(title: l10n.insightsComparisons, subtitle: l10n.insightsDefCompare),
              SellerComparisonBars(
                currentLabel: l10n.insightsCurrentLabel(_range(cur)),
                current: curTotal,
                currentValueLabel: SellerFormat.moneyWhole(curTotal),
                previousLabel: l10n.insightsPreviousLabel(_range(prev)),
                previous: prevTotal,
                previousValueLabel: SellerFormat.moneyWhole(prevTotal),
              ),
            ]),
          ),
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SellerSectionHeader(title: l10n.insightsOrdersByStage, count: stageTotal == 0 ? null : stageTotal, subtitle: l10n.insightsStageNote),
              if (stages.isEmpty)
                SellerEmptyState(icon: SellerIcons.document, title: l10n.insightsNoOrders, compact: true)
              else
                SellerBarList(items: [
                  for (final st in OrderStage.values)
                    if ((stages[st] ?? 0) > 0)
                      SellerBarItem(
                        label: l10n.stageLabel(st),
                        value: stages[st]!.toDouble(),
                        valueLabel: SellerFormat.count(stages[st]!),
                        icon: orderStageStyle(st).$2,
                        tone: orderStageStyle(st).$1,
                      ),
                ]),
            ]),
          ),
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SellerSectionHeader(title: l10n.insightsTopProducts, subtitle: l10n.insightsTopNote),
              if (top.isEmpty)
                SellerEmptyState(icon: SellerIcons.sprout, title: l10n.insightsNoOrders, compact: true)
              else
                for (var i = 0; i < top.length; i++)
                  SellerListRow(
                    leading: Container(
                      width: SellerSize.avatarSm,
                      height: SellerSize.avatarSm,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: context.colors.primaryContainer, shape: BoxShape.circle),
                      child: Text(SellerFormat.count(i + 1), style: text.labelLarge!.copyWith(color: context.colors.onPrimaryContainer)),
                    ),
                    title: top[i].name,
                    subtitle: l10n.insightsUnits(top[i].units),
                    value: SellerFormat.moneyWhole(top[i].revenue),
                  ),
            ]),
          ),
        ],
      ),
    );
  }
}
