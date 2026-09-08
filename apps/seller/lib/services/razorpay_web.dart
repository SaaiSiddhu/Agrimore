// Web-specific Razorpay checkout for an ALREADY-created order.
// This file should only be imported on web platform.
// ignore_for_file: avoid_web_libraries_in_flutter
//
// Phase AI-4C — mirrors apps/marketplace/lib/services/razorpay_web.dart's own
// `openCheckoutForExistingOrder` method exactly (same dart:js_interop
// approach, same Razorpay JS options shape). Deliberately does NOT port
// that file's `openCheckout()` (which calls `createRazorpayOrder` and
// trusts a client-supplied amount) -- apps/seller has no use for it: the
// ₹50 seller AI activation fee is always priced server-side by
// `createSellerAiActivationOrder`, never by this client.
//
// OWNER DECISION (2026-09-08, via AskUserQuestion): this checkout is
// web-only, mirroring the Sales Associate onboarding fee's own D2
// (Play-safety, external-payment-steering) restriction -- no prior AI-4/
// AI-4B/AI-4C claim-time note had resolved whether the seller AI fee needed
// the same restriction; this phase's own investigation surfaced the
// question and the owner chose to mirror D2 rather than risk a Play policy
// violation on Android. See docs/active/BRANCH_DISPOSITIONS.md's AI-4C row.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Callback type for payment success
typedef RazorpayWebSuccessCallback = void Function(
    String paymentId, String? orderId, String? signature);

/// Callback type for payment failure
typedef RazorpayWebFailureCallback = void Function(String error);

/// JS interop for window.eval
@JS('eval')
external JSAny? _eval(String code);

/// JS interop for setting window properties
@JS('window')
external JSObject get _window;

/// Web-specific Razorpay Service using dart:js_interop, scoped to the
/// existing-order checkout flow only.
class RazorpayWebService {
  RazorpayWebSuccessCallback? _onSuccess;
  RazorpayWebFailureCallback? _onFailure;

  /// Initialize the service with callbacks
  void initialize({
    required RazorpayWebSuccessCallback onSuccess,
    required RazorpayWebFailureCallback onFailure,
  }) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
  }

  /// Opens the checkout modal for an order ALREADY created server-side (by
  /// `createSellerAiActivationOrder`, which prices the ₹50 fee from a fixed
  /// server constant -- never a client-supplied amount).
  Future<void> openCheckoutForExistingOrder({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    _openRazorpayModal(
      keyId: keyId,
      orderId: orderId,
      amountPaise: amountPaise,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      description: description,
    );
  }

  /// Open the Razorpay checkout modal using JS eval.
  void _openRazorpayModal({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) {
    try {
      final desc = description ?? 'Order Payment';

      // Escape special characters in user inputs
      final escapedName =
          userName.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final escapedEmail =
          userEmail.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final escapedPhone =
          userPhone.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final escapedDesc = desc.replaceAll("'", "\\'").replaceAll('"', '\\"');

      // Store dart callbacks via JS for access from Razorpay handler
      _setupCallbacks();

      final jsCode = '''
        (function() {
          if (typeof window.Razorpay === 'undefined') {
            if (window._agrimoreSellerAiFailure) {
              window._agrimoreSellerAiFailure('Razorpay checkout script not loaded');
            }
            return;
          }

          var options = {
            key: '$keyId',
            order_id: '$orderId',
            amount: $amountPaise,
            currency: 'INR',

            name: 'Agrimore',
            description: '$escapedDesc',
            image: 'https://agrimore.in/icons/Icon-192.png',

            prefill: {
              name: '$escapedName',
              email: '$escapedEmail',
              contact: '$escapedPhone'
            },

            theme: {
              color: '#2D7D3C',
              backdrop_color: 'rgba(45, 125, 60, 0.85)',
              hide_topbar: false
            },

            retry: {
              enabled: true,
              max_count: 3
            },

            handler: function(response) {
              if (window._agrimoreSellerAiSuccess) {
                window._agrimoreSellerAiSuccess(
                  response.razorpay_payment_id || '',
                  response.razorpay_order_id || '',
                  response.razorpay_signature || ''
                );
              }
            },

            modal: {
              confirm_close: true,
              animation: true,
              backdropclose: false,
              escape: false,
              ondismiss: function() {
                if (window._agrimoreSellerAiDismiss) window._agrimoreSellerAiDismiss();
              }
            },

            notes: {
              app: 'Agrimore',
              platform: 'web',
              order_source: 'seller_ai_activation'
            }
          };

          try {
            var rzp = new window.Razorpay(options);
            rzp.on('payment.failed', function(response) {
              var error = 'Payment failed';
              if (response && response.error) {
                error = response.error.description || response.error.reason || response.error.code || error;
              }
              if (window._agrimoreSellerAiFailure) window._agrimoreSellerAiFailure(error);
            });
            rzp.open();
          } catch(e) {
            var error = e && e.message ? e.message : 'Failed to open Razorpay checkout';
            if (window._agrimoreSellerAiFailure) window._agrimoreSellerAiFailure(error);
          }
        })();
      ''';

      _eval(jsCode);
    } catch (e) {
      _onFailure?.call('Failed to open payment: ${e.toString()}');
    }
  }

  /// Set up JS callbacks that bridge to Dart. Namespaced
  /// (`_agrimoreSellerAi*`) distinctly from apps/marketplace's own
  /// `_agrimore*` window globals -- these are two separate web apps/
  /// origins in production, but keeping the names distinct avoids any
  /// confusion when reading either file side by side.
  void _setupCallbacks() {
    final successFn = (
      JSString? paymentId,
      JSString? orderId,
      JSString? signature,
    ) {
      try {
        final paymentIdValue = paymentId?.toDart ?? '';
        final orderIdValue = orderId?.toDart;
        final signatureValue = signature?.toDart;
        _onSuccess?.call(paymentIdValue, orderIdValue, signatureValue);
      } catch (e) {
        _onSuccess?.call('', null, null);
      }
    }.toJS;

    final dismissFn = () {
      _onFailure?.call('Payment cancelled by user');
    }.toJS;

    final failureFn = (JSString? error) {
      final errorValue = error?.toDart ?? 'Payment failed';
      _onFailure?.call(errorValue);
    }.toJS;

    _eval(
        'window._agrimoreSellerAiSuccess = null; window._agrimoreSellerAiDismiss = null; window._agrimoreSellerAiFailure = null;');

    _setWindowCallback('_agrimoreSellerAiSuccess', successFn);
    _setWindowCallback('_agrimoreSellerAiDismiss', dismissFn);
    _setWindowCallback('_agrimoreSellerAiFailure', failureFn);
  }

  /// Set a callback function on window
  void _setWindowCallback(String name, JSFunction fn) {
    _window.setProperty(name.toJS, fn);
  }

  /// Dispose method
  void dispose() {
    _onSuccess = null;
    _onFailure = null;
    try {
      _eval(
          'delete window._agrimoreSellerAiSuccess; delete window._agrimoreSellerAiDismiss; delete window._agrimoreSellerAiFailure;');
    } catch (_) {}
  }
}
