// lib/providers/bestseller_provider.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';

// PERF-1: on-disk cache so this section shows something instantly on a
// cold app start instead of blocking on network like every other Home
// data source used to — mirrors ProductProvider/CategoryProvider/
// BannerProvider's identical pattern.
const String _kBestsellerSlotsCacheKey = 'cached_bestseller_slots_v1';

/// Provider for fetching Bestseller slots in Marketplace app
class BestsellerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<BestsellerSlotModel> _slots = [];
  bool _isLoading = false;
  bool _isLoaded = false; // a real network load has completed
  bool _isCacheLoaded = false; // the on-disk cache preview has been shown

  List<BestsellerSlotModel> get slots => _slots;
  List<BestsellerSlotModel> get activeSlots =>
      _slots.where((s) => s.isActive && s.categoryId.isNotEmpty).toList();
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  /// Load all bestseller slots (filter client-side to avoid index)
  Future<void> loadSlots() async {
    if (_isLoaded) return;

    // STEP 1: INSTANT — show the on-disk cache while the network call is
    // still in flight below, same "cache-first" shape as ProductProvider.
    if (!_isCacheLoaded) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        _slots = cached;
        _isCacheLoaded = true;
        debugPrint('⚡ INSTANT: Loaded ${_slots.length} bestseller slots from cache');
        notifyListeners();
      }
    }

    _isLoading = !_isCacheLoaded;
    if (!_isCacheLoaded) notifyListeners();

    try {
      // Simple query - just order by position, filter active client-side
      final snapshot = await _firestore
          .collection('bestseller_slots')
          .orderBy('position')
          .get();

      _slots = snapshot.docs
          .map((doc) => BestsellerSlotModel.fromMap(
              doc.data(), doc.id))
          .where((slot) => slot.isActive && slot.categoryId.isNotEmpty)
          .toList();

      debugPrint('✅ Loaded ${_slots.length} active bestseller slots');
      await _saveToCache(_slots);

      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading bestseller slots: $e');
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Force reload slots
  Future<void> refresh() async {
    _isLoaded = false;
    _isCacheLoaded = false;
    await loadSlots();
  }

  // ============================================
  // CACHE HELPERS
  // ============================================
  Future<List<BestsellerSlotModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kBestsellerSlotsCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded
          .map((json) => BestsellerSlotModel.fromMap(
              json as Map<String, dynamic>, json['id'] ?? ''))
          .where((slot) => slot.isActive && slot.categoryId.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ Bestseller slots cache load error: $e');
      return [];
    }
  }

  Future<void> _saveToCache(List<BestsellerSlotModel> slots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // toMap()'s own 'updatedAt' is FieldValue.serverTimestamp() — a
      // write-only sentinel, not a real value, and not JSON-serializable.
      // Dropped from the cached copy the same way category_provider.dart
      // drops its own problematic date field: fromMap's ternary already
      // treats an absent 'updatedAt' as null, and nothing in this app reads
      // a cached slot's updatedAt (grep-confirmed), so this is a lossless
      // round-trip for everything actually used.
      final jsonList = slots.map((s) {
        final map = {...s.toMap(), 'id': s.id}..remove('updatedAt');
        return map;
      }).toList();
      await prefs.setString(_kBestsellerSlotsCacheKey, jsonEncode(jsonList));
      debugPrint('💾 Saved ${slots.length} bestseller slots to cache');
    } catch (e) {
      debugPrint('⚠️ Bestseller slots cache save error: $e');
    }
  }

  /// Get slot by position
  BestsellerSlotModel? getSlotByPosition(int position) {
    try {
      return _slots.firstWhere((s) => s.position == position);
    } catch (e) {
      return null;
    }
  }
}
