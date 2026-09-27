// ADMR-62 — Support case detail.
//
// Every mutating action (assign/change-status/resolve/reopen/add-note)
// calls a real Cloud Function, which these widget tests deliberately
// never invoke -- that path is what ADMR-61's own emulator suites already
// proved (23/23, including the version-mismatch race). These tests cover
// what a fake_cloud_firestore harness CAN prove honestly: rendering,
// found/not-found states, and which actions the UI exposes for a given
// status (resolve/reopen are mutually exclusive on purpose, matching the
// server's own refusal of changeSupportCaseStatus for "resolved").
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/support/support_case_detail_screen.dart';

Future<void> _seedCase(
  FakeFirebaseFirestore db,
  String id, {
  String title = 'Late delivery',
  String status = 'open',
  String? assignedTo,
  String? waitingReason,
  String? resolutionSummary,
  Map<String, String> actor = const {'type': 'customer', 'id': 'cust_1'},
}) async {
  await db.collection('support_cases').doc(id).set({
    'caseId': id,
    'title': title,
    'category': 'delivery_issue',
    'primaryActor': actor,
    'status': status,
    'waitingReason': waitingReason,
    'assignedTo': assignedTo,
    'createdBy': 'admin_1',
    'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    'resolutionSummary': resolutionSummary,
    'resolvedAt': null,
    'resolvedBy': null,
    'reopenedAt': null,
    'reopenedBy': null,
    'reopenReason': null,
    'version': 1,
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String caseId, {
  String? currentUid,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SupportCaseDetailScreen(
        caseId: caseId,
        firestore: firestore,
        currentUid: currentUid ?? 'admin_me',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a missing case shows an honest not-found state, not a crash', (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpScreen(tester, db, 'does_not_exist');

    expect(find.text('This support case no longer exists.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the found case\'s title, category and actor', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', title: 'Late delivery', status: 'open');

    await pumpScreen(tester, db, 'c1');

    expect(find.text('Late delivery'), findsOneWidget);
    expect(find.text('Delivery issue'), findsOneWidget);
    expect(find.textContaining('Customer cust_1'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
  });

  testWidgets('an open case offers Change status and Resolve, not Reopen', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', status: 'open');

    await pumpScreen(tester, db, 'c1');

    expect(find.widgetWithText(OutlinedButton, 'Change status'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Resolve'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reopen'), findsNothing);
  });

  testWidgets('a resolved case offers Reopen only, matching the server refusing '
      'changeSupportCaseStatus/resolveSupportCase on an already-resolved case',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', status: 'resolved', resolutionSummary: 'Refund issued.');

    await pumpScreen(tester, db, 'c1');

    expect(find.widgetWithText(FilledButton, 'Reopen'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Change status'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Resolve'), findsNothing);
    expect(find.textContaining('Refund issued.'), findsOneWidget);
  });

  testWidgets('a waiting case shows its waiting reason', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', status: 'waiting', waitingReason: 'awaiting rider reply');

    await pumpScreen(tester, db, 'c1');

    expect(find.textContaining('awaiting rider reply'), findsOneWidget);
  });

  testWidgets('assignment to the current admin reads "you", not their raw uid', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', assignedTo: 'admin_me');

    await pumpScreen(tester, db, 'c1', currentUid: 'admin_me');

    expect(find.textContaining('Assigned to you'), findsOneWidget);
  });

  testWidgets('Notes tab lists real notes for this case only, newest first', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1');
    await _seedCase(db, 'c2'); // a second case whose notes must never leak in
    await db.collection('support_case_notes').add({
      'noteId': 'n1',
      'caseId': 'c1',
      'authorUid': 'admin_me',
      'text': 'Called the customer back.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
    });
    await db.collection('support_case_notes').add({
      'noteId': 'n2',
      'caseId': 'c1',
      'authorUid': 'admin_other',
      'text': 'Escalated to the seller.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
    });
    await db.collection('support_case_notes').add({
      'noteId': 'n3',
      'caseId': 'c2',
      'authorUid': 'admin_me',
      'text': 'A note on a different case.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 4)),
    });

    await pumpScreen(tester, db, 'c1', currentUid: 'admin_me');
    // Notes is the tab shown by default (index 0).

    expect(find.text('Called the customer back.'), findsOneWidget);
    expect(find.text('Escalated to the seller.'), findsOneWidget);
    expect(find.text('A note on a different case.'), findsNothing);
    final newerY = tester.getTopLeft(find.text('Escalated to the seller.')).dy;
    final olderY = tester.getTopLeft(find.text('Called the customer back.')).dy;
    expect(newerY, lessThan(olderY));
  });

  testWidgets('Activity tab describes each real event type in plain language', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1');
    await db.collection('support_case_events').add({
      'caseId': 'c1',
      'type': 'created',
      'actorUid': 'admin_me',
      'at': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'details': {'title': 'Late delivery'},
    });
    await db.collection('support_case_events').add({
      'caseId': 'c1',
      'type': 'resolved',
      'actorUid': 'admin_me',
      'at': Timestamp.fromDate(DateTime(2026, 9, 2)),
      'details': {'resolutionSummary': 'Refund issued.'},
    });

    await pumpScreen(tester, db, 'c1');
    await tester.tap(find.widgetWithText(Tab, 'Activity'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Case created: Late delivery'), findsOneWidget);
    expect(find.textContaining('Resolved: Refund issued.'), findsOneWidget);
  });
}
