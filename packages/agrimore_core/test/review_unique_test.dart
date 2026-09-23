import 'package:agrimore_core/models/review_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// REVIEW-UNIQUE-1: a (re-)review writes content only; superseded reviews
/// are recognisable.
void main() {
  final r = ReviewModel(
    reviewId: 'u1',
    productId: 'p1',
    userId: 'u1',
    userName: 'Priya',
    userAvatar: '',
    rating: 4,
    comment: 'Good',
    title: 'Nice',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 2),
    helpfulCount: 7,
    isVerifiedPurchase: true,
  );

  test('first review carries createdAt; a re-review keeps the original', () {
    expect(reviewContentMap(r, isNew: true).containsKey('createdAt'), isTrue);
    expect(reviewContentMap(r, isNew: false).containsKey('createdAt'), isFalse);
  });

  test('votes and the verified badge are never overwritten', () {
    final m = reviewContentMap(r, isNew: true);
    for (final k in ['helpfulCount', 'helpfulUsers', 'unhelpfulCount', 'unhelpfulUsers', 'isVerifiedPurchase']) {
      expect(m.containsKey(k), isFalse, reason: k);
    }
    expect(m['rating'], 4);
    expect(m['userId'], 'u1');
  });

  test('supersededBy parses', () {
    expect(ReviewModel.fromMap({'userId': 'u1', 'supersededBy': 'u1'}, 'old').isSuperseded, isTrue);
    expect(ReviewModel.fromMap({'userId': 'u1'}, 'u1').isSuperseded, isFalse);
  });
}
