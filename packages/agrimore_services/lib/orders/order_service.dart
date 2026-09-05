// lib/services/order_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FIX-15 (finding N-32): CREATE ORDER WITH INITIAL TIMELINE removed —
  // orders/{orderId} has had `allow create: if false` for as long as this
  // codebase has had a server-side createOrder Cloud Function (only the
  // Admin SDK, which bypasses rules, may create an order); this method's
  // direct client write could never have succeeded. Confirmed zero callers
  // of OrderService() anywhere in any app before removing.

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
        'status': newStatus,
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

  // FIX-15 (finding N-43): COUPON VALIDATION (migrated from React Native)
  // removed. Reads a coupon field schema (`expiry`, `usedCount`,
  // `usageLimit`, `minOrder`, `discountType`, `maxDiscount`) that no
  // longer matches the live schema this codebase's server-side coupon
  // logic actually uses. Confirmed zero callers anywhere before removing —
  // apps/*'s own CouponProvider.validateCoupon(double) is an unrelated
  // method with a different signature on a different class.

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
