import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'app/app.dart';

import 'package:agrimore_services/agrimore_services.dart' hide DefaultFirebaseOptions;

import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/coupon_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/category_provider.dart';
import 'providers/address_provider.dart';
import 'providers/order_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/review_provider.dart';
import 'providers/search_provider.dart';
import 'providers/bestseller_provider.dart';
import 'providers/category_section_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/section_banner_provider.dart';

// ============================================
// MAIN ENTRY POINT - MARKETPLACE APP
// ============================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // CRITICAL: Firebase MUST be initialized before runApp
  // (Providers like CartProvider use Firestore in constructors)
  debugPrint('🔥 Initializing Firebase...');
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase error: $e');
  }

  // Set system UI immediately (no await needed)
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // START APP IMMEDIATELY - don't wait for services
  debugPrint('🚀 Starting Agrimore Marketplace (Fast Start)...');
  
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()), // For review dialog
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CouponProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => BestsellerProvider()),
        ChangeNotifierProvider(create: (_) => CategorySectionProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SectionBannerProvider()),
      ],
      child: const MarketplaceApp(),
    ),
  );
  
  // Defer all services to background - UI is already visible
  if (kIsWeb) {
    _initializeDeferredWebServices();
  } else {
    _initializeDeferredMobileServices();
  }
}

// Web: Deferred non-critical services (runs after first frame)
void _initializeDeferredWebServices() {
  Future.microtask(() async {
    // Auth persistence
    try {
      await AuthService().initializePersistence();
      debugPrint('✅ Auth ready');
    } catch (e) {
      debugPrint('⚠️ Auth error: $e');
    }
    
    // SharedPreferences
    try {
      await SharedPreferencesService.init();
      debugPrint('✅ SharedPreferences ready');
    } catch (e) {
      debugPrint('⚠️ SharedPrefs error: $e');
    }
    
    // FCM (fire-and-forget - don't block on network errors)
    FCMService().initialize().catchError((e) {
      debugPrint('⚠️ FCM error: $e');
      return null;
    });
  });
}

// Mobile: Deferred initialization (runs after UI is visible)
void _initializeDeferredMobileServices() {
  Future.microtask(() async {
    // Auth persistence
    try {
      await AuthService().initializePersistence();
      debugPrint('✅ Auth ready');
    } catch (e) {
      debugPrint('⚠️ Auth error: $e');
    }
    
    // Notifications
    try {
      await NotificationService.initialize();
      debugPrint('✅ Notifications ready');
    } catch (e) {
      debugPrint('⚠️ Notification error: $e');
    }
    
    // SharedPreferences
    try {
      await SharedPreferencesService.init();
      debugPrint('✅ SharedPreferences ready');
    } catch (e) {
      debugPrint('⚠️ SharedPrefs error: $e');
    }
    
    // FCM (fire-and-forget)
    FCMService().initialize().catchError((e) {
      debugPrint('⚠️ FCM error: $e');
      return null;
    });
  });
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
