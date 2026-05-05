import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_services/agrimore_services.dart';

// ============================================
// CACHE CONFIGURATION
// ============================================
const String _kProductsCacheKey = 'cached_products_v1';
const String _kProductsCacheTimeKey = 'cached_products_time';
const int _kCacheTTLMinutes = 10; // Cache valid for 10 minutes

class ProductProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ProductModel> _products = [];
  List<ProductModel> _recentlyViewedProducts = [];
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  String? _error;
  int? _loadedProductLimit;
  bool _isLoaded = false; // ✅ Caching flag
  Completer<void>? _loadCompleter; // ✅ Race condition fix
  bool _isCacheLoaded = false; // ✅ NEW: Track if we showed cached data

  // ✅ NEW: State variables for variant management
  ProductVariant? _selectedVariant;
  Map<String, String> _selectedOptions = {};
  List<ProductModel> _relatedProducts = [];
  bool _isLoadingRelated = false;

  // --- Getters ---
  List<ProductModel> get products => _products;
  List<ProductModel> get recentlyViewedProducts => _recentlyViewedProducts;
  ProductModel? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get productCount => _products.length;
  bool get hasProducts => _products.isNotEmpty;

  // ✅ NEW: Getters for variants and related products
  ProductVariant? get selectedVariant => _selectedVariant;
  Map<String, String> get selectedOptions => _selectedOptions;
  List<ProductModel> get relatedProducts => _relatedProducts;
  bool get isLoadingRelated => _isLoadingRelated;

  // ✅ FIXED: Added this alias method for backward compatibility
  Future<void> fetchProducts({
    String? categoryId,
    String? location,
    int? limit,
  }) async {
    return loadProducts(
      categoryId: categoryId,
      location: location,
      limit: limit,
    );
  }

  // ============================================
  // ENHANCED CACHE-FIRST LOADING
  // ============================================
  Future<void> loadProducts({
    String? categoryId,
    bool forceRefresh = false,
    String? location,
    int? limit,
  }) async {
    // ✅ If forceRefresh, reset cache flags to force Firebase fetch
    if (forceRefresh) {
      _isLoaded = false;
      _isCacheLoaded = false;
      _loadedProductLimit = null;
      debugPrint('🔄 Force refreshing products from Firebase...');
    }

    // ✅ Skip if already loaded for "all" products (in-memory cache)
    final hasEnoughInMemoryProducts = _isLoaded &&
        !forceRefresh &&
        categoryId == null &&
        (_loadedProductLimit == null ||
            (limit != null && _loadedProductLimit! >= limit));
    if (hasEnoughInMemoryProducts) {
      debugPrint('📦 Products in-memory cached, skipping...');
      return;
    }

    // ✅ Race condition fix: If already loading, wait for that operation
    if (_loadCompleter != null && categoryId == null) {
      debugPrint('📦 Products loading in progress, waiting...');
      await _loadCompleter!.future;
      if (limit == null && _loadedProductLimit != null) {
        return loadProducts(
          categoryId: categoryId,
          forceRefresh: forceRefresh,
          location: location,
          limit: limit,
        );
      }
      if (limit != null &&
          (_loadedProductLimit == null || _loadedProductLimit! >= limit)) {
        return;
      }
    }

    _loadCompleter = Completer<void>();

    try {
      // ============================================
      // STEP 1: INSTANT - Load from local cache first
      // ============================================
      if (categoryId == null && limit == null && !_isCacheLoaded) {
        final cachedProducts = await _loadFromCache();
        if (cachedProducts.isNotEmpty) {
          _products = _dedupeProducts(cachedProducts);
          _isCacheLoaded = true;
          _isLoaded = true;
          _loadedProductLimit = null;
          debugPrint(
              '⚡ INSTANT: Loaded ${_products.length} products from cache');
          _notifySafely(); // Show cached data immediately!
        }
      }

      // ============================================
      // STEP 2: BACKGROUND - Fetch fresh data from network
      // ============================================
      _isLoading = !_isCacheLoaded; // Only show loading if no cache
      _error = null;
      if (!_isCacheLoaded) _notifySafely();

      final activeLocation =
          location ?? SharedPreferencesService.getString('selected_location');

      List<ProductModel> freshProducts;
      if (categoryId != null &&
          categoryId != 'all' &&
          categoryId != 'uncategorized') {
        freshProducts = await _databaseService.getProductsByCategory(categoryId,
            location: activeLocation);
      } else {
        freshProducts = await _databaseService.getAllProducts(
          location: activeLocation,
          limit: limit,
        );
      }
      freshProducts = await _filterProductsForUserLocation(
        _dedupeProducts(freshProducts),
      );

      // ============================================
      // STEP 3: UPDATE - Only refresh UI if data changed
      // ============================================
      final hasChanges = _hasDataChanged(freshProducts);
      _products = freshProducts;
      _isLoaded = true;
      _loadedProductLimit = categoryId == null ? limit : null;

      if (categoryId == null && limit == null) {
        await _saveToCache(freshProducts); // Save fresh data to cache
      }

      debugPrint(
          '✅ NETWORK: Loaded ${_products.length} products${hasChanges ? " (updated)" : " (unchanged)"}');
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
      debugPrint('❌ Error loading products: $e');
    }
  }

  // ============================================
  // CACHE HELPERS
  // ============================================
  Future<List<ProductModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeStr = prefs.getString(_kProductsCacheTimeKey);

      // Check if cache is expired
      if (cacheTimeStr != null) {
        final cacheTime = DateTime.tryParse(cacheTimeStr);
        if (cacheTime != null) {
          final age = DateTime.now().difference(cacheTime);
          if (age.inMinutes > _kCacheTTLMinutes) {
            debugPrint('📦 Cache expired (${age.inMinutes} min old)');
            // Don't return empty - still load stale cache for instant display
          }
        }
      }

      final cachedJson = prefs.getString(_kProductsCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('⚠️ Cache load error: $e');
      return [];
    }
  }

  Future<void> _saveToCache(List<ProductModel> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = products.map((p) => p.toJson()).toList();
      await prefs.setString(_kProductsCacheKey, jsonEncode(jsonList));
      await prefs.setString(
          _kProductsCacheTimeKey, DateTime.now().toIso8601String());
      debugPrint('💾 Saved ${products.length} products to cache');
    } catch (e) {
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  bool _hasDataChanged(List<ProductModel> newProducts) {
    if (_products.length != newProducts.length) return true;
    // Quick check: compare first and last product IDs
    if (_products.isEmpty) return newProducts.isNotEmpty;
    if (_products.first.id != newProducts.first.id) return true;
    if (_products.last.id != newProducts.last.id) return true;
    return false;
  }

  List<ProductModel> _dedupeProducts(List<ProductModel> products) {
    final seen = <String>{};
    return products.where((product) {
      final key = product.id.trim().isNotEmpty
          ? product.id.trim()
          : '${product.name.trim().toLowerCase()}-${product.categoryId.trim().toLowerCase()}';
      return seen.add(key);
    }).toList();
  }

  Future<void> loadFeaturedProducts({String? location}) async {
    try {
      _isLoading = true;
      _notifySafely();

      final activeLocation =
          location ?? SharedPreferencesService.getString('selected_location');
      _products = await _filterProductsForUserLocation(
        _dedupeProducts(await _databaseService.getFeaturedProducts(
          limit: 10,
          location: activeLocation,
        )),
      );
      _loadedProductLimit = 10;
      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadProductById(String productId) async {
    try {
      _isLoading = true;
      _notifySafely();

      clearSelectedProduct();

      _selectedProduct = await _databaseService.getProductById(productId);

      if (_selectedProduct != null) {
        if (_selectedProduct!.variants.isNotEmpty) {
          _selectedVariant = _selectedProduct!.variants.first;
          _selectedOptions = Map.from(_selectedVariant!.options);
        } else {
          _selectedVariant = null;
          _selectedOptions = {};
        }

        await addToRecentlyViewed(_selectedProduct!);

        _loadRelatedProducts(_selectedProduct!.relatedProductIds);
      }

      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _loadRelatedProducts(List<String>? productIds) async {
    if (productIds == null || productIds.isEmpty) {
      _relatedProducts = [];
      _notifySafely();
      return;
    }

    try {
      _isLoadingRelated = true;
      _notifySafely();

      _relatedProducts = await _databaseService.getProductsByIds(productIds);

      _isLoadingRelated = false;
      _notifySafely();
    } catch (e) {
      debugPrint('❌ Error loading related products: $e');
      _isLoadingRelated = false;
      _notifySafely();
    }
  }

  void selectVariantOption(String optionName, String optionValue) {
    if (_selectedProduct == null) return;

    _selectedOptions[optionName] = optionValue;
    debugPrint('🔄 Variant option selected: $optionName = $optionValue');

    _selectedVariant = _findVariantForSelectedOptions();

    if (_selectedVariant != null) {
      debugPrint(
          '✅ Found variant: ${_selectedVariant!.name}, price: ₹${_selectedVariant!.salePrice}');
    } else {
      debugPrint('⚠️ No matching variant found');
    }

    // ✅ FIX: Use direct notifyListeners() for immediate UI update
    notifyListeners();
  }

  /// Select variant directly by its name
  void selectVariantByName(String variantName) {
    if (_selectedProduct == null) return;

    final variant = _selectedProduct!.variants.firstWhere(
      (v) => v.name == variantName,
      orElse: () => _selectedProduct!.variants.first,
    );

    _selectedVariant = variant;
    _selectedOptions = Map.from(variant.options);
    debugPrint(
        '✅ Selected variant by name: ${variant.name}, price: ₹${variant.salePrice}');

    notifyListeners();
  }

  ProductVariant? _findVariantForSelectedOptions() {
    if (_selectedProduct == null || _selectedProduct!.variants.isEmpty) {
      return null;
    }

    for (final variant in _selectedProduct!.variants) {
      bool match = true;
      for (final key in variant.options.keys) {
        if (variant.options[key] != _selectedOptions[key]) {
          match = false;
          break;
        }
      }
      if (match) {
        return variant;
      }
    }

    for (final variant in _selectedProduct!.variants) {
      for (final key in _selectedOptions.keys) {
        if (variant.options[key] == _selectedOptions[key]) {
          return variant;
        }
      }
    }

    return _selectedProduct!.variants.first;
  }

  /// Load recently viewed products from Firestore (persists across sessions)
  Future<void> loadRecentlyViewed() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Fallback to SharedPreferences for unauthenticated users
        await _loadRecentlyViewedFromPrefs();
        return;
      }

      // Load from Firestore
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recently_viewed')
          .orderBy('viewedAt', descending: true)
          .limit(20)
          .get();

      _recentlyViewedProducts = [];
      for (final doc in snapshot.docs) {
        try {
          final productId = doc.data()['productId'] as String?;
          if (productId != null) {
            final product = await _databaseService.getProductById(productId);
            if (product != null) {
              _recentlyViewedProducts.add(product);
            }
          }
        } catch (e) {
          debugPrint('Error loading recently viewed product: $e');
        }
      }

      debugPrint(
          '✅ Loaded ${_recentlyViewedProducts.length} recently viewed from Firestore');
      _notifySafely();
    } catch (e) {
      debugPrint('❌ Error loading recently viewed from Firestore: $e');
      // Fallback to SharedPreferences
      await _loadRecentlyViewedFromPrefs();
    }
  }

  /// Fallback: Load from SharedPreferences (for unauthenticated users)
  Future<void> _loadRecentlyViewedFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentlyViewedIds = prefs.getStringList('recently_viewed') ?? [];

      _recentlyViewedProducts = [];
      for (final productId in recentlyViewedIds.take(20)) {
        try {
          final product = await _databaseService.getProductById(productId);
          if (product != null) {
            _recentlyViewedProducts.add(product);
          }
        } catch (e) {
          debugPrint('Error loading recently viewed product $productId: $e');
        }
      }

      _notifySafely();
    } catch (e) {
      debugPrint('❌ Error loading recently viewed from prefs: $e');
    }
  }

  /// Add product to recently viewed (persists to Firestore)
  Future<void> addToRecentlyViewed(ProductModel product) async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Save to Firestore for authenticated users
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('recently_viewed')
            .doc(product.id)
            .set({
          'productId': product.id,
          'viewedAt': FieldValue.serverTimestamp(),
        });

        // Cleanup: Keep only last 20 items
        final oldDocs = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('recently_viewed')
            .orderBy('viewedAt', descending: true)
            .get();

        if (oldDocs.docs.length > 20) {
          for (int i = 20; i < oldDocs.docs.length; i++) {
            await oldDocs.docs[i].reference.delete();
          }
        }
      }

      // Also save to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      final recentlyViewedIds = prefs.getStringList('recently_viewed') ?? [];

      recentlyViewedIds.remove(product.id);
      recentlyViewedIds.insert(0, product.id);

      if (recentlyViewedIds.length > 20) {
        recentlyViewedIds.removeRange(20, recentlyViewedIds.length);
      }

      await prefs.setStringList('recently_viewed', recentlyViewedIds);

      // Update local list
      _recentlyViewedProducts.removeWhere((p) => p.id == product.id);
      _recentlyViewedProducts.insert(0, product);

      if (_recentlyViewedProducts.length > 20) {
        _recentlyViewedProducts.removeRange(20, _recentlyViewedProducts.length);
      }

      _notifySafely();
    } catch (e) {
      debugPrint('❌ Error adding to recently viewed: $e');
    }
  }

  /// Clear recently viewed (from both Firestore and SharedPreferences)
  Future<void> clearRecentlyViewed() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Clear from Firestore
        final docs = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('recently_viewed')
            .get();

        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recently_viewed');

      _recentlyViewedProducts.clear();
      _notifySafely();
    } catch (e) {
      debugPrint('❌ Error clearing recently viewed: $e');
    }
  }

  Future<void> searchProducts(String query) async {
    try {
      _isLoading = true;
      _notifySafely();
      // Note: Full-text search doesn't natively support easy compound location filtering
      // without complex indexing. But we can fetch products and filter in memory if needed.
      // For now we will rely on the query itself, or we could filter post-fetch.
      final results = await _databaseService.searchProducts(query);

      _products =
          await _filterProductsForUserLocation(_dedupeProducts(results));

      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _notifySafely();
    }
  }

  void sortProducts(String sortBy) {
    switch (sortBy) {
      case 'price_low':
        _products.sort((a, b) => a.salePrice.compareTo(b.salePrice));
        break;
      case 'price_high':
        _products.sort((a, b) => b.salePrice.compareTo(a.salePrice));
        break;
      case 'name_asc':
        _products.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        _products.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'rating':
        _products.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'popular':
        _products.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case 'newest':
      default:
        _products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    _notifySafely();
  }

  Future<void> refreshProducts({String? location}) async {
    await loadProducts(forceRefresh: true, location: location);
  }

  Future<List<ProductModel>> _filterProductsForUserLocation(
    List<ProductModel> products,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLocation =
        (prefs.getString('selected_location') ?? '').toLowerCase();
    final selectedState =
        (prefs.getString('selected_state') ?? _extractState(selectedLocation))
            .trim();
    final userState =
        selectedState.isNotEmpty ? selectedState.toLowerCase() : 'tamil nadu';
    final userDistrict = (prefs.getString('selected_district') ??
            _extractDistrict(selectedLocation))
        .toLowerCase();
    final userLat = prefs.getDouble('selected_latitude');
    final userLng = prefs.getDouble('selected_longitude');

    return products.where((product) {
      final type = product.locationType.toLowerCase().trim();
      if (type.isEmpty || type == 'state') {
        final state = (product.state ?? 'Tamil Nadu').toLowerCase();
        return state.isEmpty ||
            state == userState ||
            selectedLocation.contains(state);
      }

      if (type == 'district') {
        final state = (product.state ?? 'Tamil Nadu').toLowerCase();
        final district = (product.district ?? '').toLowerCase();
        final stateMatches = state.isEmpty || state == userState;
        final districtMatches = district.isEmpty ||
            userDistrict.isEmpty ||
            district == userDistrict ||
            selectedLocation.contains(district);
        return stateMatches && districtMatches;
      }

      if (type == 'radius') {
        if (userLat == null ||
            userLng == null ||
            product.lat == null ||
            product.lng == null ||
            product.radiusKm == null) {
          return false;
        }
        return _distanceKm(userLat, userLng, product.lat!, product.lng!) <=
            product.radiusKm!;
      }

      return true;
    }).toList();
  }

  String _extractState(String selectedLocation) {
    if (selectedLocation.contains('tamil nadu')) return 'Tamil Nadu';
    return '';
  }

  String _extractDistrict(String selectedLocation) {
    final parts = selectedLocation
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.first : '';
  }

  double _distanceKm(
      double startLat, double startLng, double endLat, double endLng) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(startLat)) *
            math.cos(_degToRad(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double degrees) => degrees * math.pi / 180;

  void clearSelectedProduct() {
    _selectedProduct = null;
    _selectedVariant = null;
    _selectedOptions.clear();
    _relatedProducts.clear();
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void clearAll() {
    _products.clear();
    _recentlyViewedProducts.clear();
    _selectedProduct = null;
    _selectedVariant = null;
    _selectedOptions.clear();
    _relatedProducts.clear();
    _error = null;
    _isLoading = false;
    _loadedProductLimit = null;
    _notifySafely();
  }

  bool _disposed = false;
  bool get mounted => !_disposed;

  void _notifySafely() {
    if (mounted) {
      Future.microtask(() {
        if (mounted) {
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _products.clear();
    _recentlyViewedProducts.clear();
    _selectedProduct = null;
    super.dispose();
  }
}
