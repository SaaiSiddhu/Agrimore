// lib/providers/seller_order_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Why a seller order action failed (mapped to localised copy by screens).
enum OrderActionError { generic, alreadyMoved, unpaid }

class SellerOrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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

  /// This calendar week (Monday through today), delivered orders only.
  double get weekRevenue {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _orders
        .where((o) => o.isDelivered && !o.createdAt.isBefore(startOfWeek))
        .fold(0.0, (total, o) => total + o.total);
  }

  /// This calendar month, delivered orders only.
  double get monthRevenue {
    final today = DateTime.now();
    return _orders
        .where(
          (o) =>
              o.isDelivered &&
              o.createdAt.year == today.year &&
              o.createdAt.month == today.month,
        )
        .fold(0.0, (total, o) => total + o.total);
  }

  /// Orders accepted but not yet delivered or cancelled.
  int get activeOrderCount => totalOrders - deliveredOrders - cancelledOrders;

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

  // ── Order actions (SELLER-ORDERS-1, ADR-S13) ──────────────────────────────
  // Every status change goes through the `sellerTransitionOrder` callable.
  // The seller app no longer writes orderStatus, the timeline or stock itself:
  // the server enforces the state machine, restores stock on cancellation
  // (createOrder already took it at placement — the old client-side deduction
  // on accept took it a second time) and the onOrderStatusChanged trigger
  // notifies the buyer.

  /// Why the last action failed, for localised copy in the screen.
  OrderActionError? _lastActionError;
  OrderActionError? get lastActionError => _lastActionError;

  Future<bool> acceptOrder(String orderId) => _transition(orderId, 'accept');

  Future<bool> rejectOrder(String orderId, {required String reason, String note = ''}) =>
      _transition(orderId, 'reject', reason: reason, note: note);

  Future<bool> cancelOrder(String orderId, {required String reason, String note = ''}) =>
      _transition(orderId, 'cancel', reason: reason, note: note);

  Future<bool> markPacking(String orderId) => _transition(orderId, 'pack');

  Future<bool> markReadyForPickup(String orderId) => _transition(orderId, 'ready');

  Future<bool> _transition(String orderId, String action, {String? reason, String note = ''}) async {
    _lastActionError = null;
    try {
      await _functions.httpsCallable('sellerTransitionOrder').call<dynamic>({
        'orderId': orderId,
        'action': action,
        if (reason != null) 'reason': reason,
        if (note.isNotEmpty) 'note': note,
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Order $action failed: ${e.code} ${e.message}');
      _lastActionError = e.code == 'failed-precondition'
          ? ((e.message ?? '').toLowerCase().contains('payment')
              ? OrderActionError.unpaid
              : OrderActionError.alreadyMoved)
          : OrderActionError.generic;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Order $action failed: $e');
      _lastActionError = OrderActionError.generic;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
