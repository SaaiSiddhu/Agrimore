// lib/providers/category_section_provider.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';

// PERF-1: on-disk cache so this section (Grocery & Kitchen strip) shows
// something instantly on a cold app start instead of blocking on network
// like every other Home data source used to — mirrors
// ProductProvider/CategoryProvider/BannerProvider's identical pattern.
const String _kCategorySectionsCacheKey = 'cached_category_sections_v1';

/// Provider for fetching Category Sections in Marketplace app
class CategorySectionProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CategorySectionSlotModel> _sections = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoaded = false;  // ✅ Cache flag
  bool _isCacheLoaded = false; // the on-disk cache preview has been shown

  List<CategorySectionSlotModel> get sections => _sections;

  /// isActive + non-empty + currently within its schedule window (an unset
  /// bound is unbounded on that side). isWithinSchedule() is re-evaluated
  /// against DateTime.now() on every read rather than baked into the cached
  /// `_sections` list -- mirrors BannerProvider.categoryHeroBanners -- so a
  /// section scheduled to start/end becomes eligible/ineligible without
  /// waiting on the next network reload.
  List<CategorySectionSlotModel> get activeSections =>
      _sections
          .where((s) => s.isActive && s.categoryIds.isNotEmpty && s.isWithinSchedule())
          .toList();

  // Alias for widget compatibility
  List<CategorySectionSlotModel> get activeSlots => activeSections;
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Collection reference
  CollectionReference get _collection => 
      _firestore.collection('category_section_slots');
  
  /// Alias for loadSections (for widget compatibility)
  Future<void> loadSlots() => loadSections();

  /// Load all active sections ordered by position
  Future<void> loadSections({bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flag
    if (forceRefresh) {
      _isLoaded = false;
      _isCacheLoaded = false;
      debugPrint('🔄 Force refreshing category sections from Firebase...');
    }

    // ✅ Skip if already loaded (in-memory cache)
    if (_isLoaded && !forceRefresh) {
      debugPrint('📂 Category sections in-memory cached, skipping...');
      return;
    }

    // STEP 1: INSTANT — show the on-disk cache while the network call is
    // still in flight below, same "cache-first" shape as ProductProvider.
    if (!_isCacheLoaded) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        _sections = cached;
        _isCacheLoaded = true;
        debugPrint('⚡ INSTANT: Loaded ${_sections.length} category sections from cache');
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _collection.get();

      _sections = snapshot.docs
          .map((doc) => CategorySectionSlotModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .where((s) => s.isActive && s.categoryIds.isNotEmpty)
          .toList();
      _sections.sort((a, b) => a.position.compareTo(b.position));

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No category sections found. Seeding default sections...');
        final defaultSections = [
          {
            'title': 'Fresh Arrivals',
            'subtitle': 'Newly added products',
            'position': 1,
            'isActive': true,
            'categoryIds': ['general', 'dairy', 'bakery'],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'displayStyle': 'list',
          },
          {
            'title': 'Trending Now',
            'subtitle': 'Most popular items',
            'position': 2,
            'isActive': true,
            'categoryIds': ['general', 'offers'],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'displayStyle': 'grid',
          }
        ];
        
        for (var section in defaultSections) {
          try {
            await _collection.add(section);
          } catch (e) {
             debugPrint('Failed to seed section: $e');
          }
        }
        
        // Reload after seeding
        final newSnapshot = await _collection.get();
        _sections = newSnapshot.docs
            .map((doc) => CategorySectionSlotModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((s) => s.isActive && s.categoryIds.isNotEmpty)
            .toList();
        _sections.sort((a, b) => a.position.compareTo(b.position));
      }

      debugPrint('✅ Loaded ${_sections.length} active category sections');
      await _saveToCache(_sections);
      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading category sections: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // CACHE HELPERS
  // ============================================
  Future<List<CategorySectionSlotModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kCategorySectionsCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded
          .map((json) => CategorySectionSlotModel.fromMap(
              json as Map<String, dynamic>, json['id'] ?? ''))
          .where((s) => s.isActive && s.categoryIds.isNotEmpty)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    } catch (e) {
      debugPrint('⚠️ Category sections cache load error: $e');
      return [];
    }
  }

  Future<void> _saveToCache(List<CategorySectionSlotModel> sections) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // toMap()'s own 'updatedAt' is FieldValue.serverTimestamp() — a
      // write-only sentinel, not a real value, and not JSON-serializable.
      // Dropped from the cached copy the same way category_provider's
      // sibling CategoryProvider drops its own problematic date field:
      // fromMap's ternary already treats an absent 'updatedAt' as null, and
      // nothing in this app reads a cached section's updatedAt
      // (grep-confirmed), so this is a lossless round-trip for everything
      // actually used.
      final jsonList = sections.map((s) {
        final map = {...s.toMap(), 'id': s.id}..remove('updatedAt');
        return map;
      }).toList();
      await prefs.setString(_kCategorySectionsCacheKey, jsonEncode(jsonList));
      debugPrint('💾 Saved ${sections.length} category sections to cache');
    } catch (e) {
      debugPrint('⚠️ Category sections cache save error: $e');
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await loadSections();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
