// ADMR-60 — hardens the shared PaginatedQueryList/SectionMessage contract
// used by all four People-360 workspaces (and, next, the support queue).
//
// A _FailingQuery wrapper gives deterministic control over exactly one
// Query<Map<String, dynamic>>.get() call failing or succeeding -- it
// implements the interface and overrides noSuchMethod so only the three
// members PaginatedQueryList actually calls (limit, startAfterDocument,
// get) need real bodies; nothing else is ever invoked on it.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/widgets/paginated_query_list.dart';

class _FailingQuery implements Query<Map<String, dynamic>> {
  _FailingQuery(this._real, this._shouldFail);
  final Query<Map<String, dynamic>> _real;
  final bool Function() _shouldFail;

  @override
  Query<Map<String, dynamic>> limit(int limit) =>
      _FailingQuery(_real.limit(limit), _shouldFail);

  @override
  Query<Map<String, dynamic>> startAfterDocument(DocumentSnapshot<Object?> snapshot) =>
      _FailingQuery(_real.startAfterDocument(snapshot), _shouldFail);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    if (_shouldFail()) {
      throw FirebaseException(
          plugin: 'cloud_firestore', code: 'unavailable', message: 'simulated failure');
    }
    return _real.get(options);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _seed(FakeFirebaseFirestore db, String collection, int count, {int startAt = 0}) async {
  for (var i = startAt; i < startAt + count; i++) {
    await db.collection(collection).doc('doc_$i').set({
      'label': 'Item $i',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1).add(Duration(minutes: i))),
    });
  }
}

void main() {
  group('SectionMessage', () {
    testWidgets('shows no button when onRetry is not given (unchanged existing behavior)',
        (tester) async {
      await tester.pumpWidget(_wrap(const SectionMessage(
        icon: Icons.inbox_outlined,
        message: 'Nothing here.',
      )));

      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('shows a working Try again button when onRetry is given', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(SectionMessage(
        icon: Icons.error_outline,
        message: 'Failed.',
        onRetry: () => tapped++,
      )));

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(tapped, 1);
    });
  });

  group('PaginatedQueryList', () {
    testWidgets('H03: initial failure shows SectionMessage with a working retry',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'items', 3);
      var shouldFail = true;
      final query = _FailingQuery(
        db.collection('items').orderBy('createdAt'),
        () => shouldFail,
      );

      await tester.pumpWidget(_wrap(PaginatedQueryList(
        baseQuery: query,
        emptyLabel: 'No items.',
        itemBuilder: (context, doc) => Text(doc.data()['label'] as String),
      )));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load this. Check your connection and try again."),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.textContaining("Couldn't load"), findsNothing);
    });

    testWidgets(
        'H04: a later-page failure preserves already-loaded records and offers retry '
        'via the reappearing Load more button', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'items', 5);
      var shouldFail = false;
      final query = _FailingQuery(
        db.collection('items').orderBy('createdAt'),
        () => shouldFail,
      );

      await tester.pumpWidget(_wrap(PaginatedQueryList(
        baseQuery: query,
        emptyLabel: 'No items.',
        pageSize: 2,
        itemBuilder: (context, doc) => Text(doc.data()['label'] as String),
      )));
      await tester.pumpAndSettle();

      // First page loaded successfully: 2 of 5, Load more still offered.
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      shouldFail = true;
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      // The failed second page didn't wipe the first page's records, and
      // Load More itself doubles as the retry action (still enabled, not
      // replaced by a dead end).
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.textContaining('Could not load more'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // NOTE ON SCOPE: verifying that a *successful* retry then appends
      // items 2/3 is not provable in this harness -- fake_cloud_firestore
      // 3.1.0 returns an empty result the second time a query object
      // built from a stored/reused Query reference is combined with
      // startAfterDocument, independent of and in addition to the
      // already-disclosed ADMR-56 limitation (that one was about a
      // where()+limit()+startAfterDocument combination specifically;
      // this reproduces with no where() clause at all, confirmed via an
      // isolated, wrapper-free repro before writing this test). Retrying
      // in production hits the real Firestore SDK, not this fake, so the
      // production behavior is unaffected -- only this specific assertion
      // is unverifiable here, disclosed rather than forced.
    });

    testWidgets('H01: changing resetKey clears the old query\'s data and loads the new one',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'items_a', 2);
      await _seed(db, 'items_b', 2, startAt: 100);

      Widget build(String collection, String resetKey) => _wrap(PaginatedQueryList(
            key: const ValueKey('shared'),
            resetKey: resetKey,
            baseQuery: db.collection(collection).orderBy('createdAt'),
            emptyLabel: 'No items.',
            itemBuilder: (context, doc) => Text(doc.data()['label'] as String),
          ));

      await tester.pumpWidget(build('items_a', 'a'));
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);

      await tester.pumpWidget(build('items_b', 'b'));
      await tester.pumpAndSettle();

      expect(find.text('Item 100'), findsOneWidget);
      expect(find.text('Item 0'), findsNothing, reason: 'stale query A data must be cleared');
    });

    testWidgets(
        'H02: a stale in-flight request from the old query cannot overwrite the new '
        'query\'s data, even if it resolves after the switch', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'items_a2', 2);
      await _seed(db, 'items_b2', 2, startAt: 200);

      Widget build(String collection, String resetKey) => _wrap(PaginatedQueryList(
            key: const ValueKey('shared2'),
            resetKey: resetKey,
            baseQuery: db.collection(collection).orderBy('createdAt'),
            emptyLabel: 'No items.',
            itemBuilder: (context, doc) => Text(doc.data()['label'] as String),
          ));

      // Rapid switch with no pump/settle in between: query A's own .get()
      // is still in flight (it needs at least one microtask turn) when
      // query B replaces it via didUpdateWidget.
      await tester.pumpWidget(build('items_a2', 'a'));
      await tester.pumpWidget(build('items_b2', 'b'));
      await tester.pumpAndSettle();

      expect(find.text('Item 200'), findsOneWidget);
      expect(find.text('Item 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'documents sharing the exact same createdAt value all render once, no '
        'duplicates, within a single page', (tester) async {
      // SCOPE: this proves same-timestamp docs are handled correctly WITHIN
      // one fetch. It does NOT prove they survive a real page boundary
      // (H05's fuller claim) -- fake_cloud_firestore 3.1.0 cannot produce a
      // genuine second page here at all (see the H04 test's own note just
      // above), so that specific cross-page claim is disclosed as
      // unverified in this harness rather than forced. Firestore's own
      // documented startAfterDocument contract disambiguates ties by
      // document id regardless; this is a test-tooling gap, not a reason
      // to doubt the production query shape, which is identical to every
      // other already-working People-360 pagination site.
      final db = FakeFirebaseFirestore();
      final tiedAt = Timestamp.fromDate(DateTime(2026, 9, 1));
      for (var i = 0; i < 4; i++) {
        await db.collection('tied').doc('doc_$i').set({'label': 'Tied $i', 'createdAt': tiedAt});
      }

      await tester.pumpWidget(_wrap(PaginatedQueryList(
        baseQuery: db.collection('tied').orderBy('createdAt'),
        emptyLabel: 'No items.',
        pageSize: 10,
        itemBuilder: (context, doc) => Text(doc.data()['label'] as String),
      )));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(find.text('Tied $i'), findsOneWidget, reason: 'Tied $i must appear exactly once');
      }
      expect(find.text('Load more'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
