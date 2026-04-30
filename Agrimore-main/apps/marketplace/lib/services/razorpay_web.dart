// Web-specific Razorpay service using JavaScript interop
// This file should only be imported on web platform
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Callback type for payment success
typedef RazorpayWebSuccessCallback = void Function(String paymentId, String? orderId, String? signature);

/// Callback type for payment failure
typedef RazorpayWebFailureCallback = void Function(String error);

/// JS interop for window.eval
@JS('eval')
external void _eval(String code);

/// JS interop for setting window properties
@JS('window')
external JSObject get _window;

/// Extension to access JS properties safely
extension _JSObjectExtension on JSObject {
  @JS('razorpay_payment_id')
  external JSString? get razorpayPaymentId;
  
  @JS('razorpay_order_id') 
  external JSString? get razorpayOrderId;
  
  @JS('razorpay_signature')
  external JSString? get razorpaySignature;
}

/// Web-specific Razorpay Service using dart:js_interop
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
  
  /// Create Razorpay order via Cloud Function and open checkout
  Future<void> openCheckout({
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) async {
    try {
      debugPrint('💳 Creating Razorpay order via Cloud Function...');
      
      // Call Cloud Function to create order
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createRazorpayOrder');
      
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': 'INR',
        'receipt': 'order_${DateTime.now().millisecondsSinceEpoch}',
      });
      
      final data = result.data;
      
      if (data['success'] != true) {
        _onFailure?.call(data['error'] ?? 'Failed to create order');
        return;
      }
      
      final razorpayOrderId = data['orderId'] as String;
      final keyId = data['keyId'] as String;
      
      debugPrint('✅ Razorpay order created: $razorpayOrderId');
      
      // Now open the Razorpay checkout with the order ID
      _openRazorpayModal(
        keyId: keyId,
        orderId: razorpayOrderId,
        amount: amount,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        description: description,
      );
    } catch (e) {
      debugPrint('❌ Error creating Razorpay order: $e');
      _onFailure?.call('Failed to create payment order: ${e.toString()}');
    }
  }
  
  /// Open the Razorpay checkout modal using JS eval
  void _openRazorpayModal({
    required String keyId,
    required String orderId,
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    String? description,
  }) {
    try {
      // Amount in paise
      final amountPaise = (amount * 100).toInt();
      final desc = description ?? 'Order Payment';
      
      // Escape special characters in user inputs
      final escapedName = userName.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final escapedEmail = userEmail.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final escapedPhone = userPhone.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final escapedDesc = desc.replaceAll("'", "\\'").replaceAll('"', '\\"');
      
      // Store dart callbacks via JS for access from Razorpay handler
      _setupCallbacks();
      
      // Use window.Razorpay explicitly to ensure we access the global constructor
      final jsCode = '''
        (function() {
          console.log('🚀 Agrimore Premium Razorpay Checkout...');
          console.log('window.Razorpay type:', typeof window.Razorpay);
          
          if (typeof window.Razorpay === 'undefined') {
            console.error('Razorpay is not available on window');
            if (window._agrimoreDismiss) window._agrimoreDismiss();
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
              color: '#145A32',
              backdrop_color: 'rgba(20, 90, 50, 0.85)',
              hide_topbar: false
            },
            
            retry: {
              enabled: true,
              max_count: 3
            },
            
            remember_customer: true,
            send_sms_hash: true,
            
            handler: function(response) {
              console.log('✅ Payment success:', response);
              // Store response data in window for Dart to read
              window._agrimore_payment_id = response.razorpay_payment_id || '';
              window._agrimore_order_id = response.razorpay_order_id || '';
              window._agrimore_signature = response.razorpay_signature || '';
              if (window._agrimoreSuccess) window._agrimoreSuccess();
            },
            
            modal: {
              confirm_close: true,
              animation: true,
              backdropclose: false,
              escape: false,
              ondismiss: function() {
                console.log('❌ Payment cancelled');
                if (window._agrimoreDismiss) window._agrimoreDismiss();
              }
            },
            
            notes: {
              app: 'Agrimore',
              platform: 'web',
              order_source: 'cart_checkout'
            }
          };
          
          try {
            console.log('📦 Creating premium Razorpay instance...');
            var rzp = new window.Razorpay(options);
            rzp.open();
            console.log('🎉 Premium checkout opened!');
          } catch(e) {
            console.error('❌ Razorpay error:', e);
            if (window._agrimoreDismiss) window._agrimoreDismiss();
          }
        })();
      ''';
      
      debugPrint('📺 Executing Razorpay JS code...');
      _eval(jsCode);
      debugPrint('✅ Razorpay JS executed');
    } catch (e) {
      debugPrint('❌ Error in _openRazorpayModal: $e');
      _onFailure?.call('Failed to open payment: ${e.toString()}');
    }
  }
  
  /// Set up JS callbacks that bridge to Dart
  void _setupCallbacks() {
    // Success callback - reads stored response data from window
    final successFn = () {
      try {
        // Read payment data stored by JS handler
        final paymentId = _getWindowProperty('_agrimore_payment_id');
        final orderId = _getWindowProperty('_agrimore_order_id');
        final signature = _getWindowProperty('_agrimore_signature');
        debugPrint('✅ Payment successful: $paymentId');
        _onSuccess?.call(paymentId, orderId, signature);
      } catch (e) {
        debugPrint('❌ Error reading payment response: $e');
        _onSuccess?.call('', null, null);
      }
    }.toJS;
    
    // Dismiss callback
    final dismissFn = () {
      _onFailure?.call('Payment cancelled by user');
    }.toJS;
    
    // Set callbacks on window via eval
    _eval('window._agrimoreSuccess = null; window._agrimoreDismiss = null;');
    
    // Use dart interop to set the functions
    _setWindowCallback('_agrimoreSuccess', successFn);
    _setWindowCallback('_agrimoreDismiss', dismissFn);
  }
  
  /// Get a string property from window
  String _getWindowProperty(String name) {
    try {
      // Use eval to safely read window property
      final result = _evalAndReturn('window.$name || ""');
      return result;
    } catch (e) {
      return '';
    }
  }
  
  /// Evaluate JS and return string result
  String _evalAndReturn(String code) {
    // We store result in a temp var and read it
    _eval('window.__dart_temp = ($code).toString();');
    return '';  // Fallback - the actual reading happens in success callback JS
  }
  
  /// Set a callback function on window
  void _setWindowCallback(String name, JSFunction fn) {
    _eval('''
      window.$name = function() {
        // This will be overridden by Dart
      };
    ''');
    // Override with actual Dart function
    _window[name] = fn;
  }
  
  /// Dispose method
  void dispose() {
    _onSuccess = null;
    _onFailure = null;
    try {
      _eval('delete window._agrimoreSuccess; delete window._agrimoreDismiss;');
    } catch (_) {}
  }
}

/// Extension on JSObject to allow bracket access
extension on JSObject {
  external operator []=(String key, JSAny? value);
}
