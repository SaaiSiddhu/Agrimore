import 'package:cloud_firestore/cloud_firestore.dart';

/// One immutable customer review and its summary, committed together.
/// Session guards stop callbacks/retries; they cannot undo a dispatched commit.
class OrderRatingService {
  OrderRatingService({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  static const tags = <String>{
    'Fast Delivery',
    'Fresh Items',
    'Good Packaging',
    'Great Value',
    'Polite Driver',
    'On Time',
  };

  Future<int> submit(String orderId, String uid, int rating,
      List<String> selectedTags, String note, bool Function() isCurrent) async {
    final frozenTags = List<String>.unmodifiable(selectedTags);
    if (orderId.isEmpty ||
        orderId.contains('/') ||
        uid.isEmpty ||
        rating < 1 ||
        rating > 5 ||
        note.length > 2000 ||
        frozenTags.length > tags.length ||
        frozenTags.any((tag) => !tags.contains(tag))) {
      throw StateError('Invalid rating');
    }
    if (!isCurrent()) throw StateError('Rating session expired');
    final order = _firestore.collection('orders').doc(orderId);
    final review = order.collection('reviews').doc(uid);
    Future<int> transact({bool receiptOnly = false}) =>
        _firestore.runTransaction<int>((transaction) async {
          if (!isCurrent()) throw StateError('Rating session expired');
          final orderSnapshot = await transaction.get(order);
          if (!isCurrent()) throw StateError('Rating session expired');
          final reviewSnapshot = await transaction.get(review);
          if (!isCurrent()) throw StateError('Rating session expired');
          final data = orderSnapshot.data();
          if (data == null ||
              data['userId'] != uid ||
              data['orderStatus'] != 'delivered') {
            throw StateError('Order cannot be rated');
          }
          final saved = reviewSnapshot.data();
          if (saved != null) {
            final confirmedRating = saved['rating'];
            if (saved['userId'] != uid ||
                confirmedRating is! int ||
                confirmedRating < 1 ||
                confirmedRating > 5 ||
                data['isRated'] != true ||
                data['rating'] != confirmedRating) {
              throw StateError('Review requires reconciliation');
            }
            return confirmedRating;
          }
          if (receiptOnly) throw StateError('No confirmed rating receipt');
          // Never silently replace legacy evidence or manufacture a review for it.
          if (data.containsKey('isRated') && data['isRated'] != false) {
            throw StateError('Review requires reconciliation');
          }
          if (!isCurrent()) throw StateError('Rating session expired');
          transaction.set(review, {
            'userId': uid,
            'rating': rating,
            'tags': frozenTags,
            'note': note,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(order, {'rating': rating, 'isRated': true});
          return rating;
        });
    try {
      return await transact();
    } on FirebaseException catch (error, stack) {
      // Immutable-review races can surface as permission-denied rather than
      // aborted. Recover only through a fresh read-only transaction receipt.
      if (!isCurrent() ||
          !const {'permission-denied', 'aborted'}.contains(error.code)) {
        rethrow;
      }
      try {
        return await transact(receiptOnly: true);
      } catch (_) {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }
}
