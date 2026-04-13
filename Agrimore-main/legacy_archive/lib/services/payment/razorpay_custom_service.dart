// 📁 Save this file at: lib/services/payment/advanced_razorpay_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:async';
import '../../app/themes/app_colors.dart';

/// 🚀 Advanced Razorpay Payment Service with Enhanced Features
/// - Multiple payment methods (Card, UPI, Wallet, NetBanking, EMI)
/// - Retry logic and timeout handling
/// - Payment analytics and tracking
/// - Advanced error recovery
/// - Transaction history management
class AdvancedRazorpayService {
  final String testKeyId;
  final String testKeySecret;
  final Color themeColor;
  final String? logoAsset;

  late Razorpay _razorpay;
  bool _isInitialized = false;
  Timer? _paymentTimeoutTimer;
  
  // Analytics & History
  List<PaymentTransaction> _transactionHistory = [];
  int _retryCount = 0;
  final int maxRetries = 2;

  // Callbacks
  final void Function(PaymentSuccessResponse)? onSuccess;
  final void Function(PaymentFailureResponse)? onFailure;
  final void Function(ExternalWalletResponse)? onWalletSelected;
  final void Function(String, String)? onRetry; // error, reason
  final void Function(bool)? onPaymentStateChange; // loading state

  AdvancedRazorpayService({
    this.testKeyId = "rzp_test_FakeKey123456",
    this.testKeySecret = "FakeSecretKey987654",
    this.themeColor = AppColors.primary,
    this.logoAsset,
    this.onSuccess,
    this.onFailure,
    this.onWalletSelected,
    this.onRetry,
    this.onPaymentStateChange,
  });

