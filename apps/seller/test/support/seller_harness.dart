import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';

/// Pumps [child] inside the seller theme (light or dark) and localisations,
/// at a given window size, system text size and reduced-motion setting.
/// Returns the English strings so tests never hard-code copy.
Future<AppLocalizations> pumpSeller(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
  bool scaffold = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late AppLocalizations l10n;
  await tester.pumpWidget(MaterialApp(
    theme: SellerTheme.light,
    darkTheme: SellerTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
      child: app!,
    ),
    home: Builder(builder: (context) {
      l10n = AppLocalizations.of(context);
      return scaffold ? Scaffold(body: child) : child;
    }),
  ));
  await tester.pump();
  return l10n;
}

/// Makes focus visible the way a hardware keyboard does, and restores the
/// automatic strategy afterwards.
void useKeyboardFocus() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
}

/// Makes focus invisible the way touch does.
void useTouchFocus() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
}
