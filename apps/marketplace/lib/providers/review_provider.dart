import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_services/reviews/product_review_writer.dart';
import 'package:agrimore_core/agrimore_core.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider(
      {FirebaseFirestore? firestore, String? Function()? reviewUserId})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _reviewUserId =
            reviewUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final String? Function() _reviewUserId;
  int _pendingAuthorWrites = 0;

  Future<T> _authorWrite<T>(Future<T> Function(ProductReviewWriter) action,
      bool Function()? isSessionCurrent) async {
    bool current() => !_statsDisposed && (isSessionCurrent?.call() ?? true);
    if (!current()) throw AuthException('The review session is unavailable.');
    _pendingAuthorWrites++;
    _isLoading = true;
    notifyListeners();
    try {
      return await action(ProductReviewWriter(
          firestore: _firestore,
          currentUserId: _reviewUserId,
          isSessionCurrent: current));
    } finally {
      _pendingAuthorWrites--;
      _isLoading = _pendingAuthorWrites > 0;
      if (!_statsDisposed) notifyListeners();
    }
  }

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
      ? _reviewStats
      : _statsByProduct[_activeStatsProduct];
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
          .map((doc) =>
              ReviewModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
      final doc = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviewStats')
          .doc('stats')
          .get();
      if (!current()) return;
      final data = doc.data();
      final stats = doc.exists
          ? ReviewStats.fromMap(
              data ?? (throw const FormatException('Missing stats data')))
          : ReviewStats(
              averageRating: 0,
              totalReviews: 0,
              fiveStarCount: 0,
              fourStarCount: 0,
              threeStarCount: 0,
              twoStarCount: 0,
              oneStarCount: 0,
              ratingDistribution: const {
                  '1': 0,
                  '2': 0,
                  '3': 0,
                  '4': 0,
                  '5': 0
                });
      if (!stats.averageRating.isFinite ||
          stats.averageRating < 0 ||
          stats.averageRating > 5 ||
          [
            stats.totalReviews,
            stats.fiveStarCount,
            stats.fourStarCount,
            stats.threeStarCount,
            stats.twoStarCount,
            stats.oneStarCount
          ].any((n) => n < 0)) {
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

  // Author content is transactional; aggregates remain backend-owned.
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
    bool Function()? isSessionCurrent,
  }) async {
    final now = DateTime.now();
    final review = ReviewModel(
        reviewId: userId,
        productId: productId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        rating: rating,
        title: title,
        comment: comment,
        createdAt: now,
        updatedAt: now,
        imageUrls: List<String>.unmodifiable(imageUrls),
        isVerifiedPurchase: isVerifiedPurchase);
    await _authorWrite(
        (writer) => writer.save(review, edit: false), isSessionCurrent);
  }

  Future<void> updateReview({
    required String productId,
    required String reviewId,
    required int rating,
    required String title,
    required String comment,
    List<String>? imageUrls,
    bool Function()? isSessionCurrent,
  }) async {
    final owner = _reviewUserId();
    final images =
        imageUrls == null ? null : List<String>.unmodifiable(imageUrls);
    bool current() =>
        !_statsDisposed &&
        owner != null &&
        _reviewUserId() == owner &&
        (isSessionCurrent?.call() ?? true);
    if (!current()) throw AuthException('The review session is unavailable.');
    if ([productId, reviewId]
        .any((id) => id.isEmpty || id.trim() != id || id.contains('/'))) {
      throw ValidationException('Invalid review target.');
    }
    await _authorWrite((writer) async {
      final doc = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .get();
      if (!current()) throw AuthException('The review session changed.');
      final data = doc.data();
      if (data == null ||
          data['userId'] != owner ||
          data['productId'] != productId) {
        throw DatabaseException('The review is unavailable for this author.');
      }
      final previous = ReviewModel.fromMap(data, reviewId);
      return writer.save(
          previous.copyWith(
              rating: rating,
              title: title,
              comment: comment,
              imageUrls: images,
              updatedAt: DateTime.now()),
          edit: true);
    }, current);
  }

  Future<void> deleteReview(String productId, String reviewId,
          {bool Function()? isSessionCurrent}) =>
      _authorWrite(
          (writer) => writer.delete(productId, reviewId), isSessionCurrent);

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
}
