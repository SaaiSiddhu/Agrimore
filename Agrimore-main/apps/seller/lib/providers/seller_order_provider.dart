// lib/providers/seller_order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class SellerOrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<OrderModel> _orders = [];
  Set<String> _sellerProductIds = {};
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all';
  StreamSubscription? _ordersSubscription;

  List<OrderModel> get orders => _filteredOrders;
  List<OrderModel> get allOrders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedFilter => _selectedFilter;

  // Order stats
  int get totalOrders => _orders.length;
  int get pendingOrders => _orders.where((o) =>
      o.orderStatus == 'pending' || o.orderStatus == 'confirmed').length;
  int get processingOrders =>
      _orders.where((o) => o.orderStatus == 'processing').length;
  int get shippedOrders => _orders.where((o) =>
      o.orderStatus == 'shipped' ||
      o.orderStatus == 'out_for_delivery' ||
      o.orderStatus == 'outfordelivery').length;
  int get deliveredOrders => _orders.where((o) => o.isDelivered).length;
  int get cancelledOrders => _orders.where((o) => o.isCancelled).length;

  double get totalRevenue => _orders
      .where((o) => o.isDelivered)
      .fold(0.0, (sum, o) => sum + o.total);

  double get todayRevenue {
    final today = DateTime.now();
    return _orders
        .where((o) =>
            o.isDelivered &&
            o.createdAt.year == today.year &&
            o.createdAt.month == today.month &&
            o.createdAt.day == today.day)
        .fold(0.0, (sum, o) => sum + o.total);
  }

  List<OrderModel> get _filteredOrders {
    if (_selectedFilter == 'all') return _orders;
    return _orders.where((o) {
      switch (_selectedFilter) {
        case 'pending':
          return o.orderStatus == 'pending' || o.orderStatus == 'confirmed';
        case 'processing':
          return o.orderStatus == 'processing';
        case 'shipped':
          return o.orderStatus == 'shipped' ||
              o.orderStatus == 'out_for_delivery' ||
              o.orderStatus == 'outfordelivery';
        case 'delivered':
          return o.isDelivered;
        case 'cancelled':
          return o.isCancelled;
        default:
          return true;
      }
    }).toList();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  /// Load orders containing products that belong to this seller.
  /// Step 1: Fetch all product IDs owned by this seller.
  /// Step 2: Stream all orders and filter those containing seller's products.
  Future<void> loadSellerOrders(String sellerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    debugPrint('📦 Loading orders for seller: $sellerId');

    try {
      // Step 1: Get all product IDs for this seller
      final productSnap = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      _sellerProductIds =
          productSnap.docs.map((d) => d.id).toSet();
      debugPrint('📦 Seller has ${_sellerProductIds.length} products');

      // Step 2: Stream orders and filter by product match
      _ordersSubscription?.cancel();
      _ordersSubscription = _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots()
          .listen((snapshot) {
        _orders = snapshot.docs
            .map((doc) {
              try {
                return OrderModel.fromMap(doc.data(), doc.id);
              } catch (e) {
                debugPrint('⚠️ Error parsing order ${doc.id}: $e');
                return null;
              }
            })
            .whereType<OrderModel>()
            .where((order) {
              // Match: order contains at least one of this seller's products
              return order.items.any((item) =>
                  _sellerProductIds.contains(item.productId));
            })
            .toList();

        _isLoading = false;
        debugPrint('✅ Loaded ${_orders.length} seller orders');
        notifyListeners();
      }, onError: (e) {
        debugPrint('❌ Error loading seller orders: $e');
        _error = 'Failed to load orders';
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('❌ Error loading seller products: $e');
      _error = 'Failed to load seller data';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': newStatus,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
        'status': newStatus,
        'title': _getStatusTitle(newStatus),
        'description': _getStatusDescription(newStatus),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Order $orderId updated to: $newStatus');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
      _error = 'Failed to update order status';
      notifyListeners();
      return false;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'confirmed':
        return 'Order Confirmed';
      case 'processing':
        return 'Processing Order';
      case 'shipped':
        return 'Order Shipped';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Order Delivered';
      case 'cancelled':
        return 'Order Cancelled';
      default:
        return status;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'confirmed':
        return 'Seller has confirmed your order';
      case 'processing':
        return 'Your order is being prepared';
      case 'shipped':
        return 'Your order has been shipped';
      case 'out_for_delivery':
        return 'Your order is out for delivery';
      case 'delivered':
        return 'Your order has been delivered';
      case 'cancelled':
        return 'Your order has been cancelled';
      default:
        return 'Order status updated';
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
