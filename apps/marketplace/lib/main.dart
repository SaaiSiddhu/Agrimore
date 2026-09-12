import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, PlatformDispatcher;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'providers/location_settings_provider.dart';
import 'providers/home_grocery_strip_config_provider.dart';
import 'providers/home_product_section_config_provider.dart';
import 'providers/review_provider.dart';
import 'providers/search_provider.dart';
import 'providers/bestseller_provider.dart';
import 'providers/category_section_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/product_credit_provider.dart';
import 'providers/section_banner_provider.dart';
import 'providers/seller_provider.dart';
import 'providers/shop_entry_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/market_mode_provider.dart';
import 'providers/ai_connection_provider.dart';
import 'providers/rfq_provider.dart';

// ============================================
// Phase 16B-3, Workstream 5a — OPT-IN Firebase emulator wiring.
// ============================================
// Exists so onboarding/checkout UI can be visually verified against a
// local emulator instead of production, without a temporary hack that
// could get committed by accident. `_useFirebaseEmulator` defaults to
// `false` and every other constant below is only ever read when it is
// `true` — so a normal build (any build that doesn't pass
// `--dart-define=USE_FIREBASE_EMULATOR=true` explicitly) is bit-identical
// to before this change. THIS MUST NEVER BE ENABLED IN A RELEASE BUILD —
// there is no default, CI flag, or environment variable that turns it on;
// it requires an explicit, manual `--dart-define` on every single run.
const bool _useFirebaseEmulator =
    bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
const String _firebaseEmulatorHost =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const int _firestoreEmulatorPort =
    int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const int _authEmulatorPort =
    int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const int _functionsEmulatorPort =
    int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);

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
    // Phase 16B-3, Workstream 5a: opt-in only, see the constants above.
    // Placed here — after Firebase.initializeApp, before anything else
    // (including the Provider constructors in runApp below, several of
    // which touch Firestore) can grab a FirebaseFirestore/FirebaseAuth/
    // FirebaseFunctions singleton — so emulator config is guaranteed to be
    // in effect before any real use.
    if (_useFirebaseEmulator) {
      debugPrint(
          '🧪 USE_FIREBASE_EMULATOR=true — pointing Auth/Firestore/Functions at $_firebaseEmulatorHost');
      await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, _authEmulatorPort);
      FirebaseFirestore.instance
          .useFirestoreEmulator(_firebaseEmulatorHost, _firestoreEmulatorPort);
      FirebaseFunctions.instance
          .useFunctionsEmulator(_firebaseEmulatorHost, _functionsEmulatorPort);
    }
    // Phase M2: real crash reporting. Debug builds stay silent — kReleaseMode is
    // the actual gate (not the native ENABLE_CRASHLYTICS BuildConfig field in
    // android/app/build.gradle.kts, which Dart code cannot read without a
    // platform channel; that field is kept in sync purely as documentation for
    // native-code readers). Forwards Flutter framework errors AND uncaught
    // async/platform errors. PII-safe: Crashlytics receives stack traces and
    // exception messages only — no setCustomKey/log call anywhere in this app
    // sends phone numbers, addresses, order contents or payment identifiers.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint('⚠️ Uncaught async error: $error\n$stack');
      }
      return true;
    };
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
        ChangeNotifierProvider(create: (_) => LocationSettingsProvider()),
        ChangeNotifierProvider(create: (_) => HomeGroceryStripConfigProvider()),
        ChangeNotifierProvider(create: (_) => HomeProductSectionConfigProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => BestsellerProvider()),
        ChangeNotifierProvider(create: (_) => CategorySectionProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ProductCreditProvider()),
        ChangeNotifierProvider(create: (_) => SectionBannerProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => ShopEntryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => MarketModeProvider()),
        ChangeNotifierProvider(create: (_) => AiConnectionProvider()),
        ChangeNotifierProvider(create: (_) => RfqProvider()),
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

  // PERF-1: fire-and-forget, deliberately NOT awaited and NOT placed before
  // runApp() above. This used to be `await`ed inside the try block before
  // runApp — on a release build it activates Play Integrity (Android) /
  // App Attest (iOS), a network attestation round-trip with fixed latency
  // that held the app's very first frame behind it (nothing can render
  // before runApp is called), which is what produced "stuck after the
  // native splash screen" regardless of connection speed. App Check is
  // monitoring-only here (see AppCheckService's header comment — no
  // `enforceAppCheck` anywhere), so nothing downstream needs to wait on it;
  // AppCheckService.activate() already swallows its own errors internally,
  // so no additional error handling is needed at this call site.
  AppCheckService.activate();
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

/// Reads [key] out of an FCM `data` payload as a trimmed, non-empty String.
///
/// FCM delivers every `data` value as a string over the wire, but the map is
/// typed `Map<String, dynamic>` — so an `as String?` cast here would throw on
/// anything unexpected. Type-check instead; this must never be able to throw.
String? _notificationDataString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void _handleNotificationTap(RemoteMessage message) {
  debugPrint('📱 Handling Notification Tap: ${message.data}');

  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    debugPrint('⚠️ Navigator is not ready to route notification');
    return;
  }

  final type = message.data['type'];
  final orderId = _notificationDataString(message.data, 'orderId');
  final productId = _notificationDataString(message.data, 'productId');

  // Path-style navigation, matching what NotificationService's own
  // handleNotificationNavigation already does successfully for foreground
  // local-notification taps. routes.dart's `/order/` and `/product/` prefix
  // handlers parse the id straight out of the path.
  //
  // This replaces `pushNamed(AppRoutes.orderDetails, arguments: {'orderId': id})`.
  // That form handed a Map to a route case that casts its arguments to String?;
  // the resulting _CastError was swallowed by onGenerateRoute's own try/catch and
  // turned into the 404 screen, so EVERY background and terminated-state
  // notification tap dead-ended. Both this call site and the route case have been
  // fixed — see AppRoutes._idArgument.
  if (type == 'order' || type == 'order_update') {
    if (orderId != null) {
      navigator.pushNamed('/order/$orderId');
    } else {
      // A blank id would build the bare path '/order/', which the prefix handler
      // deliberately rejects — send the user to their order list instead of 404.
      navigator.pushNamed(AppRoutes.orders);
    }
  } else if (type == 'product') {
    if (productId != null) {
      navigator.pushNamed('/product/$productId');
    } else {
      // Previously this branch did nothing at all, leaving the tap dead.
      navigator.pushNamed(AppRoutes.main);
    }
  } else if (type == 'offer') {
    navigator.pushNamed(AppRoutes.offers);
  } else {
    // general or fallback
    navigator.pushNamed(AppRoutes.main);
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
