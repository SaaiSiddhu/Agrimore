import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_marketplace/providers/review_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/screens/user/shop/widgets/reviews_section.dart';
import 'package:agrimore_marketplace/screens/user/shop/widgets/reviews_section_inline.dart';

// Controlled SDK interfaces only; the real provider get() path runs unchanged.
// ignore: subtype_of_sealed_class
class StatsDb extends Fake implements FirebaseFirestore {
  final reads = <String>[];
  final replies = <Completer<DocumentSnapshot<Map<String, dynamic>>>>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      StatsCollection(this, path);
}

// ignore: subtype_of_sealed_class
class StatsCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  StatsCollection(this.db, this.path);
  final StatsDb db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      StatsDocument(db, '$path/$id');
}

// ignore: subtype_of_sealed_class
class StatsDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  StatsDocument(this.db, this.path);
  final StatsDb db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String id) =>
      StatsCollection(db, '$path/$id');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    db.reads.add(path);
    final reply = Completer<DocumentSnapshot<Map<String, dynamic>>>();
    db.replies.add(reply);
    return reply.future;
  }
}

// ignore: subtype_of_sealed_class
class StatsSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  StatsSnapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

StatsSnapshot stats(double average) => StatsSnapshot({
      'averageRating': average,
      'totalReviews': 1,
      'fiveStarCount': average == 5 ? 1 : 0
    });

class PublicStatsProvider extends ReviewProvider {
  PublicStatsProvider(StatsDb db) : super(firestore: db);
  @override
  Stream<List<ReviewModel>> getReviewsStream(String productId) =>
      Stream.value(const []);
}

