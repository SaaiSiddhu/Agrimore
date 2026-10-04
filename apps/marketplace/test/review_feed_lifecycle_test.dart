import 'dart:async';
import 'package:agrimore_ui/agrimore_ui.dart' show ErrorView;
import 'package:agrimore_marketplace/providers/review_provider.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart' as app_auth;
import 'package:agrimore_marketplace/screens/user/shop/widgets/reviews_section.dart';
import 'package:agrimore_marketplace/screens/user/shop/widgets/reviews_section_inline.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'product_review_stats_lifecycle_test.dart' show StatsDb;
import 'product_review_writer_test.dart' show review;
import 'foundation_edit_profile_form_test.dart' show FormAuth;
import 'add_review_dialog_session_test.dart' show ReviewAuth;

class FeedProvider extends ReviewProvider {
  FeedProvider() : super(firestore: StatsDb());
  bool reject = false;
  final requests = <String>[];
  final replies = <StreamController<List<ReviewModel>>>[];
  @override
  Future<void> loadReviewStats(String productId) async {}
  @override
  ReviewStats? reviewStatsFor(String productId) => ReviewStats(
      averageRating: 4,
      totalReviews: 4,
      fiveStarCount: 0,
      fourStarCount: 4,
      threeStarCount: 0,
      twoStarCount: 0,
      oneStarCount: 0,
      ratingDistribution: const {'1': 0, '2': 0, '3': 0, '4': 4, '5': 0});
  @override
  Stream<List<ReviewModel>> getReviewsStream(String productId) {
    requests.add(productId);
    if (reject) throw StateError('unsafe SDK getter');
    final reply = StreamController<List<ReviewModel>>.broadcast();
    replies.add(reply);
    return reply.stream;
  }

  void refresh() => notifyListeners();
  Future<void> finish() async {
    for (final reply in replies) {
      await reply.close();
    }
    dispose();
  }
}

class FeedFixture {
  final product = ValueNotifier('productA');
  final provider = ValueNotifier(FeedProvider());
  final auth = FormAuth();
  Future<void> mount(WidgetTester t, bool inline) async {
    await t.pumpWidget(ValueListenableBuilder<FeedProvider>(
        valueListenable: provider,
        builder: (_, value, __) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<ReviewProvider>.value(value: value),
                  ChangeNotifierProvider<app_auth.AuthProvider>.value(
                      value: auth),
                  Provider<AuthService>.value(value: ReviewAuth()),
                ],
                child: MaterialApp(
                    home: Scaffold(
                        body: ValueListenableBuilder<String>(
                            valueListenable: product,
                            builder: (_, id, __) => inline
                                ? SingleChildScrollView(
                                    child: ReviewsSectionInline(
                                        productId: id,
                                        productName: id,
                                        isDark: false))
                                : ReviewsSection(
                                    productId: id,
                                    productName: id,
                                    isDark: false)))))));
    await t.pump();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await provider.value.finish();
    provider.dispose();
    product.dispose();
    auth.dispose();
  }
}

