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

  // ADMR-68 additions below: createOrOpenCaseFromSource's own dialog, shared
  // by the three rider-scoped operational screens. Those screens themselves
  // use a hardcoded FirebaseFirestore.instance (not injectable), so they
  // cannot be widget-tested directly -- this proves the shared dialog's own
  // field set and category pre-fill in isolation instead, pumped from a
  // minimal host widget the same way the real screens invoke it.
  group('createOrOpenCaseFromSource dialog (ADMR-68)', () {
    Future<void> pumpHost(WidgetTester tester, {required String defaultCategory}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => createOrOpenCaseFromSource(
                  context,
                  sourceType: 'rider_ticket',
                  sourceId: 'ticket_1',
                  defaultCategory: defaultCategory,
                ),
                child: const Text('Create/open case'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create/open case'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with a title field and the category pre-filled from the source',
        (tester) async {
      await pumpHost(tester, defaultCategory: 'payment_issue');

      expect(find.text('Create or open a support case for this'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      expect(find.text('Payment issue'), findsOneWidget);
    });

    testWidgets('requires a title before continuing', (tester) async {
      await pumpHost(tester, defaultCategory: 'delivery_issue');

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required.'), findsOneWidget);
      // Still on the dialog -- it never popped with an empty title.
      expect(find.text('Create or open a support case for this'), findsOneWidget);
    });

    testWidgets('Cancel closes the dialog without calling anything', (tester) async {
      await pumpHost(tester, defaultCategory: 'delivery_issue');

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create or open a support case for this'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
