// ADMR-63 — the shared actor-scoped support cases section, wired into all
// four People-360 workspaces' Support tabs.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/widgets/actor_support_cases_section.dart';

Future<void> _addCase(
  FakeFirebaseFirestore db, {
  required String title,
  required String actorType,
  required String actorId,
  String status = 'open',
}) {
  return db.collection('support_cases').add({
    'title': title,
    'category': 'delivery_issue',
    'primaryActor': {'type': actorType, 'id': actorId},
    'status': status,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
  }).then((_) {});
}

Future<void> pumpSection(
  WidgetTester tester,
  FakeFirebaseFirestore firestore, {
  required String actorType,
  required String actorId,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActorSupportCasesSection(
            firestore: firestore,
            actorType: actorType,
            actorId: actorId,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an honest empty state for an actor with no cases', (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpSection(tester, db, actorType: 'customer', actorId: 'cust_1');

    expect(find.text('No support cases for this customer yet.'), findsOneWidget);
  });

  testWidgets('shows only cases matching BOTH the actor type and id', (tester) async {
    final db = FakeFirebaseFirestore();
    await _addCase(db, title: 'The real one', actorType: 'rider', actorId: 'shared_id');
    // Same id, different type -- must not match. Proves the query filters on
    // both fields, not id alone.
    await _addCase(db, title: 'Wrong type, same id', actorType: 'seller', actorId: 'shared_id');
    // Same type, different id -- must not match either.
    await _addCase(db, title: 'Wrong id, same type', actorType: 'rider', actorId: 'other_id');

    await pumpSection(tester, db, actorType: 'rider', actorId: 'shared_id');

    expect(find.text('The real one'), findsOneWidget);
    expect(find.text('Wrong type, same id'), findsNothing);
    expect(find.text('Wrong id, same type'), findsNothing);
  });

  testWidgets('"Raise a case" opens a dialog with only title + category, actor already fixed',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpSection(tester, db, actorType: 'seller', actorId: 'seller_1');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Raise a case'));
    await tester.pumpAndSettle();

    expect(find.text('Raise a case for this seller'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Category'), findsOneWidget);
    // No actor-id field is offered -- it's already known, unlike the queue
    // screen's own generic create dialog.
    expect(find.textContaining('Their id'), findsNothing);
  });
}
