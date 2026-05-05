// lib/providers/seller_order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class SellerOrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<OrderModel> _orders = [];
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
  int get pendingOrders => _orders
      .where((o) => o.orderStatus == 'pending' || o.orderStatus == 'confirmed')
      .length;
  int get processingOrders =>
      _orders.where((o) => o.orderStatus == 'processing').length;
  int get readyForPickupOrders =>
      _orders.where((o) => o.orderStatus == 'ready_for_pickup').length;
  int get shippedOrders => _orders
      .where(
        (o) =>
            o.orderStatus == 'shipped' ||
            o.orderStatus == 'ready_for_pickup' ||
            o.orderStatus == 'out_for_delivery' ||
            o.orderStatus == 'outfordelivery',
      )
      .length;
  int get deliveredOrders => _orders.where((o) => o.isDelivered).length;
  int get cancelledOrders => _orders.where((o) => o.isCancelled).length;

  double get totalRevenue => _orders
      .where((o) => o.isDelivered)
      .fold(0.0, (total, o) => total + o.total);

  double get todayRevenue {
    final today = DateTime.now();
    return _orders
        .where(
          (o) =>
              o.isDelivered &&
              o.createdAt.year == today.year &&
              o.createdAt.month == today.month &&
              o.createdAt.day == today.day,
        )
        .fold(0.0, (total, o) => total + o.total);
  }

  List<OrderModel> get _filteredOrders {
    if (_selectedFilter == 'all') return _orders;
    return _orders.where((o) {
      switch (_selectedFilter) {
        case 'pending':
          return o.orderStatus == 'pending' || o.orderStatus == 'confirmed';
        case 'processing':
          return o.orderStatus == 'processing';
        case 'ready_for_pickup':
          return o.orderStatus == 'ready_for_pickup';
        case 'shipped':
          return o.orderStatus == 'shipped' ||
              o.orderStatus == 'ready_for_pickup' ||
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

  /// Load only orders assigned to this seller. Checkout writes one order per
  /// seller, so this query matches Firestore security rules.
  Future<void> loadSellerOrders(String sellerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    debugPrint('ðŸ“¦ Loading orders for seller: $sellerId');

    try {
      _ordersSubscription?.cancel();
      _ordersSubscription = _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .snapshots()
          .listen(
        (snapshot) {
          _orders = snapshot.docs
              .map((doc) {
                try {
                  return OrderModel.fromMap(doc.data(), doc.id);
                } catch (e) {
                  debugPrint('âš ï¸ Error parsing order ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<OrderModel>()
              .toList();
          _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _isLoading = false;
          debugPrint('âœ… Loaded ${_orders.length} seller orders');
          notifyListeners();
        },
        onError: (e) {
          debugPrint('âŒ Error loading seller orders: $e');
          _error = 'Failed to load orders';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('âŒ Error loading seller orders: $e');
      _error = 'Failed to load seller orders';
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

      debugPrint('âœ… Order $orderId updated to: $newStatus');
      return true;
    } catch (e) {
      debugPrint('âŒ Error updating order: $e');
      _error = 'Failed to update order status';
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptOrder(String orderId) async {
    return _updateOrderStatus(
      orderId,
      'confirmed',
      extraFields: {
        'sellerDecision': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      },
      deductStock: true,
    );
  }

  Future<bool> rejectOrder(String orderId) async {
    return _updateOrderStatus(
      orderId,
      'cancelled',
      extraFields: {
        'sellerDecision': 'rejected',
        'cancelledBy': 'seller',
        'cancelledAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<bool> markPacking(String orderId) {
    return _updateOrderStatus(orderId, 'processing');
  }

  Future<bool> markReadyForPickup(String orderId) {
    return _updateOrderStatus(
      orderId,
      'ready_for_pickup',
      extraFields: {'readyForPickupAt': FieldValue.serverTimestamp()},
    );
  }

  Future<bool> _updateOrderStatus(
    String orderId,
    String newStatus, {
    Map<String, dynamic> extraFields = const {},
    bool deductStock = false,
  }) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);

      if (deductStock) {
        await _firestore.runTransaction((transaction) async {
          final orderSnap = await transaction.get(orderRef);
          if (!orderSnap.exists) {
            throw StateError('Order not found');
          }

          final orderData = orderSnap.data() ?? <String, dynamic>{};
          final paymentMethod =
              (orderData['paymentMethod'] ?? '').toString().toLowerCase();
          final paymentStatus =
              (orderData['paymentStatus'] ?? '').toString().toLowerCase();
          final isCod = paymentMethod == 'cod' ||
              paymentMethod == 'cash_on_delivery' ||
              paymentMethod.contains('cash');
          final isPaymentSuccess = paymentStatus == 'paid' ||
              paymentStatus == 'success' ||
              paymentStatus == 'completed';
          if (!isCod && !isPaymentSuccess) {
            throw StateError('Payment is not completed for this order');
          }
          final alreadyDeducted = orderData['inventoryDeducted'] == true;
          final items = (orderData['items'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();

          final productSnapshots = <DocumentReference, DocumentSnapshot>{};
          if (!alreadyDeducted) {
            for (final item in items) {
              final productId = item['productId']?.toString();
              if (productId == null || productId.isEmpty) continue;
              final productRef =
                  _firestore.collection('products').doc(productId);
              productSnapshots[productRef] = await transaction.get(productRef);
            }
          }

          for (final entry in productSnapshots.entries) {
            final data = entry.value.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final item = items.firstWhere(
              (i) => i['productId']?.toString() == entry.key.id,
              orElse: () => <String, dynamic>{},
            );
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
            final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
            final reducedStock = currentStock - quantity;
            final nextStock = reducedStock < 0 ? 0 : reducedStock;
            transaction.update(entry.key, {
              'stock': nextStock,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          transaction.update(orderRef, {
            'orderStatus': newStatus,
            'status': newStatus,
            'inventoryDeducted': alreadyDeducted || items.isNotEmpty,
            if (!alreadyDeducted && items.isNotEmpty)
              'inventoryDeductedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            ...extraFields,
          });
        });
      } else {
        await orderRef.update({
          'orderStatus': newStatus,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          ...extraFields,
        });
      }

      await orderRef.collection('timeline').add({
        'status': newStatus,
        'title': _getStatusTitle(newStatus),
        'description': _getStatusDescription(newStatus),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('Order $orderId updated to: $newStatus');
      return true;
    } catch (e) {
      debugPrint('Error updating order: $e');
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
        return 'Packing Order';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
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
        return 'Seller is packing your order';
      case 'ready_for_pickup':
        return 'Your order is packed and ready for pickup';
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
