import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

// ============================================
// CACHE CONFIGURATION
// ============================================
const String _kCategoriesCacheKey = 'cached_categories_v1';
const String _kCategoriesCacheTimeKey = 'cached_categories_time';
const int _kCacheTTLMinutes = 10; // Cache valid for 10 minutes

class CategoryProvider with ChangeNotifier {
  final DatabaseService _databaseService;

  // Optional so the single real construction site
  // (apps/marketplace/lib/main.dart's `CategoryProvider()`) is unaffected —
  // mirrors ProductProvider's identical seam (Phase 12), added here so
  // Workstream 3's cache round-trip test can substitute a fake data source.
  CategoryProvider({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  bool _isLoaded = false; // ✅ Caching flag
  Completer<void>? _loadCompleter; // ✅ Race condition fix
  bool _isCacheLoaded = false; // ✅ NEW: Track if we showed cached data

  List<CategoryModel> get categories => _categories;
  CategoryModel? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get mounted => !_disposed;

  int get categoryCount => _categories.length;
  bool get hasCategories => _categories.isNotEmpty;

  // ✅ NEW - Alias method for compatibility
  Future<void> fetchCategories() async {
    return loadCategories();
  }

  // ✅ NEW - Safe notification method that prevents "setState during build" error
  void _notifySafely() {
    if (mounted) {
      Future.microtask(() {
        if (mounted) {
          notifyListeners();
        }
      });
    }
  }

  // ============================================
  // ENHANCED CACHE-FIRST LOADING
  // ============================================
  Future<void> loadCategories({bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flags to force Firebase fetch
    if (forceRefresh) {
      _isLoaded = false;
      _isCacheLoaded = false;
      debugPrint('🔄 Force refreshing categories from Firebase...');
    }
    
    // ✅ Skip if already loaded (in-memory cache)
    if (_isLoaded && !forceRefresh) {
      debugPrint('📂 Categories in-memory cached, skipping...');
      return;
    }
    
    // ✅ Race condition fix: If already loading, wait for that operation
    if (_loadCompleter != null) {
      debugPrint('📂 Categories loading in progress, waiting...');
      return _loadCompleter!.future;
    }
    
    _loadCompleter = Completer<void>();
    
    try {
      // ============================================
      // STEP 1: INSTANT - Load from local cache first
      // ============================================
      if (!_isCacheLoaded) {
        final cached = await _loadFromCache();
        if (cached.isNotEmpty) {
          _categories = cached;
          _isCacheLoaded = true;
          _isLoaded = true;
          debugPrint('⚡ INSTANT: Loaded ${_categories.length} categories from cache');
          _notifySafely(); // Show cached data immediately!
        }
      }

      // ============================================
      // STEP 2: BACKGROUND - Fetch fresh data from network
      // ============================================
      _isLoading = !_isCacheLoaded;
      _error = null;
      if (!_isCacheLoaded) _notifySafely();

      final freshCategories = await _databaseService
          .getAllCategories()
          .timeout(const Duration(seconds: 8));
      
      // ============================================
      // STEP 3: UPDATE - Only refresh UI if data changed
      // ============================================
      _categories = freshCategories;
      _isLoaded = true;
      await _saveToCache(freshCategories);

      debugPrint('✅ NETWORK: Loaded ${_categories.length} categories');
      _isLoading = false;
      _loadCompleter?.complete();
      _loadCompleter = null;
      _notifySafely();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _loadCompleter?.completeError(e);
      _loadCompleter = null;
      _notifySafely();
      debugPrint('❌ Error loading categories: $e');
    }
  }

  // ============================================
  // CACHE HELPERS
  // ============================================
  Future<List<CategoryModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kCategoriesCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded.map((json) => CategoryModel.fromMap(json as Map<String, dynamic>, json['id'] ?? '')).toList();
    } catch (e) {
      debugPrint('⚠️ Category cache load error: $e');
      return [];
    }
  }

  Future<void> _saveToCache(List<CategoryModel> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // CategoryModel.toMap() is also the live Firestore write path and
      // correctly emits a native Timestamp for createdAt there — that must
      // not change. jsonEncode cannot serialize a raw Timestamp (it has no
      // toJson() of its own) and throws JsonUnsupportedObjectError, which
      // this function's own catch block was silently swallowing — this
      // cache write has likely never actually succeeded.
      //
      // Unlike ProductModel.fromMap (which accepts an ISO string for its
      // dates), CategoryModel.fromMap has no String branch for createdAt —
      // an ISO string would silently read back as DateTime.now(), a lossy
      // round-trip. createdAt is confirmed unused anywhere in this app
      // (grepped: category display/sort uses displayOrder, not createdAt;
      // zero `.createdAt` reads on a CategoryModel anywhere in
      // apps/marketplace), so rather than cache a value we know we can't
      // restore, createdAt is simply omitted from the cached payload —
      // fromMap's own null-handling already defaults an absent createdAt to
      // DateTime.now(), so this is the exact same outcome, just reached
      // honestly instead of by accident. If a future need for a real cached
      // createdAt appears, the correct fix is a String branch in
      // CategoryModel.fromMap (packages/agrimore_core) — out of scope here.
      final jsonList = categories.map((c) {
        final map = {...c.toMap(), 'id': c.id};
        map.remove('createdAt');
        // Generic Timestamp sanitizer as defense-in-depth for `metadata`
        // (a free-form Map<String, dynamic>? that could embed a Timestamp
        // from Firestore data) and any date field added to toMap() later.
        return _sanitizeForJsonCache(map) as Map<String, dynamic>;
      }).toList();
      await prefs.setString(_kCategoriesCacheKey, jsonEncode(jsonList));
      await prefs.setString(_kCategoriesCacheTimeKey, DateTime.now().toIso8601String());
      debugPrint('💾 Saved ${categories.length} categories to cache');
    } catch (e) {
      debugPrint('⚠️ Category cache save error: $e');
    }
  }

