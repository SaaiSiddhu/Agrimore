import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_marketplace/services/order_rating_service.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/user/orders/rate_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;

class RatingTransport {
  final reply = Completer<int>();
  final calls = <Map<String, Object?>>[];
  bool Function()? current;
  Future<int> submit(String order, String uid, int rating, List<String> tags,
      String note, bool Function() isCurrent) {
    current = isCurrent;
    calls.add({
      'order': order,
      'uid': uid,
      'rating': rating,
      'tags': tags,
      'note': note
    });
    return reply.future;
  }
}

// Controlled SDK fixture only; production uses the sealed SDK implementation.
// ignore: subtype_of_sealed_class
class RatingSnapshot<T extends Object?> implements DocumentSnapshot<T> {
  RatingSnapshot(this.value);
  final T? value;
  @override
  T? data() => value;
  @override
  bool get exists => value != null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// Controlled SDK fixture only; production uses the sealed SDK implementation.
// ignore: subtype_of_sealed_class
class RatingRef implements DocumentReference<Map<String, dynamic>> {
  RatingRef(this.path);
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      RatingCollection('$path/$name');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// Controlled SDK fixture only; production uses the sealed SDK implementation.
// ignore: subtype_of_sealed_class
class RatingCollection implements CollectionReference<Map<String, dynamic>> {
  RatingCollection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      RatingRef('$path/$id');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RatingDatabase implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{
    'orders/owned': {'userId': 'owner_a', 'orderStatus': 'delivered'},
  };
  final attempts = <RatingTransaction>[];
  Future<void> Function(String, int)? onRead;
  bool loseRace = false;
  FirebaseException? failure;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      RatingCollection(path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    final tx = RatingTransaction(this);
    attempts.add(tx);
    final value = await handler(tx);
    if (loseRace && attempts.length == 1) {
      records['orders/owned'] = {
        'userId': 'owner_a',
        'orderStatus': 'delivered',
        'rating': 2,
        'isRated': true
      };
      records['orders/owned/reviews/owner_a'] = {
        'userId': 'owner_a',
        'rating': 2
      };
      throw FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied');
    }
    if (failure != null) throw failure!;
    for (final write in tx.writes.entries) {
      records[write.key] = {...?records[write.key], ...write.value};
    }
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RatingTransaction implements Transaction {
  RatingTransaction(this.db);
  final RatingDatabase db;
  final reads = <String>[];
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> ref) async {
    reads.add(ref.path);
    await db.onRead?.call(ref.path, reads.length);
    return RatingSnapshot<T>(db.records[ref.path] as T?);
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    writes[ref.path] = Map.of(data);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Future<void> mount(WidgetTester t, FormAuth a, RatingTransport f,
      {String id = 'OWN-FIXTURE',
      double width = 600,
      bool dark = false}) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: a,
        child: MaterialApp(
            theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light),
            home: RateOrderScreen(orderId: id, submitRating: f.submit))));
    await t.pumpAndSettle();
  }

