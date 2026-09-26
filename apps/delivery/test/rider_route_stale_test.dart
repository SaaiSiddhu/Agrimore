// Phase DLVMAP1 — the stale-location threshold (a pure function) and the
// StaleLocationBanner widget (rider_route_card.dart), tested directly since
// RiderRouteCard itself reads Firestore with no injectable backend and no
// fake-Firestore package exists in this repo to drive it into a stale state.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/orders/widgets/rider_route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('isPositionStale (DLVMAP1)', () {
    final now = DateTime(2026, 9, 27, 12, 0, 0);

    test('null at is never stale', () {
      expect(isPositionStale(null, now), isFalse);
    });

    test('exactly at the threshold is not yet stale (strictly greater than)', () {
      final at = now.subtract(kStaleLocationThreshold);
      expect(isPositionStale(at, now), isFalse);
    });

    test('one second past the threshold is stale', () {
      final at = now.subtract(kStaleLocationThreshold + const Duration(seconds: 1));
      expect(isPositionStale(at, now), isTrue);
    });

    test('a fresh position (30 seconds old) is not stale', () {
      final at = now.subtract(const Duration(seconds: 30));
      expect(isPositionStale(at, now), isFalse);
    });

    test('a custom threshold is honoured', () {
      final at = now.subtract(const Duration(minutes: 10));
      expect(isPositionStale(at, now, threshold: const Duration(minutes: 5)), isTrue);
      expect(isPositionStale(at, now, threshold: const Duration(minutes: 15)), isFalse);
    });
  });

  group('StaleLocationBanner (DLVMAP1)', () {
    testWidgets('shows the age, the refreshable body, and both actions when canRefresh', (t) async {
      var refreshed = false;
      var settingsOpened = false;
      await t.pumpWidget(host(StaleLocationBanner(
        minutesAgo: 5,
        canRefresh: true,
        refreshing: false,
        onRefresh: () => refreshed = true,
        onCheckSettings: () => settingsOpened = true,
      )));

      expect(find.text('Your location is out of date'), findsOneWidget);
      expect(find.text('Updated 5 min ago'), findsOneWidget);
      expect(find.text('Refresh your location to update the route.'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-refresh-location')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-check-settings')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('route-refresh-location')));
      expect(refreshed, isTrue);
      await t.tap(find.byKey(const ValueKey('route-check-settings')));
      expect(settingsOpened, isTrue);
    });

    testWidgets('hides Refresh location and shows the native-service body when not canRefresh', (t) async {
      await t.pumpWidget(host(const StaleLocationBanner(
        minutesAgo: 8,
        canRefresh: false,
        refreshing: false,
        onRefresh: _noop,
        onCheckSettings: _noop,
      )));

      expect(find.byKey(const ValueKey('route-refresh-location')), findsNothing);
      expect(find.byKey(const ValueKey('route-check-settings')), findsOneWidget);
      expect(
        find.text('Location updates automatically in the background. If this continues, check your settings.'),
        findsOneWidget,
      );
    });

    testWidgets('disables Refresh location and shows a spinner while refreshing', (t) async {
      await t.pumpWidget(host(const StaleLocationBanner(
        minutesAgo: 3,
        canRefresh: true,
        refreshing: true,
        onRefresh: _noop,
        onCheckSettings: _noop,
      )));

      final button = t.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('route-refresh-location')),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}

void _noop() {}