void main() {
  test('owned SDK stats path remains available', () async {
    final db = StatsDb();
    final provider = ReviewProvider(firestore: db);
    addTearDown(provider.dispose);
    final read = provider.loadReviewStats('A');
    expect(db.reads, ['products/A/reviewStats/stats']);
    db.replies.single.complete(stats(5));
    await read;
    expect(provider.reviewStats?.averageRating, 5);
  });
  test('prior product completion cannot replace latest requested product',
      () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final a = p.loadReviewStats('A'), b = p.loadReviewStats('B');
    db.replies[1].complete(stats(4));
    await b;
    db.replies[0].complete(stats(1));
    await a;
    expect(p.reviewStats?.averageRating, 4);
  });
  test('same product newer read wins over stale completion', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final first = p.loadReviewStats('A'), second = p.loadReviewStats('A');
    db.replies[1].complete(stats(5));
    await second;
    db.replies[0].complete(stats(1));
    await first;
    expect(p.reviewStats?.averageRating, 5);
  });
  test('failure is unavailable rather than fabricated zero reviews', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final read = p.loadReviewStats('A');
    db.replies.single.completeError(StateError('fixture SDK'));
    await read;
    expect(p.reviewStats, isNull);
  });
  test('disposal refuses pending stats result and notification', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    final read = p.loadReviewStats('A');
    p.dispose();
    db.replies.single.complete(stats(5));
    await expectLater(read, completes);
    expect(p.reviewStats, isNull);
  });
  test('missing document is confirmed empty stats', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final read = p.loadReviewStats('A');
    db.replies.single.complete(StatsSnapshot(null));
    await read;
    expect(p.reviewStats?.totalReviews, 0);
  });
  test('different product slots retain independent confirmed data', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final a = p.loadReviewStats('A'), b = p.loadReviewStats('B');
    db.replies[1].complete(stats(4));
    await b;
    db.replies[0].complete(stats(1));
    await a;
    expect(p.reviewStatsFor('A')?.averageRating, 1);
    expect(p.reviewStatsFor('B')?.averageRating, 4);
  });
  test('old read error cannot replace new success or loading state', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final first = p.loadReviewStats('A'), second = p.loadReviewStats('A');
    db.replies[1].complete(stats(5));
    await second;
    db.replies[0].completeError(StateError('late'));
    await first;
    expect(p.reviewStatsFor('A')?.averageRating, 5);
    expect(p.hasStatsError('A'), false);
    expect(p.isLoadingStats('A'), false);
  });
  test('retry clears failed state then publishes confirmed data', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    addTearDown(p.dispose);
    final first = p.loadReviewStats('A');
    db.replies[0].completeError(StateError('fixture'));
    await first;
    expect(p.hasStatsError('A'), true);
    final retry = p.loadReviewStats('A');
    expect(p.hasStatsError('A'), false);
    expect(p.isLoadingStats('A'), true);
    db.replies[1].complete(stats(3));
    await retry;
    expect(p.reviewStatsFor('A')?.averageRating, 3);
    expect(p.isLoadingStats('A'), false);
  });
  test('invalid product IDs and disposed calls make no SDK read', () async {
    final db = StatsDb(), p = ReviewProvider(firestore: db);
    await p.loadReviewStats('');
    await p.loadReviewStats('A/B');
    p.dispose();
    await p.loadReviewStats('A');
    expect(db.reads, isEmpty);
  });
  for (final data in <Map<String, dynamic>>[
    {'averageRating': double.nan},
    {'averageRating': 8},
    {'totalReviews': -1},
    {'averageRating': 'bad'},
  ]) {
    test('malformed stats are unavailable $data', () async {
      final db = StatsDb(), p = ReviewProvider(firestore: db);
      addTearDown(p.dispose);
      final read = p.loadReviewStats('A');
      db.replies.single.complete(StatsSnapshot(data));
      await read;
      expect(p.reviewStatsFor('A'), isNull);
      expect(p.hasStatsError('A'), true);
    });
  }
  Future<void> mount(WidgetTester t, PublicStatsProvider p,
      {bool inline = true, bool dark = false, String product = 'A'}) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final Widget section = inline
        ? ReviewsSectionInline(
            productId: product, productName: 'Fixture', isDark: dark)
        : ReviewsSection(
            productId: product, productName: 'Fixture', isDark: dark);
    await t.pumpWidget(ChangeNotifierProvider<ReviewProvider>.value(
        value: p,
        child: MaterialApp(
            theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light),
            home: Scaffold(body: section))));
    await t.pump();
  }

  for (final inline in [true, false]) {
    for (final dark in [false, true]) {
      testWidgets('stats section phone error/retry inline=$inline dark=$dark',
          (t) async {
        final db = StatsDb();
        final provider = PublicStatsProvider(db);
        addTearDown(provider.dispose);
        await mount(t, provider, inline: inline, dark: dark);
        db.replies[0].completeError(StateError('unsafe fixture SDK'));
        await t.pump();
        await t.pump();
        expect(find.text('Review ratings are unavailable right now.'),
            findsOneWidget);
        expect(find.textContaining('unsafe fixture'), findsNothing);
        expect(find.text('0.0'), findsNothing);
        await t.tap(find.text('Try Again'));
        await t.pump();
        expect(db.reads.length, 2);
        db.replies[1].complete(stats(5));
        await t.pump();
        await t.pump();
        expect(find.text('5.0'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
    testWidgets(
        'retained section uses new product before late old response inline=$inline',
        (t) async {
      final db = StatsDb(), p = PublicStatsProvider(db);
      addTearDown(p.dispose);
      await mount(t, p, inline: inline);
      await mount(t, p, inline: inline, product: 'B');
      db.replies[1].complete(stats(4));
      await t.pump();
      await t.pump();
      db.replies[0].complete(stats(1));
      await t.pump();
      await t.pump();
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('1.0'), findsNothing);
    });
    testWidgets('provider replacement reloads exact product inline=$inline',
        (t) async {
      final db = StatsDb(), other = StatsDb();
      final first = PublicStatsProvider(db),
          second = PublicStatsProvider(other);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await mount(t, first, inline: inline);
      await mount(t, second, inline: inline);
      expect(other.reads, ['products/A/reviewStats/stats']);
      other.replies.single.complete(stats(4));
      await t.pump();
      await t.pump();
      db.replies.single.complete(stats(1));
      await t.pump();
      await t.pump();
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('1.0'), findsNothing);
    });
  }
}
