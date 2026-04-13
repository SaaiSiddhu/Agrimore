import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
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
  Future<void> fetchProducts({String? categoryId}) async {
    return loadProducts(categoryId: categoryId);
  }

  // ============================================
  // ENHANCED CACHE-FIRST LOADING
  // ============================================
  Future<void> loadProducts({String? categoryId, bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flags to force Firebase fetch
    if (forceRefresh) {
      _isLoaded = false;
      _isCacheLoaded = false;
      debugPrint('🔄 Force refreshing products from Firebase...');
    }
    
    // ✅ Skip if already loaded for "all" products (in-memory cache)
    if (_isLoaded && !forceRefresh && categoryId == null) {
      debugPrint('📦 Products in-memory cached, skipping...');
      return;
    }
    
    // ✅ Race condition fix: If already loading, wait for that operation
    if (_loadCompleter != null && categoryId == null) {
      debugPrint('📦 Products loading in progress, waiting...');
      return _loadCompleter!.future;
    }
    
    _loadCompleter = Completer<void>();
    
    try {
      // ============================================
      // STEP 1: INSTANT - Load from local cache first
      // ============================================
      if (categoryId == null && !_isCacheLoaded) {
        final cachedProducts = await _loadFromCache();
        if (cachedProducts.isNotEmpty) {
          _products = cachedProducts;
          _isCacheLoaded = true;
          _isLoaded = true;
          debugPrint('⚡ INSTANT: Loaded ${_products.length} products from cache');
          _notifySafely(); // Show cached data immediately!
        }
      }

      // ============================================
      // STEP 2: BACKGROUND - Fetch fresh data from network
      // ============================================
      _isLoading = !_isCacheLoaded; // Only show loading if no cache
      _error = null;
      if (!_isCacheLoaded) _notifySafely();

      List<ProductModel> freshProducts;
      if (categoryId != null && categoryId != 'all' && categoryId != 'uncategorized') {
        freshProducts = await _databaseService.getProductsByCategory(categoryId);
      } else {
        freshProducts = await _databaseService.getAllProducts();
      }

      // ============================================
      // STEP 3: UPDATE - Only refresh UI if data changed
      // ============================================
      final hasChanges = _hasDataChanged(freshProducts);
      _products = freshProducts;
      _isLoaded = true;

      if (categoryId == null) {
        await _saveToCache(freshProducts); // Save fresh data to cache
      }

      debugPrint('✅ NETWORK: Loaded ${_products.length} products${hasChanges ? " (updated)" : " (unchanged)"}');
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
      await prefs.setString(_kProductsCacheTimeKey, DateTime.now().toIso8601String());
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

  Future<void> loadFeaturedProducts() async {
    try {
      _isLoading = true;
      _notifySafely();
      _products = await _databaseService.getFeaturedProducts(limit: 10);
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
      debugPrint('✅ Found variant: ${_selectedVariant!.name}, price: ₹${_selectedVariant!.salePrice}');
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
    debugPrint('✅ Selected variant by name: ${variant.name}, price: ₹${variant.salePrice}');
    
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
      
      debugPrint('✅ Loaded ${_recentlyViewedProducts.length} recently viewed from Firestore');
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
      _products = await _databaseService.searchProducts(query);
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

  Future<void> refreshProducts() async {
    await loadProducts();
  }

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