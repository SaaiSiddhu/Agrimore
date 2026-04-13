import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/error/exceptions.dart';

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

  // Open Razorpay checkout
  Future<void> openCheckout({
    required double amount,
    required String orderId,
    required String name,
    required String email,
    required String phone,
    String? description,
  }) async {
    try {
      final options = {
        'key': 'YOUR_RAZORPAY_KEY_ID', // Replace with your key
        'amount': (amount * 100).toInt(), // Amount in paise
        'name': 'Agrimore',
        'order_id': orderId,
        'description': description ?? 'Payment for order $orderId',
        'timeout': 300, // 5 minutes in seconds
        'prefill': {
          'contact': phone,
          'email': email,
          'name': name,
        },
        'theme': {
          'color': '#2E7D32', // Primary color
        },
        'modal': {
          'ondismiss': () {
            throw PaymentCancelledException('Payment cancelled by user');
          }
        }
      };

      _razorpay.open(options);
    } catch (e) {
      throw PaymentException('Failed to open payment: ${e.toString()}');
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
