import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart' as app_auth;
import 'package:agrimore_marketplace/providers/review_provider.dart';
import 'package:agrimore_marketplace/screens/user/shop/widgets/review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;
import 'add_review_dialog_session_test.dart' show ReviewAuth;
import 'product_review_writer_test.dart' show WriteDb, review;

class FooterFixture {
  FormAuth auth = FormAuth();
  ReviewAuth service = ReviewAuth();
  final db = WriteDb();
  final read = Completer<void>();
  late ReviewProvider provider;
  final product = ValueNotifier('A');
  FooterFixture() {
    db.records['products/A/reviews/legacy'] = review().toMap();
    db.onRead = () => read.future;
    provider = ReviewProvider(firestore: db, reviewUserId: () => service.owner);
  }
  Future<void> mount(WidgetTester t, {bool dark = false}) async {
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<app_auth.AuthProvider>.value(value: auth),
          Provider<AuthService>.value(value: service),
          ChangeNotifierProvider<ReviewProvider>.value(value: provider)
        ],
        child: MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
                body: ValueListenableBuilder<String>(
                    valueListenable: product,
                    builder: (_, value, __) => ReviewCard(
                        review: review(product: value), isDark: dark))))));
  }

  Future<void> tap(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.thumb_up_alt_outlined));
    await t.pump();
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'pending duplicate refusal and safe failure in ${dark ? 'dark' : 'light'}',
        (t) async {
      final f = FooterFixture();
      await f.mount(t, dark: dark);
      await f.tap(t);
      expect(find.text('Saving vote...'), findsOneWidget);
      await t.tap(find.byIcon(Icons.thumb_up_alt_outlined));
      await t.pump();
      expect(f.db.reads.length, 1);
      f.db.failure = FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
          message: 'unsafe diagnostic');
      f.read.complete();
      await t.pumpAndSettle();
      expect(find.text('Could not save your vote. Try again.'), findsOneWidget);
      expect(find.textContaining('unsafe diagnostic'), findsNothing);
      expect(find.text('Saving vote...'), findsNothing);
      expect(t.takeException(), isNull);
      f.db.failure = null;
      await t.tap(find.byIcon(Icons.thumb_up_alt_outlined));
      await t.pumpAndSettle();
      expect(f.db.writes, ['products/A/reviews/legacy']);
      expect(t.takeException(), isNull);
    });
  }
  for (final change in [
    'signout',
    'same-uid',
    'target',
    'provider',
    'auth-provider',
    'service',
    'disposed',
    'covered-route'
  ]) {
    testWidgets('pending vote fences $change', (t) async {
      final f = FooterFixture();
      await f.mount(t);
      await f.tap(t);
      if (change == 'signout') {
        f.service.owner = null;
        f.auth.change(null);
      }
      if (change == 'same-uid') {
        f.auth.change('owner_a');
      }
      if (change == 'target') {
        f.product.value = 'B';
      }
      if (change == 'provider') {
        f.provider = ReviewProvider(
            firestore: f.db, reviewUserId: () => f.service.owner);
        await f.mount(t);
      }
      if (change == 'auth-provider') {
        f.auth = FormAuth();
        await f.mount(t);
      }
      if (change == 'service') {
        f.service = ReviewAuth();
        await f.mount(t);
      }
      if (change == 'disposed') {
        await t.pumpWidget(const SizedBox());
      }
      if (change == 'covered-route') {
        Navigator.of(t.element(find.byType(ReviewCard))).push(
            MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('New route'))));
      }
      await t.pump();
      f.read.complete();
      await t.pumpAndSettle();
      expect(f.db.writes, isEmpty);
      expect(find.text('Could not save your vote. Try again.'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('successful vote keeps other counts and has no premature receipt',
      (t) async {
    final f = FooterFixture();
    await f.mount(t);
    await f.tap(t);
    expect(f.db.writes, isEmpty);
    f.read.complete();
    await t.pumpAndSettle();
    expect(f.db.writes, ['products/A/reviews/legacy']);
    expect(f.db.records['products/A/reviews/legacy']!['helpfulUsers'],
        ['owner_a']);
    expect(find.text('Saving vote...'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
