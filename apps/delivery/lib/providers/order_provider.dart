// lib/providers/order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

// Phase DLV-2B: the platform-wide "available orders" list, the client-side
// deny and the client-side accept transaction are gone. Riders see only
// offers sent to them (providers/offer_provider.dart) and accept/decline
// through the acceptDeliveryOffer / declineDeliveryOffer callables.
class DeliveryOrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<OrderModel> _myOrders = [];
  OrderModel? _activeOrder;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _activeOrderSubscription;
  StreamSubscription? _myOrdersSubscription;

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
    _activeOrderSubscription?.cancel();
    _myOrdersSubscription?.cancel();
    super.dispose();
  }
}
