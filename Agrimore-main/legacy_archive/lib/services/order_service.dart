// lib/services/order_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // CREATE ORDER WITH INITIAL TIMELINE
  // ============================================
  Future<String?> createOrder(OrderModel order) async {
    try {
      debugPrint('📦 Creating order: ${order.orderNumber}');

      // 1️⃣ Create order document
      final orderId = _firestore.collection('orders').doc().id;
      await _firestore.collection('orders').doc(orderId).set(order.toMap());

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
}
