import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Server limits (functions/src/seller/reviews.ts).
const int kReplyMax = 500;
const Duration kReplyEditWindow = Duration(hours: 24);

/// A review of one of the seller's products (collection group `reviews`,
/// stamped with sellerId by onProductReviewWrite).
@immutable
class SellerReview {
  const SellerReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.userName,
    required this.rating,
    this.title = '',
    this.comment = '',
    this.createdAt,
    this.verified = false,
    this.replyText,
    this.replyAt,
  });

  factory SellerReview.fromDoc(String id, Map<String, dynamic> d) {
    DateTime? t(Object? v) => v is Timestamp ? v.toDate() : null;
    final reply = d['sellerReply'] is Map ? Map<String, dynamic>.from(d['sellerReply'] as Map) : null;
    return SellerReview(
      id: id,
      productId: (d['productId'] ?? '').toString(),
      productName: (d['productName'] ?? '').toString(),
      userName: (d['userName'] ?? '').toString(),
      rating: ((d['rating'] as num?) ?? 0).round().clamp(0, 5),
      title: (d['title'] ?? '').toString(),
      comment: (d['comment'] ?? '').toString(),
      createdAt: t(d['createdAt']),
      verified: d['isVerifiedPurchase'] == true,
      replyText: reply?['text'] as String?,
      replyAt: t(reply?['at']),
    );
  }

  final String id;
  final String productId;
  final String productName;
  final String userName;
  final int rating;
  final String title;
  final String comment;
  final DateTime? createdAt;
  final bool verified;
  final String? replyText;
  final DateTime? replyAt;

  bool get answered => replyText != null && replyText!.isNotEmpty;

  /// A reply can be written, or edited within 24 h of first posting.
  bool canReply(DateTime now) => !answered || replyAt == null || now.difference(replyAt!) <= kReplyEditWindow;
}

/// All · 5★ … 1★ · Unanswered.
@immutable
class ReviewFilter {
  const ReviewFilter({this.stars, this.unansweredOnly = false});
  final int? stars;
  final bool unansweredOnly;

  bool matches(SellerReview r) => (stars == null || r.rating == stars) && (!unansweredOnly || !r.answered);
}

@immutable
class ReviewSummary {
  const ReviewSummary({required this.average, required this.total, required this.counts, required this.unanswered});
  final double average;
  final int total;

  /// counts[1..5]; index 0 unused.
  final List<int> counts;
  final int unanswered;

  static ReviewSummary of(List<SellerReview> reviews) {
    final counts = List<int>.filled(6, 0);
    var sum = 0;
    var total = 0;
    var unanswered = 0;
    for (final r in reviews) {
      if (r.rating < 1) continue;
      counts[r.rating]++;
      sum += r.rating;
      total++;
      if (!r.answered) unanswered++;
    }
    return ReviewSummary(average: total == 0 ? 0 : sum / total, total: total, counts: counts, unanswered: unanswered);
  }
}
