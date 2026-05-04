import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCustomService {
  late Razorpay _razorpay;
  Function(String paymentId, String orderId, String signature)? onSuccess;
  Function(String error)? onFailure;

  void initialize({
    required Function(String paymentId, String orderId, String signature)
        onSuccess,
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
    debugPrint('Payment Success: ${response.paymentId}');
    onSuccess?.call(
      response.paymentId ?? '',
      response.orderId ?? '',
      response.signature ?? '',
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    onFailure?.call(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
  }

  Future<void> _openPayment({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    Map<String, bool>? methods,
    Map<String, dynamic>? extraOptions,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': 'INR',
        'receipt': 'agrimore_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'customer_name': userName,
          'customer_email': userEmail,
          'source': 'agrimore_custom_payment_service',
        },
      });

      final data = result.data;
      if (data['success'] != true) {
        onFailure?.call(data['error'] ?? 'Failed to create payment order');
        return;
      }

      final options = <String, dynamic>{
        'key': data['keyId'],
        'amount': (amount * 100).toInt(),
        'order_id': data['orderId'],
        'currency': 'INR',
        'name': 'Agrimore',
        'description': 'Order Payment',
        'prefill': {
          'name': userName,
          'contact': userPhone,
          'email': userEmail,
        },
        'theme': {'color': '#4CAF50'},
      };

      if (methods != null) options['method'] = methods;
      if (extraOptions != null) options.addAll(extraOptions);

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      onFailure?.call('Failed to open payment gateway');
    }
  }

  void openUpiPayment({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? preferredUpiApp,
  }) {
    _openPayment(
      amount: amount,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      methods: const {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
      },
      extraOptions: preferredUpiApp == null
          ? null
          : {
              '_': {
                'flow': 'intent',
                'package': preferredUpiApp,
              },
            },
    );
  }

  void openCardPayment({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    _openPayment(
      amount: amount,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      methods: const {
        'card': true,
        'upi': false,
        'netbanking': false,
        'wallet': false,
      },
    );
  }

  void openAllPaymentMethods({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    _openPayment(
      amount: amount,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
    );
  }

  void dispose() {
    _razorpay.clear();
  }
}
