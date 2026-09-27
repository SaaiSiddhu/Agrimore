// Phase DLVBANK1 — the bank-change-request screen, pinned to one specific
// historical request (opened from a notification), mirroring
// identity_change_screen_test.dart's own fake-backend shape exactly.
import 'dart:async';

import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/screens/money/bank_change_request_screen.dart';
import 'package:delivery/screens/money/money_screen.dart' show BankChangeForm;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keyed by request id. A key mapped to `null` means "exists in the map but
/// not found" (deleted/inaccessible); a missing key means "still loading"
/// (never emits) -- same convention as identity_change_screen_test.dart's
/// own FakeIdentityBackend.byId.
class FakeBankChangeSource {
  final byId = <String, BankChangeRequest?>{};
  final _controllers = <String, StreamController<BankChangeRequest?>>{};

  Stream<BankChangeRequest?> call(String requestId) {
    final controller = _controllers.putIfAbsent(
        requestId, () => StreamController<BankChangeRequest?>.broadcast());
    if (!byId.containsKey(requestId)) return controller.stream;
    return Stream.multi((c) {
      c.add(byId[requestId]);
      c.addStream(controller.stream);
    });
  }
}

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('BankChangeRequestScreen: pinned to a specific request, from a notification (DLVBANK1)', () {
    testWidgets('pending shows the pending title and the reviewing copy', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'pending');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pumpAndSettle();
      expect(find.text('Request pending review'), findsOneWidget);
      expect(find.text('Your change is being checked by the Agrimore team.'), findsOneWidget);
    });

    testWidgets('approved shows the approved title and body, not the pending copy', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'approved');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pumpAndSettle();
      expect(find.text('Payout details updated'), findsOneWidget);
      expect(find.text('Request pending review'), findsNothing);
    });

    testWidgets('rejected shows the reason and a Correct and resend action', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'rejected', rejectionReason: 'IFSC does not match the bank');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pumpAndSettle();
      expect(find.text('Your last change was not approved: IFSC does not match the bank'), findsOneWidget);
      expect(find.byKey(const ValueKey('bank-change-correct')), findsOneWidget);
    });

    testWidgets('rejected with no reason falls back to the no-reason copy', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'rejected');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pumpAndSettle();
      expect(find.text('Your last change was not approved.'), findsOneWidget);
    });

    testWidgets('tapping Correct and resend opens the real bank-change form', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'rejected', rejectionReason: 'x');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('bank-change-correct')));
      await t.pumpAndSettle();
      expect(find.byType(BankChangeForm), findsOneWidget);
    });

    testWidgets('a request that no longer exists shows a distinct not-found state, never a blank crash', (t) async {
      final src = FakeBankChangeSource()..byId['gone'] = null;
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'gone', backend: src.call)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Request not available'), findsOneWidget);
    });

    testWidgets('still loading shows a spinner, not a premature empty/not-found state', (t) async {
      final src = FakeBankChangeSource(); // 'req-1' has no key at all: never emits
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Request not available'), findsNothing);
    });

    testWidgets('two historical requests: opening req-1 shows ONLY req-1, never req-2 (exact targeting, not "latest")', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'rejected', rejectionReason: 'Older: name mismatch')
        ..byId['req-2'] = const BankChangeRequest(id: 'req-2', status: 'pending');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-1', backend: src.call)));
      await t.pumpAndSettle();
      expect(find.text('Your last change was not approved: Older: name mismatch'), findsOneWidget);
      expect(find.text('Request pending review'), findsNothing,
          reason: 'req-2 is a newer request; opening req-1 must never show req-2\'s own pending state');
    });

    testWidgets('the same two requests opened the other way round shows ONLY req-2', (t) async {
      final src = FakeBankChangeSource()
        ..byId['req-1'] = const BankChangeRequest(id: 'req-1', status: 'rejected', rejectionReason: 'Older: name mismatch')
        ..byId['req-2'] = const BankChangeRequest(id: 'req-2', status: 'pending');
      await t.pumpWidget(host(BankChangeRequestScreen(riderId: 'r1', requestId: 'req-2', backend: src.call)));
      await t.pumpAndSettle();
      expect(find.text('Request pending review'), findsOneWidget);
      expect(find.textContaining('name mismatch'), findsNothing,
          reason: 'req-1 is a distinct, older request; opening req-2 must never show req-1\'s own rejection reason');
    });
  });
}
