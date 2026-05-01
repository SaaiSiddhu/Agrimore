import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_services/agrimore_services.dart';

class OrderProvider with ChangeNotifier {
  // ============================================
  // SERVICES
  // ============================================
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // STATE VARIABLES
  // ============================================
  List<OrderModel> _orders = [];
  OrderModel? _selectedOrder = null;
  List<OrderTimelineModel> _selectedOrderTimeline = [];
  bool _isLoading = false;
  bool _isLoadingTimeline = false;
  String? _error;
  StreamSubscription? _ordersSubscription;

  // ============================================
  // GETTERS
  // ============================================
  List<OrderModel> get orders => _orders;
  OrderModel? get selectedOrder => _selectedOrder;
  List<OrderTimelineModel> get selectedOrderTimeline => _selectedOrderTimeline;
  bool get isLoading => _isLoading;
  bool get isLoadingTimeline => _isLoadingTimeline;
  String? get error => _error;
  int get orderCount => _orders.length;
  bool get hasOrders => _orders.isNotEmpty;

  // ============================================
  // LOAD USER ORDERS (REAL-TIME)
  // ============================================
  void loadOrders() {
    try {
      final userId = _authService.currentUserId ?? 
                     FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) {
        _error = '❌ User not authenticated';
        notifyListeners();
        return;
      }

      debugPrint('📦 Loading orders for user: $userId');

      // Cancel previous subscription
      _ordersSubscription?.cancel();

      // Real-time listener for user orders
      _ordersSubscription = _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen(
        (snapshot) {
          try {
            _orders = snapshot.docs
                .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
                .toList();
            _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            _error = null;
            debugPrint('✅ Loaded ${_orders.length} orders');
            notifyListeners();
          } catch (e) {
            debugPrint('❌ Error parsing orders: $e');
            _error = 'Failed to load orders';
            notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('❌ Error listening to orders: $error');
          _error = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('❌ Error in loadOrders: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================
  // CREATE ORDER
  // ============================================
  Future<String?> createOrder(OrderModel order) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📦 Creating order: ${order.orderNumber}');

      final orderId = await _databaseService.createOrder(order);

      if (orderId != null) {
        // Add to local list
        _orders.insert(0, order);
        debugPrint('✅ Order created: $orderId');
      }

      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ============================================
  // LOAD ORDER BY ID
  // ============================================
  Future<void> loadOrderById(String orderId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📦 Loading order: $orderId');

      final orderDoc = await _firestore
          .collection('orders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        _selectedOrder = OrderModel.fromMap(orderDoc.data()!, orderId);
        await _loadOrderTimeline(orderId);
        debugPrint('✅ Order loaded');
      } else {
        _error = '❌ Order not found';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading order: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD ORDER TIMELINE
  // ============================================
  Future<void> _loadOrderTimeline(String orderId) async {
    try {
      _isLoadingTimeline = true;
      notifyListeners();

      final timelineQuery = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .orderBy('timestamp', descending: true)
          .get();

      _selectedOrderTimeline = timelineQuery.docs
          .map((doc) => OrderTimelineModel.fromMap(doc.data()))
          .toList();

      debugPrint('✅ Loaded ${_selectedOrderTimeline.length} timeline events');

      _isLoadingTimeline = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading timeline: $e');
      _isLoadingTimeline = false;
      notifyListeners();
    }
  }

  // ============================================
  // GET ORDERS BY STATUS (Using orderStatus field)
  // ============================================
  List<OrderModel> getOrdersByStatus(String status) {
    return _orders
        .where((order) => order.orderStatus.toLowerCase() == status.toLowerCase())
        .toList();
  }

  // ============================================
  // GET PENDING ORDERS
  // ============================================
  List<OrderModel> get pendingOrders {
    return _orders
        .where((order) =>
            order.orderStatus == 'pending' ||
            order.orderStatus == 'confirmed' ||
            order.orderStatus == 'processing')
        .toList();
  }

  // ============================================
  // GET ACTIVE ORDERS
  // ============================================
  List<OrderModel> get activeOrders {
    return _orders
        .where((order) =>
            order.orderStatus != 'delivered' &&
            order.orderStatus != 'cancelled' &&
            order.orderStatus != 'refunded')
        .toList();
  }

  // ============================================
  // GET COMPLETED ORDERS
  // ============================================
  List<OrderModel> get completedOrders {
    return _orders
        .where((order) =>
            order.orderStatus == 'delivered' ||
            order.orderStatus == 'completed')
        .toList();
  }

  // ============================================
  // GET CANCELLED ORDERS
  // ============================================
  List<OrderModel> get cancelledOrders {
    return _orders
        .where((order) => order.orderStatus == 'cancelled')
        .toList();
  }

  // ============================================
  // GET REFUNDED ORDERS
  // ============================================
  List<OrderModel> get refundedOrders {
    return _orders.where((order) => order.orderStatus == 'refunded').toList();
  }

  // ============================================
  // CANCEL ORDER
  // ============================================
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('❌ Cancelling order: $orderId');

      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
      });

      // Add timeline event
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
        'status': 'cancelled',
        'title': 'Order Cancelled',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Reload order
      await loadOrderById(orderId);

      debugPrint('✅ Order cancelled');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling order: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // UPDATE ORDER STATUS (FOR ADMIN)
  // ============================================
  Future<bool> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? description,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📦 Updating order status: $orderId -> $newStatus');

      // Update main order document
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline event
      final timelineData = {
        'status': newStatus,
        'title': _getStatusTitle(newStatus),
        'description': description ?? _getStatusDescription(newStatus),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add(timelineData);

      // Reload order
      await loadOrderById(orderId);

      debugPrint('✅ Order status updated');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // GET STATUS TITLE
  // ============================================
  String _getStatusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'Order Pending';
      case 'confirmed':
        return 'Order Confirmed';
      case 'processing':
        return 'Processing Order';
      case 'shipped':
        return 'Order Shipped';
      case 'delivered':
        return 'Order Delivered';
      case 'cancelled':
        return 'Order Cancelled';
      case 'refunded':
        return 'Refund Processed';
      default:
        return 'Order Updated';
    }
  }

  // ============================================
  // GET STATUS DESCRIPTION
  // ============================================
  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Your order has been placed and is awaiting confirmation.';
      case 'confirmed':
        return 'Your order has been confirmed by the seller.';
      case 'processing':
        return 'Your order is being prepared for shipment.';
      case 'shipped':
        return 'Your order has been shipped and is on the way.';
      case 'delivered':
        return 'Your order has been delivered successfully.';
      case 'cancelled':
        return 'Your order has been cancelled.';
      case 'refunded':
        return 'Your refund has been processed.';
      default:
        return 'Your order status has been updated.';
    }
  }

  // ============================================
  // RETURN ORDER
  // ============================================
  Future<bool> returnOrder(String orderId, String reason) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔄 Initiating return for order: $orderId');

      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': 'returned',
        'updatedAt': FieldValue.serverTimestamp(),
        'returnReason': reason,
        'returnInitiatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline event
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
        'status': 'returned',
        'title': 'Return Initiated',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await loadOrderById(orderId);

      debugPrint('✅ Return initiated');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error initiating return: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // SEARCH ORDERS
  // ============================================
  List<OrderModel> searchOrders(String query) {
    final lowerQuery = query.toLowerCase();
    return _orders
        .where((order) =>
            order.orderNumber.toLowerCase().contains(lowerQuery) ||
            order.id.toLowerCase().contains(lowerQuery) ||
            order.deliveryAddress.fullAddress
                .toLowerCase()
                .contains(lowerQuery))
        .toList();
  }

  // ============================================
  // GET ORDER STATISTICS
  // ============================================
  Map<String, int> getOrderStatistics() {
    return {
      'total': _orders.length,
      'pending': pendingOrders.length,
      'active': activeOrders.length,
      'completed': completedOrders.length,
      'cancelled': cancelledOrders.length,
      'refunded': refundedOrders.length,
    };
  }

  // ============================================
  // GET TOTAL REVENUE
  // ============================================
  double getTotalRevenue() {
    return completedOrders.fold(0.0, (sum, order) => sum + order.total);
  }

  // ============================================
  // CLEAR SELECTED ORDER
  // ============================================
  void clearSelectedOrder() {
    _selectedOrder = null;
    _selectedOrderTimeline.clear();
    notifyListeners();
  }

  // ============================================
  // CLEAR ERROR
  // ============================================
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _orders.clear();
    _selectedOrder = null;
    _selectedOrderTimeline.clear();
    super.dispose();
  }
}
