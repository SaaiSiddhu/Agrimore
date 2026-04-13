// lib/config/razorpay_config.dart
import 'package:flutter/foundation.dart';

class RazorpayConfig {
  // ✅ LIVE KEYS
  static const String keyId = 'rzp_live_ST1fL8IpN0e24U';
  static const String keySecret = 'i0bLdO15k6K8iK5B989DKc0y';
  
  static const String appName = 'Agrimore';
  static const String currency = 'INR';
  static const int paymentTimeoutSeconds = 300;
  static const int maxRetries = 2;
  static const String themeColor = '#2E7D32';
  
  static bool get isLiveMode => keyId.startsWith('rzp_live_');
  static String get paymentMode => isLiveMode ? '🔴 LIVE' : '🟡 TEST';
  
  static void logConfiguration() {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════');
      debugPrint('🔧 RAZORPAY CONFIGURATION');
      debugPrint('Mode: $paymentMode');
      debugPrint('Key: ${keyId.substring(0, 15)}...');
      debugPrint('═══════════════════════════════════');
    }
  }
}