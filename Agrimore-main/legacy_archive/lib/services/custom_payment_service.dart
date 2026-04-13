import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCustomService {
  late Razorpay _razorpay;
  Function(String paymentId, String orderId, String signature)? onSuccess;
  Function(String error)? onFailure;

  void initialize({
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String error) onFailure,
  }) {
    _razorpay = Razorpay();
    this.onSuccess = onSuccess;
    this.onFailure = onFailure;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Payment Success: ${response.paymentId}');
    onSuccess?.call(
      response.paymentId ?? '',
      response.orderId ?? '',
      response.signature ?? '',
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Payment Error: ${response.code} - ${response.message}');
    onFailure?.call(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💼 External Wallet: ${response.walletName}');
  }

  // Open Razorpay with UPI preselected
  void openUpiPayment({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? preferredUpiApp,
  }) {
    var options = {
      'key': 'rzp_live_RZMIepwnzTqjsH', // Your Razorpay key
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': 'Agrimore',
      'description': 'Order Payment',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'method': {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
      },
      'theme': {'color': '#4CAF50'},
    };

    if (preferredUpiApp != null) {
      options['_']['flow'] = 'intent';
      options['_']['package'] = preferredUpiApp;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      onFailure?.call('Failed to open payment gateway');
    }
  }

  // Open Razorpay with Card preselected
  void openCardPayment({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag',
      'amount': (amount * 100).toInt(),
      'name': 'Agrimore',
      'description': 'Order Payment',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'method': {
        'card': true,
        'upi': false,
        'netbanking': false,
        'wallet': false,
      },
      'theme': {'color': '#4CAF50'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      onFailure?.call('Failed to open payment gateway');
    }
  }

  // Open Razorpay with all payment methods
  void openAllPaymentMethods({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag',
      'amount': (amount * 100).toInt(),
      'name': 'Agrimore',
      'description': 'Order Payment',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'theme': {'color': '#4CAF50'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      onFailure?.call('Failed to open payment gateway');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
