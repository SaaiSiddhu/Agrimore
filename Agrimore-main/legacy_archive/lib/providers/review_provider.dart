import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/review_model.dart';

class ReviewProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ReviewModel> _reviews = [];
  ReviewStats? _reviewStats;
  bool _isLoading = false;
  String _sortBy = 'newest'; // newest, highest, lowest, helpful
  int _filterRating = 0; // 0 = all, 1-5 = specific rating
  String _searchQuery = '';

  List<ReviewModel> get reviews => _reviews;
  ReviewStats? get reviewStats => _reviewStats;
  bool get isLoading => _isLoading;
  String get sortBy => _sortBy;
  int get filterRating => _filterRating;

  // Real-time stream of reviews
  Stream<List<ReviewModel>> getReviewsStream(String productId) {
    Query query = _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('createdAt', descending: true);

    if (_filterRating > 0) {
      query = query.where('rating', isEqualTo: _filterRating);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ReviewModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // Get review stats
  Future<void> loadReviewStats(String productId) async {
    try {
      final doc = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviewStats')
          .doc('stats')
          .get();

      if (doc.exists) {
        _reviewStats = ReviewStats.fromMap(doc.data() as Map<String, dynamic>);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading review stats: $e');
    }
  }

  // Add new review
  Future<void> addReview({
    required String productId,
    required String userId,
    required String userName,
    required String userAvatar,
    required int rating,
    required String title,
    required String comment,
    List<String> imageUrls = const [],
    bool isVerifiedPurchase = false,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final reviewRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc();

      final review = ReviewModel(
        reviewId: reviewRef.id,
        productId: productId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        rating: rating,
        comment: comment,
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        imageUrls: imageUrls,
        isVerifiedPurchase: isVerifiedPurchase,
      );

      await reviewRef.set(review.toMap());

      // Update review stats (ideally via Cloud Function, but manual for now)
      await _updateReviewStats(productId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding review: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update review
  Future<void> updateReview({
    required String productId,
    required String reviewId,
    required int rating,
    required String title,
    required String comment,
    List<String>? imageUrls, // Allow updating images
  }) async {
    try {
      Map<String, dynamic> updates = {
        'rating': rating,
        'title': title,
        'comment': comment,
        'updatedAt': DateTime.now(),
      };
      
      if (imageUrls != null) {
        updates['imageUrls'] = imageUrls;
      }

      await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update(updates);

      await _updateReviewStats(productId);
    } catch (e) {
      debugPrint('Error updating review: $e');
    }
  }

  // Delete review
  Future<void> deleteReview(String productId, String reviewId) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      await _updateReviewStats(productId);
    } catch (e) {
      debugPrint('Error deleting review: $e');
    }
  }

  // Mark as helpful
  Future<void> markHelpful(
    String productId,
    String reviewId,
    String userId,
    bool isHelpful,
  ) async {
    try {
      final reviewRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId);

      final reviewDoc = await reviewRef.get();
      if (!reviewDoc.exists) return;

      final review = ReviewModel.fromMap(
        reviewDoc.data() as Map<String, dynamic>,
        reviewDoc.id,
      );

      List<String> helpfulUsers = List.from(review.helpfulUsers);
      List<String> unhelpfulUsers = List.from(review.unhelpfulUsers);

      if (isHelpful) {
        if (helpfulUsers.contains(userId)) {
          helpfulUsers.remove(userId);
        } else {
          helpfulUsers.add(userId);
          unhelpfulUsers.remove(userId);
        }
      } else {
        if (unhelpfulUsers.contains(userId)) {
          unhelpfulUsers.remove(userId);
        } else {
          unhelpfulUsers.add(userId);
          helpfulUsers.remove(userId);
        }
      }

      await reviewRef.update({
        'helpfulUsers': helpfulUsers,
        'unhelpfulUsers': unhelpfulUsers,
        'helpfulCount': helpfulUsers.length,
        'unhelpfulCount': unhelpfulUsers.length,
      });
    } catch (e) {
      debugPrint('Error marking helpful: $e');
    }
  }

  // Update sort filter
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  // Update rating filter
  void setFilterRating(int rating) {
    _filterRating = rating;
    notifyListeners();
  }

  // Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // This should ideally be a Cloud Function, but for client-side it's here
  Future<void> _updateReviewStats(String productId) async {
     try {
      final reviewsSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        // No reviews, reset stats
        await _firestore
            .collection('products')
            .doc(productId)
            .collection('reviewStats')
            .doc('stats')
            .set({
          'averageRating': 0.0,
          'totalReviews': 0,
          'fiveStarCount': 0,
          'fourStarCount': 0,
          'threeStarCount': 0,
          'twoStarCount': 0,
          'oneStarCount': 0,
          'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
        });
        await loadReviewStats(productId);
        return;
      }

      double totalRating = 0;
      int fiveStar = 0;
      int fourStar = 0;
      int threeStar = 0;
      int twoStar = 0;
      int oneStar = 0;

      for (var doc in reviewsSnapshot.docs) {
        final rating = (doc.data()['rating'] ?? 0).toInt();
        totalRating += rating;
        if (rating == 5) fiveStar++;
        else if (rating == 4) fourStar++;
        else if (rating == 3) threeStar++;
        else if (rating == 2) twoStar++;
        else if (rating == 1) oneStar++;
      }

      final totalReviews = reviewsSnapshot.docs.length;
      final averageRating = totalRating / totalReviews;

      final stats = ReviewStats(
        averageRating: averageRating,
        totalReviews: totalReviews,
        fiveStarCount: fiveStar,
        fourStarCount: fourStar,
        threeStarCount: threeStar,
        twoStarCount: twoStar,
        oneStarCount: oneStar,
        ratingDistribution: {
          '1': oneStar,
          '2': twoStar,
          '3': threeStar,
          '4': fourStar,
          '5': fiveStar,
        },
      );

      await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviewStats')
          .doc('stats')
          .set(stats.toMap());
      
      // Also update the main product document
      await _firestore.collection('products').doc(productId).update({
        'rating': averageRating,
        'reviewCount': totalReviews,
      });

      // Reload stats into provider
      _reviewStats = stats;
      notifyListeners();

    } catch (e) {
      debugPrint('Error updating stats: $e');
    }
  }
}