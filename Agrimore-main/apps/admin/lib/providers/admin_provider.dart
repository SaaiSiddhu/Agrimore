import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart'; 

class AdminProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();

  // Dashboard Stats
  Map<String, dynamic> _dashboardStats = {
    'products': 0,
    'orders': 0,
    'users': 0,
    'revenue': 0.0,
  };
  Map<String, dynamic> get dashboardStats => _dashboardStats;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Products
  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;
  bool _isLoadingProducts = false;
  bool get isLoadingProducts => _isLoadingProducts;

  // Orders
  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  // Users
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> get users => _users;

  // Categories (moved to CategoryModel section below)
  bool _isLoadingCategories = false;
  bool get isLoadingCategories => _isLoadingCategories;

  // Coupons
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> get coupons => _coupons;

  // ============================================
  // DASHBOARD
  // ============================================
  
  Future<void> loadDashboardStats() async {
    try {
      _dashboardStats = await _adminService.getDashboardStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    }
  }

  // ============================================
  // PRODUCTS
  // ============================================
  
  void listenToProducts() {
    _isLoadingProducts = true;
    notifyListeners();
    _adminService.getProducts().listen((products) {
      _products = products;
      _isLoadingProducts = false;
      notifyListeners();
    });
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      _isLoadingProducts = true;
      notifyListeners();
      
      await _adminService.addProduct(product);
      
      _isLoadingProducts = false;
      notifyListeners();
    } catch (e) {
      _isLoadingProducts = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, ProductModel product) async {
    try {
      // ✅ FIXED: Pass the full ProductModel object, not a Map
      await _adminService.updateProduct(productId, product);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _adminService.deleteProduct(productId);
    } catch (e) {
      rethrow;
    }
  }
  
  // ✅ NEW: Bulk delete products
  Future<void> deleteProducts(List<String> productIds) async {
    try {
      // This logic should be in AdminService, but for now, we loop here
      for (final productId in productIds) {
        await _adminService.deleteProduct(productId);
      }
    } catch (e) {
      rethrow;
    }
  }


  // ============================================
  // ORDERS
  // ============================================
  
  void listenToOrders() {
    _adminService.getOrders().listen((orders) {
      _orders = orders;
      notifyListeners();
    });
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _adminService.updateOrderStatus(orderId, status);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // USERS (FIXED - Single method)
  // ============================================
  
  Future<void> listenToUsers() async {
    try {
      _isLoading = true;
      notifyListeners();

      _adminService.getUsers().listen((users) {
        _users = users;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error listening to users: $e');
      rethrow;
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _adminService.updateUserRole(userId, role);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _adminService.toggleUserStatus(userId, isActive);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _adminService.deleteUser(userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserInfo(String userId, Map<String, dynamic> data) async {
    try {
      await _adminService.updateUserInfo(userId, data);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // CATEGORIES (Enhanced with CategoryModel)
  // ============================================
  
  // ✅ UPDATED: Use List<CategoryModel> instead of Map
  List<CategoryModel> _categoryModels = [];
  List<CategoryModel> get categories => _categoryModels;
  
  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    notifyListeners();
    try {
      _adminService.getCategories().listen((categories) {
        // Convert Map to CategoryModel
        _categoryModels = categories.map((c) => CategoryModel.fromMap(c, c['id'] ?? '')).toList();
        _isLoadingCategories = false;
        notifyListeners();
      });
    } catch (e) {
      _isLoadingCategories = false;
      notifyListeners();
      debugPrint('Error loading categories: $e');
    }
  }

  // ✅ NEW: Add category with full CategoryModel
  Future<void> addCategory(CategoryModel category) async {
    try {
      final id = await _adminService.addCategoryModel(category);
      
      // If has parent, update parent's subcategoryIds
      if (category.parentId != null && category.parentId!.isNotEmpty) {
        final parent = _categoryModels.where((c) => c.id == category.parentId).firstOrNull;
        if (parent != null) {
          final updatedIds = [...parent.subcategoryIds, id];
          await _adminService.updateCategoryModel(parent.copyWith(subcategoryIds: updatedIds));
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ NEW: Update category with full CategoryModel  
  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _adminService.updateCategoryModel(category);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      // Delete all children first (cascade)
      final children = _categoryModels.where((c) => c.parentId == categoryId).toList();
      for (final child in children) {
        await deleteCategory(child.id);
      }
      
      // Remove from parent's subcategoryIds
      final category = _categoryModels.where((c) => c.id == categoryId).firstOrNull;
      if (category?.parentId != null) {
        final parent = _categoryModels.where((c) => c.id == category!.parentId).firstOrNull;
        if (parent != null) {
          final updatedIds = parent.subcategoryIds.where((id) => id != categoryId).toList();
          await _adminService.updateCategoryModel(parent.copyWith(subcategoryIds: updatedIds));
        }
      }
      
      await _adminService.deleteCategory(categoryId);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // COUPONS
  // ============================================
  
  void listenToCoupons() {
    _adminService.getCoupons().listen((coupons) {
      _coupons = coupons;
      notifyListeners();
    });
  }

  Future<void> addCoupon({
    required String code,
    required double discount,
    required String type,
    required DateTime expiryDate,
    int? maxUses,
  }) async {
    try {
      await _adminService.addCoupon(
        code: code,
        discount: discount,
        type: type,
        expiryDate: expiryDate,
        maxUses: maxUses,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleCouponStatus(String couponId, bool isActive) async {
    try {
      await _adminService.toggleCouponStatus(couponId, isActive);
    } catch (e) {
      rethrow;
    }
  }
}