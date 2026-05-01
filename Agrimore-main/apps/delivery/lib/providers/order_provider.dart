// lib/providers/order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class DeliveryOrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<OrderModel> _availableOrders = [];
  final Set<String> _deniedOrderIds = {}; // Track denied orders locally
  OrderModel? _activeOrder;
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _activeOrderSubscription;
  
  VoidCallback? onNewOrder;
  
  // Getters - filter out denied orders
  List<OrderModel> get availableOrders => 
      _availableOrders.where((o) => !_deniedOrderIds.contains(o.id)).toList();
  OrderModel? get activeOrder => _activeOrder;
  bool get isLoading => _isLoading;
  bool get hasActiveOrder => _activeOrder != null;
  String? get error => _error;
  
  // Load available orders (ready for pickup)
  void loadAvailableOrders() {
    _isLoading = true;
    notifyListeners();
    
    debugPrint('📦 Loading available orders for delivery...');
    
    _ordersSubscription?.cancel();
    _ordersSubscription = _firestore
        .collection('orders')
        .where('orderStatus', whereIn: ['ready_for_pickup', 'processing', 'confirmed'])
        .snapshots()
        .listen((snapshot) {
      debugPrint('📦 Received ${snapshot.docs.length} orders');
      
      // ✅ Check for new orders
      bool hasNewOrder = false;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added && !_isLoading) {
          hasNewOrder = true;
        }
      }
      
      if (hasNewOrder && onNewOrder != null) {
        onNewOrder!();
      }
      
      _availableOrders = snapshot.docs
          .map((doc) {
            final order = OrderModel.fromMap(doc.data(), doc.id);
            // Debug log for each order's address coordinates
            debugPrint('   Order ${order.orderNumber}: lat=${order.deliveryAddress.latitude}, lng=${order.deliveryAddress.longitude}');
            return order;
          })
          .toList();
      // Sort in memory to avoid composite index
      _availableOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
      debugPrint('📦 ${availableOrders.length} orders ready (${_deniedOrderIds.length} denied)');
      notifyListeners();
    }, onError: (e) {
      debugPrint('❌ Error loading orders: $e');
      _error = 'Failed to load orders';
      _isLoading = false;
      notifyListeners();
    });
  }
  
  // Deny an order (hide from list locally)
  void denyOrder(String orderId) {
    debugPrint('🚫 Denying order: $orderId');
    _deniedOrderIds.add(orderId);
    notifyListeners();
  }
  
  // Clear denied orders (e.g., on refresh)
  void clearDeniedOrders() {
    _deniedOrderIds.clear();
    notifyListeners();
  }
  
  // Accept an order
  Future<bool> acceptOrder(String orderId, String partnerId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'deliveryPartnerId': partnerId,
        'orderStatus': 'picked_up',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Add timeline event
      await _firestore.collection('orders').doc(orderId).collection('timeline').add({
        'status': 'picked_up',
        'title': 'Order picked up',
        'description': 'Delivery partner has picked up your order',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      _error = 'Failed to accept order';
      notifyListeners();
      return false;
    }
  }
  
  // Update order status
  Future<bool> updateOrderStatus(String orderId, String status, String description) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('orders').doc(orderId).collection('timeline').add({
        'status': status,
        'title': _getStatusTitle(status),
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (status == 'delivered') {
        _activeOrder = null;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update status';
      notifyListeners();
      return false;
    }
  }
  
  String _getStatusTitle(String status) {
    switch (status) {
      case 'picked_up': return 'Order Accepted';
      case 'reached_pickup': return 'Reached Pickup Location';
      case 'parcel_picked': return 'Parcel Picked Up';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': return 'Delivered';
      default: return status;
    }
  }
  
  // Watch active order
  void watchActiveOrder(String partnerId) {
    _activeOrderSubscription?.cancel();
    _activeOrderSubscription = _firestore
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: partnerId)
        .snapshots()
        .listen((snapshot) {
      final activeDocs = snapshot.docs.where((doc) {
        final status = doc.data()['orderStatus']?.toString();
        return ['picked_up', 'reached_pickup', 'parcel_picked', 'out_for_delivery'].contains(status);
      }).toList();
      if (activeDocs.isNotEmpty) {
        _activeOrder = OrderModel.fromMap(
          activeDocs.first.data(),
          activeDocs.first.id,
        );
      } else {
        _activeOrder = null;
      }
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _activeOrderSubscription?.cancel();
    super.dispose();
  }
}
