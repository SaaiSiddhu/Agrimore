import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_settings_provider.dart';
import 'package:seller/screens/account/help_screen.dart';
import 'package:seller/screens/account/notification_prefs.dart';
import 'package:seller/screens/account/notification_settings_screen.dart';
import 'package:seller/screens/account/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SELLER-ACCOUNT-1b: preferences use the server's keys, save optimistically
/// and roll back on failure; theme persists; help search filters.
Future<AppLocalizations> _pump(WidgetTester tester, Widget child, {SellerSettingsProvider? settings}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
      ChangeNotifierProvider<SellerSettingsProvider>(create: (_) => settings ?? SellerSettingsProvider()),
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
        return child;
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  test('prefs map uses exactly the server keys; missing categories are on', () {
    final p = NotificationPrefs.fromMap({'quotes': false, 'quietStartMin': 5000});
    expect(p.isOn('quotes'), isFalse);
    expect(p.isOn('orders'), isTrue);
    expect(p.quietStartMin, 22 * 60);
    expect(p.toMap().keys.toSet(), {...kNotificationCategories, 'quietHours', 'quietStartMin', 'quietEndMin'});
  });

  testWidgets('toggling saves; a failed save rolls back and says so', (tester) async {
    final saved = <NotificationPrefs>[];
    var succeed = true;
    final l10n = await _pump(
      tester,
      NotificationSettingsScreen(
        initial: const NotificationPrefs(),
        saver: (p) async {
          saved.add(p);
          return succeed;
        },
      ),
    );
    await tester.tap(find.text(l10n.prefQuotes));
    await tester.pump();
    expect(saved.last.isOn('quotes'), isFalse);
    succeed = false;
    await tester.tap(find.text(l10n.prefPayments));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.prefSaveFailed), findsOneWidget);
    final paymentsSwitch = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, l10n.prefPayments));
    expect(paymentsSwitch.value, isTrue);
    await tester.tap(find.text(l10n.prefQuietHours));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme choice persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SellerSettingsProvider(prefs: prefs);
    final l10n = await _pump(tester, const SellerSettingsScreen(versionOverride: '1.2.3 (45)'), settings: settings);
    expect(find.text('1.2.3 (45)'), findsOneWidget);
    await tester.tap(find.text(l10n.settingsThemeDark));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect(prefs.getString('seller.themeMode'), 'dark');
    expect(SellerSettingsProvider(prefs: prefs).themeMode, ThemeMode.dark);
  });

  testWidgets('help search filters the FAQs', (tester) async {
    final l10n = await _pump(tester, const HelpScreen());
    expect(find.text(l10n.faqPayoutQ), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'invoice');
    await tester.pump();
    expect(find.text(l10n.faqPayoutQ), findsNothing);
    expect(find.text(l10n.faqInvoiceQ), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.text(l10n.helpNoMatch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
