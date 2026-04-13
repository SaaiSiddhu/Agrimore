import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsored_banner_model.dart';

class SponsoredBannerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SponsoredBannerModel> _sponsoredBanners = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<SponsoredBannerModel> get sponsoredBanners => _sponsoredBanners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Active banners filtered & sorted
  List<SponsoredBannerModel> get activeSponsoredBanners {
    final list = _sponsoredBanners.where((banner) => banner.isActive).toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  SponsoredBannerProvider() {
    _startRealtimeListener();
  }

  Future<void> loadSponsoredBanners() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('sponsored_banners')
          .orderBy('priority')
          .get();

      _sponsoredBanners =
          snapshot.docs.map((doc) => SponsoredBannerModel.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading sponsored banners: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startRealtimeListener() {
    _subscription?.cancel();

    try {
      _subscription = _firestore
          .collection('sponsored_banners')
          .orderBy('priority')
          .snapshots()
          .listen((snapshot) {
        final newList =
            snapshot.docs.map((doc) => SponsoredBannerModel.fromFirestore(doc)).toList();

        final oldIds = _sponsoredBanners.map((e) => e.id).join(',');
        final newIds = newList.map((e) => e.id).join(',');
        final hasDifference = oldIds != newIds ||
            newList.length != _sponsoredBanners.length ||
            !_areContentsEqual(_sponsoredBanners, newList);

        _sponsoredBanners = newList;

        if (hasDifference) {
          notifyListeners();
        }
      }, onError: (err) {
        debugPrint('Sponsored banner realtime listener error: $err');
      });
    } catch (e) {
      debugPrint('Failed to start sponsored banner realtime listener: $e');
    }
  }

  bool _areContentsEqual(
      List<SponsoredBannerModel> a, List<SponsoredBannerModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      if (ai.id != bi.id ||
          ai.productId != bi.productId ||
          ai.imageUrl != bi.imageUrl ||
          ai.title != bi.title ||
          ai.subtitle != bi.subtitle ||
          ai.colorHex != bi.colorHex ||
          ai.isActive != bi.isActive ||
          ai.priority != bi.priority) {
        return false;
      }
    }
    return true;
  }

  Future<void> createSponsoredBanner({
    required String productId,
    required String imageUrl,
    required String title,
    required String subtitle,
    required String colorHex,
    required int priority,
  }) async {
    try {
      await _firestore.collection('sponsored_banners').add({
        'productId': productId,
        'imageUrl': imageUrl,
        'title': title,
        'subtitle': subtitle,
        'colorHex': colorHex,
        'isActive': true,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating sponsored banner: $e');
      rethrow;
    }
  }

  Future<void> updateSponsoredBanner(
      String bannerId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('sponsored_banners').doc(bannerId).update(data);
    } catch (e) {
      debugPrint('Error updating sponsored banner: $e');
      rethrow;
    }
  }

  Future<void> deleteSponsoredBanner(String bannerId) async {
    try {
      await _firestore.collection('sponsored_banners').doc(bannerId).delete();
    } catch (e) {
      debugPrint('Error deleting sponsored banner: $e');
      rethrow;
    }
  }

  Future<void> toggleSponsoredBannerStatus(String bannerId, bool isActive) async {
    try {
      await updateSponsoredBanner(bannerId, {'isActive': isActive});
    } catch (e) {
      debugPrint('Error toggling sponsored banner status: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
