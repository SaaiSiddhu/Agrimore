import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

// ADMR-24: typed result for updateOrderStatus, replacing a bare bool that
// every call site (order_status_updater.dart, order_management_screen.dart's
// bulk action) was ignoring outright — a real failure was shown as success.
// See functions/src/admin/adminOrderActions.ts's own Outcome union, which
// this mirrors.
enum OrderStatusUpdateOutcome {
  applied,
  alreadyApplied,
  staleState,
  notFound,
  validationFailed,
  permissionDenied,
  networkError,
}

class OrderStatusUpdateResult {
  final OrderStatusUpdateOutcome outcome;
  final String? message;
  const OrderStatusUpdateResult(this.outcome, {this.message});

  bool get isSuccess =>
      outcome == OrderStatusUpdateOutcome.applied ||
      outcome == OrderStatusUpdateOutcome.alreadyApplied;
}

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
  // ADMR-28: dispatch/assignment history for the selected order — its own
  // loading/error state, mirroring the timeline's exact pattern, since a
  // real Firestore query can fail independently of the order document
  // itself having already loaded successfully.
  List<DispatchOfferRecord> _selectedOrderDispatchOffers = [];
  bool _isLoadingDispatchOffers = false;
  String? _dispatchOffersError;
  // ADMR-29: rider earnings, associate commission exceptions and
  // order-linked support tickets for the selected order — each its own
  // independent loading/error state, same reasoning as dispatch offers.
  RiderEarningRecord? _selectedOrderRiderEarning;
  bool _isLoadingRiderEarning = false;
  String? _riderEarningError;
  List<CommissionExceptionRecord> _selectedOrderCommissionExceptions = [];
  bool _isLoadingCommissionExceptions = false;
  String? _commissionExceptionsError;
  List<RiderSupportTicketRecord> _selectedOrderSupportTickets = [];
  bool _isLoadingSupportTickets = false;
  String? _supportTicketsError;
  // ADMR-30: seller settlement rows for the selected order — its own
  // independent loading/error state, same reasoning as dispatch offers.
  List<SellerPayoutRecord> _selectedOrderSellerPayouts = [];
  bool _isLoadingSellerPayouts = false;
  String? _sellerPayoutsError;
  // ADMR-36: the assigned rider's own current, aggregate cash liability
  // (independent of this order alone) — its own loading/error state, same
  // reasoning as the other per-order-detail loaders.
  RiderCashAccountRecord? _selectedOrderRiderCashAccount;
  bool _isLoadingRiderCashAccount = false;
  String? _riderCashAccountError;
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
  List<DispatchOfferRecord> get selectedOrderDispatchOffers => _selectedOrderDispatchOffers;
  bool get isLoadingDispatchOffers => _isLoadingDispatchOffers;
  String? get dispatchOffersError => _dispatchOffersError;
  RiderEarningRecord? get selectedOrderRiderEarning => _selectedOrderRiderEarning;
  bool get isLoadingRiderEarning => _isLoadingRiderEarning;
  String? get riderEarningError => _riderEarningError;
  List<CommissionExceptionRecord> get selectedOrderCommissionExceptions => _selectedOrderCommissionExceptions;
  bool get isLoadingCommissionExceptions => _isLoadingCommissionExceptions;
  String? get commissionExceptionsError => _commissionExceptionsError;
  List<RiderSupportTicketRecord> get selectedOrderSupportTickets => _selectedOrderSupportTickets;
  bool get isLoadingSupportTickets => _isLoadingSupportTickets;
  String? get supportTicketsError => _supportTicketsError;
  List<SellerPayoutRecord> get selectedOrderSellerPayouts => _selectedOrderSellerPayouts;
  bool get isLoadingSellerPayouts => _isLoadingSellerPayouts;
  String? get sellerPayoutsError => _sellerPayoutsError;
  RiderCashAccountRecord? get selectedOrderRiderCashAccount => _selectedOrderRiderCashAccount;
  bool get isLoadingRiderCashAccount => _isLoadingRiderCashAccount;
  String? get riderCashAccountError => _riderCashAccountError;
  bool get isLoading => _isLoading;
  bool get isLoadingTimeline => _isLoadingTimeline;
  String? get error => _error;
  int get orderCount => _orders.length;
  bool get hasOrders => _orders.isNotEmpty;

  // ============================================
  // LOAD ALL ORDERS (FOR ADMIN - NO USER FILTER)
  // ============================================
  void loadOrders() {
    try {
      debugPrint('📦 Loading ALL orders for admin...');

      // Cancel previous subscription
      _ordersSubscription?.cancel();

      // Real-time listener for ALL orders (no userId filter for admin)
      _ordersSubscription = _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          try {
            _orders = snapshot.docs
                .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
                .toList();
            
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

  // FIX-15 (finding N-32): CREATE ORDER removed — wrapped
  // DatabaseService.createOrder(), itself removed as dead (orders/{orderId}
  // has had allow create: if false for as long as this codebase has had a
  // server-side createOrder Cloud Function). Confirmed zero UI callers of
  // this wrapper anywhere in apps/admin before removing.

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
        await _loadDispatchOffers(orderId);
        await _loadRiderEarning(orderId);
        await _loadCommissionExceptions(orderId);
        await _loadRelatedSupportTickets(orderId);
        await _loadSellerPayouts(orderId);
        await _loadRiderCashAccount(_selectedOrder?.deliveryPartnerId);
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
  // LOAD DISPATCH/ASSIGNMENT HISTORY (ADMR-28)
  // ============================================
  // delivery_requests/{orderId}_{riderId} — one real, already-written
  // document per rider ever offered this order (functions/src/delivery/
  // dispatch.ts's sendOffers). Read-only: nothing here writes back.
  Future<void> _loadDispatchOffers(String orderId) async {
    try {
      _isLoadingDispatchOffers = true;
      _dispatchOffersError = null;
      notifyListeners();

      final query = await _firestore
          .collection('delivery_requests')
          .where('orderId', isEqualTo: orderId)
          .get();

      final offers = query.docs
          .map((doc) => DispatchOfferRecord.fromMap(doc.data()))
          .toList()
        ..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at); // newest first
        });

      _selectedOrderDispatchOffers = offers;
      debugPrint('✅ Loaded ${offers.length} dispatch offers');

      _isLoadingDispatchOffers = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading dispatch offers: $e');
      _dispatchOffersError = e.toString();
      _isLoadingDispatchOffers = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD RIDER EARNINGS (ADMR-29)
  // ============================================
  // rider_earnings/{orderId} — exactly one real, already-written document
  // per delivered order (functions/src/delivery/riderMoney.ts's own
  // recordDeliveryEarningCore); the order id IS the doc id, so this is a
  // direct get, never a query. Absent = genuinely not yet earned (not
  // delivered by a rider yet, or the trigger hasn't fired) — not an error.
  Future<void> _loadRiderEarning(String orderId) async {
    try {
      _isLoadingRiderEarning = true;
      _riderEarningError = null;
      notifyListeners();

      final doc = await _firestore.collection('rider_earnings').doc(orderId).get();

      _selectedOrderRiderEarning =
          doc.exists ? RiderEarningRecord.fromMap(doc.data()!, orderId) : null;
      debugPrint(_selectedOrderRiderEarning != null
          ? '✅ Loaded rider earning record'
          : 'ℹ️ No rider earning record yet for this order');

      _isLoadingRiderEarning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading rider earning: $e');
      _riderEarningError = e.toString();
      _isLoadingRiderEarning = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD RIDER CASH ACCOUNT (ADMR-36)
  // ============================================
  // rider_accounts/{riderId} — the rider's own running cash balance across
  // every order they have ever collected COD for (functions/src/delivery/
  // riderMoney.ts's own balanceFields), never specific to this one order.
  // Loaded only when this order has an assigned rider. A missing document
  // is a real zero (this rider has never held any COD cash), not an error.
  Future<void> _loadRiderCashAccount(String? riderId) async {
    if (riderId == null || riderId.isEmpty) {
      _selectedOrderRiderCashAccount = null;
      _riderCashAccountError = null;
      return;
    }
    try {
      _isLoadingRiderCashAccount = true;
      _riderCashAccountError = null;
      notifyListeners();

      final doc = await _firestore.collection('rider_accounts').doc(riderId).get();

      _selectedOrderRiderCashAccount = RiderCashAccountRecord.fromMap(
        doc.exists ? doc.data()! : const {},
        riderId,
      );
      debugPrint('✅ Loaded rider cash account for $riderId');

      _isLoadingRiderCashAccount = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading rider cash account: $e');
      _riderCashAccountError = e.toString();
      _isLoadingRiderCashAccount = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD COMMISSION EXCEPTIONS (ADMR-29)
  // ============================================
  // commission_exceptions filtered by orderId (single equality field, no
  // composite index needed) — functions/src/customer/employeeCommission.ts
  // writes one when a commission rate could not be resolved for an
  // attributed order, instead of silently paying nothing.
  Future<void> _loadCommissionExceptions(String orderId) async {
    try {
      _isLoadingCommissionExceptions = true;
      _commissionExceptionsError = null;
      notifyListeners();

      final query = await _firestore
          .collection('commission_exceptions')
          .where('orderId', isEqualTo: orderId)
          .get();

      _selectedOrderCommissionExceptions = query.docs
          .map((doc) => CommissionExceptionRecord.fromMap(doc.data(), doc.id))
          .toList();
      debugPrint(
          '✅ Loaded ${_selectedOrderCommissionExceptions.length} commission exceptions');

      _isLoadingCommissionExceptions = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading commission exceptions: $e');
      _commissionExceptionsError = e.toString();
      _isLoadingCommissionExceptions = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD RELATED SUPPORT TICKETS (ADMR-29)
  // ============================================
  // rider_support_tickets filtered by relatedTo.id (single equality field),
  // client-filtered for relatedTo.type=='order' — sidesteps any composite-
  // index question entirely, same risk-averse pattern as dispatch offers'
  // own client sort. functions/src/delivery/riderSupport.ts's own
  // submitSupportRequestCore is the real writer of relatedTo.
  Future<void> _loadRelatedSupportTickets(String orderId) async {
    try {
      _isLoadingSupportTickets = true;
      _supportTicketsError = null;
      notifyListeners();

      final query = await _firestore
          .collection('rider_support_tickets')
          .where('relatedTo.id', isEqualTo: orderId)
          .get();

      final tickets = query.docs
          .map((doc) => RiderSupportTicketRecord.fromMap(doc.data(), doc.id))
          .where((t) => t.relatedToType == 'order')
          .toList()
        ..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at); // newest first
        });

      _selectedOrderSupportTickets = tickets;
      debugPrint('✅ Loaded ${tickets.length} related support tickets');

      _isLoadingSupportTickets = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading related support tickets: $e');
      _supportTicketsError = e.toString();
      _isLoadingSupportTickets = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD SELLER SETTLEMENT (ADMR-30)
  // ============================================
  // seller_payouts filtered by orderId (single equality field, no
  // composite index needed) — functions/src/customer/sellerNotifications.ts
  // writes one per distinct seller among the order's items on delivery; a
  // genuinely multi-vendor order can produce more than one row, so this is
  // always a list, never a single-doc get.
  Future<void> _loadSellerPayouts(String orderId) async {
    try {
      _isLoadingSellerPayouts = true;
      _sellerPayoutsError = null;
      notifyListeners();

      final query = await _firestore
          .collection('seller_payouts')
          .where('orderId', isEqualTo: orderId)
          .get();

      _selectedOrderSellerPayouts = query.docs
          .map((doc) => SellerPayoutRecord.fromMap(doc.data(), doc.id))
          .toList();
      debugPrint('✅ Loaded ${_selectedOrderSellerPayouts.length} seller payouts');

      _isLoadingSellerPayouts = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading seller payouts: $e');
      _sellerPayoutsError = e.toString();
      _isLoadingSellerPayouts = false;
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

  // ADMR-35: cancelOrder (a raw Firestore write bypassing
  // adminUpdateOrderStatus entirely) removed — its only caller,
  // order_management_screen.dart's bulk-cancel action, now routes through
  // updateOrderStatus below, the same canonical path every other status
  // change already uses.

  // ============================================
  // UPDATE ORDER STATUS (FOR ADMIN)
  // ============================================
  Future<OrderStatusUpdateResult> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? description,
    String? expectedCurrentStatus,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📦 Updating order status: $orderId -> $newStatus');

      final requestId = const Uuid().v4();
      final res = await FirebaseFunctions.instance
          .httpsCallable('adminUpdateOrderStatus')
          .call<Map<String, dynamic>>({
        'orderId': orderId,
        'newStatus': newStatus,
        'requestId': requestId,
        if (description != null && description.isNotEmpty) 'reason': description,
        if (expectedCurrentStatus != null)
          'expectedCurrentStatus': expectedCurrentStatus,
      });

      final outcome = res.data['outcome'] as String?;
      _isLoading = false;

      if (outcome == 'applied' || outcome == 'already_applied') {
        await loadOrderById(orderId);
        debugPrint('✅ Order status updated: $outcome');
        notifyListeners();
        return OrderStatusUpdateResult(
          outcome == 'applied'
              ? OrderStatusUpdateOutcome.applied
              : OrderStatusUpdateOutcome.alreadyApplied,
        );
      }

      final message = res.data['message'] as String?;
      _error = message ?? 'Status update failed ($outcome)';
      notifyListeners();
      switch (outcome) {
        case 'stale_state':
          return OrderStatusUpdateResult(
              OrderStatusUpdateOutcome.staleState,
              message: message);
        case 'not_found':
          return OrderStatusUpdateResult(OrderStatusUpdateOutcome.notFound,
              message: message);
        default:
          return OrderStatusUpdateResult(
              OrderStatusUpdateOutcome.validationFailed,
              message: message);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ adminUpdateOrderStatus: ${e.code} ${e.message}');
      _error = e.message ?? e.code;
      _isLoading = false;
      notifyListeners();
      return OrderStatusUpdateResult(
        e.code == 'permission-denied'
            ? OrderStatusUpdateOutcome.permissionDenied
            : OrderStatusUpdateOutcome.validationFailed,
        message: e.message ?? e.code,
      );
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return OrderStatusUpdateResult(OrderStatusUpdateOutcome.networkError,
          message: e.toString());
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

  // ADMR-35: returnOrder removed — zero callers anywhere in the admin app,
  // and its own 'returned' status was never a member of
  // adminUpdateOrderStatus's VALID_STATUSES either, so it could not have
  // produced a status the rest of the system recognizes even if it were
  // called. Commercial returns (register domain C11) remain a genuinely
  // unbuilt policy area, not something this phase invents.

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
    _selectedOrderDispatchOffers.clear();
    _selectedOrderRiderEarning = null;
    _selectedOrderCommissionExceptions.clear();
    _selectedOrderSupportTickets.clear();
    _selectedOrderSellerPayouts.clear();
    _selectedOrderRiderCashAccount = null;
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
    _selectedOrderDispatchOffers.clear();
    _selectedOrderRiderEarning = null;
    _selectedOrderCommissionExceptions.clear();
    _selectedOrderSupportTickets.clear();
    _selectedOrderSellerPayouts.clear();
    _selectedOrderRiderCashAccount = null;
    super.dispose();
  }
}