void main() {
  for (final inline in [false, true]) {
    testWidgets('feed failure is unavailable with retry inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      f.provider.value.replies.last
          .addError(StateError('unsafe query diagnostic'));
      await t.pump();
      await t.pump();
      expect(find.text('Reviews are unavailable right now.'), findsOneWidget);
      expect(find.textContaining('unsafe query'), findsNothing);
      expect(t.takeException(), isNull);
      await f.finish(t);
    });
    testWidgets('unrelated provider notification keeps feed inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      final count = f.provider.value.requests.length;
      f.provider.value.refresh();
      await t.pump();
      await t.pump();
      expect(f.provider.value.requests.length, count);
      await f.finish(t);
    });
    testWidgets('loading differs from confirmed empty inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      expect(find.text('No Reviews Yet'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      f.provider.value.replies.single.add([]);
      await t.pump();
      await t.pump();
      expect(find.text('No Reviews Yet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await f.finish(t);
    });
    testWidgets('retry rebinds and refuses canceled events inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      final old = f.provider.value.replies.single;
      old.addError(StateError('query refused'));
      await t.pump();
      await t.pump();
      t.widget<ErrorView>(find.byType(ErrorView)).onRetry!();
      await t.pump();
      expect(f.provider.value.requests, ['productA', 'productA']);
      old.add([review(product: 'productA').copyWith(title: 'Old retry data')]);
      await t.pump();
      expect(find.text('Old retry data'), findsNothing);
      f.provider.value.replies.last.add([]);
      await t.pump();
      await t.pump();
      expect(find.text('No Reviews Yet'), findsOneWidget);
      await f.finish(t);
    });
    testWidgets(
        'product replacement clears rows before new data inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      final old = f.provider.value.replies.single;
      old.add([review(product: 'productA').copyWith(title: 'Product A row')]);
      await t.pump();
      await t.pump();
      expect(find.text('Product A row'), findsOneWidget);
      f.product.value = 'productB';
      await t.pump();
      expect(find.text('Product A row'), findsNothing);
      expect(f.provider.value.requests.last, 'productB');
      old.addError(StateError('canceled query'));
      old.add([review(product: 'productA').copyWith(title: 'Late A row')]);
      await t.pump();
      expect(find.text('Late A row'), findsNothing);
      expect(t.takeException(), isNull);
      f.provider.value.replies.last.add([
        review(product: 'productA')
            .copyWith(productId: 'productB', title: 'Product B row')
      ]);
      await t.pump();
      await t.pump();
      expect(find.text('Product B row'), findsOneWidget);
      await f.finish(t);
    });
    testWidgets('provider replacement clears old feed inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      final old = f.provider.value;
      old.replies.single.add(
          [review(product: 'productA').copyWith(title: 'Old provider row')]);
      await t.pump();
      await t.pump();
      f.provider.value = FeedProvider();
      await t.pump();
      expect(find.text('Old provider row'), findsNothing);
      expect(f.provider.value.requests, ['productA']);
      old.replies.single.add(
          [review(product: 'productA').copyWith(title: 'Late provider row')]);
      await t.pump();
      expect(find.text('Late provider row'), findsNothing);
      await old.finish();
      await f.finish(t);
    });
    testWidgets('filter replacement resets rows inline=$inline', (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      f.provider.value.replies.single
          .add([review(product: 'productA').copyWith(title: 'Old filter row')]);
      await t.pump();
      await t.pump();
      f.provider.value.setFilterRating(5);
      await t.pump();
      expect(find.text('Old filter row'), findsNothing);
      expect(f.provider.value.requests.length, 2);
      await f.finish(t);
    });
    testWidgets('error after data hides stale rows inline=$inline', (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      f.provider.value.replies.single
          .add([review(product: 'productA').copyWith(title: 'Prior row')]);
      await t.pump();
      await t.pump();
      f.provider.value.replies.single.addError(StateError('network failure'));
      await t.pump();
      await t.pump();
      expect(find.text('Prior row'), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
      await f.finish(t);
    });
    testWidgets('closed without snapshot is unavailable inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      await f.provider.value.replies.single.close();
      await t.pump();
      await t.pump();
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('No Reviews Yet'), findsNothing);
      await f.finish(t);
    });
    testWidgets('captured retry cannot revive replaced target inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      f.provider.value.replies.single.addError(StateError('query failed'));
      await t.pump();
      await t.pump();
      final retry = t.widget<ErrorView>(find.byType(ErrorView)).onRetry!;
      f.product.value = 'productB';
      await t.pump();
      final count = f.provider.value.requests.length;
      retry();
      await t.pump();
      expect(f.provider.value.requests.length, count);
      await f.finish(t);
    });
    testWidgets('cross-product row is unavailable inline=$inline', (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      f.provider.value.replies.single.add([
        review(product: 'productA')
            .copyWith(productId: 'productB', title: 'Wrong target')
      ]);
      await t.pump();
      await t.pump();
      expect(find.text('Wrong target'), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
      await f.finish(t);
    });
    for (final id in ['', 'bad/path']) {
      testWidgets('invalid target does not query inline=$inline id=$id',
          (t) async {
        final f = FeedFixture();
        f.product.value = id;
        await f.mount(t, inline);
        expect(f.provider.value.requests, isEmpty);
        expect(find.byType(ErrorView), findsOneWidget);
        await f.finish(t);
      });
    }
    testWidgets('synchronous SDK getter failure retries inline=$inline',
        (t) async {
      final f = FeedFixture();
      f.provider.value.reject = true;
      await f.mount(t, inline);
      expect(find.byType(ErrorView), findsOneWidget);
      f.provider.value.reject = false;
      t.widget<ErrorView>(find.byType(ErrorView)).onRetry!();
      await t.pump();
      f.provider.value.replies.single.add([]);
      await t.pump();
      await t.pump();
      expect(find.text('No Reviews Yet'), findsOneWidget);
      await f.finish(t);
    });
    testWidgets(
        'disposed feed rejects late error and captured retry inline=$inline',
        (t) async {
      final f = FeedFixture();
      await f.mount(t, inline);
      final stream = f.provider.value.replies.single;
      stream.addError(StateError('initial refusal'));
      await t.pump();
      await t.pump();
      final retry = t.widget<ErrorView>(find.byType(ErrorView)).onRetry!;
      await t.pumpWidget(const SizedBox());
      final count = f.provider.value.requests.length;
      stream.addError(StateError('late transport detail'));
      retry();
      await t.pump();
      expect(f.provider.value.requests.length, count);
      expect(t.takeException(), isNull);
      await f.finish(t);
    });
  }
  testWidgets('full sheet freezes product and handles query failure/retry',
      (t) async {
    final f = FeedFixture();
    await f.mount(t, true);
    f.provider.value.replies.single.add(List.generate(
        4,
        (i) => review(product: 'productA')
            .copyWith(reviewId: 'row$i', title: 'Opening row $i')));
    await t.pump();
    await t.pump();
    await t.ensureVisible(find.text('View all 4 reviews'));
    await t.tap(find.text('View all 4 reviews'));
    await t.pump(const Duration(milliseconds: 400));
    expect(f.provider.value.requests, ['productA', 'productA']);
    f.provider.value.replies.last.addError(StateError('unsafe sheet error'));
    await t.pump();
    await t.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    final retry = t.widget<ErrorView>(find.byType(ErrorView)).onRetry!;
    f.product.value = 'productB';
    await t.pump();
    retry();
    await t.pump();
    expect(f.provider.value.requests.last, 'productA');
    f.provider.value.replies.last.add([
      review(product: 'productA').copyWith(title: 'Frozen product A sheet row')
    ]);
    await t.pump();
    await t.pump();
    expect(find.text('Frozen product A sheet row'), findsOneWidget);

    final oldProvider = f.provider.value;
    f.provider.value = FeedProvider();
    await t.pump();
    await t.pump();
    expect(find.text('Frozen product A sheet row'), findsNothing);
    final next = f.provider.value;
    expect(next.requests, contains('productA'));
    next.replies[next.requests.indexOf('productA')].add([
      review(product: 'productA').copyWith(title: 'New provider frozen A row')
    ]);
    await t.pump();
    await t.pump();
    expect(find.text('New provider frozen A row'), findsOneWidget);
    await oldProvider.finish();
    expect(t.takeException(), isNull);
    await f.finish(t);
  });
}
