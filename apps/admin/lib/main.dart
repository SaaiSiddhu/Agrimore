import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import 'providers/admin_provider.dart';
import 'providers/product_provider.dart';
import 'providers/category_provider.dart';
import 'providers/order_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/sponsored_banner_provider.dart';
import 'providers/coupon_provider.dart';
import 'providers/user_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bestseller_provider.dart';
import 'providers/category_section_provider.dart';
import 'providers/home_product_section_provider.dart';
import 'providers/wallet_config_provider.dart';
import 'providers/section_banner_provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/seller_provider.dart';
import 'providers/benefit_compliance_provider.dart';

// ============================================
// Phase ADMR-75 — OPT-IN Firebase emulator wiring, mirrors
// apps/marketplace's own established Phase 16B-3 pattern exactly. Exists so
// this app's own UI can be visually verified against a local emulator
// instead of production, without a hack that could get committed by
// accident. `_useFirebaseEmulator` defaults to `false` and every other
// constant below is only ever read when it is `true` — a normal build (any
// build that doesn't pass `--dart-define=USE_FIREBASE_EMULATOR=true`
// explicitly) is bit-identical to before this change. THIS MUST NEVER BE
// ENABLED IN A RELEASE BUILD — there is no default, CI flag, or environment
// variable that turns it on; it requires an explicit, manual `--dart-define`
// on every single run. Storage is ALSO wired here (marketplace's own
// snippet doesn't need it; this app extensively touches Storage — KYC
// docs, payout staging docs, support-case evidence).
// ============================================
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
const int _storageEmulatorPort =
    int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

// ============================================
// MAIN ENTRY POINT - ADMIN APP
// ============================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Initialize Firebase
  debugPrint('🔥 Initializing Firebase for Admin...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
    // ADMR-75: opt-in only, see the constants above. Placed here — after
    // Firebase.initializeApp, before anything else (including
    // AppCheckService.activate() and any Provider construction that might
    // grab a Firestore/Auth/Functions/Storage singleton) — so emulator
    // config is guaranteed to be in effect before any real use.
    if (_useFirebaseEmulator) {
      debugPrint(
          '🧪 USE_FIREBASE_EMULATOR=true — pointing Auth/Firestore/Functions/Storage at $_firebaseEmulatorHost');
      await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, _authEmulatorPort);
      FirebaseFirestore.instance.useFirestoreEmulator(_firebaseEmulatorHost, _firestoreEmulatorPort);
      FirebaseFunctions.instance.useFunctionsEmulator(_firebaseEmulatorHost, _functionsEmulatorPort);
      await FirebaseStorage.instance.useStorageEmulator(_firebaseEmulatorHost, _storageEmulatorPort);
    }
    // Phase 17, Workstream 2: monitoring mode only — see
    // AppCheckService's header comment. Never blocks startup.
    await AppCheckService.activate();
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
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

  // Configure system UI
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

  debugPrint('🚀 Starting Agrimore Admin Panel...');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProvider(create: (_) => SponsoredBannerProvider()),
        ChangeNotifierProvider(create: (_) => CouponProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BestsellerProvider()),
        ChangeNotifierProvider(create: (_) => CategorySectionProvider()),
        ChangeNotifierProvider(create: (_) => HomeProductSectionProvider()),
        ChangeNotifierProvider(create: (_) => WalletConfigProvider()),
        ChangeNotifierProvider(create: (_) => SectionBannerProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => BenefitComplianceProvider()),
      ],
      child: const AdminApp(),
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
