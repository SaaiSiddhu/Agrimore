import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/screens/shell/seller_shell.dart';

/// SELLER-UI-1a: five destinations in ADR order, bottom bar on phones, rail
/// on wide screens, goToTab from inside a destination.
Future<AppLocalizations> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late AppLocalizations l10n;
  await tester.pumpWidget(ChangeNotifierProvider<SellerOrderProvider>(
    create: (_) => SellerOrderProvider.preview(const []),
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
        return SellerShell(screens: [
          for (final t in SellerTab.values)
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => SellerShell.goToTab(ctx, SellerTab.payments),
                  child: Text('screen-${t.name}'),
                ),
              ),
            ),
        ]);
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  testWidgets('phone: bottom bar in ADR order; tap and goToTab switch', (tester) async {
    final l10n = await _pump(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    final labels = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
    expect(labels, [l10n.navHome, l10n.navOrders, l10n.navCatalogue, l10n.paymentsTitle, l10n.navAccount]);
    int shown() => tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;
    expect(shown(), SellerTab.home.index);
    await tester.tap(find.text(l10n.navOrders));
    await tester.pumpAndSettle();
    expect(shown(), SellerTab.orders.index);
    // goToTab from inside the visible destination.
    await tester.tap(find.text('screen-orders'));
    await tester.pumpAndSettle();
    expect(shown(), SellerTab.payments.index);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide: navigation rail', (tester) async {
    await _pump(tester, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