  Future<void> start(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.star_border).last);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '  Fixture note  ');
    await t.ensureVisible(find.text('Submit Rating'));
    await t.tap(find.text('Submit Rating'));
    await t.pump();
  }

  testWidgets('valid short order ID does not crash', (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f, id: 'abc');
    expect(t.takeException(), isNull);
    expect(find.text('Order #ABC'), findsOneWidget);
  });
  testWidgets('signed-out opening cannot submit or celebrate', (t) async {
    final a = FormAuth()..owner = null, f = RatingTransport();
    await mount(t, a, f);
    if (find.byIcon(Icons.star_border).evaluate().isNotEmpty) await start(t);
    await t.pump();
    expect(find.text('Thank You!'), findsNothing);
    expect(f.calls, isEmpty);
  });
  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('opening form expires with auth epoch $uid', (t) async {
      final a = FormAuth(), f = RatingTransport();
      await mount(t, a, f);
      a.change(uid);
      await t.pumpAndSettle();
      expect(find.text('How was your experience?'), findsNothing);
    });
    testWidgets('pending confirmation cannot celebrate after auth epoch $uid',
        (t) async {
      final a = FormAuth(), f = RatingTransport();
      await mount(t, a, f);
      await start(t);
      a.change(uid);
      f.reply.complete(5);
      await t.pumpAndSettle();
      expect(find.text('Thank You!'), findsNothing);
      expect(f.current!(), isFalse);
    });
  }
  testWidgets('replaced auth provider invalidates pending result', (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f);
    await start(t);
    await mount(t, FormAuth(), f);
    f.reply.complete(5);
    await t.pumpAndSettle();
    expect(find.text('Thank You!'), findsNothing);
  });
  testWidgets('retained route cannot change target while pending', (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f);
    await start(t);
    await mount(t, a, f, id: 'OTHER-FIXTURE');
    f.reply.complete(5);
    await t.pumpAndSettle();
    expect(find.text('Thank You!'), findsNothing);
  });
  testWidgets('current failure shows safe feedback and permits retry',
      (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f);
    await start(t);
    f.reply.completeError(StateError('unsafe fixture SDK detail'));
    await t.pumpAndSettle();
    expect(find.textContaining('unsafe fixture'), findsNothing);
    expect(find.text('Unable to save your rating. Please try again.'),
        findsOneWidget);
    expect(find.text('Thank You!'), findsNothing);
  });
  testWidgets('disposed rating ignores late completion', (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f);
    await start(t);
    await t.pumpWidget(const SizedBox());
    f.reply.complete(5);
    await t.pump();
    expect(t.takeException(), isNull);
    expect(f.current!(), isFalse);
  });
  testWidgets('confirmed rating is displayed without mutable draft changes',
      (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f);
    await start(t);
    expect(f.calls.single['uid'], 'owner_a');
    expect(f.calls.single['note'], 'Fixture note');
    f.reply.complete(3);
    await t.pumpAndSettle();
    expect(find.text('Thank You!'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(3));
  });

  for (final receipt in [0, 6]) {
    testWidgets('invalid receipt cannot celebrate $receipt', (t) async {
      final a = FormAuth(), f = RatingTransport();
      await mount(t, a, f);
      await start(t);
      f.reply.complete(receipt);
      await t.pumpAndSettle();
      expect(find.text('Thank You!'), findsNothing);
      expect(find.text('Unable to save your rating. Please try again.'),
          findsOneWidget);
    });
  }
  testWidgets(
      'double submit and mutable draft changes are blocked while pending',
      (t) async {
    final a = FormAuth(), f = RatingTransport();
    await mount(t, a, f);
    await t.tap(find.byIcon(Icons.star_border).last);
    await t.pumpAndSettle();
    final submit = t
        .widget<GestureDetector>(find
            .ancestor(
                of: find.text('Submit Rating'),
                matching: find.byType(GestureDetector))
            .first)
        .onTap!;
    submit();
    submit();
    await t.pump();
    expect(f.calls.length, 1);
    final stars = find.byIcon(Icons.star);
    final gesture = t.widget<GestureDetector>(find
        .ancestor(of: stars.first, matching: find.byType(GestureDetector))
        .first);
    expect(gesture.onTap, isNull);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    f.reply.complete(5);
    await t.pumpAndSettle();
    expect(find.text('Thank You!'), findsOneWidget);
  });
  for (final dark in [false, true]) {
    testWidgets('phone rating form brightness $dark', (t) async {
      final a = FormAuth(), f = RatingTransport();
      await mount(t, a, f, width: 390, dark: dark);
      expect(find.text('How was your experience?'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  group('actual rating transaction service', () {
    Future<int> submit(RatingDatabase db,
            {bool Function()? current,
            int rating = 4,
            List<String> tags = const ['Fresh Items'],
            String note = 'Fixture'}) =>
        OrderRatingService(firestore: db).submit(
            'owned', 'owner_a', rating, tags, note, current ?? () => true);
    test('paired writes carry captured payload and one stable review ID',
        () async {
      final db = RatingDatabase();
      expect(await submit(db), 4);
      expect(db.attempts.single.reads,
          ['orders/owned', 'orders/owned/reviews/owner_a']);
      expect(db.attempts.single.writes.keys,
          ['orders/owned/reviews/owner_a', 'orders/owned']);
      expect(db.records['orders/owned']!['isRated'], true);
      expect(db.records['orders/owned/reviews/owner_a']!['rating'], 4);
      expect(await submit(db, rating: 5), 4);
      expect(db.attempts.last.writes, isEmpty);
    });
    for (final record in [
      {'userId': 'owner_b', 'orderStatus': 'delivered'},
      {'userId': 'owner_a', 'orderStatus': 'pending'},
      {'userId': 'owner_a', 'orderStatus': 'delivered', 'isRated': 'true'},
      {
        'userId': 'owner_a',
        'orderStatus': 'delivered',
        'isRated': true,
        'rating': 4
      },
    ]) {
      test('refuses ineligible or unreconciled record $record', () async {
        final db = RatingDatabase();
        db.records['orders/owned'] = record;
        await expectLater(submit(db), throwsStateError);
        expect(db.attempts.single.writes, isEmpty);
      });
    }
    for (final field in ['userId', 'rating', 'isRated']) {
      test('existing review requires matching confirmed summary $field',
          () async {
        final db = RatingDatabase();
        await submit(db);
        if (field == 'userId') {
          db.records['orders/owned/reviews/owner_a']!['userId'] = 'other';
        } else {
          db.records['orders/owned']![field] = field == 'rating' ? 5 : false;
        }
        await expectLater(submit(db), throwsStateError);
        expect(db.attempts.last.writes, isEmpty);
      });
    }
    for (final count in [0, 1, 2]) {
      test('session invalidation before/after reads refuses writes $count',
          () async {
        final db = RatingDatabase();
        bool current = count != 0;
        db.onRead = (path, n) async {
          if (n == count) current = false;
        };
        await expectLater(submit(db, current: () => current), throwsStateError);
        expect(db.attempts.every((tx) => tx.writes.isEmpty), true);
      });
    }
    test('captures immutable selected tags before first await', () async {
      final db = RatingDatabase(), tags = <String>['Fresh Items'];
      final held = Completer<void>();
      db.onRead = (path, n) async {
        if (n == 1) await held.future;
      };
      final pending = submit(db, tags: tags);
      tags.clear();
      held.complete();
      expect(await pending, 4);
      expect(
          db.records['orders/owned/reviews/owner_a']!['tags'], ['Fresh Items']);
    });
    test('losing immutable race reads confirmed receipt without more writes',
        () async {
      final db = RatingDatabase()..loseRace = true;
      expect(await submit(db, rating: 5), 2);
      expect(db.attempts.length, 2);
      expect(db.attempts.last.writes, isEmpty);
      expect(db.records['orders/owned/reviews/owner_a']!['rating'], 2);
    });

    test(
        'denied commit without confirmed receipt preserves failure and no writes',
        () async {
      final db = RatingDatabase()
        ..failure = FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied');
      await expectLater(
          submit(db),
          throwsA(isA<FirebaseException>()
              .having((e) => e.code, 'code', 'permission-denied')));
      expect(db.attempts.length, 2);
      expect(db.attempts.last.writes, isEmpty);
      expect(db.records.containsKey('orders/owned/reviews/owner_a'), false);
    });
    test('unavailable commit does not manufacture recovery receipt', () async {
      final db = RatingDatabase()
        ..failure =
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      await expectLater(submit(db), throwsA(isA<FirebaseException>()));
      expect(db.attempts.length, 1);
      expect(db.records.containsKey('orders/owned/reviews/owner_a'), false);
    });
    test('invalid payload refuses transport before any read', () async {
      final db = RatingDatabase();
      await expectLater(submit(db, rating: 6), throwsStateError);
      await expectLater(submit(db, tags: ['invalid']), throwsStateError);
      await expectLater(submit(db, note: 'x' * 2001), throwsStateError);
      expect(db.attempts, isEmpty);
    });
  });
}
