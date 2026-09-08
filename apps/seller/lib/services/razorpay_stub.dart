// Stub for non-web platforms (Android).
// Used when the conditional import in seller_ai_integration_screen.dart
// falls back on a non-web build.
//
// Phase AI-4C — mirrors apps/marketplace/lib/services/razorpay_stub.dart's
// own shape. Deliberately throws rather than no-op'ing: the screen's own
// build() is ALSO kIsWeb-gated (matching the onboarding-fee screen's own
// "belt and suspenders" pattern), so reaching this on Android means that
// guard was removed -- fail loudly rather than silently doing nothing.
// OWNER DECISION (2026-09-08): the ₹50 seller AI activation fee is
// web-only, mirroring the Sales Associate onboarding fee's own D2
// (Play-safety) restriction.

typedef RazorpayWebSuccessCallback = void Function(
    String paymentId, String? orderId, String? signature);
typedef RazorpayWebFailureCallback = void Function(String error);

class RazorpayWebService {
  void initialize({
    required RazorpayWebSuccessCallback onSuccess,
    required RazorpayWebFailureCallback onFailure,
  }) {
    // No-op on Android.
  }

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
        'Seller AI Assistant activation payment is web-only (Play-safety).');
  }

  void dispose() {
    // No-op on Android.
  }
}
