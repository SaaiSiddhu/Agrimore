// Phase DLVID1 — the identity-change request form, its pending/rejected
// status cards, and the inbox/profile entry points into it.
import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/identity/rider_identity.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/profile/identity_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeIdentityBackend implements RiderIdentityBackend {
  final requests = <Map<String, String>>[];
  IdentityRequestException? failWith;
  IdentityChangeRequest? current;
  final _latest = StreamController<IdentityChangeRequest?>.broadcast();

  @override
  Future<String> requestChange({
    required String changeType,
    required String proposedValue,
    required String reason,
  }) async {
    if (failWith != null) throw failWith!;
    requests.add({
      'changeType': changeType,
      'proposedValue': proposedValue,
      'reason': reason,
    });
    return 'req-1';
  }

  @override
  Stream<IdentityChangeRequest?> latestRequest(String riderId) async* {
    yield current;
    yield* _latest.stream;
  }
}

IdentityChangeRequest _request({
  required IdentityChangeStatus status,
  String proposedValue = 'Arjun Kumar',
  String reason = 'Name updated as per new government ID',
  String? rejectionReason,
}) =>
    IdentityChangeRequest(
      id: 'req-1',
      changeType: kIdentityChangeTypeName,
      proposedValue: proposedValue,
      reason: reason,
      status: status,
      rejectionReason: rejectionReason,
      createdAt: DateTime(2026, 9, 26),
    );

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('identity change request form (DLVID1)', () {
    testWidgets('submitting a valid request calls the backend and shows a success toast', (t) async {
      final backend = FakeIdentityBackend();
      await t.pumpWidget(host(IdentityChangeScreen(
        riderId: 'r1',
        currentName: 'Arjun K.',
        backend: backend,
      )));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('identity-name')), 'Arjun Kumar');
      await t.enterText(
        find.byKey(const ValueKey('identity-reason')),
        'Name updated as per new government ID',
      );
      await t.tap(find.byKey(const ValueKey('identity-submit')));
      await t.pumpAndSettle();
      expect(backend.requests, [
        {
          'changeType': 'name',
          'proposedValue': 'Arjun Kumar',
          'reason': 'Name updated as per new government ID',
        }
      ]);
      expect(find.text('Your request has been submitted.'), findsOneWidget);
    });

    testWidgets('a field-specific validation failure shows an inline error, not a toast', (t) async {
      final backend = FakeIdentityBackend()
        ..failWith = const IdentityRequestException(IdentityRequestFailure.invalid, 'proposedValue');
      await t.pumpWidget(host(IdentityChangeScreen(
        riderId: 'r1',
        currentName: 'Arjun K.',
        backend: backend,
      )));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('identity-name')), 'A');
      await t.enterText(find.byKey(const ValueKey('identity-reason')), 'Because');
      await t.tap(find.byKey(const ValueKey('identity-submit')));
      await t.pumpAndSettle();
      expect(find.text('Enter your full legal name (2–100 characters).'), findsOneWidget);
      expect(find.text('Check your details and try again.'), findsNothing);
    });

    testWidgets('already having a pending request shows a distinct message, not a generic one', (t) async {
      final backend = FakeIdentityBackend()
        ..failWith = const IdentityRequestException(IdentityRequestFailure.alreadyPending);
      await t.pumpWidget(host(IdentityChangeScreen(
        riderId: 'r1',
        currentName: 'Arjun K.',
        backend: backend,
      )));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('identity-name')), 'Arjun Kumar');
      await t.enterText(find.byKey(const ValueKey('identity-reason')), 'Because');
      await t.tap(find.byKey(const ValueKey('identity-submit')));
      await t.pumpAndSettle();
      expect(find.text('You already have a request waiting for review.'), findsOneWidget);
    });

    testWidgets('a pending request shows the pending card instead of the form', (t) async {
      final backend = FakeIdentityBackend()
        ..current = _request(status: IdentityChangeStatus.pending);
      await t.pumpWidget(host(IdentityChangeScreen(
        riderId: 'r1',
        currentName: 'Arjun K.',
        backend: backend,
      )));
      await t.pumpAndSettle();
      expect(find.text('Request pending review'), findsOneWidget);
      expect(find.byKey(const ValueKey('identity-submit')), findsNothing);
    });

    testWidgets('a rejected request shows the reason, and Correct and resend reopens the form prefilled', (t) async {
      final backend = FakeIdentityBackend()
        ..current = _request(
          status: IdentityChangeStatus.rejected,
          proposedValue: 'Arjun Kumar',
          reason: 'Name updated as per new government ID',
          rejectionReason: 'Supporting document is unclear',
        );
      await t.pumpWidget(host(IdentityChangeScreen(
        riderId: 'r1',
        currentName: 'Arjun K.',
        backend: backend,
      )));
      await t.pumpAndSettle();
      expect(find.text('Request not approved'), findsOneWidget);
      expect(find.text('Supporting document is unclear'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('identity-correct')));
      await t.pumpAndSettle();
      final nameField = t.widget<TextField>(find.byKey(const ValueKey('identity-name')));
      final reasonField = t.widget<TextField>(find.byKey(const ValueKey('identity-reason')));
      expect(nameField.controller!.text, 'Arjun Kumar');
      expect(reasonField.controller!.text, 'Name updated as per new government ID');
    });
  });
}
