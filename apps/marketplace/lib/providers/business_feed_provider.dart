import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// BUSINESS-NETWORK-2 (slice 2 of 2): the customer's feed of posts from
/// sellers they follow. Screen-scoped (a plain ChangeNotifier instance),
/// matching BUSINESS-NETWORK-1's own BusinessFollowProvider pattern --
/// this feed only matters while the feed screen is open.
///
/// Query approach (decided at claim time, see the ledger row for the full
/// reasoning): a customer's followed-seller ids come from
/// follows.where('followerId','==',uid) (already proven by
/// phase47_seller_follow_test.js); the feed itself queries
/// business_posts.where('sellerId','in', ids).orderBy('createdAt','desc').
/// Firestore's `in` operator caps at 30 values, so a customer following
/// more than 30 sellers only sees posts from the first 30 -- an honest v1
/// limit, not a bug (no customer follows anywhere near 30 sellers today).
class BusinessFeedProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get posts => _posts;

  Future<void> loadFeed() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _posts = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final followsSnap = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: uid)
          .get();
      final sellerIds = followsSnap.docs
          .map((d) => d.data()['sellerId'] as String?)
          .whereType<String>()
          .toSet()
          .take(30)
          .toList();

      if (sellerIds.isEmpty) {
        _posts = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final postsSnap = await _firestore
          .collection('business_posts')
          .where('sellerId', whereIn: sellerIds)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final sellerNames = <String, String>{};
      for (final sellerId in sellerIds) {
        final doc = await _firestore.collection('sellers').doc(sellerId).get();
        sellerNames[sellerId] = (doc.data()?['shopName'] as String?)?.trim().isNotEmpty == true
            ? (doc.data()!['shopName'] as String)
            : 'A seller you follow';
      }

      _posts = postsSnap.docs.map((d) {
        final data = d.data();
        final sellerId = data['sellerId'] as String?;
        return {
          'id': d.id,
          'sellerId': sellerId,
          'text': data['text'],
          'imageUrl': data['imageUrl'],
          'productId': data['productId'],
          'shopName': sellerNames[sellerId] ?? 'A seller you follow',
        };
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading business feed: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
