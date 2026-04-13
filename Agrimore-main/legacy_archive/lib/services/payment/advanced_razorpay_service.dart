// lib/services/payment/advanced_razorpay_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../app/themes/app_colors.dart';
import '../../config/razorpay_config.dart';

class AdvancedRazorpayService {
  final Color themeColor;
  final String? logoAsset;

  late Razorpay _razorpay;
  bool _isInitialized = false;
  String? _currentOrderId;

  // Callbacks passed from the constructor (optional)
  final void Function(PaymentSuccessResponse)? onSuccess;
  final void Function(PaymentFailureResponse)? onFailure;
  final void Function(ExternalWalletResponse)? onWalletSelected;

  AdvancedRazorpayService({
    this.themeColor = AppColors.primary,
    this.logoAsset,
    this.onSuccess,
    this.onFailure,
    this.onWalletSelected,
  });

  /// 🔹 Initializes Razorpay and attaches listeners
  void initialize({
    // Callbacks passed from the screen (preferred)
    void Function(PaymentSuccessResponse)? onSuccess,
    void Function(PaymentFailureResponse)? onFailure,
    void Function(ExternalWalletResponse)? onWalletSelected,
  }) {
    if (_isInitialized) return;

    try {
      RazorpayConfig.logConfiguration();
      _razorpay = Razorpay();

      // Attach the internal handlers
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
          (PaymentSuccessResponse response) {
        // ✅ FIXED: Pass the correct callback parameter
        _handlePaymentSuccess(response, onSuccess ?? this.onSuccess);
      });

      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
          (PaymentFailureResponse response) {
        // ✅ FIXED: Pass the correct callback parameter
        _handlePaymentError(response, onFailure ?? this.onFailure);
      });

      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
          (ExternalWalletResponse response) {
        debugPrint("💳 Wallet: ${response.walletName}");
        (this.onWalletSelected ?? onWalletSelected)?.call(response);
      });

      _isInitialized = true;
      debugPrint("🟢 Razorpay Initialized (${RazorpayConfig.paymentMode})");
    } catch (e) {
      debugPrint("❌ Initialization Error: $e");
    }
  }

  /// Creates an order on Razorpay's servers.
  Future<String?> createOrder({
    required double amount,
    required String currency,
    String? receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final auth = base64Encode(
        utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}')
      );
      
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/orders'),
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(),
          'currency': currency,
          'receipt': receipt ?? 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
          'notes': notes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentOrderId = data['id'];
        debugPrint("✅ Order Created: $_currentOrderId | ₹$amount");
        return _currentOrderId;
      } else {
        final error = jsonDecode(response.body);
        debugPrint("❌ Order Failed: ${error['error']['description']}");
        onFailure?.call(PaymentFailureResponse(
          response.statusCode, 
          error['error']['description'], 
          {}
        ));
        return null;
      }
    } catch (e) {
      debugPrint("❌ Order Exception: $e");
      onFailure?.call(PaymentFailureResponse(500, e.toString(), {}));
      return null;
    }
  }

  /// Opens the advanced, unified Razorpay checkout.
  Future<void> openAdvancedCheckout({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? paymentMethod, // Nullable to show all options
    String? orderId,
    String? description,
    Map<String, String>? customNotes,
  }) async {
    if (!_isInitialized) {
      debugPrint("⚠️ Razorpay not initialized");
      onFailure?.call(PaymentFailureResponse(
        0, 'Payment service not initialized', {}
      ));
      return;
    }

    // 1. Create Order
    final createdOrderId = await createOrder(
      amount: amount,
      currency: RazorpayConfig.currency,
      receipt: 'order_${DateTime.now().millisecondsSinceEpoch}',
      notes: customNotes?.map((k, v) => MapEntry(k, v)),
    );

    if (createdOrderId == null) {
      onFailure?.call(PaymentFailureResponse(
        1, 'Failed to create Razorpay order', {}
      ));
      return;
    }

    // 2. Open Checkout
    try {
      var options = {
        'key': RazorpayConfig.keyId,
        'amount': (amount * 100).toInt(),
        'order_id': createdOrderId,
        'name': RazorpayConfig.appName,
        'description': description ?? 'Secure Payment',
        'currency': RazorpayConfig.currency,
        'timeout': RazorpayConfig.paymentTimeoutSeconds,
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
          'name': userName,
        },
        'retry': {
          'enabled': true,
          'max_count': RazorpayConfig.maxRetries,
        },
        'theme': {
          'color': RazorpayConfig.themeColor,
        },
        'modal': {
          'backdropclose': false,
          'escape': false,
          'confirm_close': true,
        },
        'notes': customNotes ?? {},
        'send_sms_hash': true,
      };

      // Conditionally add the payment method to pre-select it
      if (paymentMethod != null) {
        options['method'] = paymentMethod;
      }

      debugPrint("🎯 Opening Checkout | ₹$amount | ${RazorpayConfig.paymentMode}");
      _razorpay.open(options);
    } catch (e) {
      debugPrint("❌ Checkout Error: $e");
      onFailure?.call(PaymentFailureResponse(
        2, 'Checkout failed: $e', {}
      ));
    }
  }

  bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    try {
      final data = '$orderId|$paymentId';
      final key = utf8.encode(RazorpayConfig.keySecret);
      final bytes = utf8.encode(data);
      
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(bytes);
      final generatedSignature = digest.toString();

      return generatedSignature == signature;
    } catch (e) {
      debugPrint("❌ Signature Error: $e");
      return false;
    }
  }

  // --- Internal Handlers ---
  
  void _handlePaymentSuccess(
    PaymentSuccessResponse response,
    void Function(PaymentSuccessResponse)? onSuccess, // ✅ FIXED: Parameter name
  ) {
    HapticFeedback.mediumImpact();

    final isValid = verifySignature(
      orderId: response.orderId ?? _currentOrderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );

    if (isValid) {
      debugPrint("✅ PAYMENT SUCCESS | ${response.paymentId}");
      onSuccess?.call(response);
    } else {
      debugPrint("⚠️ Invalid signature");
      onFailure?.call(PaymentFailureResponse(
        999, 'Signature verification failed', {}
      ));
    }
  }

  void _handlePaymentError(
    PaymentFailureResponse response,
    void Function(PaymentFailureResponse)? onFailure, // ✅ FIXED: Parameter name
  ) {
    HapticFeedback.heavyImpact();
    debugPrint("❌ PAYMENT ERROR (${response.code}): ${response.message}");
    onFailure?.call(response);
  }
  
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("💳 Wallet: ${response.walletName}");
    onWalletSelected?.call(response);
  }

  void dispose() {
    if (_isInitialized) {
      _razorpay.clear();
      _isInitialized = false;
      debugPrint("🧹 Razorpay Disposed");
    }
  }
}