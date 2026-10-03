import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Author content only. Product/seller aggregates and review trust metadata
/// remain owned by onProductReviewWrite; this writer never updates them.
class ProductReviewWriter {
  ProductReviewWriter(
      {required FirebaseFirestore firestore,
      required String? Function() currentUserId,
      required bool Function() isSessionCurrent})
      : _firestore = firestore,
        _currentUserId = currentUserId,
        _isSessionCurrent = isSessionCurrent;

  final FirebaseFirestore _firestore;
  final String? Function() _currentUserId;
  final bool Function() _isSessionCurrent;

  bool _validId(String id) =>
      id.isNotEmpty && id.trim() == id && !id.contains('/');
  String _open([String? expected]) {
    final owner = _currentUserId();
    if (owner == null ||
        !_validId(owner) ||
        (expected != null && expected != owner) ||
        !_isSessionCurrent()) {
      throw AuthException('The review session is unavailable.');
    }
    return owner;
  }

  void _guard(String owner) {
    if (_currentUserId() != owner || !_isSessionCurrent()) {
      throw AuthException('The review session changed.');
    }
  }

  void _target(String productId, String reviewId) {
    if (!_validId(productId) || !_validId(reviewId)) {
      throw ValidationException('Invalid review target.');
    }
  }

  void _owns(Map<String, dynamic>? data, String owner, String productId) {
    if (data == null ||
        data['userId'] != owner ||
        data['productId'] != productId) {
      throw DatabaseException('The review is unavailable for this author.');
    }
  }

  Future<String> save(ReviewModel review, {required bool edit}) async {
    final owner = _open(review.userId);
    final id = edit ? review.reviewId : owner;
    _target(review.productId, id);
    if (review.rating < 1 || review.rating > 5) {
      throw ValidationException('Invalid review rating.');
    }
    // Snapshot mutable draft images before entering any SDK await/retry.
    final content = reviewContentMap(review, isNew: false);
    content['imageUrls'] = List<String>.unmodifiable(review.imageUrls);
    final createdAt = Timestamp.fromDate(review.createdAt);
    final ref = _firestore
        .collection('products')
        .doc(review.productId)
        .collection('reviews')
        .doc(id);
    await _firestore.runTransaction<void>((tx) async {
      _guard(owner);
      final doc = await tx.get(ref);
      _guard(owner);
      if (doc.exists) {
        _owns(doc.data(), owner, review.productId);
      } else if (edit) {
        throw DataNotFoundException('The review is no longer available.');
      }
      final payload = <String, dynamic>{...content};
      if (!doc.exists) payload['createdAt'] = createdAt;
      _guard(owner);
      tx.set(ref, payload, SetOptions(merge: true));
    });
    // A dispatched SDK commit cannot be undone; suppress a stale receipt.
    _guard(owner);
    return id;
  }

  Future<void> delete(String productId, String reviewId) async {
    final owner = _open();
    _target(productId, reviewId);
    final ref = _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId);
    await _firestore.runTransaction<void>((tx) async {
      _guard(owner);
      final doc = await tx.get(ref);
      _guard(owner);
      if (!doc.exists) return; // Confirmed absent: idempotent delete receipt.
      _owns(doc.data(), owner, productId);
      _guard(owner);
      tx.delete(ref);
    });
    _guard(owner);
  }
}
