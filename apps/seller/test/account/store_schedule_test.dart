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
import 'package:seller/screens/account/store_schedule.dart';
import 'package:seller/screens/home/dashboard_screen.dart';

/// SELLER-OPS-2: weekly off days and holidays (same rule as
/// functions/src/common/sellerAvailability.ts sellerClosedReason).
Widget _app(Widget child, void Function(AppLocalizations) onL10n) => MultiProvider(
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
          onL10n(AppLocalizations.of(context));
          return child;
        }),
      ),
    );

void main() {
  // Wed 23 Sep 2026 23:00 IST and Thu 24 Sep 00:30 IST.
  final wedNight = DateTime.utc(2026, 9, 23, 17, 30);
  final thuEarly = DateTime.utc(2026, 9, 23, 19, 0);

  test('closed on the Indian calendar day', () {
    const s = StoreSchedule(weeklyOff: {3}, holidays: ['2026-09-24']);
    expect(s.closedOn(wedNight), ClosedToday.weeklyOff);
    expect(s.closedOn(thuEarly), ClosedToday.holiday);
    expect(const StoreSchedule().closedOn(wedNight), isNull);
  });

  test('fromSeller drops malformed values; toUpdate drops past holidays', () {
    final s = StoreSchedule.fromSeller({
      'weeklyOff': [7, 0, 8, '1', 1],
      'holidays': ['2026-09-30', 'soon', '2026-09-01', '2026-09-24'],
    });
    expect(s.weeklyOff, {1, 7});
    expect(s.holidays, ['2026-09-01', '2026-09-24', '2026-09-30']);
    expect(s.toUpdate(thuEarly), {'weeklyOff': [1, 7], 'holidays': ['2026-09-24', '2026-09-30']});
  });

  testWidgets('choosing Sunday off saves it; all seven days is refused', (tester) async {
    late AppLocalizations l10n;
    StoreSchedule? saved;
    await tester.pumpWidget(_app(
      StoreScheduleScreen(initial: const StoreSchedule(), now: wedNight, onSave: (s) async => saved = s),
      (l) => l10n = l,
    ));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, l10n.weekdaySun));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.accountSave));
    await tester.pump();
    expect(saved?.weeklyOff, {7});

    saved = null;
    for (final d in [l10n.weekdayMon, l10n.weekdayTue, l10n.weekdayWed, l10n.weekdayThu, l10n.weekdayFri, l10n.weekdaySat]) {
      await tester.tap(find.widgetWithText(FilterChip, d));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, l10n.accountSave));
    await tester.pump();
    expect(saved, isNull);
    expect(find.text(l10n.scheduleAllDaysOff), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  test('Account line describes the schedule', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(describeSchedule(const StoreSchedule(), l10n, wedNight), l10n.scheduleOpenEveryDay);
    expect(describeSchedule(const StoreSchedule(weeklyOff: {7, 1}), l10n, wedNight), 'Closed Mon, Sun');
    expect(describeSchedule(const StoreSchedule(weeklyOff: {7}, holidays: ['2026-09-30']), l10n, wedNight), 'Closed Sun · 1 holiday');
  });

  testWidgets('Home says the store is closed today', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(_app(
      DashboardScreen(now: wedNight, stats: const {}, pendingPayout: 0, schedule: const StoreSchedule(weeklyOff: {3})),
      (l) => l10n = l,
    ));
    await tester.pump();
    expect(find.text(l10n.scheduleClosedToday), findsOneWidget);
    expect(find.text(l10n.scheduleClosedWeeklyOff), findsOneWidget);
  });
}
