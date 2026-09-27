// DLVOA1: the discoverable readiness screen. Covers the ready/action-needed
// rendering for each concern, a Fix tap re-invoking the injected readiness
// check (never marking success merely because the fix action was launched
// -- the row only turns green once the NEXT read says so), and the
// lifecycle-driven recheck on resume (a revoked permission reappears as
// needing attention, not silently staying green).
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/offers/device_readiness.dart';
import 'package:delivery/screens/settings/device_readiness_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

List<ReadinessItem> _allReady() => const [
      ReadinessItem(id: ReadinessItemId.notifications, ready: true),
      ReadinessItem(id: ReadinessItemId.fullScreenAlert, ready: true),
      ReadinessItem(id: ReadinessItemId.location, ready: true),
      ReadinessItem(id: ReadinessItemId.backgroundLocation, ready: true),
      ReadinessItem(id: ReadinessItemId.battery, ready: true),
    ];

List<ReadinessItem> _oneActionNeeded() => const [
      ReadinessItem(id: ReadinessItemId.notifications, ready: false),
      ReadinessItem(id: ReadinessItemId.fullScreenAlert, ready: true),
      ReadinessItem(id: ReadinessItemId.location, ready: true),
      ReadinessItem(id: ReadinessItemId.backgroundLocation, ready: true),
      ReadinessItem(id: ReadinessItemId.battery, ready: true),
    ];

void main() {
  testWidgets('every item ready: no action-needed row, no Fix button', (t) async {
    await t.pumpWidget(_host(DeviceReadinessScreen(readiness: () async => _allReady())));
    await t.pumpAndSettle();
    expect(find.text('Action needed'), findsNothing);
    expect(find.text('Fix'), findsNothing);
    expect(find.text('Ready'), findsNWidgets(5));
  });

  testWidgets('one item needs action: shows exactly one Fix button', (t) async {
    await t.pumpWidget(_host(DeviceReadinessScreen(readiness: () async => _oneActionNeeded())));
    await t.pumpAndSettle();
    expect(find.text('Action needed'), findsOneWidget);
    expect(find.text('Fix'), findsOneWidget);
  });

  testWidgets('a non-actionable item never shows a Fix button, even if reported not ready', (t) async {
    // currentDeviceReadiness() never actually produces ready:false with
    // actionable:false (unsupported always reads as ready) -- this fixture
    // is a deliberately adversarial combination to prove the Fix button
    // itself is gated on actionable, independent of ready.
    await t.pumpWidget(_host(DeviceReadinessScreen(
      readiness: () async => const [
        ReadinessItem(id: ReadinessItemId.notifications, ready: true),
        ReadinessItem(id: ReadinessItemId.fullScreenAlert, ready: false, actionable: false),
        ReadinessItem(id: ReadinessItemId.location, ready: true),
        ReadinessItem(id: ReadinessItemId.backgroundLocation, ready: true),
        ReadinessItem(id: ReadinessItemId.battery, ready: true),
      ],
    )));
    await t.pumpAndSettle();
    expect(find.text('Fix'), findsNothing);
  });

  testWidgets('tapping Fix re-reads readiness; the row only turns ready once the read says so', (t) async {
    var calls = 0;
    Future<List<ReadinessItem>> read() async {
      calls++;
      // Still not ready on the SECOND read (the one Fix triggers) -- proves
      // the row does not flip to ready merely because the action launched.
      return calls < 3 ? _oneActionNeeded() : _allReady();
    }

    await t.pumpWidget(_host(DeviceReadinessScreen(readiness: read)));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Action needed'), findsOneWidget);

    await t.tap(find.text('Fix'));
    await t.pumpAndSettle();
    expect(calls, 2);
    // The fix action itself is a no-op off Android; the re-read after it
    // still reports not ready, so the row must still show action-needed.
    expect(find.text('Action needed'), findsOneWidget);
  });

  testWidgets('resuming the app rereads readiness without any user action', (t) async {
    var calls = 0;
    Future<List<ReadinessItem>> read() async {
      calls++;
      return calls == 1 ? _oneActionNeeded() : _allReady();
    }

    await t.pumpWidget(_host(DeviceReadinessScreen(readiness: read)));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Action needed'), findsOneWidget);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Action needed'), findsNothing);
  });
}
