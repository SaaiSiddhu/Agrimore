import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agrimore_core/models/product_model.dart';
import 'package:agrimore_core/models/category_model.dart';
import 'package:agrimore_core/models/order_model.dart';
import 'package:agrimore_core/models/coupon_model.dart';
import 'package:agrimore_core/models/address_model.dart';
import 'package:agrimore_core/models/review_model.dart';
import 'package:agrimore_core/models/cart_model.dart';
import 'package:agrimore_core/models/wishlist_model.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/models/order_status.dart'; // This import seems unused, but kept from original
import 'package:agrimore_core/models/user_model.dart'; // ✅ NEW: Added for getUserProfile

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // USERS
  // ============================================

  /// ✅ NEW: Fetches a user's profile data as a raw map.
  /// Used by UserProvider and AIChatService.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        debugPrint('❌ User profile not found: $userId');
        return null;
      }
      debugPrint('✅ Loaded user profile for: $userId');
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      throw DatabaseException('Failed to get user profile: ${e.toString()}');
    }
  }

  // ============================================
  // PRODUCTS
  // ============================================

  // Get all products (NO INDEX REQUIRED)
  Future<List<ProductModel>> getAllProducts() async {
    try {
      debugPrint('🔍 Loading all products...');

      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      debugPrint('📦 Found ${snapshot.docs.length} products');

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final products = snapshot.docs.map((doc) {
        try {
          return ProductModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          debugPrint('❌ Error parsing product ${doc.id}: $e');
          return null;
        }
      }).whereType<ProductModel>().toList();

      // Sort in memory
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('✅ Loaded ${products.length} products');
      return products;
    } catch (e) {
      debugPrint('❌ Error getting products: $e');
      // ✅ ENHANCED: Throw exception for provider to catch
      throw DatabaseException('Failed to get products: ${e.toString()}');
    }
  }

  // Get multiple products by a list of IDs
  Future<List<ProductModel>> getProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();

      final products = snapshot.docs.map((doc) {
        try {
          return ProductModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          return null;
        }
      }).whereType<ProductModel>().toList();

      // Filter for isActive
      return products.where((p) => p.isActive).toList();
    } catch (e) {
      debugPrint('❌ Error getting products by IDs: $e');
      throw DatabaseException(
          'Failed to get products by IDs: ${e.toString()}');
    }
  }

  // Get products by category (NO INDEX REQUIRED)
  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    try {
      debugPrint('🔍 Loading products for category: $categoryId');

      final snapshot = await _firestore
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .get();

      final products = snapshot.docs.map((doc) {
        try {
          return ProductModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          return null;
        }
      }).whereType<ProductModel>().toList();

      // Sort in memory
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('✅ Loaded ${products.length} products in category');
      return products;
    } catch (e) {
      debugPrint('❌ Error: $e');
      throw DatabaseException(
          'Failed to get products by category: ${e.toString()}');
    }
  }

  // Get featured products
  Future<List<ProductModel>> getFeaturedProducts({int? limit}) async {
    try {
      Query query = _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('isFeatured', isEqualTo: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      final products = snapshot.docs.map((doc) {
        try {
          return ProductModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id);
        } catch (e) {
          return null;
        }
      }).whereType<ProductModel>().toList();

      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products;
    } catch (e) {
      debugPrint('❌ Error getting featured products: $e');
      throw DatabaseException(
          'Failed to get featured products: ${e.toString()}');
    }
  }

  // Get product by ID
  Future<ProductModel?> getProductById(String productId) async {
    try {
      debugPrint('🔍 Loading product: $productId');

      final doc = await _firestore.collection('products').doc(productId).get();

      if (!doc.exists) {
        debugPrint('❌ Product not found');
        return null;
      }

      final product = ProductModel.fromMap(doc.data()!, doc.id);
      debugPrint('✅ Product loaded: ${product.name}');
      return product;
    } catch (e) {
      debugPrint('❌ Error getting product: $e');
      throw DatabaseException('Failed to get product: ${e.toString()}');
    }
  }

  // ✅ ENHANCED: Advanced, query-based product search
  Future<List<ProductModel>> searchProducts(String query) async {
    if (query.isEmpty) {
      // Return top 20 featured if query is empty
      return getFeaturedProducts(limit: 20);
    }
    debugPrint('🔍 Searching products for: $query');
    final lowerQuery = query.toLowerCase();
    try {
      // This query requires a 'name_search' field in Firestore
      // which should be a lowercase version of the product name.
      // It also requires a composite index: [isActive: Ascending, name_search: Ascending]
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('name_search', isGreaterThanOrEqualTo: lowerQuery)
          .where('name_search', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(20) // Limit to 20 results for performance
          .get();

      final products = snapshot.docs.map((doc) {
        try {
          return ProductModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          debugPrint('❌ Error parsing product ${doc.id}: $e');
          return null;
        }
      }).whereType<ProductModel>().toList();

      debugPrint('✅ Found ${products.length} products for query "$query"');
      return products;
    } catch (e) {
      debugPrint('❌ Error searching products: $e');
      debugPrint('⚠️ Falling back to inefficient search method.');
      // Fallback to the user's original, less efficient search as a safety net
      return _searchProductsFallback(query);
    }
  }

  /// Original search method, kept as a fallback.
  Future<List<ProductModel>> _searchProductsFallback(String query) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      final products = snapshot.docs.map((doc) {
        try {
          return ProductModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          return null;
        }
      }).whereType<ProductModel>().toList();

      // Filter by search query
      final filtered = products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
            product.description.toLowerCase().contains(query.toLowerCase());
      }).toList();

      return filtered;
    } catch (e) {
      debugPrint('❌ Error in fallback product search: $e');
      throw DatabaseException(
          'Failed to search products (fallback): ${e.toString()}');
    }
  }

  // Add product (Admin)
  Future<String> addProduct(ProductModel product) async {
    try {
      final docRef =
          await _firestore.collection('products').add(product.toMap());
      debugPrint('✅ Product added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error adding product: $e');
      throw DatabaseException('Failed to add product: ${e.toString()}');
    }
  }

  // Update product (Admin)
  Future<void> updateProduct(
      String productId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('products').doc(productId).update(updates);
      debugPrint('✅ Product updated: $productId');
    } catch (e) {
      debugPrint('❌ Error updating product: $e');
      throw DatabaseException('Failed to update product: ${e.toString()}');
    }
  }

  // Delete product (Admin)
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      debugPrint('✅ Product deleted: $productId');
    } catch (e) {
      throw DatabaseException('Failed to delete product: ${e.toString()}');
    }
  }

  // ============================================
  // CATEGORIES
  // ============================================

  // Get all categories
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      debugPrint('🔍 Loading categories...');

      // ✅ FIXED: Fetch ALL categories without isActive filter 
      // (matching AdminService.getCategories behavior)
      // Categories without isActive field were being excluded
      final snapshot = await _firestore
          .collection('categories')
          .orderBy('name')
          .get();

      debugPrint('📦 Found ${snapshot.docs.length} category documents');

      final categories = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          debugPrint('   📂 Category: ${data['name']} (isActive: ${data['isActive']})');
          return CategoryModel.fromMap(data, doc.id);
        } catch (e) {
          debugPrint('❌ Error parsing category ${doc.id}: $e');
          return null;
        }
      }).whereType<CategoryModel>().toList();

      // ✅ Filter by isActive in memory (defaults to true if not set)
      final activeCategories = categories.where((c) => c.isActive).toList();
      // Sort by displayOrder
      activeCategories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      debugPrint('✅ Loaded ${activeCategories.length} active categories');
      return activeCategories;
    } catch (e) {
      debugPrint('❌ Error getting categories: $e');
      throw DatabaseException('Failed to get categories: ${e.toString()}');
    }
  }

  // Add category (Admin)
  Future<String> addCategory(CategoryModel category) async {
    try {
      final docRef =
          await _firestore.collection('categories').add(category.toMap());
      return docRef.id;
    } catch (e) {
      throw DatabaseException('Failed to add category: ${e.toString()}');
    }
  }

  // Update category (Admin)
  Future<void> updateCategory(
      String categoryId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .update(updates);
    } catch (e) {
      throw DatabaseException('Failed to update category: ${e.toString()}');
    }
  }

  // Delete Category (Admin)
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _firestore.collection('categories').doc(categoryId).delete();
    } catch (e) {
      throw DatabaseException('Failed to delete category: ${e.toString()}');
    }
  }

  // ============================================
  // CART
  // ============================================

  // Get user cart
  Stream<CartModel?> getUserCart(String userId) {
    try {
      return _firestore
          .collection('carts')
          .doc(userId)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return CartModel.fromMap(doc.data()!, doc.id);
      });
    } catch (e) {
      throw DatabaseException('Failed to get cart: ${e.toString()}');
    }
  }

  // Update cart
  Future<void> updateCart(String userId, CartModel cart) async {
    try {
      await _firestore.collection('carts').doc(userId).set(cart.toMap());
    } catch (e) {
      throw DatabaseException('Failed to update cart: ${e.toString()}');
    }
  }

  // Clear cart
  Future<void> clearCart(String userId) async {
    try {
      await _firestore.collection('carts').doc(userId).delete();
    } catch (e) {
      throw DatabaseException('Failed to clear cart: ${e.toString()}');
    }
  }

  // ============================================
  // WISHLIST
  // ============================================

  // Get user wishlist
  Stream<WishlistModel?> getUserWishlist(String userId) {
    try {
      return _firestore
          .collection('wishlists')
          .doc(userId)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return WishlistModel.fromMap(doc.data()!, doc.id);
      });
    } catch (e) {
      throw DatabaseException('Failed to get wishlist: ${e.toString()}');
    }
  }

  // Update wishlist
  Future<void> updateWishlist(String userId, WishlistModel wishlist) async {
    try {
      await _firestore
          .collection('wishlists')
          .doc(userId)
          .set(wishlist.toMap());
    } catch (e) {
      throw DatabaseException('Failed to update wishlist: ${e.toString()}');
    }
  }

  // ============================================
  // ORDERS
  // ============================================

  // Create order
  Future<String> createOrder(OrderModel order) async {
    try {
      final docRef = await _firestore.collection('orders').add(order.toMap());
      return docRef.id;
    } catch (e) {
      throw DatabaseException('Failed to create order: ${e.toString()}');
    }
  }

  // Get user orders
  Stream<List<OrderModel>> getUserOrders(String userId) {
    try {
      return _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw DatabaseException('Failed to get orders: ${e.toString()}');
    }
  }

  // Get order by ID
  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();

      if (!doc.exists) {
        throw DataNotFoundException('Order not found');
      }

      return OrderModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw DatabaseException('Failed to get order: ${e.toString()}');
    }
  }

  // Update order status (Admin)
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatabaseException('Failed to update order status: ${e.toString()}');
    }
  }

  // Get all orders (Admin)
  Stream<List<OrderModel>> getAllOrders({String? status}) {
    try {
      Query query = _firestore.collection('orders');

      if (status != null) {
        query = query.where('orderStatus', isEqualTo: status);
      }

      return query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) =>
                OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      });
    } catch (e) {
      throw DatabaseException('Failed to get orders: ${e.toString()}');
    }
  }

  // ============================================
  // ADDRESSES
  // ============================================

  // Get user addresses (Stream for real-time UI)
  Stream<List<AddressModel>> getUserAddresses(String userId) {
    try {
      return _firestore
          .collection('addresses')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => AddressModel.fromMap({
                  ...doc.data(),
                  'id': doc.id, // Ensure document ID is included
                }))
            .toList();
      });
    } catch (e) {
      throw DatabaseException('Failed to get addresses: ${e.toString()}');
    }
  }

  /// ✅ NEW: Get user addresses as a one-time list (for AI Service)
  Future<List<Map<String, dynamic>>> getUserAddressesList(
      String userId) async {
    try {
      final snap = await _firestore
          .collection('addresses')
          .where('userId', isEqualTo: userId)
          .get();
      if (snap.docs.isEmpty) {
        return [];
      }
      // The AI service wants a List<Map>, not List<AddressModel>
      final addresses = snap.docs.map((d) {
        final m = d.data();
        m['id'] = d.id; // Ensure ID is part of the map
        return m;
      }).toList();
      return addresses;
    } catch (e) {
      debugPrint('❌ Error getting addresses list: $e');
      throw DatabaseException('Failed to get addresses: ${e.toString()}');
    }
  }

  // Add address
  Future<String> addAddress(AddressModel address) async {
    try {
      // Use the address's own ID if it has one
      final docRef = _firestore.collection('addresses').doc(address.id);
      await docRef.set(address.toMap());
      return docRef.id;
    } catch (e) {
      throw DatabaseException('Failed to add address: ${e.toString()}');
    }
  }

  // Update address
  Future<void> updateAddress(
      String addressId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('addresses')
          .doc(addressId)
          .update(updates);
    } catch (e) {
      throw DatabaseException('Failed to update address: ${e.toString()}');
    }
  }

  // Delete address
  Future<void> deleteAddress(String addressId) async {
    try {
      await _firestore.collection('addresses').doc(addressId).delete();
    } catch (e) {
      throw DatabaseException('Failed to delete address: ${e.toString()}');
    }
  }

  // ============================================
  // COUPONS
  // ============================================

  // Get all active coupons
  Stream<List<CouponModel>> getActiveCoupons() {
    try {
      return _firestore
          .collection('coupons')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CouponModel.fromMap(doc.data(), doc.id))
            .where((coupon) => coupon.isValid)
            .toList();
      });
    } catch (e) {
      throw DatabaseException('Failed to get coupons: ${e.toString()}');
    }
  }

  // Get coupon by code
  Future<CouponModel?> getCouponByCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return CouponModel.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      throw DatabaseException('Failed to get coupon: ${e.toString()}');
    }
  }

  // Add coupon (Admin)
  Future<String> addCoupon(CouponModel coupon) async {
    try {
      final docRef =
          await _firestore.collection('coupons').add(coupon.toMap());
      return docRef.id;
    } catch (e) {
      throw DatabaseException('Failed to add coupon: ${e.toString()}');
    }
  }

  // Update coupon usage
  Future<void> incrementCouponUsage(String couponId) async {
    try {
      await _firestore.collection('coupons').doc(couponId).update({
        'usedCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw DatabaseException('Failed to update coupon: ${e.toString()}');
    }
  }

  // ============================================
  // REVIEWS (SUBCOLLECTION BASED)
  // ============================================

  Stream<List<ReviewModel>> getProductReviews(String productId) {
    try {
      return _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => ReviewModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting reviews: $e');
      throw DatabaseException('Failed to get reviews: ${e.toString()}');
    }
  }

  Future<ReviewStats?> getReviewStats(String productId) async {
    try {
      final doc = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviewStats')
          .doc('stats')
          .get();

      if (doc.exists) {
        return ReviewStats.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error loading review stats: $e');
      return null;
    }
  }

  Future<String> addReview(ReviewModel review) async {
    try {
      final reviewRef = _firestore
          .collection('products')
          .doc(review.productId)
          .collection('reviews')
          .doc();

      // Use copyWith to set the new reviewId
      final finalReview = review.copyWith(reviewId: reviewRef.id);
      await reviewRef.set(finalReview.toMap());

      await _updateReviewStats(review.productId);

      debugPrint('✅ Review added: ${reviewRef.id}');
      return reviewRef.id;
    } catch (e) {
      debugPrint('❌ Error adding review: $e');
      throw DatabaseException('Failed to add review: ${e.toString()}');
    }
  }

  Future<void> updateReview(ReviewModel review) async {
    try {
      await _firestore
          .collection('products')
          .doc(review.productId)
          .collection('reviews')
          .doc(review.reviewId)
          .update(review.toMap());

      await _updateReviewStats(review.productId);

      debugPrint('✅ Review updated: ${review.reviewId}');
    } catch (e) {
      debugPrint('❌ Error updating review: $e');
      throw DatabaseException('Failed to update review: ${e.toString()}');
    }
  }

  Future<void> deleteReview(String productId, String reviewId) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      await _updateReviewStats(productId);

      debugPrint('✅ Review deleted: $reviewId');
    } catch (e) {
      debugPrint('❌ Error deleting review: $e');
      throw DatabaseException('Failed to delete review: ${e.toString()}');
    }
  }

  Future<void> markReviewHelpful(
    String productId,
    String reviewId,
    String userId,
    bool isHelpful,
  ) async {
    try {
      final reviewRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId);

      final reviewDoc = await reviewRef.get();
      if (!reviewDoc.exists) {
        throw DataNotFoundException('Review not found');
      }

      final review = ReviewModel.fromMap(
          reviewDoc.data() as Map<String, dynamic>, reviewId);

      List<String> helpfulUsers = List.from(review.helpfulUsers);
      List<String> unhelpfulUsers = List.from(review.unhelpfulUsers);

      if (isHelpful) {
        if (helpfulUsers.contains(userId)) {
          helpfulUsers.remove(userId);
        } else {
          helpfulUsers.add(userId);
          unhelpfulUsers.remove(userId);
        }
      } else {
        if (unhelpfulUsers.contains(userId)) {
          unhelpfulUsers.remove(userId);
        } else {
          unhelpfulUsers.add(userId);
          helpfulUsers.remove(userId);
        }
      }

      await reviewRef.update({
        'helpfulUsers': helpfulUsers,
        'unhelpfulUsers': unhelpfulUsers,
        'helpfulCount': helpfulUsers.length,
        'unhelpfulCount': unhelpfulUsers.length,
      });

      debugPrint(
          '✅ Review marked as ${isHelpful ? 'helpful' : 'unhelpful'}: $reviewId');
    } catch (e) {
      debugPrint('❌ Error marking helpful: $e');
      throw DatabaseException('Failed to mark helpful: ${e.toString()}');
    }
  }

  Stream<List<ReviewModel>> getUserReviews(String userId) {
    try {
      return _firestore
          .collectionGroup('reviews')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => ReviewModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting user reviews: $e');
      throw DatabaseException('Failed to get user reviews: ${e.toString()}');
    }
  }

  Future<List<ReviewModel>> getTopRatedReviews(
    String productId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ReviewModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting top-rated reviews: $e');
      return [];
    }
  }

  Future<List<ReviewModel>> getMostHelpfulReviews(
    String productId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('helpfulCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ReviewModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting helpful reviews: $e');
      return [];
    }
  }

  Future<ReviewModel?> getUserProductReview(
    String productId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return ReviewModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id);
    } catch (e) {
      debugPrint('❌ Error checking user review: $e');
      return null;
    }
  }

  Future<void> _updateReviewStats(String productId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .get();

      final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (reviews.isEmpty) {
        await _firestore
            .collection('products')
            .doc(productId)
            .collection('reviewStats')
            .doc('stats')
            .set({
          'totalReviews': 0,
          'averageRating': 0.0,
          'fiveStarCount': 0,
          'fourStarCount': 0,
          'threeStarCount': 0,
          'twoStarCount': 0,
          'oneStarCount': 0,
          'ratingDistribution': {
            '5': 0,
            '4': 0,
            '3': 0,
            '2': 0,
            '1': 0,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Also update product document
        await _firestore.collection('products').doc(productId).update({
          'rating': 0.0,
          'reviewCount': 0,
        });

        return;
      }

      double totalRating = 0;
      int fiveStarCount = 0;
      int fourStarCount = 0;
      int threeStarCount = 0;
      int twoStarCount = 0;
      int oneStarCount = 0;

      for (var review in reviews) {
        totalRating += review.rating;
        if (review.rating == 5)
          fiveStarCount++;
        else if (review.rating == 4)
          fourStarCount++;
        else if (review.rating == 3)
          threeStarCount++;
        else if (review.rating == 2)
          twoStarCount++;
        else if (review.rating == 1) oneStarCount++;
      }

      final averageRating = totalRating / reviews.length;

      final stats = {
        'totalReviews': reviews.length,
        'averageRating': double.parse(averageRating.toStringAsFixed(1)),
        'fiveStarCount': fiveStarCount,
        'fourStarCount': fourStarCount,
        'threeStarCount': threeStarCount,
        'twoStarCount': twoStarCount,
        'oneStarCount': oneStarCount,
        'ratingDistribution': {
          '5': fiveStarCount,
          '4': fourStarCount,
          '3': threeStarCount,
          '2': twoStarCount,
          '1': oneStarCount,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviewStats')
          .doc('stats')
          .set(stats, SetOptions(merge: true));

      await _firestore.collection('products').doc(productId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'reviewCount': reviews.length,
      });

      debugPrint('✅ Review stats updated for product: $productId');
    } catch (e) {
      debugPrint('❌ Error updating review stats: $e');
    }
  }

  Future<void> updateReviewBatch(
    String productId,
    List<String> reviewIds,
    Map<String, dynamic> updates,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var reviewId in reviewIds) {
        final ref = _firestore
            .collection('products')
            .doc(productId)
            .collection('reviews')
            .doc(reviewId);

        batch.update(ref, updates);
      }

      await batch.commit();
      debugPrint('✅ Batch updated ${reviewIds.length} reviews');
    } catch (e) {
      debugPrint('❌ Error batch updating reviews: $e');
      throw DatabaseException(
          'Failed to batch update reviews: ${e.toString()}');
    }
  }

  Future<List<ReviewModel>> getFilteredReviews(
    String productId, {
    int minRating = 1,
    int maxRating = 5,
    bool verifiedOnly = false,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews');

      if (minRating > 1 || maxRating < 5) {
        query = query
            .where('rating', isGreaterThanOrEqualTo: minRating)
            .where('rating', isLessThanOrEqualTo: maxRating);
      }

      if (verifiedOnly) {
        query = query.where('isVerifiedPurchase', isEqualTo: true);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ReviewModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting filtered reviews: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getReviewAnalytics(String productId) async {
    try {
      final stats = await getReviewStats(productId);
      if (stats == null) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'percentageByRating': {},
        };
      }

      final percentageByRating = <String, double>{};
      if (stats.totalReviews > 0) {
        percentageByRating['5'] =
            (stats.fiveStarCount / stats.totalReviews * 100).roundToDouble();
        percentageByRating['4'] =
            (stats.fourStarCount / stats.totalReviews * 100).roundToDouble();
        percentageByRating['3'] =
            (stats.threeStarCount / stats.totalReviews * 100).roundToDouble();
        percentageByRating['2'] =
            (stats.twoStarCount / stats.totalReviews * 100).roundToDouble();
        percentageByRating['1'] =
            (stats.oneStarCount / stats.totalReviews * 100).roundToDouble();
      }

      return {
        'totalReviews': stats.totalReviews,
        'averageRating': stats.averageRating,
        'percentageByRating': percentageByRating,
        'fiveStarCount': stats.fiveStarCount,
        'fourStarCount': stats.fourStarCount,
        'threeStarCount': stats.threeStarCount,
        'twoStarCount': stats.twoStarCount,
        'oneStarCount': stats.oneStarCount,
      };
    } catch (e) {
      debugPrint('❌ Error getting review analytics: $e');
      return {};
    }
  }
}