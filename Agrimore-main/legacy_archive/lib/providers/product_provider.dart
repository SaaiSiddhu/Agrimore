import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../services/database_service.dart';

class ProductProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<ProductModel> _products = [];
  List<ProductModel> _recentlyViewedProducts = [];
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  String? _error;

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

  Future<void> loadProducts({String? categoryId}) async {
    try {
      _isLoading = true;
      _error = null;
      _notifySafely();

      if (categoryId != null && categoryId != 'all' && categoryId != 'uncategorized') {
        _products = await _databaseService.getProductsByCategory(categoryId);
      } else {
        _products = await _databaseService.getAllProducts();
      }

      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _notifySafely();
      debugPrint('❌ Error loading products: $e');
    }
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

    _selectedVariant = _findVariantForSelectedOptions();
    
    _notifySafely();
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

  Future<void> loadRecentlyViewed() async {
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
      debugPrint('❌ Error loading recently viewed: $e');
    }
  }

  Future<void> addToRecentlyViewed(ProductModel product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentlyViewedIds = prefs.getStringList('recently_viewed') ?? [];
      
      recentlyViewedIds.remove(product.id);
      recentlyViewedIds.insert(0, product.id);
      
      if (recentlyViewedIds.length > 20) {
        recentlyViewedIds.removeRange(20, recentlyViewedIds.length);
      }
      
      await prefs.setStringList('recently_viewed', recentlyViewedIds);
      
      _recentlyViewedProducts.remove(product);
      _recentlyViewedProducts.insert(0, product);
      
      if (_recentlyViewedProducts.length > 20) {
        _recentlyViewedProducts.removeRange(20, _recentlyViewedProducts.length);
      }
      
      _notifySafely();
    } catch (e) {
      debugPrint('❌ Error adding to recently viewed: $e');
    }
  }

  Future<void> clearRecentlyViewed() async {
    try {
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