import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Author content and authenticated self-votes. Product/seller aggregates and review trust metadata
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

  List<String> _voteUsers(Map<String, dynamic> data, String key) {
    final raw = data.containsKey(key) ? data[key] : const <String>[];
    if (raw is! List || raw.any((v) => v is! String || !_validId(v))) {
      throw DatabaseException('The review votes are unavailable.');
    }
    final users = List<String>.from(raw);
    if (users.toSet().length != users.length) {
      throw DatabaseException('The review votes are unavailable.');
    }
    return users;
  }

  Future<void> vote(
      String productId, String reviewId, String actor, bool isHelpful) async {
    final owner = _open(actor);
    _target(productId, reviewId);
    final ref = _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId);
    // Freeze the initial toggle intent; SDK retries re-read other voters,
    // but must not invert our selection if another device changes our vote.
    bool? selected;
    await _firestore.runTransaction<void>((tx) async {
      _guard(owner);
      final snapshot = await tx.get(ref);
      _guard(owner);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw DataNotFoundException('The review is no longer available.');
      }
      final author = data['userId'];
      if (data['productId'] != productId ||
          author is! String ||
          !_validId(author) ||
          data['supersededBy'] != null) {
        throw DatabaseException('The review is unavailable for voting.');
      }
      final yes = _voteUsers(data, 'helpfulUsers');
      final no = _voteUsers(data, 'unhelpfulUsers');
      final yesCount =
          data.containsKey('helpfulCount') ? data['helpfulCount'] : 0;
      final noCount =
          data.containsKey('unhelpfulCount') ? data['unhelpfulCount'] : 0;
      if (yesCount is! int ||
          noCount is! int ||
          yesCount != yes.length ||
          noCount != no.length ||
          yes.toSet().intersection(no.toSet()).isNotEmpty) {
        throw DatabaseException('The review votes are unavailable.');
      }
      selected ??= !(isHelpful ? yes : no).contains(owner);
      yes.remove(owner);
      no.remove(owner);
      if (selected!) {
        (isHelpful ? yes : no).add(owner);
      }
      _guard(owner);
      tx.update(ref, {
        'helpfulUsers': yes,
        'unhelpfulUsers': no,
        'helpfulCount': yes.length,
        'unhelpfulCount': no.length,
      });
    });
    // The SDK may already have committed. Refuse a stale receipt, never undo it.
    _guard(owner);
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
