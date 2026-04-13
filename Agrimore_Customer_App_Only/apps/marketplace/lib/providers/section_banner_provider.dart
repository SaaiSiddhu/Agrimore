import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for section banners in the marketplace app
class SectionBannerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<SectionBannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoaded = false;  // ✅ Cache flag

  List<SectionBannerModel> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get banners for a specific position (after section N)
  List<SectionBannerModel> getBannersAfterSection(int sectionIndex) {
    return _banners
        .where((b) => b.isActive && b.displayAfterSection == sectionIndex)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Check if there are banners for a specific position
  bool hasBannersAfterSection(int sectionIndex) {
    return _banners.any((b) => b.isActive && b.displayAfterSection == sectionIndex);
  }

  /// Load all active section banners
  Future<void> loadBanners({bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flag
    if (forceRefresh) {
      _isLoaded = false;
      debugPrint('🔄 Force refreshing section banners from Firebase...');
    }
    
    // ✅ Skip if already loaded (in-memory cache)
    if (_isLoaded && !forceRefresh) {
      debugPrint('📢 Section banners in-memory cached, skipping...');
      return;
    }
    
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch all banners and filter locally to avoid composite index requirement
      final snapshot = await _firestore
          .collection('section_banners')
          .get();

      _banners = snapshot.docs
          .map((doc) => SectionBannerModel.fromFirestore(doc))
          .where((b) => b.isActive) // Filter active locally
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)); // Sort locally
      
      debugPrint('📢 Loaded ${_banners.length} section banners');
      _isLoaded = true;
      _error = null;
    } catch (e) {
      debugPrint('Error loading section banners: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh banners
  Future<void> refresh() async {
    await loadBanners();
  }
}
