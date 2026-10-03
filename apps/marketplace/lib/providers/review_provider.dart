import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  List<ReviewModel> _reviews = [];
  ReviewStats? _reviewStats;
  final Map<String, ReviewStats> _statsByProduct = {};
  final Map<String, int> _statsEpochs = {};
  final Set<String> _statsLoading = {};
  final Set<String> _statsFailed = {};
  String? _activeStatsProduct;
  bool _statsDisposed = false;
  bool _isLoading = false;
  String _sortBy = 'newest'; // newest, highest, lowest, helpful
  int _filterRating = 0; // 0 = all, 1-5 = specific rating
  String _searchQuery = '';

  List<ReviewModel> get reviews => _reviews;
  ReviewStats? get reviewStats => _activeStatsProduct == null
      ? _reviewStats : _statsByProduct[_activeStatsProduct];
  ReviewStats? reviewStatsFor(String productId) => _statsByProduct[productId];
  bool isLoadingStats(String productId) => _statsLoading.contains(productId);
  bool hasStatsError(String productId) => _statsFailed.contains(productId);
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
          .where((r) => !r.isSuperseded)
          .toList();
    });
  }

  // Public backend-derived stats belong to their product and read generation.
  Future<void> loadReviewStats(String productId) async {
    if (_statsDisposed || productId.isEmpty || productId.contains('/')) return;
    _activeStatsProduct = productId;
    final epoch = (_statsEpochs[productId] ?? 0) + 1;
    _statsEpochs[productId] = epoch;
    _statsByProduct.remove(productId);
    _statsFailed.remove(productId);
    _statsLoading.add(productId);
    notifyListeners();
    bool current() => !_statsDisposed && _statsEpochs[productId] == epoch;
    try {
      final doc = await _firestore.collection('products').doc(productId)
          .collection('reviewStats').doc('stats').get();
      if (!current()) return;
      final data = doc.data();
      final stats = doc.exists
          ? ReviewStats.fromMap(data ?? (throw const FormatException('Missing stats data')))
          : ReviewStats(averageRating: 0, totalReviews: 0, fiveStarCount: 0,
              fourStarCount: 0, threeStarCount: 0, twoStarCount: 0, oneStarCount: 0,
              ratingDistribution: const {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0});
      if (!stats.averageRating.isFinite || stats.averageRating < 0 || stats.averageRating > 5 ||
          [stats.totalReviews, stats.fiveStarCount, stats.fourStarCount,
            stats.threeStarCount, stats.twoStarCount, stats.oneStarCount].any((n) => n < 0)) {
        throw const FormatException('Invalid stats');
      }
      _statsByProduct[productId] = stats;
    } catch (_) {
      if (!current()) return;
      _statsFailed.add(productId);
    }
    if (current()) {
      _statsLoading.remove(productId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _statsDisposed = true;
    _statsByProduct.clear();
    _statsEpochs.clear();
    _statsLoading.clear();
    _statsFailed.clear();
    _reviewStats = null;
    super.dispose();
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

      // REVIEW-UNIQUE-1: one review per buyer per product (id = uid).
      final reviewRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(userId);
      final exists = (await reviewRef.get()).exists;

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

      await reviewRef.set(reviewContentMap(review, isNew: !exists), SetOptions(merge: true));

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