import 'dart:math' as math;

import 'package:delivery/design_system/design_system.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _luminance(Color c) {
  double chan(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: DeliveryTheme.of(brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, home) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: home!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('DeliveryColors & WCAG AA contrast (Phases 01–03, 14, 32)', () {
    test('light and dark palettes match canonical Burnt Orange tokens', () {
      const light = DeliveryColors.light;
      const dark = DeliveryColors.dark;

      expect(light.primary, const Color(0xFFC2410C));
      expect(light.background, const Color(0xFFFFFAF5));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.textPrimary, const Color(0xFF241A16));

      expect(dark.background, const Color(0xFF171210));
      expect(dark.surface, const Color(0xFF251C17));
      expect(dark.primary, const Color(0xFFFDBA74));
      expect(dark.onPrimary, const Color(0xFF2B1206));
    });

    test('text and filled controls meet WCAG AA >= 4.5:1 contrast', () {
      const light = DeliveryColors.light;
      const dark = DeliveryColors.dark;

      expect(_contrastRatio(light.textPrimary, light.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.textPrimary, light.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.textSecondary, light.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.onPrimary, light.primary), greaterThanOrEqualTo(4.5));

      expect(_contrastRatio(dark.textPrimary, dark.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(dark.textPrimary, dark.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(dark.textSecondary, dark.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(dark.onPrimary, dark.primary), greaterThanOrEqualTo(4.5));
    });
  });

  group('DeliveryFormat (Phase 05)', () {
    test('formats rupees, counts, and masked PII consistently', () {
      expect(DeliveryFormat.money(1250), '₹1,250');
      expect(DeliveryFormat.money(55.46), '₹55.46');
      expect(DeliveryFormat.money(-400), '− ₹400');
      expect(DeliveryFormat.rupees(400), '₹400.00');
      expect(DeliveryFormat.rupeesWhole(450.2), '₹450');
      expect(DeliveryFormat.count(123456), '1,23,456');
      expect(DeliveryFormat.maskPhone('+91 98765 43210'), '+91 •••••• 3210');
      expect(DeliveryFormat.maskAadhaar('123456789012'), 'XXXX XXXX 9012');
      expect(DeliveryFormat.maskTail('123456789012'), '•••• 9012');
      expect(DeliveryFormat.maskUpi('ravi.kumar@okaxis'), 'ra***@okaxis');
      expect(DeliveryFormat.initials('Ravi Kumar'), 'RK');
    });
  });

  group('DeliveryAppearanceController (Phases 03, 14, 31)', () {
    test('loads and persists System, Light, and Dark modes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctrl = DeliveryAppearanceController();
      await ctrl.load(prefs);
      expect(ctrl.mode, ThemeMode.system);

      await ctrl.setMode(ThemeMode.dark, prefs);
      expect(ctrl.mode, ThemeMode.dark);
      expect(prefs.getString(DeliveryAppearanceController.prefKey), 'dark');

      final restored = DeliveryAppearanceController();
      await restored.load(prefs);
      expect(restored.mode, ThemeMode.dark);
    });
  });

  group('Design System Components (Phases 06–13)', () {
    testWidgets('DeliveryButton enforces >= 48dp touch target and loading state', (t) async {
      var tapped = 0;
      await t.pumpWidget(_wrap(
        Column(
          children: [
            DeliveryButton.primary(
              key: const ValueKey('btn-primary'),
              label: 'Accept offer',
              onPressed: () => tapped++,
            ),
            DeliveryButton.secondary(
              key: const ValueKey('btn-loading'),
              label: 'Saving',
              isLoading: true,
              onPressed: () => tapped++,
            ),
          ],
        ),
      ));

      final size = t.getSize(find.byKey(const ValueKey('btn-primary')));
      expect(size.height, greaterThanOrEqualTo(48));

      await t.tap(find.byKey(const ValueKey('btn-primary')));
      expect(tapped, 1);

      await t.tap(find.byKey(const ValueKey('btn-loading')), warnIfMissed: false);
      expect(tapped, 1);
    });

    testWidgets('DeliveryCountdownRing transitions across SLA thresholds', (t) async {
      await t.pumpWidget(_wrap(
        const Row(
          children: [
            DeliveryCountdownRing(remainingSeconds: 24, totalSeconds: 30, caption: 'sec'),
            DeliveryCountdownRing(remainingSeconds: 9, totalSeconds: 30, caption: 'sec'),
            DeliveryCountdownRing(remainingSeconds: 4, totalSeconds: 30, caption: 'sec'),
          ],
        ),
      ));
      expect(find.text('24s'), findsOneWidget);
      expect(find.text('9s'), findsOneWidget);
      expect(find.text('4s'), findsOneWidget);
    });

    testWidgets('DeliveryOtpField handles 6-digit PIN entry and completion', (t) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      String? completed;
      await t.pumpWidget(_wrap(
        DeliveryOtpField(
          controller: ctrl,
          length: 6,
          label: 'Delivery OTP',
          onCompleted: (v) => completed = v,
        ),
      ));

      await t.enterText(find.byType(TextField), '482910');
      await t.pump();
      expect(completed, '482910');
    });

    testWidgets('DeliveryVehicleSelector selects across 6 canonical vehicles', (t) async {
      var selected = DeliveryVehicleKind.motorcycle;
      await t.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => DeliveryVehicleSelector(
            selected: selected,
            onSelected: (v) => setState(() => selected = v),
            options: const [
              DeliveryVehicleOption(kind: DeliveryVehicleKind.bicycle, label: 'Bicycle'),
              DeliveryVehicleOption(kind: DeliveryVehicleKind.motorcycle, label: 'Motorcycle'),
              DeliveryVehicleOption(kind: DeliveryVehicleKind.scooter, label: 'Scooter'),
              DeliveryVehicleOption(kind: DeliveryVehicleKind.evTwoWheeler, label: 'Electric EV'),
              DeliveryVehicleOption(kind: DeliveryVehicleKind.autoThreeWheeler, label: '3-Wheeler Auto'),
              DeliveryVehicleOption(kind: DeliveryVehicleKind.miniTruck, label: 'Mini Truck / Van'),
            ],
          ),
        ),
      ));

      await t.tap(find.text('Electric EV'));
      await t.pump();
      expect(selected, DeliveryVehicleKind.evTwoWheeler);
    });

    testWidgets('DeliveryOnlineSwitch toggles availability and scales at 200% text', (t) async {
      var online = false;
      await t.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => DeliveryOnlineSwitch(
            isOnline: online,
            onlineTitle: 'You are online',
            offlineTitle: 'You are offline',
            onlineSubtitle: 'Listening for nearby orders',
            offlineSubtitle: 'Switch online to receive orders',
            onChanged: (v) => setState(() => online = v),
          ),
        ),
        textScale: 2.0,
      ));
      expect(t.takeException(), isNull);
      expect(find.text('You are offline'), findsOneWidget);

      await t.tap(find.byType(Switch));
      await t.pump();
      expect(online, isTrue);
      expect(find.text('You are online'), findsOneWidget);
    });
  });
}
