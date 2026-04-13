// Stub file for mobile platform
// This is used when the conditional import falls back on non-web platforms

/// Placeholder callback types
typedef RazorpayWebSuccessCallback = void Function(String paymentId, String? orderId, String? signature);
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
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    // No-op on mobile - use RazorpayCustomService instead
  }
  
  void dispose() {
    // No-op on mobile
  }
}
