// Stub file for mobile platform
// This is used when the conditional import falls back on non-web platforms
import 'payment_checkout_order.dart';

/// Placeholder callback types
typedef RazorpayWebSuccessCallback = void Function(
    String paymentId, String? orderId, String? signature);
typedef RazorpayWebFailureCallback = void Function(String error);

/// Stub class for mobile - not used on mobile platforms
class RazorpayWebService {
  void initialize({
    required RazorpayWebSuccessCallback onSuccess,
    required RazorpayWebFailureCallback onFailure,
  }) {
    // No-op on mobile
  }

  Future<void> openCheckout({
    required double amount,
    CheckoutPaymentPurpose purpose = CheckoutPaymentPurpose.goods,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    // No-op on mobile - use RazorpayCustomService instead
  }

  /// Mirrors razorpay_web.dart's method of the same name (Phase 16B-2).
  /// Deliberately throws rather than no-op'ing: every call site is also
  /// kIsWeb-gated (Play-safety, D2), so reaching this on mobile means that
  /// guard was removed — fail loudly rather than silently doing nothing.
  Future<void> openCheckoutForExistingOrder({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    throw UnsupportedError(
        'Associate onboarding payment is web-only (Play-safety, D2).');
  }

  void dispose() {
    // No-op on mobile
  }
}
