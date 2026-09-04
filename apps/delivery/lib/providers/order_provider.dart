// lib/providers/order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class DeliveryOrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<OrderModel> _availableOrders = [];
  List<OrderModel> _myOrders = [];
  final Set<String> _deniedOrderIds = {};
  OrderModel? _activeOrder;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _ordersSubscription;
  StreamSubscription? _activeOrderSubscription;
  StreamSubscription? _myOrdersSubscription;

  VoidCallback? onNewOrder;

  List<OrderModel> get availableOrders => _availableOrders
      .where(
        (o) =>
            !_deniedOrderIds.contains(o.id) &&
            (o.deliveryPartnerId == null || o.deliveryPartnerId!.isEmpty),
      )
      .toList();
  List<OrderModel> get myOrders => _myOrders;
  OrderModel? get activeOrder => _activeOrder;
  bool get isLoading => _isLoading;
  bool get hasActiveOrder => _activeOrder != null;
  String? get error => _error;

  int get todayDeliveries {
    final now = DateTime.now();
    return _myOrders.where((o) {
      final date = o.updatedAt ?? o.createdAt;
      return o.isDelivered &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
  }

  double get todayEarnings {
    final now = DateTime.now();
    return _myOrders.where((o) {
      final date = o.updatedAt ?? o.createdAt;
      return o.isDelivered &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).fold(0.0, (total, o) => total + _deliveryEarningFor(o));
  }

  double get weeklyEarnings {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _myOrders
        .where(
          (o) => o.isDelivered && (o.updatedAt ?? o.createdAt).isAfter(cutoff),
        )
        .fold(0.0, (total, o) => total + _deliveryEarningFor(o));
  }

  double get codCollected => _myOrders
      .where(
        (o) => o.isDelivered && o.paymentMethod.toLowerCase().contains('cod'),
      )
      .fold(0.0, (total, o) => total + o.total);

  void loadAvailableOrders() {
    _isLoading = true;
    notifyListeners();

    debugPrint('Loading available orders for delivery...');

    _ordersSubscription?.cancel();
    _ordersSubscription = _firestore
        .collection('orders')
        .where('orderStatus', whereIn: ['ready_for_pickup'])
        .snapshots()
        .listen(
          (snapshot) {
            var hasNewOrder = false;
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added && !_isLoading) {
                hasNewOrder = true;
              }
            }

            if (hasNewOrder && onNewOrder != null) {
              onNewOrder!();
            }

            _availableOrders = snapshot.docs
                .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error loading orders: $e');
            _error = 'Failed to load orders';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> denyOrder(String orderId, {String? partnerId}) async {
    _deniedOrderIds.add(orderId);
    if (partnerId != null && partnerId.isNotEmpty) {
      await _firestore.collection('orders').doc(orderId).set({
        'deliveryRejectedBy': FieldValue.arrayUnion([partnerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    notifyListeners();
  }

  void clearDeniedOrders() {
    _deniedOrderIds.clear();
    notifyListeners();
  }

  Future<bool> acceptOrder(String orderId, String partnerId) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(orderRef);
        if (!snap.exists) {
          throw StateError('Order not found');
        }
        final data = snap.data() ?? <String, dynamic>{};
        final assignedTo = data['deliveryPartnerId']?.toString() ?? '';
        final orderStatus = data['orderStatus']?.toString() ?? '';
        if (orderStatus != 'ready_for_pickup') {
          throw StateError('Order is not available for pickup');
        }
        if (assignedTo.isNotEmpty && assignedTo != partnerId) {
          throw StateError('Order already assigned');
        }
        transaction.update(orderRef, {
          'deliveryPartnerId': partnerId,
          'orderStatus': 'delivery_accepted',
          'status': 'delivery_accepted',
          'deliveryAcceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await orderRef.collection('timeline').add({
        'status': 'delivery_accepted',
        'title': 'Delivery Accepted',
        'description': 'Delivery partner accepted this assignment',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error accepting order: $e');
      _error = 'Failed to accept order';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOrderStatus(
    String orderId,
    String status,
    String description,
  ) async {
    try {
      final update = <String, dynamic>{
        'orderStatus': status,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._statusTimestamp(status),
      };
      if (status == 'delivered') {
        update['deliveredAt'] = FieldValue.serverTimestamp();
        update['codSettlementStatus'] = 'pending';
      }

      await _firestore.collection('orders').doc(orderId).update(update);

      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('timeline')
          .add({
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
      debugPrint('Error updating delivery status: $e');
      _error = 'Failed to update status';
      notifyListeners();
      return false;
    }
  }

  Future<bool> releaseOrder(
    String orderId,
    String partnerId, {
    required String reason,
  }) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      await orderRef.update({
        'deliveryPartnerId': FieldValue.delete(),
        'orderStatus': 'ready_for_pickup',
        'status': 'ready_for_pickup',
        'deliveryIssue': reason,
        'deliveryIssueAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await orderRef.collection('timeline').add({
        'status': 'delivery_released',
        'title': 'Delivery Released',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'partnerId': partnerId,
      });

      _activeOrder = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error releasing delivery order: $e');
      _error = 'Failed to release order';
      notifyListeners();
      return false;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'delivery_accepted':
        return 'Delivery Accepted';
      case 'arrived_at_store':
        return 'Arrived at Store';
      case 'picked_up':
        return 'Picked Up';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  Map<String, dynamic> _statusTimestamp(String status) {
    switch (status) {
      case 'arrived_at_store':
        return {'arrivedAtStoreAt': FieldValue.serverTimestamp()};
      case 'picked_up':
        return {'pickedUpAt': FieldValue.serverTimestamp()};
      case 'out_for_delivery':
        return {'outForDeliveryAt': FieldValue.serverTimestamp()};
      default:
        return {};
    }
  }

  void watchActiveOrder(String partnerId) {
    _activeOrderSubscription?.cancel();
    _activeOrderSubscription = _firestore
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: partnerId)
        .snapshots()
        .listen((snapshot) {
      final activeDocs = snapshot.docs.where((doc) {
        final status = doc.data()['orderStatus']?.toString();
        return [
          'delivery_accepted',
          'arrived_at_store',
          'picked_up',
          'out_for_delivery',
          'outfordelivery',
        ].contains(status);
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

  void watchMyDeliveries(String partnerId) {
    _myOrdersSubscription?.cancel();
    _myOrdersSubscription = _firestore
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: partnerId)
        .snapshots()
        .listen((snapshot) {
      _myOrders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    });
  }

  double _deliveryEarningFor(OrderModel order) {
    if (order.deliveryCharge > 0) return order.deliveryCharge;
    return 15;
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _activeOrderSubscription?.cancel();
    _myOrdersSubscription?.cancel();
    super.dispose();
  }
}
