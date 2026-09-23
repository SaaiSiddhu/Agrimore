// lib/providers/order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../delivery/rider_steps.dart' as steps;

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

  /// Phase DLV-3C: a rider step (arrived_at_store, picked_up,
  /// out_for_delivery) goes through the advanceDeliveryStep callable, which
  /// checks it against the delivery state table, writes the status, its
  /// timestamp and the timeline, and records where the rider was. This app
  /// no longer writes an order status itself. Returns null on success, or a
  /// sentence to show the rider.
  Future<String?> advanceStep(String orderId, String status, Map<String, dynamic> fix) async {
    try {
      await steps.advanceDeliveryStep(orderId, status, fix);
      notifyListeners();
      return null;
    } on steps.RiderStepException catch (e) {
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }

  /// Phase DLV-3C: "Seller not ready" through releaseDeliveryOrder. The old
  /// direct write removed deliveryPartnerId, which the rules protect for the
  /// assigned rider, so every release failed. Before pickup only.
  Future<String?> releaseOrder(String orderId, {required String reason}) async {
    try {
      await steps.releaseDeliveryOrder(orderId, reason: reason);
      _activeOrder = null;
      notifyListeners();
      return null;
    } on steps.RiderStepException catch (e) {
      _error = e.message;
      notifyListeners();
      return e.message;
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
