import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// ADMR-44: setUserRole.ts's own VALID_ROLES uses 'customer' for the
/// non-privileged case (roleClaims.ts's own vocabulary); every other part
/// of this app persists and reads the literal string 'user' for the same
/// concept (UserModel.isBuyer, edit_user_screen.dart's own role options).
/// Pure and top-level so a wrong mapping here — which would either fail
/// validation outright or silently request the wrong role — is directly
/// testable without constructing AdminService itself.
String apiRoleForStoredRole(String storedRole) =>
    storedRole == 'user' ? 'customer' : storedRole;

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // PRODUCTS
  // ============================================
  
  Future<String> addProduct(ProductModel product) async {
    try {
      // ✅ Generate slug from product name
      final slug = _generateSlug(product.name);
      
      // ✅ Check if product with this name already exists
      final existingDoc = await _firestore.collection('products').doc(slug).get();
      if (existingDoc.exists) {
        throw Exception('A product with name "${product.name}" already exists');
      }
      
      await _firestore.collection('products').doc(slug).set(product.toJson());
      debugPrint('✅ Product added with ID: $slug');
      return slug;
    } catch (e) {
      debugPrint('Error adding product: $e');
      throw Exception('Failed to add product: $e');
    }
  }
  
  /// Generate URL-friendly slug from name
  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  Future<void> updateProduct(String productId, ProductModel product) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .update(product.toJson());
    } catch (e) {
      debugPrint('Error updating product: $e');
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      debugPrint('Error deleting product: $e');
      throw Exception('Failed to delete product: $e');
    }
  }

  Stream<List<ProductModel>> getProducts() {
    return _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ============================================
  // ORDERS
  // ============================================
  
  Stream<List<OrderModel>> getOrders() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ADMR-35: updateOrderStatus removed — zero callers anywhere in the
  // repo (confirmed by a repo-wide grep, not just apps/admin), and it only
  // ever wrote the legacy `status` field, never the canonical `orderStatus`
  // OrderModel actually reads first — a real inconsistency it never
  // reached in practice, since nothing called it. The canonical path is
  // functions/src/admin/adminOrderActions.ts's adminUpdateOrderStatus,
  // called via OrderProvider.updateOrderStatus.

  // ============================================
  // USERS
  // ============================================
  
  Stream<List<Map<String, dynamic>>> getUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // ADMR-44: was a bare client Firestore write — firestore.rules'
  // `allow update: if isAdmin() || ...` grants ANY admin unrestricted
  // access to ANY user's role field, with no audit trail, no self-
  // demotion guard and no last-admin protection (ADMR-12's own comment on
  // this method already named this gap explicitly; that phase added only
  // a client-side confirmation dialog, deliberately not this deeper fix).
  // setUserRole.ts already exists, already deployed, and already provides
  // all of that server-side — it had zero client callers anywhere in
  // apps/admin. This routes through it instead of inventing a new command.
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('setUserRole').call<Map<String, dynamic>>({
        'userId': userId,
        'role': apiRoleForStoredRole(role),
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('setUserRole: ${e.code} ${e.message}');
      throw Exception(e.message ?? 'Failed to update user role');
    } catch (e) {
      debugPrint('Error updating user role: $e');
      throw Exception('Failed to update user role: $e');
    }
  }

  // ✅ NEW - Toggle user status (active/inactive)
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error toggling user status: $e');
      throw Exception('Failed to toggle user status: $e');
    }
  }

  // ✅ NEW - Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  // ✅ NEW - Update user information
  Future<void> updateUserInfo(String userId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      debugPrint('Error updating user info: $e');
      throw Exception('Failed to update user info: $e');
    }
  }

  // ============================================
  // ANALYTICS
  // ============================================
  
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get products count and low stock
      final productsSnapshot = await _firestore.collection('products').get();
      final productsCount = productsSnapshot.docs.length;
      // ADMR-31: previously a raw `stock < 10` check on `data['stock'] ??
      // data['quantity']` — missed variant-only stock entirely (the ADMR-4
      // bug, independently reintroduced here), ignored each product's own
      // lowStockThreshold, never excluded a draft/inactive listing, and
      // conflated out-of-stock (0) with genuinely low stock. Parsing through
      // ProductModel and the shared isLowStock() fixes all four at once by
      // reusing the one canonical definition instead of a second copy.
      int lowStockCount = 0;
      for (var doc in productsSnapshot.docs) {
        final product = ProductModel.fromMap(doc.data(), doc.id);
        if (isLowStock(product)) lowStockCount++;
      }

      // Get orders count and pending orders
      final ordersSnapshot = await _firestore.collection('orders').get();
      final ordersCount = ordersSnapshot.docs.length;
      int pendingOrdersCount = 0;
      
      debugPrint('📊 Dashboard Stats: Found ${ordersSnapshot.docs.length} orders in collection');
      
      // Calculate revenue from delivered orders and count pending
      double revenue = 0.0;
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        debugPrint('   Order ${doc.id}: status=$status, total=${data['total']}');
        
        if (status == 'delivered' || status == 'completed') {
          // ADMR-31: dropped the `totalAmount` fallback — confirmed by grep
          // that no writer anywhere in functions/src or any app has ever
          // written that field name; it was dead defensive code, not a live
          // compatibility need.
          revenue += (data['total'] ?? 0).toDouble();
        }
        if (status == 'pending' || status == 'processing') {
          pendingOrdersCount++;
        }
      }

      // Get users count
      final usersSnapshot = await _firestore.collection('users').get();
      final usersCount = usersSnapshot.docs.length;
      
      // Count sellers (users with role = 'seller' or isSeller = true)
      int sellersCount = 0;
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data['role'] == 'seller' || data['isSeller'] == true) {
          sellersCount++;
        }
      }

      // Get categories count
      final categoriesSnapshot = await _firestore.collection('categories').get();
      final categoriesCount = categoriesSnapshot.docs.length;

      debugPrint('📊 Dashboard Stats Summary:');
      debugPrint('   Products: $productsCount, LowStock: $lowStockCount');
      debugPrint('   Orders: $ordersCount, Pending: $pendingOrdersCount');
      debugPrint('   Users: $usersCount, Sellers: $sellersCount');
      debugPrint('   Categories: $categoriesCount, Revenue: ₹$revenue');

      return {
        'products': productsCount,
        'orders': ordersCount,
        'users': usersCount,
        'revenue': revenue,
        'pendingOrders': pendingOrdersCount,
        'sellers': sellersCount,
        'categories': categoriesCount,
        'lowStock': lowStockCount,
      };
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {
        'products': 0,
        'orders': 0,
        'users': 0,
        'revenue': 0.0,
        'pendingOrders': 0,
        'sellers': 0,
        'categories': 0,
        'lowStock': 0,
      };
    }
  }

  // ============================================
  // CATEGORIES
  // ============================================
  
  Future<String> addCategory(String name, String description, String icon) async {
    try {
      // ✅ Use slug as document ID
      final slug = _generateSlug(name);
      
      // ✅ Check if category with this name already exists
      final existingDoc = await _firestore.collection('categories').doc(slug).get();
      if (existingDoc.exists) {
        throw Exception('A category with name "$name" already exists');
      }
      
      await _firestore.collection('categories').doc(slug).set({
        'name': name,
        'description': description,
        'icon': icon,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Category added with ID: $slug');
      return slug;
    } catch (e) {
      debugPrint('Error adding category: $e');
      throw Exception('Failed to add category: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getCategories() {
    return _firestore
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _firestore.collection('categories').doc(categoryId).delete();
    } catch (e) {
      debugPrint('Error deleting category: $e');
      throw Exception('Failed to delete category: $e');
    }
  }

  Future<void> updateCategory(
    String categoryId,
    String name,
    String description,
    String icon,
  ) async {
    try {
      await _firestore.collection('categories').doc(categoryId).update({
        'name': name,
        'description': description,
        'icon': icon,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating category: $e');
      throw Exception('Failed to update category: $e');
    }
  }

  // ✅ NEW: Add category with full CategoryModel (for hierarchy)
  Future<String> addCategoryModel(CategoryModel category) async {
    try {
      // ✅ Use slug as document ID
      final slug = category.slug ?? _generateSlug(category.name);
      
      // ✅ Check if category with this name already exists
      final existingDoc = await _firestore.collection('categories').doc(slug).get();
      if (existingDoc.exists) {
        throw Exception('A category with name "${category.name}" already exists');
      }
      
      await _firestore.collection('categories').doc(slug).set(category.toMap());
      debugPrint('✅ Category added with ID: $slug');
      return slug;
    } catch (e) {
      debugPrint('Error adding category model: $e');
      throw Exception('Failed to add category: $e');
    }
  }

  // ✅ NEW: Update category with full CategoryModel (for hierarchy)
  Future<void> updateCategoryModel(CategoryModel category) async {
    try {
      await _firestore.collection('categories').doc(category.id).update(category.toMap());
    } catch (e) {
      debugPrint('Error updating category model: $e');
      throw Exception('Failed to update category: $e');
    }
  }

  /// Live count of products currently assigned to any of [categoryIds] --
  /// CategoryModel's own `productCount` field is never incremented,
  /// decremented, or recomputed anywhere (every category is created with it
  /// defaulted to 0 and nothing ever changes it afterward), so it cannot be
  /// trusted for display. [categoryIds] is expected to be a category plus
  /// every one of its descendants (see AdminProvider.countProductsInCategory)
  /// -- a real product filed under a subcategory must still count toward its
  /// parent, the same way `productBelongsToCategory` already treats it as
  /// belonging to the parent everywhere else in the app. Chunked at 30
  /// (Firestore's own `whereIn` cap) so correctness never depends on how many
  /// descendants a category happens to have. Count aggregation queries are
  /// cheap (no documents are actually fetched); this does NOT match the
  /// legacy name-based `categoryId` values `productBelongsToCategory` also
  /// falls back to (`whereIn` is exact-match only) -- a disclosed, narrower
  /// gap than the parent/descendant undercount this fixes.
  Future<int> countProductsInCategory(List<String> categoryIds) async {
    try {
      var total = 0;
      for (var i = 0; i < categoryIds.length; i += 30) {
        final chunk = categoryIds.sublist(
          i,
          i + 30 > categoryIds.length ? categoryIds.length : i + 30,
        );
        final snapshot = await _firestore
            .collection('products')
            .where('categoryId', whereIn: chunk)
            .count()
            .get();
        total += snapshot.count ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('Error counting products in category: $e');
      throw Exception('Failed to count products in category: $e');
    }
  }

  // ============================================
  // COUPONS
  // ============================================
  
  Future<void> addCoupon({
    required String code,
    required double discount,
    required String type,
    required DateTime expiryDate,
    int? maxUses,
  }) async {
    try {
      await _firestore.collection('coupons').add({
        'code': code.toUpperCase(),
        'title': '$discount ${type == 'percentage' ? '%' : '₹'} OFF',
        'description': 'Apply this code to get discount',
        'discount': discount,
        'type': type, // 'percentage' or 'flat'
        'validFrom': FieldValue.serverTimestamp(),
        'validTo': Timestamp.fromDate(expiryDate),
        'minOrderAmount': 0,
        'usageLimit': maxUses ?? 0,
        'usedCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding coupon: $e');
      throw Exception('Failed to add coupon: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getCoupons() {
    return _firestore
        .collection('coupons')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  Future<void> toggleCouponStatus(String couponId, bool isActive) async {
    try {
      await _firestore.collection('coupons').doc(couponId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error toggling coupon status: $e');
      throw Exception('Failed to toggle coupon status: $e');
    }
  }

  Future<void> deleteCoupon(String couponId) async {
    try {
      await _firestore.collection('coupons').doc(couponId).delete();
    } catch (e) {
      debugPrint('Error deleting coupon: $e');
      throw Exception('Failed to delete coupon: $e');
    }
  }

  Future<void> updateCoupon({
    required String couponId,
    required String code,
    required double discount,
    required String type,
    required DateTime expiryDate,
    int? maxUses,
  }) async {
    try {
      await _firestore.collection('coupons').doc(couponId).update({
        'code': code.toUpperCase(),
        'title': '$discount ${type == 'percentage' ? '%' : '₹'} OFF',
        'discount': discount,
        'type': type,
        'validTo': Timestamp.fromDate(expiryDate),
        'usageLimit': maxUses ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating coupon: $e');
      throw Exception('Failed to update coupon: $e');
    }
  }

  // ============================================
  // NOTIFICATIONS
  // ============================================

  Future<void> sendNotificationToUser(
    String userId,
    String title,
    String body,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
      throw Exception('Failed to send notification: $e');
    }
  }

  Future<void> sendBroadcastNotification(String title, String body) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      
      final batch = _firestore.batch();
      for (var userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userDoc.id,
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error sending broadcast notification: $e');
      throw Exception('Failed to send broadcast notification: $e');
    }
  }

  // ============================================
  // SEARCH & FILTERS
  // ============================================

  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
