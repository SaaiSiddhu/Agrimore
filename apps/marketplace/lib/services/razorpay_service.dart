// Unified Razorpay Payment Service
// Works on both Web (via JS interop) and Mobile (via razorpay_flutter)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'payment_checkout_order.dart';

// Platform-specific imports
import 'razorpay_web.dart' if (dart.library.io) 'razorpay_stub.dart';

// Mobile-only: razorpay_flutter
import 'razorpay_flutter_stub.dart'
    if (dart.library.io) 'package:razorpay_flutter/razorpay_flutter.dart';

export 'payment_checkout_order.dart' show CheckoutPaymentPurpose;

/// Callback types
typedef PaymentSuccessCallback = void Function(
    String paymentId, String? orderId, String? signature);
typedef PaymentFailureCallback = void Function(String error);
typedef PaymentDismissCallback = void Function();
typedef PaymentOrderCreatedCallback = Future<void> Function(
    PaymentCheckoutOrder order);

/// Unified Razorpay Service for all platforms
class RazorpayService {
  bool _disposed = false;
  Razorpay? _razorpay; // Mobile only
  RazorpayWebService? _razorpayWeb; // Web only

  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onFailure;
  PaymentDismissCallback? _onDismiss;

  // Order details for callback context
  String _userName = '';
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
    CheckoutPaymentPurpose purpose = CheckoutPaymentPurpose.goods,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
    BuildContext? context,
    PaymentOrderCreatedCallback? onOrderCreated,
  }) async {
    if (_disposed) return;
    _userName = userName;
    _userPhone = userPhone;

    if (kIsWeb) {
      await _razorpayWeb?.openCheckout(
        amount: amount,
        purpose: purpose,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        description: description,
        onOrderCreated: onOrderCreated,
      );
    } else {
      await _openMobileCheckout(
        amount: amount,
        purpose: purpose,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        description: description,
        context: context,
        onOrderCreated: onOrderCreated,
      );
    }
  }

  /// Mobile-specific checkout using razorpay_flutter
  Future<void> _openMobileCheckout({
    required double amount,
    required CheckoutPaymentPurpose purpose,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
    BuildContext? context,
    PaymentOrderCreatedCallback? onOrderCreated,
  }) async {
    try {
      debugPrint('💳 Creating Razorpay order via Cloud Function...');

      // Call Cloud Function to create order with 15s timeout
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable(
        'createRazorpayOrder',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': 'INR',
        'purpose': purpose.value,
        'receipt': 'agrimore_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'customer_name': userName,
          'customer_email': userEmail,
          'source': 'agrimore_app',
        },
      }).timeout(const Duration(seconds: 16));

      final data = result.data;
      if (_disposed) return;

      if (data['success'] != true) {
        _onFailure?.call(data['error'] ?? 'Failed to create order');
        return;
      }

      final order = PaymentCheckoutOrder.fromResponse(data);
      // Save the exact provider tuple before the customer can pay. A failed
      // or interrupted hook cannot silently fall through to SDK checkout.
      if (onOrderCreated != null) await onOrderCreated(order);
      if (_disposed) return;
      final razorpayOrderId = order.orderId;
      final keyId = order.keyId;
      final isTestMode = order.isTestMode;

      debugPrint(
          '✅ Razorpay order created: $razorpayOrderId (TestMode: $isTestMode)');

      if (isTestMode) {
        if (context != null && context.mounted) {
          _showSandboxPaymentSheet(
            context: context,
            amount: order.amountPaise / 100.0,
            orderId: razorpayOrderId,
            description: description,
          );
        } else {
          debugPrint(
              '🧪 Auto-completing sandbox payment in background mode...');
          final mockPaymentId =
              'pay_test_${DateTime.now().millisecondsSinceEpoch}';
          final mockSignature =
              'test_sig_${DateTime.now().millisecondsSinceEpoch}';
          _onSuccess?.call(mockPaymentId, razorpayOrderId, mockSignature);
        }
        return;
      }

      // Enhanced Razorpay checkout options with premium branding
      final options = {
        'key': keyId,
        'amount': order.amountPaise,
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
      _onFailure?.call('Could not open payment. Please try again.');
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
  }

  void _showSandboxPaymentSheet({
    required BuildContext context,
    required double amount,
    required String orderId,
    String? description,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF145A32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF145A32),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Razorpay Gateway',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.amber.shade700, width: 0.8),
                                ),
                                child: Text(
                                  'SANDBOX',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description ?? 'Order Payment Simulation',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount Payable',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF145A32),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order Ref',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              orderId,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_userName.isNotEmpty || _userPhone.isNotEmpty) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _userPhone.isNotEmpty
                                    ? '$_userName ($_userPhone)'
                                    : _userName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    final mockPaymentId =
                        'pay_test_${DateTime.now().millisecondsSinceEpoch}';
                    final mockSignature =
                        'test_sig_${DateTime.now().millisecondsSinceEpoch}';
                    debugPrint('🧪 Sandbox payment approved: $mockPaymentId');
                    _onSuccess?.call(mockPaymentId, orderId, mockSignature);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF145A32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Simulate Successful Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _onFailure?.call('Payment simulation declined by user');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Simulate Payment Failure'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _onDismiss?.call();
                  },
                  child: Text(
                    'Cancel Checkout',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Verify Razorpay signature and captured status via backend before marking paid.
  Future<bool> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    if (paymentId.isEmpty || orderId.isEmpty || signature.isEmpty) {
      debugPrint('Razorpay verification skipped: missing payment fields');
      return false;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyRazorpayPayment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'paymentId': paymentId,
        'orderId': orderId,
        'signature': signature,
      }).timeout(const Duration(seconds: 16));
      final verified = result.data['verified'] == true;
      debugPrint(verified
          ? 'Razorpay payment verified: $paymentId'
          : 'Razorpay payment verification failed: $paymentId');
      return verified;
    } catch (e) {
      debugPrint('Razorpay verification error: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
    _razorpay?.clear();
    _razorpayWeb?.dispose();
    _onSuccess = null;
    _onFailure = null;
    _onDismiss = null;
  }
}
