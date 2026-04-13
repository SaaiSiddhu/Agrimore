import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:agrimore_core/agrimore_core.dart';

class PaymentService {
  late Razorpay _razorpay;
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;

  // Initialize Razorpay
  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) {
    _razorpay = Razorpay();
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // Open Razorpay checkout securely using Cloud Functions
  Future<void> openCheckout({
    required double amount,
    required String orderId,
    required String name,
    required String email,
    required String phone,
    String? description,
  }) async {
    try {
      debugPrint('💳 Creating Secure Razorpay order via Cloud Function...');
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createRazorpayOrder');
      
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': 'INR',
        'receipt': 'agrimore_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'customer_name': name,
          'customer_email': email,
          'source': 'flutter_app',
        },
      });
      
      final data = result.data;
      if (data['success'] != true) throw PaymentException(data['error'] ?? 'Order creation failed');

      final keyId = data['keyId'] as String;
      final razorpayOrderId = data['orderId'] as String;

      final options = {
        'key': keyId, // Fetched securely from backend
        'amount': (amount * 100).toInt(),
        'name': 'Agrimore',
        'order_id': razorpayOrderId,
        'description': description ?? 'Payment for order $razorpayOrderId',
        'timeout': 300,
        'prefill': {
          'contact': phone,
          'email': email,
          'name': name,
        },
        'theme': {
          'color': '#2E7D32',
        },
      };

      _razorpay.open(options);
    } catch (e) {
      throw PaymentException('Failed to open secure payment: ${e.toString()}');
    }
  }

  // Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(response);
  }

  // Handle payment failure
  void _handlePaymentFailure(PaymentFailureResponse response) {
    _onFailure?.call(response);
  }

  // Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet payment
  }

  // Verify payment signature
  bool verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
    required String secret,
  }) {
    try {
      // Implement signature verification logic
      // This should be done on the backend for security
      return true;
    } catch (e) {
      return false;
    }
  }

  // Process COD order
  Future<Map<String, dynamic>> processCODOrder({
    required String orderId,
    required double amount,
  }) async {
    try {
      // Process COD order logic
      return {
        'success': true,
        'orderId': orderId,
        'paymentMethod': 'COD',
        'amount': amount,
      };
    } catch (e) {
      throw PaymentException('Failed to process COD order: ${e.toString()}');
    }
  }

  // Create Razorpay order (backend integration required)
  Future<String> createRazorpayOrder({
    required double amount,
    required String currency,
  }) async {
    try {
      // This should call your backend API to create Razorpay order
      // Backend will use Razorpay API with secret key
      
      // Example response from backend
      return 'order_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      throw PaymentException('Failed to create order: ${e.toString()}');
    }
  }

  // Dispose Razorpay
  void dispose() {
    _razorpay.clear();
  }
}
