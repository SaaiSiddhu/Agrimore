import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Read-only mirror of apps/admin/lib/providers/sponsored_banner_provider.dart's
/// own read half: a realtime listener on the `sponsored_banners` collection
/// (ordered by `priority`) and an [activeSponsoredBanners] getter filtering
/// `isActive`. Marketplace never writes this collection -- create/update/
/// delete/toggle stay admin-only, unchanged.
class SponsoredBannerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<SponsoredBannerModel> _sponsoredBanners = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Active banners, sorted by `priority` ascending -- same shape as the
  /// admin provider's own `activeSponsoredBanners` getter.
  List<SponsoredBannerModel> get activeSponsoredBanners {
    final list = _sponsoredBanners.where((banner) => banner.isActive).toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  Future<void> loadSponsoredBanners({bool forceRefresh = false}) async {
    if (_hasLoadedOnce && !forceRefresh) return;
    _isLoading = true;
    if (!_hasLoadedOnce) notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('sponsored_banners')
          .orderBy('priority')
          .get();
      _sponsoredBanners =
          snapshot.docs.map((doc) => SponsoredBannerModel.fromFirestore(doc)).toList();
      _startRealtimeListener();
    } catch (e) {
      debugPrint('⚠️ SponsoredBannerProvider load error: $e');
      // Keep whatever was already loaded -- never clear a good list because
      // one refresh failed.
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void _startRealtimeListener() {
    _subscription?.cancel();
    _subscription = _firestore
        .collection('sponsored_banners')
        .orderBy('priority')
        .snapshots()
        .listen((snapshot) {
      _sponsoredBanners =
          snapshot.docs.map((doc) => SponsoredBannerModel.fromFirestore(doc)).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ SponsoredBannerProvider listener error: $e');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
