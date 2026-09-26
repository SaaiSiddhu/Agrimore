// Phase DLVMAP2 — the shared external-navigation launch sequence and its
// retry/copy-coordinates fallback (21.7 External navigation handoff).
import 'package:agrimore_ui/agrimore_ui.dart' show DeliveryPoint, WorkspaceBrand, WorkspaceTheme;
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/navigation/navigation_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _dest = DeliveryPoint(lat: 9.925201, lng: 78.119775);

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: (context) => child)),
    );

void main() {
  group('launchExternalNavigation (DLVMAP2)', () {
    test('turn-by-turn succeeding is reported, directions never tried', () async {
      final calls = <Uri>[];
      final result = await launchExternalNavigation(
        _dest,
        launcher: (uri, mode) async {
          calls.add(uri);
          return true;
        },
      );
      expect(result, NavigationLaunchResult.turnByTurn);
      expect(calls, hasLength(1));
      expect(calls.single.scheme, 'google.navigation');
    });

    test('turn-by-turn throwing falls through to directions', () async {
      final calls = <Uri>[];
      final result = await launchExternalNavigation(
        _dest,
        launcher: (uri, mode) async {
          calls.add(uri);
          if (calls.length == 1) throw Exception('no handler');
          return true;
        },
      );
      expect(result, NavigationLaunchResult.directions);
      expect(calls, hasLength(2));
    });

    test('turn-by-turn returning false falls through to directions', () async {
      final calls = <Uri>[];
      final result = await launchExternalNavigation(
        _dest,
        launcher: (uri, mode) async {
          calls.add(uri);
          return calls.length != 1;
        },
      );
      expect(result, NavigationLaunchResult.directions);
      expect(calls, hasLength(2));
    });

    test('both failing is reported as failed', () async {
      final result = await launchExternalNavigation(_dest, launcher: (uri, mode) async => false);
      expect(result, NavigationLaunchResult.failed);
    });

    test('both throwing is reported as failed, not propagated', () async {
      final result = await launchExternalNavigation(
        _dest,
        launcher: (uri, mode) async => throw Exception('no handler'),
      );
      expect(result, NavigationLaunchResult.failed);
    });
  });

  group('launchExternalNavigationWithFallback (DLVMAP2)', () {
    testWidgets('a successful launch never shows the fallback sheet', (t) async {
      await t.pumpWidget(host(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => launchExternalNavigationWithFallback(
            context,
            _dest,
            launcher: (uri, mode) async => true,
          ),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Could not open navigation'), findsNothing);
    });

    testWidgets('a total failure shows the fallback sheet with both actions', (t) async {
      await t.pumpWidget(host(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => launchExternalNavigationWithFallback(
            context,
            _dest,
            launcher: (uri, mode) async => false,
          ),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Could not open navigation'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-failed-retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-failed-copy')), findsOneWidget);
    });

    testWidgets('Try again re-launches, and a subsequent success dismisses the sheet', (t) async {
      var attempt = 0;
      await t.pumpWidget(host(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => launchExternalNavigationWithFallback(
            context,
            _dest,
            launcher: (uri, mode) async {
              attempt++;
              // Both calls (turn-by-turn, then directions) of the first
              // launchExternalNavigation fail; the retry's first call
              // (turn-by-turn) succeeds.
              return attempt > 2;
            },
          ),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Could not open navigation'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('nav-failed-retry')));
      await t.pumpAndSettle();
      expect(find.text('Could not open navigation'), findsNothing);
      // 2 attempts per launchExternalNavigation call before success: the
      // first call tries turn-by-turn (fails) then directions (fails); the
      // retry's first launcher call (turn-by-turn) succeeds.
      expect(attempt, 3);
    });

    testWidgets('Copy coordinates copies lat,lng and dismisses the sheet', (t) async {
      final copied = <ClipboardData>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(ClipboardData(text: (call.arguments as Map)['text'] as String));
        }
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await t.pumpWidget(host(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => launchExternalNavigationWithFallback(
            context,
            _dest,
            launcher: (uri, mode) async => false,
          ),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('nav-failed-copy')));
      await t.pumpAndSettle();
      expect(find.text('Could not open navigation'), findsNothing);
      expect(copied.single.text, '9.925201,78.119775');
      expect(find.text('Coordinates copied'), findsOneWidget);
    });
  });
}
