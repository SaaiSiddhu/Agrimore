// ADMR-62 — Support case queue.
//
// currentUid is injectable (mirrors firestore) precisely so these tests
// never need a real signed-in FirebaseAuth user -- see the
// _currentUidOverride comment in support_queue_screen.dart.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/support/support_queue_screen.dart';

Future<void> _seedCase(
  FakeFirebaseFirestore db,
  String id, {
  required String title,
  required String status,
  String? assignedTo,
  DateTime? updatedAt,
}) async {
  await db.collection('support_cases').doc(id).set({
    'caseId': id,
    'title': title,
    'category': 'delivery_issue',
    'primaryActor': {'type': 'customer', 'id': 'cust_$id'},
    'status': status,
    'waitingReason': null,
    'assignedTo': assignedTo,
    'createdBy': 'admin_1',
    'createdAt': Timestamp.fromDate(updatedAt ?? DateTime(2026, 9, 1)),
    'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime(2026, 9, 1)),
    'resolutionSummary': null,
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
  FakeFirebaseFirestore firestore, {
  String? currentUid,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SupportQueueScreen(firestore: firestore, currentUid: currentUid ?? 'admin_me'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every case, newest updatedAt first', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', title: 'Older', status: 'open', updatedAt: DateTime(2026, 9, 1));
    await _seedCase(db, 'c2', title: 'Newer', status: 'open', updatedAt: DateTime(2026, 9, 5));

    await pumpScreen(tester, db);

    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsOneWidget);
    final newerY = tester.getTopLeft(find.text('Newer')).dy;
    final olderY = tester.getTopLeft(find.text('Older')).dy;
    expect(newerY, lessThan(olderY));
  });

  testWidgets('an empty queue shows an honest empty state, not a crash', (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpScreen(tester, db);

    expect(find.text('No support cases yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a status filter narrows the list to that status only', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', title: 'Open case', status: 'open');
    await _seedCase(db, 'c2', title: 'Resolved case', status: 'resolved');

    await pumpScreen(tester, db);
    expect(find.text('Open case'), findsOneWidget);
    expect(find.text('Resolved case'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Resolved'));
    await tester.pumpAndSettle();

    expect(find.text('Resolved case'), findsOneWidget);
    expect(find.text('Open case'), findsNothing);
  });

  testWidgets("'My cases' shows only cases assigned to the current admin", (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', title: 'Mine', status: 'open', assignedTo: 'admin_me');
    await _seedCase(db, 'c2', title: 'Someone else\'s', status: 'open', assignedTo: 'admin_other');
    await _seedCase(db, 'c3', title: 'No assignee yet', status: 'open');

    await pumpScreen(tester, db, currentUid: 'admin_me');
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Someone else\'s'), findsOneWidget);
    expect(find.text('No assignee yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'My cases'));
    await tester.pumpAndSettle();

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Someone else\'s'), findsNothing);
    expect(find.text('No assignee yet'), findsNothing);
  });

  testWidgets('a case row shows its actor, category and assignment state', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedCase(db, 'c1', title: 'Late delivery', status: 'in_progress', assignedTo: 'admin_me');

    await pumpScreen(tester, db, currentUid: 'admin_me');

    expect(find.textContaining('Customer cust_c1'), findsOneWidget);
    expect(find.textContaining('Delivery issue'), findsOneWidget);
    // 'In Progress' also appears on the filter chip, so scope the check to
    // the row itself rather than asserting a bare, ambiguous findsOneWidget.
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('In Progress')),
      findsOneWidget,
    );
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('tapping "New case" opens the create dialog with the real field set', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpScreen(tester, db);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New case'));
    await tester.pumpAndSettle();

    expect(find.text('New support case'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Category'), findsOneWidget);
    expect(find.text('Who this case is about'), findsOneWidget);
    expect(find.widgetWithText(TextField, "Their id"), findsOneWidget);
    // The real createSupportCaseCore schema has no description field --
    // asserting its absence here would guard against silently adding one
    // that the backend would just ignore.
  });
}
