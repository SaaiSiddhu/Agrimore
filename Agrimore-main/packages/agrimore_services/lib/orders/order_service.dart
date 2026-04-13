// lib/services/order_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // CREATE ORDER WITH INITIAL TIMELINE
  // ============================================
  Future<String?> createOrder(OrderModel order) async {
    try {
      debugPrint('📦 Creating order: ${order.orderNumber}');

      // 1️⃣ Create order document
      final orderId = order.id.isNotEmpty ? order.id : _firestore.collection('orders').doc().id;
      
      // Update the id if we had to generate a new one
      final orderData = order.toMap();
      orderData['id'] = orderId;
      
      await _firestore.collection('orders').doc(orderId).set(orderData);

      // 2️⃣ Create initial timeline entry
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
        'status': 'pending',
        'title': 'Order Placed',
        'description': 'Your order has been placed successfully.',
        'timestamp': FieldValue.serverTimestamp(),
        'icon': 'shopping_bag',
      });

      debugPrint('✅ Order created with ID: $orderId');
      return orderId;
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      return null;
    }
  }

  // ============================================
  // ADD TIMELINE EVENT MANUALLY
  // ============================================
  Future<void> addTimelineEvent(
    String orderId, {
    required String status,
    required String title,
    required String description,
  }) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
        'status': status,
        'title': title,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Timeline event added: $status');
    } catch (e) {
      debugPrint('❌ Error adding timeline event: $e');
    }
  }

  // ============================================
  // HELPER: Add timeline on status change
  // ============================================
  Future<void> updateOrderStatusWithTimeline(
    String orderId,
    String newStatus, {
    String? description,
  }) async {
    try {
      final titleMap = {
        'pending': 'Order Pending',
        'confirmed': 'Order Confirmed',
        'processing': 'Processing Order',
        'shipped': 'Order Shipped',
        'delivered': 'Order Delivered',
        'cancelled': 'Order Cancelled',
        'refunded': 'Refund Processed',
      };

      final descriptionMap = {
        'pending': 'Your order has been placed and is awaiting confirmation.',
        'confirmed': 'Your order has been confirmed by the seller.',
        'processing': 'Your order is being prepared for shipment.',
        'shipped': 'Your order has been shipped and is on the way.',
        'delivered': 'Your order has been delivered successfully.',
        'cancelled': 'Your order has been cancelled.',
        'refunded': 'Your refund has been processed.',
      };

      // Update order status
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline event
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
        'status': newStatus,
        'title': titleMap[newStatus] ?? 'Order Updated',
        'description':
            description ?? (descriptionMap[newStatus] ?? 'Order updated.'),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Order status updated and timeline added');
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
    }
  }

  // ============================================
  // COUPON VALIDATION (Migrated from React Native)
  // ============================================
  Future<Map<String, dynamic>> validateCoupon(String code, double cartTotal, String userId) async {
    try {
      final snap = await _firestore.collection('coupons').where('code', isEqualTo: code).get();

      if (snap.docs.isEmpty) return {'valid': false, 'error': 'Invalid coupon code'};

      final couponDoc = snap.docs.first;
      final coupon = couponDoc.data();

      if (coupon['isActive'] == false) return {'valid': false, 'error': 'This coupon is no longer active'};

      final expiryDate = (coupon['expiry'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryDate)) return {'valid': false, 'error': 'This coupon has expired'};

      if ((coupon['usedCount'] ?? 0) >= (coupon['usageLimit'] ?? 999999)) {
        return {'valid': false, 'error': 'Coupon usage limit reached'};
      }

      if (cartTotal < (coupon['minOrder'] ?? 0)) {
        return {'valid': false, 'error': 'Minimum order value is ₹${coupon['minOrder']}'};
      }

      double discountAmount = 0;
      if (coupon['discountType'] == 'percentage') {
        discountAmount = cartTotal * (coupon['discount'] / 100);
        if (coupon['maxDiscount'] != null && discountAmount > coupon['maxDiscount']) {
          discountAmount = coupon['maxDiscount'].toDouble();
        }
      } else {
        discountAmount = coupon['discount'].toDouble();
      }

      return {
        'valid': true,
        'couponId': couponDoc.id,
        'discountAmount': discountAmount.round(),
        'code': coupon['code'],
        'description': coupon['description'],
      };
    } catch (e) {
      debugPrint('Coupon validation error: $e');
      return {'valid': false, 'error': 'Failed to validate coupon'};
    }
  }

  // ============================================
  // STOCK UPDATE (Migrated from React Native)
  // ============================================
  Future<void> updateStockAfterOrder(List<dynamic> products, String operation) async {
    try {
      final batch = _firestore.batch();
      for (final product in products) {
        final productRef = _firestore.collection('products').doc(product['id']);
        final num qty = product['quantity'] ?? 1;
        
        final stockChange = operation == 'decrement' ? -qty : qty;
        final soldChange = operation == 'decrement' ? qty : -qty;

        batch.update(productRef, {
          'stock': FieldValue.increment(stockChange.toInt()),
          'soldCount': FieldValue.increment(soldChange.toInt()),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Stock update error: $e');
    }
  }

  // ============================================
  // WALLET TRANSACTION (Migrated from React Native)
  // ============================================
  Future<num> createWalletTransaction(
    String userId,
    String type, // 'credit' | 'debit'
    double amount,
    String title,
    String reason, [
    String? orderId,
  ]) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      return await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final num currentBalance = userDoc.exists ? (userDoc.data()?['walletBalance'] ?? 0) : 0;
        final num newBalance = type == 'credit' ? currentBalance + amount : currentBalance - amount;

        // Create transaction record
        final transRef = _firestore.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(transRef, {
          'type': type,
          'amount': amount,
          'title': title,
          'description': title,
          'reason': reason,
          'orderId': orderId ?? '',
          'balanceAfter': newBalance,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update balance
        transaction.update(userRef, {
          'walletBalance': newBalance,
        });

        return newBalance;
      });
    } catch (e) {
      debugPrint('Wallet transaction error: $e');
      rethrow;
    }
  }
}
