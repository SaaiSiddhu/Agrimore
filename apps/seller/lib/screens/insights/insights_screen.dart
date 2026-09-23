import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final now = widget.now ?? DateTime.now();
    final cur = istDayKeys(now, _days);
    final prev = istDayKeys(now, _days, endOffsetDays: _days);
    final curSeries = [for (final k in cur) _stats[k]?.gross ?? 0.0];
    final prevSeries = [for (final k in prev) _stats[k]?.gross ?? 0.0];
    final curTotal = curSeries.fold<double>(0, (a, b) => a + b);
    final prevTotal = prevSeries.fold<double>(0, (a, b) => a + b);
    final b2b = [for (final k in cur) _stats[k]?.b2bGross ?? 0.0].fold<double>(0, (a, b) => a + b);
    final delta = KpiSummary.delta(curTotal, prevTotal);

    final orders = context.watch<SellerOrderProvider>().allOrders;
    final from = now.subtract(Duration(days: _days));
    final top = topProducts(ordersIn(orders, from, now));
    final stages = stageCounts(orders, from, now);
    final maxStage = stages.values.fold<int>(0, (m, v) => v > m ? v : m);
    String pct(double? d) => d == null ? l10n.kpiNoComparison : '${d >= 0 ? '+' : '−'}${(d.abs() * 100).round()}%';

    Widget card(String title, Widget child) => Card(
          margin: const EdgeInsets.only(bottom: WsSpace.s12),
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: WsSpace.s12),
              child,
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.insightsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final d in kInsightPeriods) ButtonSegment(value: d, label: Text(l10n.insightsDays(d)))],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: WsSpace.s16),
          if (_failed) ...[
            SaInfoBanner(variant: SaBannerVariant.error, message: l10n.homeStatsFailed),
            const SizedBox(height: WsSpace.s12),
          ],
          card(
            l10n.kpiSales,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AgFormat.rupeesWhole(curTotal), style: text.headlineMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
              Text(l10n.insightsVsPrevious(pct(delta), AgFormat.rupeesWhole(prevTotal)), style: text.bodySmall!.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s16),
              Semantics(
                label: l10n.insightsChartSummary(AgFormat.rupeesWhole(curTotal), AgFormat.rupeesWhole(prevTotal), _days),
                excludeSemantics: true,
                child: SizedBox(
                  height: WsSize.thumbLg,
                  width: double.infinity,
                  child: CustomPaint(painter: _TwoLinePainter(curSeries, prevSeries, t.primary, t.textTertiary)),
                ),
              ),
              const SizedBox(height: WsSpace.s8),
              Row(children: [
                _Legend(color: t.primary, label: l10n.insightsThisPeriod),
                const SizedBox(width: WsSpace.s16),
                _Legend(color: t.textTertiary, label: l10n.insightsPreviousPeriod),
              ]),
              if (curTotal > 0) ...[
                const SizedBox(height: WsSpace.s12),
                Text(l10n.insightsB2bShare('${(b2b / curTotal * 100).round()}%'), style: text.bodySmall),
              ],
            ]),
          ),
          card(
            l10n.insightsOrdersByStage,
            stages.isEmpty
                ? Text(l10n.insightsNoOrders, style: text.bodyMedium!.copyWith(color: t.textSecondary))
                : Column(children: [
                    for (final s in OrderStage.values)
                      if ((stages[s] ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
                          child: Row(children: [
                            SizedBox(width: WsSpace.s64 + WsSpace.s48, child: Text(l10n.stageLabel(s), style: text.bodySmall)),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(WsRadius.pill),
                                child: LinearProgressIndicator(
                                  value: stages[s]! / maxStage,
                                  minHeight: WsSpace.s8,
                                  backgroundColor: t.surfaceSunken,
                                ),
                              ),
                            ),
                            const SizedBox(width: WsSpace.s8),
                            Text(AgFormat.count(stages[s]!), style: text.bodySmall!.copyWith(fontFeatures: WsType.tabularFigures)),
                          ]),
                        ),
                  ]),
          ),
          card(
            l10n.insightsTopProducts,
            top.isEmpty
                ? Text(l10n.insightsNoOrders, style: text.bodyMedium!.copyWith(color: t.textSecondary))
                : Column(children: [
                    for (var i = 0; i < top.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(radius: WsSize.avatarSm / 2, child: Text(AgFormat.count(i + 1))),
                        title: Text(top[i].name, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(l10n.ordersItems(top[i].units), style: text.bodySmall),
                        trailing: Text(AgFormat.rupeesWhole(top[i].revenue),
                            style: text.titleSmall!.copyWith(fontFeatures: WsType.tabularFigures)),
                      ),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: WsSpace.s12, height: WsSpace.s4, color: color),
        const SizedBox(width: WsSpace.s4),
        Text(label, style: context.wsText.bodySmall),
      ]);
}

class _TwoLinePainter extends CustomPainter {
  _TwoLinePainter(this.current, this.previous, this.currentColor, this.previousColor);
  final List<double> current;
  final List<double> previous;
  final Color currentColor;
  final Color previousColor;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...current, ...previous];
    final max = all.fold<double>(0, (m, v) => v > m ? v : m);
    void line(List<double> values, Color color) {
      if (values.length < 2) return;
      final dx = size.width / (values.length - 1);
      double y(double v) => max == 0 ? size.height : size.height - v / max * size.height;
      final path = Path()..moveTo(0, y(values.first));
      for (var i = 1; i < values.length; i++) {
        path.lineTo(dx * i, y(values[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = WsSize.outline
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line(previous, previousColor);
    line(current, currentColor);
  }

  @override
  bool shouldRepaint(_TwoLinePainter old) => old.current != current || old.previous != previous;
}
