import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart' as app_auth;
import 'package:agrimore_marketplace/screens/user/shop/widgets/review_card.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;
import 'add_review_dialog_session_test.dart' show ReviewAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_marketplace/providers/review_provider.dart';
import 'product_review_writer_test.dart' show WriteDb, review;

void main() {
  test('delete refuses a foreign author and leaves record intact', () async {
    final db = WriteDb();
    db.records['products/productA/reviews/legacy'] = {
      'userId': 'other',
      'productId': 'productA',
      'rating': 4,
    };
    final provider =
        ReviewProvider(firestore: db, reviewUserId: () => 'ownerA');
    await expectLater(
        provider.deleteReview('productA', 'legacy'), throwsException);
    expect(db.records, isNotEmpty);
    expect(db.writes, isEmpty);
    provider.dispose();
  });
  test('delete propagates SDK refusal instead of confirming success', () async {
    final db = WriteDb()
      ..failure =
          FirebaseException(plugin: 'firestore', code: 'permission-denied');
    db.records['products/productA/reviews/legacy'] = {
      'userId': 'ownerA',
      'productId': 'productA',
      'rating': 4,
    };
    final provider =
        ReviewProvider(firestore: db, reviewUserId: () => 'ownerA');
    await expectLater(
        provider.deleteReview('productA', 'legacy'), throwsException);
    expect(db.writes, isEmpty);
    provider.dispose();
  });
  test('owned add writes only stable author content and never aggregates',
      () async {
    final db = WriteDb();
    final provider =
        ReviewProvider(firestore: db, reviewUserId: () => 'ownerA');
    await provider.addReview(
        productId: 'productA',
        userId: 'ownerA',
        userName: 'Author',
        userAvatar: '',
        rating: 4,
        title: 'Good',
        comment: 'Useful');
    expect(db.writes, ['products/productA/reviews/ownerA']);
    expect(db.records.values.single.containsKey('isVerifiedPurchase'), isFalse);
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });
  test('edit preserves existing author profile and trust metadata', () async {
    final db = WriteDb();
    db.records['products/productA/reviews/legacy'] = {
      ...review().toMap(),
      'userId': 'ownerA',
      'productId': 'productA',
      'userName': 'Original',
      'helpfulCount': 8,
      'isVerifiedPurchase': true,
    };
    final provider =
        ReviewProvider(firestore: db, reviewUserId: () => 'ownerA');
    await provider.updateReview(
        productId: 'productA',
        reviewId: 'legacy',
        rating: 3,
        title: 'Changed',
        comment: 'New content');
    final data = db.records.values.single;
    expect(data['title'], 'Changed');
    expect(data['userName'], 'Original');
    expect(data['helpfulCount'], 8);
    expect(data['isVerifiedPurchase'], isTrue);
    expect(db.writes, ['products/productA/reviews/legacy']);
    provider.dispose();
  });
  for (final change in ['owner', 'epoch', 'dispose']) {
    test('pending delete refuses $change before SDK write', () async {
      final db = WriteDb();
      db.records['products/productA/reviews/legacy'] = {
        'userId': 'ownerA',
        'productId': 'productA',
        'rating': 4,
      };
      var owner = 'ownerA';
      var current = true;
      final barrier = Completer<void>();
      db.onRead = () => barrier.future;
      final provider = ReviewProvider(firestore: db, reviewUserId: () => owner);
      final result = provider.deleteReview('productA', 'legacy',
          isSessionCurrent: () => current);
      final assertion = expectLater(result, throwsException);
      if (change == 'owner') owner = 'ownerB';
      if (change == 'epoch') current = false;
      if (change == 'dispose') provider.dispose();
      barrier.complete();
      await assertion;
      expect(db.writes, isEmpty);
      if (change != 'dispose') provider.dispose();
    });
  }
  test('transaction retry rechecks author before deletion', () async {
    final db = WriteDb();
    db.records['products/productA/reviews/legacy'] = {
      'userId': 'ownerA',
      'productId': 'productA',
      'rating': 4,
    };
    var owner = 'ownerA';
    db.onRetry = () {
      owner = 'ownerB';
    };
    final provider = ReviewProvider(firestore: db, reviewUserId: () => owner);
    await expectLater(
        provider.deleteReview('productA', 'legacy'), throwsException);
    expect(db.writes, isEmpty);
    provider.dispose();
  });
  test(
      'commit followed by session change suppresses receipt without fake rollback',
      () async {
    final db = WriteDb();
    db.records['products/productA/reviews/legacy'] = {
      'userId': 'ownerA',
      'productId': 'productA',
      'rating': 4,
    };
    var current = true;
    db.afterCommit = () {
      current = false;
    };
    final provider =
        ReviewProvider(firestore: db, reviewUserId: () => 'ownerA');
    await expectLater(
        provider.deleteReview('productA', 'legacy',
            isSessionCurrent: () => current),
        throwsException);
    expect(db.records, isEmpty);
    expect(db.writes, ['products/productA/reviews/legacy']);
    provider.dispose();
  });
  test('confirmed absent delete is idempotent and has no aggregate write',
      () async {
    final db = WriteDb();
    final provider =
        ReviewProvider(firestore: db, reviewUserId: () => 'ownerA');
    await provider.deleteReview('productA', 'legacy');
    expect(db.writes, isEmpty);
    provider.dispose();
  });
  for (final scenario in [
    'confirmed',
    'failure',
    'signout',
    'same-owner',
    'disposed'
  ]) {
    testWidgets('card delete waits and fences $scenario', (t) async {
      final auth = FormAuth();
      final service = ReviewAuth();
      final provider = PendingReviewProvider();
      await t.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<app_auth.AuthProvider>.value(value: auth),
            Provider<AuthService>.value(value: service),
            ChangeNotifierProvider<ReviewProvider>.value(value: provider),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: ReviewCard(
                      review: review().copyWith(userId: 'owner_a'),
                      isDark: false)))));
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await t.pump();
      expect(find.text('Delete Review'), findsOneWidget);
      expect(provider.calls, 1);
      expect(provider.guard!(), isTrue);
      if (scenario == 'signout') auth.change(null);
      if (scenario == 'same-owner') auth.change('owner_a');
      if (scenario == 'disposed') await t.pumpWidget(const SizedBox());
      if (scenario == 'failure') {
        provider.result.completeError(StateError('unsafe internal detail'));
      } else {
        provider.result.complete();
      }
      await t.pumpAndSettle();
      if (scenario == 'confirmed') {
        expect(find.text('Delete Review'), findsNothing);
      }
      if (scenario == 'failure') {
        expect(find.text('Unable to delete your review. Please try again.'),
            findsOneWidget);
        expect(find.textContaining('unsafe internal'), findsNothing);
      }
      if (scenario == 'signout' || scenario == 'same-owner') {
        expect(provider.guard!(), isFalse);
        expect(find.text('Delete Review'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      provider.dispose();
      auth.dispose();
    });
  }
}

class PendingReviewProvider extends ReviewProvider {
  PendingReviewProvider()
      : super(firestore: WriteDb(), reviewUserId: () => 'owner_a');
  final result = Completer<void>();
  int calls = 0;
  bool Function()? guard;
  @override
  Future<void> deleteReview(String productId, String reviewId,
      {bool Function()? isSessionCurrent}) {
    calls++;
    guard = isSessionCurrent;
    return result.future;
  }
}
