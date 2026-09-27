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

  // ADMR-35: updateOrderStatus (wrapping AdminService's own raw-write
  // method below) removed — zero callers anywhere in the admin app. Every
  // real order-status change goes through OrderProvider.updateOrderStatus,
  // which calls the canonical adminUpdateOrderStatus command.

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

  // ✅ NEW: Update category with full CategoryModel.
  // Reparenting (a changed parentId) is refused if it would create a cycle,
  // and otherwise keeps BOTH the old and new parent's subcategoryIds in sync
  // -- addCategory only ever had to bookkeep one direction (a brand-new
  // category has no old parent to detach from); reparenting needs both.
  Future<void> updateCategory(CategoryModel category) async {
    try {
      final existing = _categoryModels.where((c) => c.id == category.id).firstOrNull;
      final oldParentId = existing?.parentId;
      final newParentId = category.parentId;
      final isReparent = newParentId != oldParentId;

      if (isReparent && _wouldCreateCategoryCycle(category.id, newParentId)) {
        final candidateName =
            _categoryModels.where((c) => c.id == newParentId).firstOrNull?.name ?? 'that category';
        throw Exception(
            'Cannot make "${category.name}" a subcategory of "$candidateName" — "$candidateName" is already inside "${category.name}", and that would create a circular hierarchy.');
      }

      // Descendants' own `level` values are computed once, relative to
      // category's OWN pre-move level, before any write -- reading
      // _categoryModels after the move started would see a mix of old and
      // new levels once the loop below starts persisting them.
      final levelDelta = isReparent && existing != null ? category.level - existing.level : 0;
      final descendantsToRelevel =
          levelDelta != 0 ? _descendantCategoriesOf(category.id) : const <CategoryModel>[];

      await _adminService.updateCategoryModel(category);

      if (isReparent) {
        if (oldParentId != null && oldParentId.isNotEmpty) {
          final oldParent = _categoryModels.where((c) => c.id == oldParentId).firstOrNull;
          if (oldParent != null) {
            final updatedIds = oldParent.subcategoryIds.where((id) => id != category.id).toList();
            await _adminService.updateCategoryModel(oldParent.copyWith(subcategoryIds: updatedIds));
          }
        }
        if (newParentId != null && newParentId.isNotEmpty) {
          final newParent = _categoryModels.where((c) => c.id == newParentId).firstOrNull;
          if (newParent != null && !newParent.subcategoryIds.contains(category.id)) {
            final updatedIds = [...newParent.subcategoryIds, category.id];
            await _adminService.updateCategoryModel(newParent.copyWith(subcategoryIds: updatedIds));
          }
        }
      }

      // A reparent that changes category's own level (almost always, since
      // level is derived from depth) leaves every transitive descendant's
      // stored level stale by the same delta -- pre-existing since CAT-3's
      // own edit-dialog reparent path (which has the identical gap), only
      // fixed here because this shared method is both paths' single write
      // site.
      for (final descendant in descendantsToRelevel) {
        await _adminService.updateCategoryModel(descendant.copyWith(level: descendant.level + levelDelta));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Live count of products currently assigned to [categoryId] OR any of its
  /// descendants -- see AdminService.countProductsInCategory's own doc
  /// comment for why CategoryModel.productCount itself can't be trusted for
  /// this, and for why descendants must be included (a product filed under a
  /// subcategory still counts toward its parent everywhere else in the app).
  /// Reuses _descendantCategoriesOf, the same descendant walker CAT-7's own
  /// level-cascade already trusts, rather than a second implementation.
  Future<int> countProductsInCategory(String categoryId) => _adminService
      .countProductsInCategory([
        categoryId,
        ..._descendantCategoriesOf(categoryId).map((c) => c.id),
      ]);

  /// True if setting [categoryId]'s parent to [candidateParentId] would
  /// create a cycle. Public passthrough to the private cycle-walk below --
  /// category_management_screen.dart is a separate library (file-private
  /// members aren't visible across files in Dart) and needs this for live
  /// drag-hover validation before a drop is even attempted.
  bool wouldCreateCategoryCycle(String categoryId, String? candidateParentId) =>
      _wouldCreateCategoryCycle(categoryId, candidateParentId);

  /// Number of levels below [categoryId] in its current tree shape (0 for a
  /// leaf). Used to reject a drag-reparent that would push some descendant
  /// past CategoryModel's own documented 4-level cap (level 0..3) -- the
  /// existing canHaveChildren check on the TARGET parent only ever bounded
  /// the dragged category's own new level, never its own subtree's height.
  int subtreeHeightOf(String categoryId) {
    final children = _categoryModels.where((c) => c.parentId == categoryId);
    var maxChildHeight = -1;
    for (final child in children) {
      final childHeight = subtreeHeightOf(child.id);
      if (childHeight > maxChildHeight) maxChildHeight = childHeight;
    }
    return maxChildHeight + 1;
  }

  /// Every transitive descendant of [categoryId] (children, grandchildren,
  /// ...), walked DOWN via parentId -- the reverse direction of
  /// _wouldCreateCategoryCycle's own upward walk. Order is unspecified;
  /// callers only need the set, not a particular traversal order.
  List<CategoryModel> _descendantCategoriesOf(String categoryId) {
    final result = <CategoryModel>[];
    final frontier = <String>[categoryId];
    while (frontier.isNotEmpty) {
      final parentId = frontier.removeLast();
      final children = _categoryModels.where((c) => c.parentId == parentId);
      for (final child in children) {
        result.add(child);
        frontier.add(child.id);
      }
    }
    return result;
  }

  /// True if setting [categoryId]'s parent to [candidateParentId] would
  /// create a cycle -- either the category parenting itself, or parenting
  /// onto one of its own descendants. Walks UP from the candidate via
  /// parentId (not down through subcategoryIds) since every category's own
  /// parentId is the single source of truth for its position; subcategoryIds
  /// is bookkeeping derived from it, not the other way around.
  bool _wouldCreateCategoryCycle(String categoryId, String? candidateParentId) {
    if (candidateParentId == null || candidateParentId.isEmpty) return false;
    if (candidateParentId == categoryId) return true;
    String? currentId = candidateParentId;
    final visited = <String>{};
    while (currentId != null && currentId.isNotEmpty) {
      if (currentId == categoryId) return true;
      if (!visited.add(currentId)) break; // pre-existing corrupt cycle in the data -- stop, don't loop forever
      final current = _categoryModels.where((c) => c.id == currentId).firstOrNull;
      currentId = current?.parentId;
    }
    return false;
  }

  /// Moves [category] to [newIndex] among its siblings (same parentId --
  /// dragging never changes which group a category belongs to, only its
  /// position within it), then re-persists sequential displayOrder values
  /// (0..N-1) across the whole sibling group. Re-sequencing the whole group,
  /// rather than only the two endpoints, stays correct even when existing
  /// displayOrder values are duplicated or gapped -- the admin form has
  /// always been a free-text number with no uniqueness enforcement, so
  /// assuming today's values are already clean would be unsafe.
  Future<void> reorderCategory(CategoryModel category, int newIndex) async {
    final siblings = _categoryModels.where((c) => c.parentId == category.parentId).toList()
      ..sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    final oldIndex = siblings.indexWhere((c) => c.id == category.id);
    if (oldIndex == -1 || newIndex < 0 || newIndex >= siblings.length || oldIndex == newIndex) {
      return;
    }

    final reordered = List<CategoryModel>.from(siblings);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].displayOrder != i) {
        await _adminService.updateCategoryModel(reordered[i].copyWith(displayOrder: i));
      }
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