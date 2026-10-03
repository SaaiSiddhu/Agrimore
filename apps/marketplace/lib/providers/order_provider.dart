import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_services/agrimore_services.dart';

class OrderProvider with ChangeNotifier {
  // ============================================
  // SERVICES
  // ============================================
  OrderProvider({
    String? Function()? currentUserId,
    Stream<String?> Function()? authChanges,
    Stream<List<OrderModel>> Function(String)? snapshots,
    Future<OrderModel?> Function(String)? readOrder,
    Future<List<OrderTimelineModel>> Function(String)? readTimeline,
    Future<void> Function(String, Map<String, dynamic>)? update,
    Future<void> Function(String, Map<String, dynamic>)? addTimeline,
  })  : _currentUserId = currentUserId ?? (() => AuthService().currentUserId),
        _authChanges = authChanges ??
            (() => AuthService().authStateChanges.map((u) => u?.uid)),
        _snapshots = snapshots,
        _readOrder = readOrder,
        _readTimeline = readTimeline,
        _update = update,
        _addTimeline = addTimeline;
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? Function() _currentUserId;
  final Stream<String?> Function() _authChanges;
  final Stream<List<OrderModel>> Function(String)? _snapshots;
  final Future<OrderModel?> Function(String)? _readOrder;
  final Future<List<OrderTimelineModel>> Function(String)? _readTimeline;
  final Future<void> Function(String, Map<String, dynamic>)? _update,
      _addTimeline;
  Stream<List<OrderModel>> _stream(String uid) =>
      _snapshots?.call(uid) ??
      _firestore
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList());
  Future<OrderModel?> _order(String id) async {
    if (_readOrder != null) return _readOrder(id);
    final d = await _firestore.collection('orders').doc(id).get();
    return d.exists ? OrderModel.fromMap(d.data()!, d.id) : null;
  }

  Future<List<OrderTimelineModel>> _timeline(String id) async {
    if (_readTimeline != null) return _readTimeline(id);
    final s = await _firestore
        .collection('orders')
        .doc(id)
        .collection('timeline')
        .orderBy('timestamp', descending: true)
        .get();
    return s.docs.map((d) => OrderTimelineModel.fromMap(d.data())).toList();
  }

  Future<void> _writeOrder(String id, Map<String, dynamic> data) =>
      _update?.call(id, data) ??
      _firestore.collection('orders').doc(id).update(data);
  Future<void> _writeTimeline(String id, Map<String, dynamic> data) async {
    if (_addTimeline != null) return _addTimeline(id, data);
    await _firestore
        .collection('orders')
        .doc(id)
        .collection('timeline')
        .add(data);
  }

  List<OrderModel> _orders = [];
  OrderModel? _selectedOrder;
  List<OrderTimelineModel> _selectedOrderTimeline = [];
  String? _ownerId, _error;
  int _sessionGeneration = 0,
      _listGeneration = 0,
      _detailGeneration = 0,
      _commands = 0;
  bool _disposed = false,
      _listStarted = false,
      _loadingDetail = false,
      _loadingTimeline = false;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  StreamSubscription<String?>? _authSubscription;
  bool get _hasOwner =>
      !_disposed && _ownerId != null && _ownerId == _currentUserId();
  bool _owns(String uid, int generation) =>
      _hasOwner && _ownerId == uid && generation == _sessionGeneration;
  bool _valid(OrderModel value, String uid, [String? id]) =>
      value.userId == uid &&
      value.id.isNotEmpty &&
      (id == null || value.id == id);
  List<OrderModel> get orders =>
      List.unmodifiable(_hasOwner ? _orders : <OrderModel>[]);
  OrderModel? get selectedOrder => _hasOwner ? _selectedOrder : null;
  List<OrderTimelineModel> get selectedOrderTimeline => List.unmodifiable(
      _hasOwner ? _selectedOrderTimeline : <OrderTimelineModel>[]);
  bool get isLoading => _hasOwner && (_loadingDetail || _commands > 0);
  bool get isLoadingTimeline => _hasOwner && _loadingTimeline;
  String? get error => _hasOwner ? _error : null;
  int get orderCount => orders.length;
  bool get hasOrders => orders.isNotEmpty;

  bool _syncOwner() {
    final uid = _currentUserId();
    if (_ownerId == uid) return false;
    _ownerId = uid;
    ++_sessionGeneration;
    ++_listGeneration;
    ++_detailGeneration;
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _orders = [];
    _selectedOrder = null;
    _selectedOrderTimeline = [];
    _error = null;
    _commands = 0;
    _loadingDetail = false;
    _loadingTimeline = false;
    return true;
  }

  bool _bindSession() {
    if (_disposed) return false;
    _authSubscription ??= _authChanges().listen((uid) {
      if (_disposed || uid != _currentUserId() || uid == _ownerId) return;
      _syncOwner();
      notifyListeners();
      if (_listStarted && uid != null) loadOrders();
    });
    return _syncOwner();
  }

  void _begin() {
    final changed = _bindSession();
    if (changed && _listStarted && _ownerId != null) loadOrders();
  }

  void loadOrders() {
    if (_disposed) return;
    _listStarted = true;
    _bindSession();
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    final listGeneration = ++_listGeneration;
    final uid = _ownerId, generation = _sessionGeneration;
    _error = null;
    if (uid == null) {
      notifyListeners();
      return;
    }
    bool ownsList() =>
        _owns(uid, generation) && listGeneration == _listGeneration;
    try {
      _ordersSubscription = _stream(uid).listen((rows) {
        if (!ownsList()) return;
        if (rows.any((r) => !_valid(r, uid))) {
          _orders = [];
          _error = 'Could not load your orders.';
        } else {
          _orders = List.of(rows)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _error = null;
        }
        notifyListeners();
      }, onError: (Object _) {
        if (!ownsList()) return;
        _error = 'Could not load your orders. Please try again.';
        notifyListeners();
      });
    } catch (_) {
      if (ownsList()) {
        _error = 'Could not load your orders. Please try again.';
        notifyListeners();
      }
    }
  }

  // Order creation remains server-only; this provider cannot create orders.
  Future<void> loadOrderById(String orderId) async {
    if (_disposed) return;
    _begin();
    final uid = _ownerId, generation = _sessionGeneration;
    final detailGeneration = ++_detailGeneration;
    _selectedOrder = null;
    _selectedOrderTimeline = [];
    _loadingDetail = uid != null;
    _loadingTimeline = false;
    _error = null;
    notifyListeners();
    if (uid == null) return;
    bool ownsDetail() =>
        _owns(uid, generation) && detailGeneration == _detailGeneration;
    try {
      final value = await _order(orderId);
      if (!ownsDetail()) return;
      if (value == null) {
        _error = 'Order not found.';
        return;
      }
      if (!_valid(value, uid, orderId)) {
        throw StateError('Order owner mismatch.');
      }
      _selectedOrder = value;
      _loadingTimeline = true;
      notifyListeners();
      try {
        final timeline = await _timeline(orderId);
        if (!ownsDetail()) return;
        _selectedOrderTimeline = List.of(timeline);
      } catch (_) {
        if (ownsDetail()) {
          _error = 'Could not load the order timeline. Please try again.';
        }
      } finally {
        if (ownsDetail()) _loadingTimeline = false;
      }
    } catch (_) {
      if (ownsDetail()) {
        _selectedOrder = null;
        _selectedOrderTimeline = [];
        _error = 'Could not load your order. Please try again.';
      }
    } finally {
      if (ownsDetail()) {
        _loadingDetail = false;
        notifyListeners();
      }
    }
  }

  void _requireSession(String uid, int generation) {
    if (!_owns(uid, generation)) throw StateError('Order session changed.');
  }

  Future<bool> _command(String orderId, Map<String, dynamic> update,
      Map<String, dynamic> timeline) async {
    if (_disposed) return false;
    _begin();
    final uid = _ownerId,
        generation = _sessionGeneration,
        detailAtStart = _detailGeneration;
    if (uid == null) return false;
    ++_commands;
    _error = null;
    notifyListeners();
    try {
      final value = await _order(orderId);
      _requireSession(uid, generation);
      if (value == null || !_valid(value, uid, orderId)) {
        throw StateError('Order owner mismatch.');
      }
      await _writeOrder(orderId, update);
      _requireSession(uid, generation);
      await _writeTimeline(orderId, timeline);
      _requireSession(uid, generation);
      // A completed old action cannot steal a newer selected-detail request.
      if (detailAtStart == _detailGeneration) await loadOrderById(orderId);
      _requireSession(uid, generation);
      return true;
    } catch (_) {
      if (_owns(uid, generation)) {
        _error = 'Could not update your order. Please try again.';
      }
      return false;
    } finally {
      if (_owns(uid, generation)) {
        --_commands;
        notifyListeners();
      }
    }
  }

  Future<bool> cancelOrder(String orderId, String reason) => _command(orderId, {
        'orderStatus': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
      }, {
        'status': 'cancelled',
        'title': 'Order Cancelled',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
  // Legacy wrapper retained for API compatibility; no marketplace UI callers.
  Future<bool> updateOrderStatus(String orderId, String newStatus,
          {String? description}) =>
      _command(orderId, {
        'orderStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, {
        'status': newStatus,
        'title': _getStatusTitle(newStatus),
        'description': description ?? _getStatusDescription(newStatus),
        'timestamp': FieldValue.serverTimestamp(),
      });
  // Legacy wrapper retained; server/rules authorization remains authoritative.
  Future<bool> returnOrder(String orderId, String reason) => _command(orderId, {
        'orderStatus': 'returned',
        'updatedAt': FieldValue.serverTimestamp(),
        'returnReason': reason,
        'returnInitiatedAt': FieldValue.serverTimestamp(),
      }, {
        'status': 'returned',
        'title': 'Return Initiated',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
  List<OrderModel> getOrdersByStatus(String status) => orders
      .where((o) => o.orderStatus.toLowerCase() == status.toLowerCase())
      .toList();
  List<OrderModel> get pendingOrders => orders
      .where(
          (o) => ['pending', 'confirmed', 'processing'].contains(o.orderStatus))
      .toList();
  List<OrderModel> get activeOrders => orders
      .where((o) =>
          !['delivered', 'cancelled', 'refunded'].contains(o.orderStatus))
      .toList();
  List<OrderModel> get completedOrders => orders
      .where((o) => ['delivered', 'completed'].contains(o.orderStatus))
      .toList();
  List<OrderModel> get cancelledOrders =>
      orders.where((o) => o.orderStatus == 'cancelled').toList();
  List<OrderModel> get refundedOrders =>
      orders.where((o) => o.orderStatus == 'refunded').toList();
  List<OrderModel> searchOrders(String query) {
    final value = query.toLowerCase();
    return orders
        .where((o) =>
            o.orderNumber.toLowerCase().contains(value) ||
            o.id.toLowerCase().contains(value) ||
            o.deliveryAddress.fullAddress.toLowerCase().contains(value))
        .toList();
  }

  Map<String, int> getOrderStatistics() => {
        'total': orderCount,
        'pending': pendingOrders.length,
        'active': activeOrders.length,
        'completed': completedOrders.length,
        'cancelled': cancelledOrders.length,
        'refunded': refundedOrders.length
      };
  double getTotalRevenue() =>
      completedOrders.fold(0.0, (total, o) => total + o.total);
  void clearSelectedOrder() {
    if (_disposed) return;
    _begin();
    ++_detailGeneration;
    _selectedOrder = null;
    _selectedOrderTimeline = [];
    _loadingDetail = false;
    _loadingTimeline = false;
    notifyListeners();
  }

  void clearError() {
    if (!_disposed) {
      _begin();
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_sessionGeneration;
    ++_listGeneration;
    ++_detailGeneration;
    _ordersSubscription?.cancel();
    _authSubscription?.cancel();
    _orders = [];
    _selectedOrder = null;
    _selectedOrderTimeline = [];
    super.dispose();
  }

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
}
