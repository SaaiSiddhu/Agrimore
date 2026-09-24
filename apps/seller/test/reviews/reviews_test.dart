import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/screens/reviews/review_rules.dart';
import 'package:seller/screens/reviews/reviews_screen.dart';

/// SELLER-ACCOUNT-1a: the seller sees server ratings, filters, and can
/// reply once (editable for 24 h).
final DateTime _now = DateTime(2026, 9, 23, 12);

SellerReview _r(String id, int rating, {String? reply, int replyHoursAgo = 1}) => SellerReview(
      id: id,
      productId: 'p',
      productName: 'Basmati Rice',
      userName: 'Priya',
      rating: rating,
      comment: 'Comment $id',
      createdAt: _now.subtract(const Duration(days: 1)),
      replyText: reply,
      replyAt: reply == null ? null : _now.subtract(Duration(hours: replyHoursAgo)),
    );

void main() {
  group('review rules', () {
    test('summary: average, distribution, unanswered', () {
      final s = ReviewSummary.of([_r('1', 5), _r('2', 4, reply: 'Thanks'), _r('3', 3)]);
      expect(s.average, 4);
      expect(s.total, 3);
      expect(s.counts[5], 1);
      expect(s.unanswered, 2);
    });

    test('filters', () {
      expect(const ReviewFilter(stars: 5).matches(_r('1', 5)), isTrue);
      expect(const ReviewFilter(stars: 5).matches(_r('1', 4)), isFalse);
      expect(const ReviewFilter(unansweredOnly: true).matches(_r('1', 4, reply: 'x')), isFalse);
    });

    test('reply editable for 24 h only', () {
      expect(_r('1', 5).canReply(_now), isTrue);
      expect(_r('1', 5, reply: 'x', replyHoursAgo: 23).canReply(_now), isTrue);
      expect(_r('1', 5, reply: 'x', replyHoursAgo: 25).canReply(_now), isFalse);
    });

    test('fromDoc reads the server reply and verified flag', () {
      final r = SellerReview.fromDoc('r1', {
        'rating': 4.0,
        'isVerifiedPurchase': true,
        'sellerReply': {'text': 'Thank you', 'at': Timestamp.fromDate(_now)},
      });
      expect(r.rating, 4);
      expect(r.verified, isTrue);
      expect(r.replyText, 'Thank you');
      expect(r.replyAt, _now);
    });
  });

  Future<AppLocalizations> pump(WidgetTester tester, Widget child) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(ChangeNotifierProvider<SellerAuthProvider>(
      create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved),
      child: MaterialApp(
        theme: SellerTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return child;
        }),
      ),
    ));
    await tester.pump();
    return l10n;
  }

  testWidgets('summary, filter to unanswered, reply', (tester) async {
    String? sent;
    final l10n = await pump(
      tester,
      SellerReviewsScreen(
        now: _now,
        reviews: [_r('1', 5), _r('2', 2, reply: 'Sorry', replyHoursAgo: 30)],
        replier: (r, text) async {
          sent = '${r.id}:$text';
          return null;
        },
      ),
    );
    expect(find.text('3.5'), findsOneWidget);
    expect(find.text(l10n.reviewsCount(2)), findsOneWidget);
    // Locked reply on review 2: no edit button; review 1 can be answered.
    expect(find.text(l10n.reviewsEditReply), findsNothing);
    await tester.tap(find.text(l10n.reviewsUnanswered(1)));
    await tester.pump();
    expect(find.text('Comment 2'), findsNothing);
    await tester.ensureVisible(find.text(l10n.reviewsReply));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reviewsReply));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('replyText')), 'Thank you!');
    await tester.pump();
    await tester.tap(find.text(l10n.reviewsReplySend));
    await tester.pumpAndSettle();
    expect(sent, '1:Thank you!');
    expect(find.text(l10n.reviewReplySent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state (dark)', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(ChangeNotifierProvider<SellerAuthProvider>(
      create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved),
      child: MaterialApp(
        theme: SellerTheme.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return SellerReviewsScreen(now: _now, reviews: const []);
        }),
      ),
    ));
    await tester.pump();
    expect(find.text(l10n.reviewsEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
