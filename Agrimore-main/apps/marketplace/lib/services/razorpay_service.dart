// Unified Razorpay Payment Service
// Works on both Web (via JS interop) and Mobile (via razorpay_flutter)

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Platform-specific imports
import 'razorpay_web.dart' if (dart.library.io) 'razorpay_stub.dart';

// Mobile-only: razorpay_flutter
import 'package:razorpay_flutter/razorpay_flutter.dart' if (dart.library.html) 'razorpay_flutter_stub.dart';

/// Callback types
typedef PaymentSuccessCallback = void Function(String paymentId, String? orderId, String? signature);
typedef PaymentFailureCallback = void Function(String error);
typedef PaymentDismissCallback = void Function();

/// Unified Razorpay Service for all platforms
class RazorpayService {
  Razorpay? _razorpay; // Mobile only
  RazorpayWebService? _razorpayWeb; // Web only
  
  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onFailure;
  PaymentDismissCallback? _onDismiss;
  
  // Order details for callback context
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  
  RazorpayService() {
    if (!kIsWeb) {
      _initMobile();
    }
  }
  
  void _initMobile() {
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleMobileSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleMobileError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }
  
  /// Initialize with callbacks
  void initialize({
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onFailure,
    PaymentDismissCallback? onDismiss,
  }) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onDismiss = onDismiss;
    
    if (kIsWeb) {
      _razorpayWeb = RazorpayWebService();
      _razorpayWeb!.initialize(
        onSuccess: (paymentId, orderId, signature) {
          _onSuccess?.call(paymentId, orderId, signature);
        },
        onFailure: (error) {
          if (error.contains('cancelled')) {
            _onDismiss?.call();
          } else {
            _onFailure?.call(error);
          }
        },
      );
    }
  }
  
  /// Open payment checkout
  Future<void> openCheckout({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    _userName = userName;
    _userEmail = userEmail;
    _userPhone = userPhone;
    
    if (kIsWeb) {
      await _razorpayWeb?.openCheckout(
        amount: amount,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        description: description,
      );
    } else {
      await _openMobileCheckout(
        amount: amount,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        description: description,
      );
    }
  }
  
  /// Mobile-specific checkout using razorpay_flutter
  Future<void> _openMobileCheckout({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    try {
      debugPrint('💳 Creating Razorpay order via Cloud Function (Mobile)...');
      
      // Call Cloud Function to create order
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createRazorpayOrder');
      
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': 'INR',
        'receipt': 'agrimore_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'customer_name': userName,
          'customer_email': userEmail,
          'source': 'agrimore_app',
        },
      });
      
      final data = result.data;
      
      if (data['success'] != true) {
        _onFailure?.call(data['error'] ?? 'Failed to create order');
        return;
      }
      
      final razorpayOrderId = data['orderId'] as String;
      final keyId = data['keyId'] as String;
      
      debugPrint('✅ Razorpay order created: $razorpayOrderId');
      
      // Enhanced Razorpay checkout options with premium branding
      final options = {
        'key': keyId,
        'amount': (amount * 100).toInt(), // Amount in paise
        'order_id': razorpayOrderId,
        'currency': 'INR',
        
        // Premium Branding
        'name': 'Agrimore',
        'description': description ?? 'Premium Order Payment',
        'image': 'https://agrimore.in/icons/Icon-192.png', // App logo
        
        // Customer prefill for faster checkout
        'prefill': {
          'name': userName,
          'email': userEmail,
          'contact': userPhone,
        },
        
        // Premium Theme with app colors
        'theme': {
          'color': '#145A32', // Agrimore Green
          'backdrop_color': '#0B3B20', // Darker green backdrop
          'hide_topbar': false,
        },
        
        // Smart Retry for failed payments
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        
        // Remember customer for faster future payments
        'remember_customer': true,
        
        // Send SMS/Email updates
        'send_sms_hash': true,
        
        // Modal configuration
        'modal': {
          'confirm_close': true, // Ask before closing
          'animation': true,
          'backdropclose': false, // Don't close on backdrop click
          'escape': false, // Don't close on ESC
        },
        
        // Payment method preferences (show all)
        'config': {
          'display': {
            'hide': [
              // {'method': 'paylater'}, // Uncomment to hide Pay Later
            ],
            'preferences': {
              'show_default_blocks': true,
            },
          },
        },
        
        // Notes for order tracking
        'notes': {
          'app': 'Agrimore',
          'platform': 'mobile',
          'order_source': 'cart_checkout',
        },
      };
      
      debugPrint('📱 Opening premium Razorpay checkout...');
      _razorpay?.open(options);
    } catch (e) {
      debugPrint('❌ Error opening mobile checkout: $e');
      _onFailure?.call('Failed to open payment: ${e.toString()}');
    }
  }
  
  // Mobile event handlers
  void _handleMobileSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Mobile payment success: ${response.paymentId}');
    _onSuccess?.call(
      response.paymentId ?? '',
      response.orderId,
      response.signature,
    );
  }
  
  void _handleMobileError(PaymentFailureResponse response) {
    debugPrint('❌ Mobile payment error: ${response.message}');
    _onFailure?.call(response.message ?? 'Payment failed');
  }
  
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('📱 External wallet: ${response.walletName}');
    // Handle external wallet if needed
  }
  
  /// Dispose resources
  void dispose() {
    _razorpay?.clear();
    _razorpayWeb?.dispose();
    _onSuccess = null;
    _onFailure = null;
    _onDismiss = null;
  }
}
