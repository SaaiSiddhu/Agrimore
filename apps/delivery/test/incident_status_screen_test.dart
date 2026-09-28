// Phase DLVC3 — IncidentStatusScreen/MyIncidentsScreen: the persistent
// rider-facing destination emergency_sheet.dart's own live report card
// never had -- reachable after that sheet closes, from Profile, or from a
// notification, and reopenable after an app restart.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/safety/incident_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('IncidentStatusScreen', () {
    testWidgets('a reported (not yet seen) incident shows the recorded state', (t) async {
      await t.pumpWidget(host(IncidentStatusScreen(
        incidentId: 'r1_req1',
        watcher: (_) => Stream.value({'status': 'reported', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 20))}),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Report recorded'), findsOneWidget);
      expect(find.textContaining('Last updated'), findsOneWidget);
    });

    testWidgets('an acknowledged incident shows the seen state', (t) async {
      await t.pumpWidget(host(IncidentStatusScreen(
        incidentId: 'r1_req1',
        watcher: (_) => Stream.value({
          'status': 'acknowledged',
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 20)),
          'acknowledgedAt': Timestamp.fromDate(DateTime(2026, 9, 20, 1)),
        }),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Seen by the Agrimore team'), findsOneWidget);
    });

    testWidgets('a resolved incident shows the exact resolution text', (t) async {
      await t.pumpWidget(host(IncidentStatusScreen(
        incidentId: 'r1_req1',
        watcher: (_) => Stream.value({
          'status': 'resolved',
          'resolution': 'Confirmed the rider is safe; escort arranged.',
          'resolvedAt': Timestamp.fromDate(DateTime(2026, 9, 20, 2)),
        }),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Closed by the Agrimore team'), findsOneWidget);
      expect(find.textContaining('Confirmed the rider is safe; escort arranged.'), findsOneWidget);
    });

    testWidgets('a missing/deleted incident shows an honest not-available card, not a crash', (t) async {
      await t.pumpWidget(host(IncidentStatusScreen(incidentId: 'gone', watcher: (_) => Stream.value(null))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('This report is no longer available.'), findsOneWidget);
    });

    testWidgets('an unauthorized read (permission-denied) shows the SAME honest not-available card', (t) async {
      await t.pumpWidget(host(IncidentStatusScreen(
        incidentId: 'not-mine',
        watcher: (_) => Stream<Map<String, dynamic>?>.error(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        ),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'a permission-denied read must degrade to a message, never crash');
      expect(find.text('Not available'), findsOneWidget);
    });
  });

  group('MyIncidentsScreen', () {
    testWidgets('no reports shows the empty state', (t) async {
      await t.pumpWidget(host(MyIncidentsScreen(riderId: 'r1', incidentsSource: (_) => Stream.value(const []))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text("You haven't filed a safety report."), findsOneWidget);
    });

    testWidgets('lists past reports and opens the tapped one\'s exact status', (t) async {
      await t.pumpWidget(host(MyIncidentsScreen(
        riderId: 'r1',
        incidentsSource: (_) => Stream.value([
          {'incidentId': 'r1_a', 'status': 'resolved', 'resolvedAt': Timestamp.fromDate(DateTime(2026, 9, 18))},
          {'incidentId': 'r1_b', 'status': 'reported', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 20))},
        ]),
        watcher: (_) => Stream.value(const {'status': 'reported'}),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('incident-r1_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-r1_b')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('incident-r1_b')));
      await t.pumpAndSettle();
      final screen = t.widget<IncidentStatusScreen>(find.byType(IncidentStatusScreen));
      expect(screen.incidentId, 'r1_b', reason: 'tapping the SECOND row must open THAT exact incident, not the first');
    });
  });
}
