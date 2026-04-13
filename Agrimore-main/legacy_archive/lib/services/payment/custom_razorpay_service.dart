// lib/services/payment/custom_razorpay_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../../config/razorpay_config.dart';

/// 🎨 Custom Razorpay Service - NO POPUP, Fully Custom UI
class CustomRazorpayService {
  
  /// Create Order
  Future<CustomOrderResponse?> createOrder({
    required double amount,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final auth = base64Encode(
        utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}')
      );
      
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/orders'),
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(),
          'currency': 'INR',
          'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
          'notes': notes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("✅ Order Created: ${data['id']}");
        
        return CustomOrderResponse(
          orderId: data['id'],
          amount: data['amount'] / 100,
          currency: data['currency'],
          receipt: data['receipt'],
        );
      } else {
        debugPrint("❌ Order Creation Failed: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Order Exception: $e");
      return null;
    }
  }

  /// Process UPI Payment
  Future<PaymentResponse> processUpiPayment({
    required String orderId,
    required double amount,
    required String vpa, // UPI ID like user@paytm
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      final auth = base64Encode(
        utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}')
      );

      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/payments/create/upi'),
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(),
          'currency': 'INR',
          'order_id': orderId,
          'method': 'upi',
          'vpa': vpa,
          'customer': {
            'name': customerName,
            'email': customerEmail,
            'contact': customerPhone,
          },
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return PaymentResponse(
          success: true,
          paymentId: data['id'],
          orderId: orderId,
          signature: _generateSignature(orderId, data['id']),
          method: 'upi',
        );
      } else {
        return PaymentResponse(
          success: false,
          error: data['error']['description'] ?? 'Payment failed',
          method: 'upi',
        );
      }
    } catch (e) {
      return PaymentResponse(
        success: false,
        error: e.toString(),
        method: 'upi',
      );
    }
  }

  /// Get Available UPI Apps
  List<UpiApp> getAvailableUpiApps() {
    return [
      UpiApp(
        name: 'Google Pay',
        packageName: 'com.google.android.apps.nbu.paisa.user',
        icon: '💳',
        color: const Color(0xFF4285F4),
      ),
      UpiApp(
        name: 'PhonePe',
        packageName: 'com.phonepe.app',
        icon: '📱',
        color: const Color(0xFF5F259F),
      ),
      UpiApp(
        name: 'Paytm',
        packageName: 'net.one97.paytm',
        icon: '💰',
        color: const Color(0xFF00BAF2),
      ),
      UpiApp(
        name: 'BHIM',
        packageName: 'in.org.npci.upiapp',
        icon: '🏦',
        color: const Color(0xFF005BAA),
      ),
      UpiApp(
        name: 'Amazon Pay',
        packageName: 'in.amazon.mShop.android.shopping',
        icon: '🛒',
        color: const Color(0xFFFF9900),
      ),
    ];
  }

  /// Verify Signature
  String _generateSignature(String orderId, String paymentId) {
    final data = '$orderId|$paymentId';
    final key = utf8.encode(RazorpayConfig.keySecret);
    final bytes = utf8.encode(data);
    
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    return digest.toString();
  }

  bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    final generated = _generateSignature(orderId, paymentId);
    return generated == signature;
  }
}

/// Custom Order Response Model
class CustomOrderResponse {
  final String orderId;
  final double amount;
  final String currency;
  final String receipt;

  CustomOrderResponse({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.receipt,
  });
}

/// Payment Response Model
class PaymentResponse {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;
  final String method;

  PaymentResponse({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
    required this.method,
  });
}

/// UPI App Model
class UpiApp {
  final String name;
  final String packageName;
  final String icon;
  final Color color;

  UpiApp({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.color,
  });
}
