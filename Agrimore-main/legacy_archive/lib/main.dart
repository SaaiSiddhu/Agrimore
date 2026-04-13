import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'app/app.dart';

import 'services/shared_preferences_service.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';

import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/coupon_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/category_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/address_provider.dart';
import 'providers/order_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/sponsored_banner_provider.dart';

// ============================================
// MAIN ENTRY POINT
// ============================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Initialize Firebase
  debugPrint('🔥 Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
  }

  // Initialize AdMob
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
      debugPrint('✅ AdMob initialized');
    } catch (e) {
      debugPrint('❌ AdMob init error: $e');
    }
  }

  // Initialize Auth Persistence
  try {
    final authService = AuthService();
    await authService.initializePersistence();
    debugPrint('✅ Auth persistence set');
  } catch (e) {
    debugPrint('⚠️ Persistence error: $e');
  }

  // Initialize Notifications
  try {
    if (kIsWeb) {
      await FCMService().initialize();
    } else {
      await NotificationService.initialize();
    }
    debugPrint('✅ Notifications ready');
  } catch (e) {
    debugPrint('⚠️ Notification init error: $e');
  }

  // Initialize SharedPreferences
  try {
    await SharedPreferencesService.init();
    debugPrint('✅ SharedPreferences ready');
  } catch (e) {
    debugPrint('❌ SharedPreferences error: $e');
  }

  // Configure system UI (portrait only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Initial system UI - will be updated by theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  debugPrint('🚀 Starting Agrimore App...');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CouponProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProvider(create: (_) => SponsoredBannerProvider()),
      ],
      child: const AgrimoreApp(),
    ),
  );
}

// ============================================
// UPDATE SYSTEM UI BASED ON THEME
// ============================================
void updateSystemUIForTheme(bool isDark) {
  if (kIsWeb) return;
  
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ),
  );
  debugPrint('🎨 System UI updated for ${isDark ? "dark" : "light"} mode');
}
