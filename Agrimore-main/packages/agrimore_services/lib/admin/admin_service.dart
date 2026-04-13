import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

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

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating order status: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

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

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
      int lowStockCount = 0;
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final stock = (data['stock'] ?? data['quantity'] ?? 0) as int;
        if (stock < 10) lowStockCount++;
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
          revenue += (data['total'] ?? data['totalAmount'] ?? 0).toDouble();
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