  /// 🔹 Initialize with enhanced error handling
  void initialize({
    void Function(PaymentSuccessResponse)? onSuccess,
    void Function(PaymentFailureResponse)? onFailure,
    void Function(ExternalWalletResponse)? onWalletSelected,
  }) {
    if (_isInitialized) {
      debugPrint("⚠️ Razorpay already initialized");
      return;
    }

    try {
      _razorpay = Razorpay();

      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
          (PaymentSuccessResponse response) {
        _handlePaymentSuccess(response, onSuccess);
      });

      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
          (PaymentFailureResponse response) {
        _handlePaymentError(response, onFailure);
      });

      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
          (ExternalWalletResponse response) {
        debugPrint("💳 Wallet Selected: ${response.walletName}");
        onWalletSelected?.call(response);
      });

      _isInitialized = true;
      debugPrint("🟢 Advanced Razorpay Service Initialized");
    } catch (e) {
      debugPrint("❌ Initialization Error: $e");
      rethrow;
    }
  }

  /// 🔹 Unified Advanced Checkout
  Future<void> openAdvancedCheckout({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String paymentMethod = 'card', // card, upi, wallet, netbanking, emi
    String? orderId,
    String? description,
    bool enableRecurring = false,
    bool enableAutoCapture = true,
    Map<String, String>? customNotes,
  }) async {
    if (!_isInitialized) {
      debugPrint("⚠️ Razorpay not initialized");
      onFailure?.call(PaymentFailureResponse(
        0,
        'Payment service not initialized',
        {'description': 'Please initialize the service before opening checkout'},
      ));
      return;
    }

    _resetRetryCount();
    _startPaymentTimeout();
    onPaymentStateChange?.call(true);

    try {
      final options = _buildAdvancedPaymentOptions(
        amount: amount,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        paymentMethod: paymentMethod,
        orderId: orderId,
        description: description,
        enableRecurring: enableRecurring,
        enableAutoCapture: enableAutoCapture,
        customNotes: customNotes,
      );

      debugPrint("🎯 Opening Razorpay with method: $paymentMethod");
      _razorpay.open(options);
    } catch (e) {
      debugPrint("❌ Checkout Error: $e");
      onPaymentStateChange?.call(false);
      onFailure?.call(PaymentFailureResponse(
        0,
        'Failed to open checkout',
        {'description': e.toString()},
      ));
    }
  }

  /// 🔹 Build Advanced Payment Options
  Map<String, dynamic> _buildAdvancedPaymentOptions({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String paymentMethod,
    String? orderId,
    String? description,
    bool enableRecurring = false,
    bool enableAutoCapture = true,
    Map<String, String>? customNotes,
  }) {
    return {
      'key': testKeyId,
      'amount': (amount * 100).toInt(),
      'currency': 'INR',
      'order_id': orderId ?? _generateOrderId(),
      'name': 'Agrimore',
      'description': description ?? 'Secure Online Payment',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'notes': customNotes ?? {'app': 'agroconnect_mobile'},
      'method': paymentMethod != 'card' ? paymentMethod : null,
      'theme': {
        'color': _colorToHex(themeColor),
        'backdrop': false,
        'hide_topbar': false,
      },
      'retry': {
        'enabled': true,
        'max_count': maxRetries,
      },
      'subscription_notify': enableRecurring ? 1 : 0,
      'capture': enableAutoCapture,
      'timeout': 900, // 15 minutes
      'display_amount': true,
      'animation': true,
      'send_sms_hash': true,
      'image': logoAsset,
      'reference_skip': 'dashboard',
      'show_coupons': true,
      'show_wallet': true,
      'recurring': enableRecurring,
    };
  }

  /// 🔹 Handle Payment Success with Analytics
  void _handlePaymentSuccess(
    PaymentSuccessResponse response,
    void Function(PaymentSuccessResponse)? onSuccess,
  ) {
    _cancelPaymentTimeout();
    onPaymentStateChange?.call(false);
    HapticFeedback.mediumImpact();

    final transaction = PaymentTransaction(
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? '',
      signature: response.signature ?? '',
      status: PaymentStatus.success,
      timestamp: DateTime.now(),
      amount: 0,
      method: 'razorpay',
      retryCount: _retryCount,
    );

    _transactionHistory.add(transaction);
    _resetRetryCount();

    debugPrint("✅ Payment Success: ${response.paymentId}");
    debugPrint("📋 Order ID: ${response.orderId}");
    
    onSuccess?.call(response);
  }

  /// 🔹 Handle Payment Error with Smart Retry
  void _handlePaymentError(
    PaymentFailureResponse response,
    void Function(PaymentFailureResponse)? onFailure,
  ) {
    _cancelPaymentTimeout();
    onPaymentStateChange?.call(false);
    HapticFeedback.heavyImpact();

    final errorMsg = response.message ?? 'Payment failed due to unknown error';
    final errorCode = response.code ?? 0;

    debugPrint("❌ Payment Error (Code: $errorCode): $errorMsg");

    final transaction = PaymentTransaction(
      paymentId: 'failed_$errorCode',
      orderId: '',
      signature: '',
      status: PaymentStatus.failed,
      timestamp: DateTime.now(),
      amount: 0,
      method: 'razorpay',
      retryCount: _retryCount,
      errorMessage: errorMsg,
      errorCode: errorCode,
    );

    _transactionHistory.add(transaction);

    if (_shouldRetry(errorCode, _retryCount)) {
      _retryCount++;
      onRetry?.call(errorMsg, 'Automatic retry #$_retryCount');
      debugPrint("🔄 Retry #$_retryCount triggered");
    } else {
      _resetRetryCount();
      onFailure?.call(response);
    }
  }

  /// 🔹 Smart Retry Logic
  bool _shouldRetry(int errorCode, int currentRetry) {
    final retryableErrors = [0, 2, 3, 4];
    return retryableErrors.contains(errorCode) && currentRetry < maxRetries;
  }

  /// 🔹 Payment Timeout Handler
  void _startPaymentTimeout() {
    _paymentTimeoutTimer = Timer(const Duration(minutes: 15), () {
      debugPrint("⏱️ Payment timeout - User took too long");
      onFailure?.call(PaymentFailureResponse(
        999,
        'Payment timeout',
        {'description': 'Transaction took longer than expected'},
      ));
      onPaymentStateChange?.call(false);
    });
  }

  void _cancelPaymentTimeout() {
    _paymentTimeoutTimer?.cancel();
    _paymentTimeoutTimer = null;
  }

  /// 🔹 Get Transaction History
  List<PaymentTransaction> getTransactionHistory() {
    return List.unmodifiable(_transactionHistory);
  }

  /// 🔹 Get Latest Transaction
  PaymentTransaction? getLatestTransaction() {
    return _transactionHistory.isNotEmpty ? _transactionHistory.last : null;
  }

  /// 🔹 Filter Transactions by Status
  List<PaymentTransaction> getTransactionsByStatus(PaymentStatus status) {
    return _transactionHistory.where((t) => t.status == status).toList();
  }

  /// 🔹 Get Payment Statistics
  Map<String, dynamic> getPaymentStats() {
    final successful = _transactionHistory
        .where((t) => t.status == PaymentStatus.success)
        .length;
    final failed = _transactionHistory
        .where((t) => t.status == PaymentStatus.failed)
        .length;
    final totalAmount = _transactionHistory
        .where((t) => t.status == PaymentStatus.success)
        .fold(0.0, (sum, t) => sum + t.amount);

    return {
      'total_transactions': _transactionHistory.length,
      'successful': successful,
      'failed': failed,
      'success_rate': _transactionHistory.isEmpty
          ? 0.0
          : successful / _transactionHistory.length * 100,
      'total_amount': totalAmount,
    };
  }

  /// 🔹 Helper Methods
  void _resetRetryCount() {
    _retryCount = 0;
  }

  String _generateOrderId() {
    return 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// 🔹 Clean up resources
  void dispose() {
    _cancelPaymentTimeout();
    if (_isInitialized) {
      _razorpay.clear();
      _isInitialized = false;
      debugPrint("🧹 Advanced Razorpay Service disposed");
    }
  }
}

/// 📊 Payment Status Enum
enum PaymentStatus { success, failed, pending, cancelled }

/// 📊 Payment Transaction Model
class PaymentTransaction {
  final String paymentId;
  final String orderId;
  final String signature;
  final PaymentStatus status;
  final DateTime timestamp;
  final double amount;
  final String method;
  final int retryCount;
  final String? errorMessage;
  final int? errorCode;

  PaymentTransaction({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.status,
    required this.timestamp,
    required this.amount,
    required this.method,
    required this.retryCount,
    this.errorMessage,
    this.errorCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'amount': amount,
      'method': method,
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'errorCode': errorCode,
    };
  }
}