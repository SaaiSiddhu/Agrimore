// Phase DLV-E1 — reporting a delivery problem after pickup and saving the
// proof photo: the proof never turns a confirmed delivery into a failure;
// a report is sent once per sheet; the panel shows the record's real state.
import 'dart:async';
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/delivery/delivery_problems.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/orders/delivery_problem_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBackend implements DeliveryProblemBackend {
  final reports = <Map<String, dynamic>>[];
  int uploadFailures = 0, attachFailures = 0, uploads = 0, attaches = 0;
  ProblemException? reportFail;

  @override
  Future<String> report(Map<String, dynamic> payload) async {
    reports.add(payload);
    final f = reportFail;
    reportFail = null;
    if (f != null) throw f;
    return '${payload['orderId']}_${payload['requestId']}';
  }

  @override
  Future<void> uploadProof(String orderId, Uint8List bytes, String contentType) async {
    uploads++;
    if (uploadFailures > 0) {
      uploadFailures--;
      throw Exception('upload failed');
    }
  }

  @override
  Future<void> attachProof(String orderId) async {
    attaches++;
    if (attachFailures > 0) {
      attachFailures--;
      throw Exception('attach failed');
    }
  }
}

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('a problem can be reported only once the rider holds the goods', () {
    expect(isAfterPickup('picked_up'), isTrue);
    expect(isAfterPickup('outForDelivery'), isTrue);
    expect(isAfterPickup('delivery_accepted'), isFalse);
    expect(isAfterPickup('arrived_at_store'), isFalse);
    expect(isAfterPickup('delivered'), isFalse);
    expect(afterPickupReasons, contains(DeliveryFailureReason.damagedGoods));
    expect(afterPickupReasons, isNot(contains(DeliveryFailureReason.sellerNotReady)));
  });

  test('record state and refusals', () {
    expect(problemStateOf(null), ProblemState.reported);
    expect(problemStateOf({'status': 'acknowledged'}), ProblemState.seen);
    expect(problemStateOf({'status': 'resolved', 'disposition': 'reattempt'}), ProblemState.reattempt);
    expect(problemStateOf({'status': 'resolved', 'disposition': 'returned_to_seller'}), ProblemState.returnedToSeller);
    expect(problemFailureOf('failed-precondition', 'open_exception'), ProblemFailure.alreadyOpen);
    expect(problemFailureOf('unavailable', null), ProblemFailure.network);
    expect(openExceptionIdOf({'openDeliveryException': {'id': 'x'}}), 'x');
    expect(openExceptionIdOf({}), isNull);
  });

  group('proof', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    test('saved first time', () async {
      final b = FakeBackend();
      expect(await saveDeliveryProof(b, 'o1', bytes, 'image/jpeg'), isTrue);
      expect((b.uploads, b.attaches), (1, 1));
    });
    test('one failure is retried', () async {
      final b = FakeBackend()..uploadFailures = 1;
      expect(await saveDeliveryProof(b, 'o1', bytes, 'image/jpeg'), isTrue);
      expect(b.uploads, 2);
    });
    test('persistent failure returns false and never throws', () async {
      final b = FakeBackend()..attachFailures = 5;
      expect(await saveDeliveryProof(b, 'o1', bytes, 'image/jpeg'), isFalse);
    });
  });

  group('panel', () {
    testWidgets('after pickup with nothing open: the report button', (t) async {
      await t.pumpWidget(host(DeliveryProblemPanel(
        orderId: 'o1',
        orderStream: Stream.value({'orderStatus': 'out_for_delivery'}),
      )));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-problem')), findsOneWidget);
    });

    testWidgets('before pickup: nothing', (t) async {
      await t.pumpWidget(host(DeliveryProblemPanel(
        orderId: 'o1',
        orderStream: Stream.value({'orderStatus': 'delivery_accepted'}),
      )));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-problem')), findsNothing);
    });

    testWidgets('an open problem shows the record as it moves, with Agrimore\'s words', (t) async {
      final ex = StreamController<Map<String, dynamic>?>();
      addTearDown(ex.close);
      await t.pumpWidget(host(DeliveryProblemPanel(
        orderId: 'o1',
        orderStream: Stream.value({'orderStatus': 'out_for_delivery', 'openDeliveryException': {'id': 'o1_r'}}),
        exceptionStream: (_) => ex.stream,
      )));
      ex.add({'status': 'reported'});
      await t.pumpAndSettle();
      expect(find.text('Problem reported'), findsOneWidget);
      ex.add({'status': 'acknowledged'});
      await t.pumpAndSettle();
      expect(find.text('Seen by Agrimore'), findsOneWidget);
      ex.add({'status': 'resolved', 'disposition': 'reattempt', 'resolution': 'Customer is home now.'});
      await t.pumpAndSettle();
      expect(find.text('Try the delivery again'), findsOneWidget);
      expect(find.text('Agrimore wrote: Customer is home now.'), findsOneWidget);
    });

    testWidgets('report sheet: a failure is shown and the retry reuses the request id', (t) async {
      final b = FakeBackend()..reportFail = const ProblemException(ProblemFailure.network);
      await t.pumpWidget(host(ProblemReportSheet(orderId: 'o1', backend: b, fix: () async => {'lat': 9.9, 'lng': 78.1})));
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('problem-send'))).onPressed, isNull, reason: 'pick a reason first');
      await t.tap(find.byKey(const ValueKey('reason-damaged_goods')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('problem-send')));
      await t.tap(find.byKey(const ValueKey('problem-send')));
      await t.pumpAndSettle();
      expect(find.text("No connection — the report didn't go through. Try again."), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('problem-send')));
      await t.tap(find.byKey(const ValueKey('problem-send')));
      await t.pumpAndSettle();
      expect(b.reports, hasLength(2));
      expect(b.reports[1]['requestId'], b.reports[0]['requestId']);
      expect(b.reports[0]['reason'], 'damaged_goods');
      expect(b.reports[0]['lat'], 9.9);
    });
  });
}
