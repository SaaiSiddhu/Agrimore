import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'app/app.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agrimore_services/agrimore_services.dart' hide DefaultFirebaseOptions;
import 'package:agrimore_core/agrimore_core.dart' hide DefaultFirebaseOptions;
import 'package:shared_preferences/shared_preferences.dart';

import 'app/routes.dart';
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
import 'providers/seller_provider.dart';
import 'providers/shop_entry_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/market_mode_provider.dart';

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

  // Share the app's global navigatorKey with NotificationService
  // so notification taps route to the correct pages
  NotificationService.navigatorKey = navigatorKey;

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
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => ShopEntryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => MarketModeProvider()),
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

// Whether the user has already been shown the in-app "Enable Notifications"
// priming screen (see EnableNotificationsScreen) on this device. Until then,
// we must NOT trigger the OS permission dialog — it needs to be the result
// of that screen's own "Enable Notifications" button, not something that
// fires silently before the user has even logged in.
Future<bool> _notificationsPrimed() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageConstants.keyNotificationsPrimed) ?? false;
  } catch (_) {
    return false;
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

    // FCM (fire-and-forget) — only once the user has been through the
    // in-app notifications priming screen, so we don't steal that moment.
    if (await _notificationsPrimed()) {
      FCMService().initialize(onNotificationTap: _handleNotificationTap).catchError((e) {
        debugPrint('⚠️ FCM error: $e');
        return null;
      });
    }
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

    // SharedPreferences
    try {
      await SharedPreferencesService.init();
      debugPrint('✅ SharedPreferences ready');
    } catch (e) {
      debugPrint('⚠️ SharedPrefs error: $e');
    }

    // Notifications + FCM — deferred until the in-app priming screen has
    // run once on this device (see EnableNotificationsScreen), so the OS
    // permission dialog never appears before the user reaches it.
    if (await _notificationsPrimed()) {
      try {
        await NotificationService.initialize();
        debugPrint('✅ Notifications ready');
      } catch (e) {
        debugPrint('⚠️ Notification error: $e');
      }

      FCMService().initialize(onNotificationTap: _handleNotificationTap).catchError((e) {
        debugPrint('⚠️ FCM error: $e');
        return null;
      });
    }

    // Handle notification that launched the app from terminated state
    if (!kIsWeb) {
      try {
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('📱 App launched from notification (terminated state)');
          // Delay to allow navigator to be ready
          Future.delayed(const Duration(seconds: 2), () {
            _handleNotificationTap(initialMessage);
          });
        }
      } catch (e) {
        debugPrint('⚠️ getInitialMessage error: $e');
      }
    }
  });
}

// ============================================
// HANDLE NOTIFICATION TAP
// ============================================
void _handleNotificationTap(RemoteMessage message) {
  debugPrint('📱 Handling Notification Tap: ${message.data}');
  
  if (navigatorKey.currentState == null) {
    debugPrint('⚠️ Navigator is not ready to route notification');
    return;
  }
  
  final type = message.data['type'];
  final orderId = message.data['orderId'];
  final productId = message.data['productId'];
  
  if (type == 'order' || type == 'order_update') {
    if (orderId != null) {
      navigatorKey.currentState!.pushNamed(
        AppRoutes.orderDetails, 
        arguments: {'orderId': orderId}
      );
    } else {
      navigatorKey.currentState!.pushNamed(AppRoutes.orders);
    }
  } else if (type == 'product') {
    if (productId != null) {
      navigatorKey.currentState!.pushNamed(
        AppRoutes.productDetails,
        arguments: {'productId': productId}
      );
    }
  } else if (type == 'offer') {
    navigatorKey.currentState!.pushNamed(AppRoutes.offers); 
  } else {
    // general or fallback
    navigatorKey.currentState!.pushNamed(AppRoutes.main);
  }
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