  /// Recursively replaces any Firestore Timestamp with an ISO8601 string so
  /// the result is safe to pass to jsonEncode. Mirrors ProductProvider's
  /// identical helper (duplicated rather than shared, since it's a small,
  /// self-contained utility and this phase's scope is confined to
  /// apps/marketplace with no changes to packages/ or a new shared file).
  dynamic _sanitizeForJsonCache(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map) {
      // Explicit generic + key.toString(): plain .map() without it infers
      // Map<dynamic, dynamic>, which fails the `as Map<String, dynamic>`
      // cast at this helper's call site above.
      return value.map<String, dynamic>(
          (key, val) => MapEntry(key.toString(), _sanitizeForJsonCache(val)));
    }
    if (value is List) {
      return value.map(_sanitizeForJsonCache).toList();
    }
    return value;
  }

  // ✅ FIXED - Safe state notification
  Future<void> refreshCategories() async {
    await loadCategories();
  }

  // ✅ FIXED - Safe state notification
  void selectCategory(CategoryModel category) {
    _selectedCategory = category;
    _notifySafely();
  }

  // ✅ FIXED - Safe state notification
  void clearSelectedCategory() {
    _selectedCategory = null;
    _notifySafely();
  }

  // Get category by ID
  CategoryModel? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW - Get category by name
  CategoryModel? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (cat) => cat.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW - Search categories
  List<CategoryModel> searchCategories(String query) {
    if (query.isEmpty) return _categories;
    
    final lowerQuery = query.toLowerCase();
    return _categories.where((category) {
      return category.name.toLowerCase().contains(lowerQuery) ||
             (category.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ✅ FIXED - Safe state notification
  void clearError() {
    _error = null;
    _notifySafely();
  }

  // ✅ FIXED - Safe state notification
  void clearAll() {
    _categories.clear();
    _selectedCategory = null;
    _error = null;
    _isLoading = false;
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    _categories.clear();
    _selectedCategory = null;
    super.dispose();
  }
}
