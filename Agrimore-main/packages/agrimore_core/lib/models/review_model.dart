import 'package:cloud_firestore/cloud_firestore.dart'; // Import this for Timestamp

class ReviewModel {
  final String reviewId;
  final String productId;
  final String userId;
  final String userName;
  final String userAvatar;
  final int rating;
  final String comment;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int helpfulCount;
  final List<String> helpfulUsers;
  final int unhelpfulCount;
  final List<String> unhelpfulUsers;
  final bool isVerifiedPurchase;
  final List<String> imageUrls;

  ReviewModel({
    required this.reviewId,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.helpfulCount = 0,
    this.helpfulUsers = const [],
    this.unhelpfulCount = 0,
    this.unhelpfulUsers = const [],
    this.isVerifiedPurchase = false,
    this.imageUrls = const [],
  });

  factory ReviewModel.fromMap(Map<String, dynamic> data, String docId) {
    // Helper function to safely convert Timestamps or other date formats
    DateTime _parseDate(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      if (timestamp is String) {
        return DateTime.tryParse(timestamp) ?? DateTime.now();
      }
      return DateTime.now();
    }
    
    return ReviewModel(
      reviewId: docId,
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userAvatar: data['userAvatar'] ?? '',
      rating: (data['rating'] ?? 0).toInt(),
      comment: data['comment'] ?? '',
      title: data['title'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      helpfulCount: (data['helpfulCount'] ?? 0).toInt(),
      helpfulUsers: List<String>.from(data['helpfulUsers'] ?? []),
      unhelpfulCount: (data['unhelpfulCount'] ?? 0).toInt(),
      unhelpfulUsers: List<String>.from(data['unhelpfulUsers'] ?? []),
      isVerifiedPurchase: data['isVerifiedPurchase'] ?? false,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'comment': comment,
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'helpfulCount': helpfulCount,
      'helpfulUsers': helpfulUsers,
      'unhelpfulCount': unhelpfulCount,
      'unhelpfulUsers': unhelpfulUsers,
      'isVerifiedPurchase': isVerifiedPurchase,
      'imageUrls': imageUrls,
    };
  }

  // ✅ NEW: Copy with method
  ReviewModel copyWith({
    String? reviewId,
    String? productId,
    String? userId,
    String? userName,
    String? userAvatar,
    int? rating,
    String? comment,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? helpfulCount,
    List<String>? helpfulUsers,
    int? unhelpfulCount,
    List<String>? unhelpfulUsers,
    bool? isVerifiedPurchase,
    List<String>? imageUrls,
  }) {
    return ReviewModel(
      reviewId: reviewId ?? this.reviewId,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      helpfulUsers: helpfulUsers ?? this.helpfulUsers,
      unhelpfulCount: unhelpfulCount ?? this.unhelpfulCount,
      unhelpfulUsers: unhelpfulUsers ?? this.unhelpfulUsers,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  // ✅ NEW: toString for debugging
  @override
  String toString() {
    return 'ReviewModel(id: $reviewId, rating: $rating, user: $userName, helpful: $helpfulCount)';
  }

  // ✅ NEW: Equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewModel && other.reviewId == reviewId;
  }

  // ✅ NEW: hashCode
  @override
  int get hashCode => reviewId.hashCode;
}

class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;
  final Map<String, int>? ratingDistribution; // ✅ NEW

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.fiveStarCount,
    required this.fourStarCount,
    required this.threeStarCount,
    required this.twoStarCount,
    required this.oneStarCount,
    this.ratingDistribution, // ✅ NEW
  });

  factory ReviewStats.fromMap(Map<String, dynamic> data) {
    return ReviewStats(
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalReviews: (data['totalReviews'] ?? 0).toInt(),
      fiveStarCount: (data['fiveStarCount'] ?? 0).toInt(),
      fourStarCount: (data['fourStarCount'] ?? 0).toInt(),
      threeStarCount: (data['threeStarCount'] ?? 0).toInt(),
      twoStarCount: (data['twoStarCount'] ?? 0).toInt(),
      oneStarCount: (data['oneStarCount'] ?? 0).toInt(),
      ratingDistribution: data['ratingDistribution'] != null
          ? Map<String, int>.from(data['ratingDistribution'])
          : null, // ✅ NEW
    );
  }

  // ✅ NEW: toMap method
  Map<String, dynamic> toMap() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'fiveStarCount': fiveStarCount,
      'fourStarCount': fourStarCount,
      'threeStarCount': threeStarCount,
      'twoStarCount': twoStarCount,
      'oneStarCount': oneStarCount,
      'ratingDistribution': ratingDistribution,
    };
  }

  // ✅ NEW: Helper method to get percentage
  double getPercentageForRating(int stars) {
    if (totalReviews == 0) return 0.0;
    int count = 0;
    switch (stars) {
      case 5:
        count = fiveStarCount;
        break;
      case 4:
        count = fourStarCount;
        break;
      case 3:
        count = threeStarCount;
        break;
      case 2:
        count = twoStarCount;
        break;
      case 1:
        count = oneStarCount;
        break;
    }
    return (count / totalReviews) * 100;
  }

  // ✅ NEW: toString for debugging
  @override
  String toString() {
    return 'ReviewStats(avg: ${averageRating.toStringAsFixed(1)}, total: $totalReviews)';
  }

  // ✅ NEW: Equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewStats &&
        other.averageRating == averageRating &&
        other.totalReviews == totalReviews;
  }

  // ✅ NEW: hashCode
  @override
  int get hashCode => averageRating.hashCode ^ totalReviews.hashCode;
}