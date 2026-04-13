// lib/config/razorpay_config.dart
import 'package:flutter/foundation.dart';

class RazorpayConfig {
  // ✅ LIVE KEYS
  static const String keyId = 'rzp_live_RfCwI1SDSVoN0b';
  static const String keySecret = 'K02v4uSZjPBElHGj7FO4a60g';
  
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