import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';

// PERF-1: on-disk cache so mid-feed section banners show something
// instantly on a cold app start instead of blocking on network like every
// other Home data source used to — mirrors
// ProductProvider/CategoryProvider/BannerProvider's identical pattern.
// SectionBannerModel has no toMap()/fromMap() pair (only fromFirestore(),
// which needs a real DocumentSnapshot) — a model change would touch
// packages/agrimore_core and force a five-app analyze, out of this
// marketplace-only phase's scope — so this hand-rolls the encode/decode
// the same way BannerProvider's own cache does for the same reason.
const String _kSectionBannersCacheKey = 'cached_section_banners_v1';

/// Provider for section banners in the marketplace app
class SectionBannerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SectionBannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoaded = false;  // ✅ Cache flag
  bool _isCacheLoaded = false; // the on-disk cache preview has been shown

  List<SectionBannerModel> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get banners for a specific position (after section N) on a given page.
  /// Defaults to Home so every existing call site is unaffected.
  List<SectionBannerModel> getBannersAfterSection(
    int sectionIndex, {
    String pageScope = SectionBannerModel.pageScopeHome,
  }) {
    return _banners
        .where((b) =>
            b.isActive &&
            b.displayAfterSection == sectionIndex &&
            b.pageScope == pageScope)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Check if there are banners for a specific position on a given page.
  bool hasBannersAfterSection(
    int sectionIndex, {
    String pageScope = SectionBannerModel.pageScopeHome,
  }) {
    return _banners.any((b) =>
        b.isActive &&
        b.displayAfterSection == sectionIndex &&
        b.pageScope == pageScope);
  }

  /// Load all active section banners
  Future<void> loadBanners({bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flag
    if (forceRefresh) {
      _isLoaded = false;
      _isCacheLoaded = false;
      debugPrint('🔄 Force refreshing section banners from Firebase...');
    }

    // ✅ Skip if already loaded (in-memory cache)
    if (_isLoaded && !forceRefresh) {
      debugPrint('📢 Section banners in-memory cached, skipping...');
      return;
    }

    if (_isLoading) return;

    // STEP 1: INSTANT — show the on-disk cache while the network call is
    // still in flight below, same "cache-first" shape as ProductProvider.
    if (!_isCacheLoaded) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        _banners = cached;
        _isCacheLoaded = true;
        debugPrint('⚡ INSTANT: Loaded ${_banners.length} section banners from cache');
        notifyListeners();
      }
    }

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
      await _saveToCache(_banners);
      _isLoaded = true;
      _error = null;
    } catch (e) {
      debugPrint('Error loading section banners: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================
  // CACHE HELPERS
  // ============================================
  Future<List<SectionBannerModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kSectionBannersCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded
          .map((json) {
            final map = json as Map<String, dynamic>;
            return SectionBannerModel(
              id: map['id'] ?? '',
              imageUrl: map['imageUrl'] ?? '',
              title: map['title'],
              subtitle: map['subtitle'],
              shopNowUrl: map['shopNowUrl'],
              buttonText: map['buttonText'],
              position: map['position'] ?? 0,
              displayAfterSection: map['displayAfterSection'] ?? 1,
              pageScope: map['pageScope'] ?? SectionBannerModel.pageScopeHome,
              isActive: map['isActive'] ?? true,
              showAdBadge: map['showAdBadge'] ?? false,
              createdAt:
                  DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
              updatedAt: map['updatedAt'] != null
                  ? DateTime.tryParse(map['updatedAt'])
                  : null,
            );
          })
          .where((b) => b.isActive)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    } catch (e) {
      debugPrint('⚠️ Section banners cache load error: $e');
      return [];
    }
  }

  Future<void> _saveToCache(List<SectionBannerModel> banners) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = banners.map((b) => {
        'id': b.id,
        'imageUrl': b.imageUrl,
        'title': b.title,
        'subtitle': b.subtitle,
        'shopNowUrl': b.shopNowUrl,
        'buttonText': b.buttonText,
        'position': b.position,
        'displayAfterSection': b.displayAfterSection,
        'pageScope': b.pageScope,
        'isActive': b.isActive,
        'showAdBadge': b.showAdBadge,
        'createdAt': b.createdAt.toIso8601String(),
        'updatedAt': b.updatedAt?.toIso8601String(),
      }).toList();
      await prefs.setString(_kSectionBannersCacheKey, jsonEncode(jsonList));
      debugPrint('💾 Saved ${banners.length} section banners to cache');
    } catch (e) {
      debugPrint('⚠️ Section banners cache save error: $e');
    }
  }

  /// Refresh banners
  Future<void> refresh() async {
    await loadBanners();
  }
}
