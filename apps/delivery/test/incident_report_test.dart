// Phase DLV-S2 — "Tell the Agrimore team": one report per sheet (retries reuse
// the request id), never blocked by GPS, and the status shown is the
// record's, never a promise that help is coming.
import 'dart:async';
import 'dart:math';

import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/safety/emergency_sheet.dart';
import 'package:delivery/safety/incident_report.dart';
import 'package:flutter/material.dart';
import 'support/ws_app.dart';
import 'package:flutter_test/flutter_test.dart';

// Words that would promise a response nobody has committed to.
// (The sheet's own "does not alert the police" is a disclaimer, not a promise.)
final promises = RegExp(
    r'\b((police|ambulance|help|someone|the team) (is|are|will be) (coming|on (its|their|the) way|sent)|on (its|their|the) way|dispatched|will (call|reach|contact) you)\b',
    caseSensitive: false);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  group('pure', () {
    test('request ids fit the server pattern and differ', () {
      final a = newIncidentRequestId(), b = newIncidentRequestId();
      expect(RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(a), isTrue);
      expect(a, isNot(b));
      expect(newIncidentRequestId(Random(1)), newIncidentRequestId(Random(1)));
    });

    test('status wording follows the record and promises nothing', () {
      expect(incidentStatusText(l, null).title, 'Report recorded');
      expect(incidentStatusText(l, {'status': 'reported'}).detail, contains('may have seen it yet'));
      expect(incidentStatusText(l, {'status': 'acknowledged'}).title, 'Seen by the Agrimore team');
      final r = incidentStatusText(l, {'status': 'resolved', 'resolution': ' Called you; bike towed. '});
      expect(r.title, 'Closed by the Agrimore team');
      expect(r.detail, 'Called you; bike towed.');
      expect(incidentStatusText(l, {'status': 'resolved'}).detail, 'No note was added.');
      for (final s in ['reported', 'acknowledged']) {
        final t = incidentStatusText(l, {'status': s});
        expect(promises.hasMatch('${t.title} ${t.detail}'), isFalse, reason: s);
      }
    });

    test('refusals are sentences, never the raw code', () {
      expect(incidentErrorMessage(l, 'resource-exhausted', 'too_many'), contains('Too many reports'));
      expect(incidentErrorMessage(l, 'permission-denied', 'not_a_rider'), contains('cannot report here'));
      expect(incidentErrorMessage(l, 'unavailable', null), startsWith('No connection'));
      expect(incidentErrorMessage(l, 'internal', null), contains('call 112'));
    });
  });

  group('sheet', () {
    late List<Map<String, dynamic>> calls;
    late StreamController<Map<String, dynamic>?> record;

    Future<void> pump(WidgetTester t,
        {required IncidentReporter reporter, IncidentFix? fix}) async {
      await t.pumpWidget(wsApp(
        home: Scaffold(
          body: EmergencySheet(
            launcher: (_) async => true,
            supportPhone: '+91 98765 43210',
            reporter: reporter,
            watcher: (_) => record.stream,
            fix: fix ?? () async => {'lat': 9.93, 'lng': 78.12, 'accuracy': 8.0, 'isMocked': false},
          ),
        ),
      ));
    }

    setUp(() {
      calls = [];
      record = StreamController<Map<String, dynamic>?>();
    });
    // Not awaited: close() on a controller nobody listened to never completes.
    tearDown(() {
      record.close();
    });

    testWidgets('no report button on the dial-only sheet', (t) async {
      await t.pumpWidget(wsApp(home: Scaffold(body: EmergencySheet(launcher: (_) async => true))));
      expect(find.text('Tell the Agrimore team'), findsNothing);
    });

    testWidgets('report carries the fix, then shows the record as it moves', (t) async {
      await pump(t, reporter: (p) async {
        calls.add(p);
        return 'r1_${p['requestId']}';
      });
      await t.tap(find.text('Tell the Agrimore team'));
      await t.pumpAndSettle();
      expect(calls.single['kind'], 'sos');
      expect(calls.single['lat'], 9.93);
      expect(find.text('Report recorded'), findsOneWidget);
      expect(find.text('Tell the Agrimore team'), findsNothing);
      record.add({'status': 'acknowledged'});
      await t.pumpAndSettle();
      expect(find.text('Seen by the Agrimore team'), findsOneWidget);
      record.add({'status': 'resolved', 'resolution': 'Spoke to you; safe.'});
      await t.pumpAndSettle();
      expect(find.text('Closed by the Agrimore team'), findsOneWidget);
      expect(find.text('Spoke to you; safe.'), findsOneWidget);
    });

    testWidgets('a failed report says so, and the retry reuses the request id', (t) async {
      var fail = true;
      await pump(t, reporter: (p) async {
        calls.add(p);
        if (fail) throw const IncidentReportException('unavailable');
        return 'r1_x';
      });
      await t.tap(find.text('Tell the Agrimore team'));
      await t.pumpAndSettle();
      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.text('Report recorded'), findsNothing);
      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls[1]['requestId'], calls[0]['requestId']);
      expect(find.text('Report recorded'), findsOneWidget);
    });

    testWidgets('a second tap while sending does not send twice', (t) async {
      final answer = Completer<String>();
      await pump(t, reporter: (p) {
        calls.add(p);
        return answer.future;
      });
      await t.tap(find.text('Tell the Agrimore team'));
      await t.pump();
      await t.tap(find.text('Recording your report…'), warnIfMissed: false);
      await t.pump();
      expect(calls, hasLength(1));
      answer.complete('r1_x');
      await t.pumpAndSettle();
      expect(find.text('Report recorded'), findsOneWidget);
    });

    testWidgets('denied location: the report goes without a position', (t) async {
      await pump(t, fix: () async => {}, reporter: (p) async {
        calls.add(p);
        return 'r1_x';
      });
      await t.tap(find.text('Tell the Agrimore team'));
      await t.pumpAndSettle();
      expect(calls.single.containsKey('lat'), isFalse);
      expect(find.text('Report recorded'), findsOneWidget);
    });

    testWidgets('GPS that never answers holds the report at most 5 s', (t) async {
      await pump(t, fix: () => Completer<Map<String, dynamic>>().future, reporter: (p) async {
        calls.add(p);
        return 'r1_x';
      });
      await t.tap(find.text('Tell the Agrimore team'));
      await t.pump(const Duration(seconds: 4));
      expect(calls, isEmpty);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(calls.single.containsKey('lat'), isFalse);
      expect(find.text('Report recorded'), findsOneWidget);
    });

    testWidgets('nothing on the sheet promises a response', (t) async {
      await pump(t, reporter: (p) async => 'r1_x');
      await t.tap(find.text('Tell the Agrimore team'));
      await t.pumpAndSettle();
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        expect(promises.hasMatch(w.data ?? ''), isFalse, reason: 'promises: "${w.data}"');
      }
    });
  });
}
