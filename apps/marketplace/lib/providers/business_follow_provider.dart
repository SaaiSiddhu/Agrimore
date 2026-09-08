import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// BUSINESS-NETWORK-1 (slice 1 of 2): follow/unfollow state for a single
/// seller's business profile. Scoped per-screen (see BusinessProfileScreen,
/// which wraps itself with a local ChangeNotifierProvider) rather than
/// registered app-wide in main.dart -- a follow toggle only needs to exist
/// while a profile screen is open, so this doesn't need main.dart's
/// MultiProvider at all.
///
/// The `follows/{followerId}_{sellerId}` doc id is composite (matching this
/// codebase's own established composite-key convention from
/// product_price_mappings), so the follow state for one (follower, seller)
/// pair is always exactly one doc read/write away -- no query needed.
class BusinessFollowProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isFollowing = false;
  bool _isLoading = false;

  bool get isFollowing => _isFollowing;
  bool get isLoading => _isLoading;

  String? _docId(String sellerId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return '${uid}_$sellerId';
  }

  Future<void> checkFollowing(String sellerId) async {
    final docId = _docId(sellerId);
    if (docId == null) {
      _isFollowing = false;
      notifyListeners();
      return;
    }
    try {
      final doc = await _firestore.collection('follows').doc(docId).get();
      _isFollowing = doc.exists;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
    }
  }

  /// Returns the new following state on success, or null if the toggle
  /// could not be attempted (not signed in, or trying to follow yourself --
  /// matches firestore.rules' own sellerId != request.auth.uid guard, so a
  /// seller viewing their own profile never even sends a doomed write).
  Future<bool?> toggleFollow(String sellerId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == sellerId) return null;

    final docId = '${uid}_$sellerId';
    _isLoading = true;
    notifyListeners();
    try {
      if (_isFollowing) {
        await _firestore.collection('follows').doc(docId).delete();
        _isFollowing = false;
      } else {
        await _firestore.collection('follows').doc(docId).set({
          'followerId': uid,
          'sellerId': sellerId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _isFollowing = true;
      }
      return _isFollowing;
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
