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

  // ADMR-68 additions below: the Linked Records tab for
  // linkSupportCaseRecord/unlinkSupportCaseRecord (ADMR-65, backend-only
  // until now).
  group('Linked Records tab (ADMR-68)', () {
    Future<void> openLinkedRecordsTab(WidgetTester tester, FakeFirebaseFirestore db, String caseId) async {
      await pumpScreen(tester, db, caseId);
      await tester.tap(find.widgetWithText(Tab, 'Linked Records'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows an honest empty state when nothing is linked yet', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');

      await openLinkedRecordsTab(tester, db, 'c1');

      expect(find.text('No linked records yet.'), findsOneWidget);
    });

    testWidgets('a linked order shows a working View link, a linked ticket shows an inline summary '
        'instead of a fabricated route', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');
      await db.doc('orders/order_1').set({'orderNumber': 'ORD-1'});
      await db.doc('rider_support_tickets/ticket_1').set({
        'riderId': 'rider_1', 'category': 'delivery_issue', 'status': 'submitted',
      });
      await db.doc('support_cases/c1').update({
        'linkedRecords': [
          {'type': 'order', 'id': 'order_1'},
          {'type': 'rider_ticket', 'id': 'ticket_1'},
        ],
      });

      await openLinkedRecordsTab(tester, db, 'c1');

      expect(find.text('Order'), findsOneWidget);
      expect(find.text('Rider support ticket'), findsOneWidget);
      // The order has a real detail route -- a working View link, not a
      // fabricated one.
      expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);
      // The ticket has none -- an honest inline summary of its own real
      // fields instead.
      expect(find.textContaining('delivery_issue'), findsOneWidget);
      expect(find.textContaining('submitted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a linked record that no longer exists is disclosed honestly, not hidden or crashed',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');
      await db.doc('support_cases/c1').update({
        'linkedRecords': [
          {'type': 'rider_incident', 'id': 'does-not-exist'},
        ],
      });

      await openLinkedRecordsTab(tester, db, 'c1');

      expect(find.text('This record no longer exists.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Add link" opens a dialog offering only the real constrained record types',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');

      await openLinkedRecordsTab(tester, db, 'c1');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add link'));
      await tester.pumpAndSettle();

      expect(find.text('Add a linked record'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'Record type'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Its id'), findsOneWidget);
    });

    testWidgets('removing a link asks for confirmation and discloses it does not touch the record itself',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');
      await db.doc('orders/order_1').set({'orderNumber': 'ORD-1'});
      await db.doc('support_cases/c1').update({
        'linkedRecords': [
          {'type': 'order', 'id': 'order_1'},
        ],
      });

      await openLinkedRecordsTab(tester, db, 'c1');
      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pumpAndSettle();

      expect(find.text('Remove this link?'), findsOneWidget);
      expect(find.textContaining('does not change or delete'), findsOneWidget);
    });
  });

  // ADMR-71 additions below: the Evidence tab for attachSupportCaseEvidence
  // (server-side idempotent, atomic-audit-event, real-emulator-verified by
  // functions/scripts/phaseADMR71_evidence_test.js). Scoped to what a
  // fake_cloud_firestore harness can honestly prove -- rendering of already-
  // attached evidence records. The upload flow itself (file_picker,
  // firebase_storage) has no platform channel in a bare `flutter test` VM,
  // the same disclosed limitation the three rider-scoped screens already
  // have (ADMR-68's own ledger entry) -- so "Attach evidence" is proven to
  // RENDER, never tapped, and the real upload+finalize path is proven only
  // by the real-emulator suite.
  group('Evidence tab (ADMR-71)', () {
    Future<void> openEvidenceTab(WidgetTester tester, FakeFirebaseFirestore db, String caseId) async {
      await pumpScreen(tester, db, caseId);
      await tester.tap(find.widgetWithText(Tab, 'Evidence'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows an honest empty state when nothing is attached yet', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');

      await openEvidenceTab(tester, db, 'c1');

      expect(find.text('No evidence attached yet.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Attach evidence'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a real evidence record renders its filename, size and uploader', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');
      await db.collection('support_case_evidence').doc('c1_req-0001').set({
        'evidenceId': 'c1_req-0001',
        'caseId': 'c1',
        'storagePath': 'support_case_evidence/c1/req-0001',
        'size': 204800, // 200 KB
        'contentType': 'image/jpeg',
        'originalFileName': 'damaged_parcel.jpg',
        'uploadedBy': 'admin_1',
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      await openEvidenceTab(tester, db, 'c1');

      expect(find.text('damaged_parcel.jpg'), findsOneWidget);
      expect(find.textContaining('200 KB'), findsOneWidget);
      expect(find.textContaining('uploaded by admin_1'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a PDF evidence record shows the document icon, not the image icon', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');
      await db.collection('support_case_evidence').doc('c1_req-0002').set({
        'evidenceId': 'c1_req-0002',
        'caseId': 'c1',
        'storagePath': 'support_case_evidence/c1/req-0002',
        'size': 1048576, // 1 MB
        'contentType': 'application/pdf',
        'originalFileName': 'invoice.pdf',
        'uploadedBy': 'admin_2',
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
      });

      await openEvidenceTab(tester, db, 'c1');

      expect(find.text('invoice.pdf'), findsOneWidget);
      expect(find.textContaining('1.0 MB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('evidence for a DIFFERENT case never leaks into this one\'s list', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedCase(db, 'c1');
      await _seedCase(db, 'c2');
      await db.collection('support_case_evidence').doc('c2_req-0001').set({
        'evidenceId': 'c2_req-0001',
        'caseId': 'c2',
        'storagePath': 'support_case_evidence/c2/req-0001',
        'size': 1000,
        'contentType': 'image/png',
        'originalFileName': 'other_case.png',
        'uploadedBy': 'admin_1',
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      await openEvidenceTab(tester, db, 'c1');

      expect(find.text('No evidence attached yet.'), findsOneWidget);
      expect(find.text('other_case.png'), findsNothing);
    });
  });
}
