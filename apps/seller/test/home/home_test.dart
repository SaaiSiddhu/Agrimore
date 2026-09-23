import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/rfq_provider.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/home/dashboard_screen.dart';
import 'package:seller/screens/home/home_stats.dart';

/// SELLER-HOME-1a: KPIs over the server rollup, with Indian-day boundaries
/// and the previous-period comparison, and the command centre renders them.
DayStat _d(String day, double gross, int orders, {int cancelled = 0}) =>
    DayStat(day: day, gross: gross, orders: orders, cancelled: cancelled);

void main() {
  group('IST day keys', () {
    test('the Indian day turns over at 18:30 UTC', () {
      expect(istDayKey(DateTime.utc(2026, 9, 22, 18, 29, 59)), '20260922');
      expect(istDayKey(DateTime.utc(2026, 9, 22, 18, 30)), '20260923');
      expect(istDayKey(DateTime.utc(2026, 12, 31, 18, 30)), '20270101');
    });

    test('matches the server istDay() source', () {
      // functions/src/seller/sellerStats.ts uses a 330-minute offset.
      expect(kIstOffset.inMinutes, 330);
    });

    test('day windows are contiguous and oldest first', () {
      final now = DateTime.utc(2026, 9, 23, 6);
      expect(istDayKeys(now, 3), ['20260921', '20260922', '20260923']);
      expect(istDayKeys(now, 3, endOffsetDays: 3), ['20260918', '20260919', '20260920']);
    });
  });

  group('KpiSummary', () {
    final now = DateTime.utc(2026, 9, 23, 6); // 11:30 IST on the 23rd
    final byDay = {
      for (final s in [
        _d('20260923', 1000, 4),
        _d('20260922', 500, 2),
        _d('20260917', 300, 3, cancelled: 1),
        _d('20260916', 700, 1),
        _d('20260915', 999, 9),
      ])
        s.day: s,
    };

    test('today vs yesterday', () {
      final k = KpiSummary.of(byDay, KpiPeriod.today, now);
      expect(k.current.gross, 1000);
      expect(k.current.orders, 4);
      expect(k.previous.gross, 500);
      expect(k.grossDelta, 1.0);
      expect(k.ordersDelta, 2);
      expect(k.current.aov, 250);
      expect(k.series.length, 7);
      expect(k.series.last, 1000);
    });

    test('7 days vs the 7 before; cancelled orders do not count', () {
      final k = KpiSummary.of(byDay, KpiPeriod.days7, now);
      expect(k.current.gross, 1500 + 300); // 17th–23rd
      expect(k.current.orders, 4 + 2 + 2);
      expect(k.previous.gross, 700 + 999); // 10th–16th
      expect(k.series.length, 7);
    });

    test('no previous data → no percentage', () {
      final k = KpiSummary.of({'20260923': _d('20260923', 10, 1)}, KpiPeriod.today, now);
      expect(k.grossDelta, isNull);
      expect(k.aovDelta, isNull);
      expect(KpiSummary.of(const {}, KpiPeriod.days30, now).current.aov, isNull);
    });
  });

  testWidgets('command centre shows KPIs, change and the settlement', (tester) async {
    late AppLocalizations l10n;
    final now = DateTime.utc(2026, 9, 23, 6);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
        ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider.preview(const [])),
        ChangeNotifierProvider<SellerProductProvider>(create: (_) => SellerProductProvider.preview(const [])),
        ChangeNotifierProvider<RfqProvider>(create: (_) => RfqProvider.preview(const [])),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return DashboardScreen(
            now: now,
            pendingPayout: 1234,
            stats: {'20260923': _d('20260923', 1000, 4), '20260922': _d('20260922', 500, 2)},
          );
        }),
      ),
    ));
    await tester.pump();
    expect(find.text(l10n.homeAllCaughtUp), findsOneWidget);
    expect(find.text(AgFormat.rupeesWhole(1000)), findsOneWidget);
    expect(find.text(l10n.kpiUpVsPrevious('100%')), findsOneWidget);
    expect(find.text(l10n.kpiOrdersMore(2)), findsOneWidget);
    expect(find.text(AgFormat.rupees(1234)), findsOneWidget);
    await tester.tap(find.text(l10n.period7d));
    await tester.pump();
    expect(find.text(AgFormat.rupeesWhole(1500)), findsOneWidget);
    expect(find.text(l10n.kpiNoComparison), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
