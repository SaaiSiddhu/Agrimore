// Web-specific Razorpay service using JavaScript interop
// This file should only be imported on web platform
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Callback type for payment success
typedef RazorpayWebSuccessCallback = void Function(String paymentId, String? orderId, String? signature);

/// Callback type for payment failure
typedef RazorpayWebFailureCallback = void Function(String error);

/// Web-specific Razorpay Service using dart:js
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
  
  /// Open the Razorpay checkout modal using direct JS evaluation
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
      
      // Store callbacks in window for JS access
      js.context['_razorpaySuccess'] = js.allowInterop((dynamic response) {
        final paymentId = js_util.getProperty(response, 'razorpay_payment_id')?.toString() ?? '';
        final respOrderId = js_util.getProperty(response, 'razorpay_order_id')?.toString();
        final signature = js_util.getProperty(response, 'razorpay_signature')?.toString();
        debugPrint('✅ Payment successful: $paymentId');
        _onSuccess?.call(paymentId, respOrderId, signature);
      });
      
      js.context['_razorpayDismiss'] = js.allowInterop(() {
        _onFailure?.call('Payment cancelled by user');
      });
      
      // Use window.Razorpay explicitly to ensure we access the global constructor
      final jsCode = '''
        (function() {
          console.log('🚀 Agrimore Premium Razorpay Checkout...');
          console.log('window.Razorpay type:', typeof window.Razorpay);
          
          if (typeof window.Razorpay === 'undefined') {
            console.error('Razorpay is not available on window');
            if (window._razorpayDismiss) window._razorpayDismiss();
            return;
          }
          
          var options = {
            // Core payment info
            key: '$keyId',
            order_id: '$orderId',
            amount: $amountPaise,
            currency: 'INR',
            
            // 🌿 Premium Agrimore Branding
            name: 'Agrimore',
            description: '$escapedDesc',
            image: 'https://agrimore.in/icons/Icon-192.png',
            
            // Customer prefill for faster checkout
            prefill: {
              name: '$escapedName',
              email: '$escapedEmail',
              contact: '$escapedPhone'
            },
            
            // 🎨 Premium Theme
            theme: {
              color: '#2E7D32',
              backdrop_color: 'rgba(27, 94, 32, 0.85)',
              hide_topbar: false
            },
            
            // Smart retry on failure
            retry: {
              enabled: true,
              max_count: 3
            },
            
            // Remember customer
            remember_customer: true,
            
            // 🔔 SMS hash for auto-read OTP
            send_sms_hash: true,
            
            // Payment success handler
            handler: function(response) {
              console.log('✅ Payment success:', response);
              if (window._razorpaySuccess) window._razorpaySuccess(response);
            },
            
            // Modal options
            modal: {
              confirm_close: true,
              animation: true,
              backdropclose: false,
              escape: false,
              ondismiss: function() {
                console.log('❌ Payment cancelled');
                if (window._razorpayDismiss) window._razorpayDismiss();
              }
            },
            
            // Notes for tracking
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
            if (window._razorpayDismiss) window._razorpayDismiss();
          }
        })();
      ''';
      
      debugPrint('📺 Executing Razorpay JS code...');
      js.context.callMethod('eval', [jsCode]);
      debugPrint('✅ Razorpay JS executed');
    } catch (e) {
      debugPrint('❌ Error in _openRazorpayModal: $e');
      _onFailure?.call('Failed to open payment: ${e.toString()}');
    }
  }
  
  /// Dispose method
  void dispose() {
    _onSuccess = null;
    _onFailure = null;
    try {
      js.context.deleteProperty('_razorpaySuccess');
      js.context.deleteProperty('_razorpayDismiss');
    } catch (_) {}
  }
}
