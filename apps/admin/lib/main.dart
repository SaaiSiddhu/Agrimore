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
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
  }

  // ADMR-75/76: opt-in only, see the constants above. Placed here — after
  // Firebase.initializeApp, before anything else (including
  // AppCheckService.activate() and any Provider construction that might
  // grab a Firestore/Auth/Functions/Storage singleton) — so emulator config
  // is guaranteed to be in effect before any real use. Unlike every OTHER
  // init step in this file (which logs and continues), a failure HERE is
  // FATAL when emulator mode was explicitly requested: silently continuing
  // would leave the app connected to REAL production Firebase while the
  // operator believes they are safely testing locally -- exactly the
  // failure mode the owner's own prompt names. A comment saying "never
  // enable in release" is not enforcement; refusing to start is.
  if (_useFirebaseEmulator) {
    try {
      debugPrint(
          '🧪 USE_FIREBASE_EMULATOR=true — pointing Auth/Firestore/Functions/Storage at $_firebaseEmulatorHost');
      await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, _authEmulatorPort);
      FirebaseFirestore.instance.useFirestoreEmulator(_firebaseEmulatorHost, _firestoreEmulatorPort);
      FirebaseFunctions.instance.useFunctionsEmulator(_firebaseEmulatorHost, _functionsEmulatorPort);
      await FirebaseStorage.instance.useStorageEmulator(_firebaseEmulatorHost, _storageEmulatorPort);
    } catch (e) {
      debugPrint('🛑 FATAL: emulator wiring requested but failed, refusing to start: $e');
      runApp(_EmulatorWiringFailedApp(error: e.toString()));
      return;
    }
  }

  // Phase 17, Workstream 2: monitoring mode only — see
  // AppCheckService's header comment. Never blocks startup.
  // ADMR-87: skipped entirely in emulator mode. Found live, not assumed —
  // AppCheckService's web ReCaptchaV3Provider is constructed with the
  // still-placeholder kRecaptchaV3SiteKey regardless of emulator mode;
  // activate() itself fails open as designed, but FirebaseAuth's own
  // token-fetch-per-request (@firebase/auth's "Error while retrieving App
  // Check token: AppCheck: ReCAPTCHA error") corrupts the emulator sign-in
  // request enough to make the Auth EMULATOR reject valid credentials as
  // invalid-credential — real credentials, confirmed directly against the
  // Auth emulator's own REST API, still failed through the app. App Check
  // has no reason to run against a local test session at all (mirrors this
  // same file's own emulator-config-before-any-real-use ordering rationale
  // just above), so it is skipped outright rather than merely allowed to
  // fail open.
  if (!_useFirebaseEmulator) {
    try {
      await AppCheckService.activate();
    } catch (e) {
      debugPrint('⚠️ App Check init error: $e');
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
      // ADMR-76: a real, in-app, tool-independent visible indicator when
      // emulator mode is active -- see _EmulatorModeBanner's own comment.
      child: _useFirebaseEmulator ? const _EmulatorModeBanner(child: AdminApp()) : const AdminApp(),
    ),
  );
}

/// ADMR-76: shown INSTEAD of the real app when USE_FIREBASE_EMULATOR=true
/// but wiring the emulator connections itself threw. Refusing to start is
/// the enforcement; a "never enable in release" comment alone is not.
class _EmulatorWiringFailedApp extends StatelessWidget {
  const _EmulatorWiringFailedApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dangerous_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Emulator configuration failed',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'USE_FIREBASE_EMULATOR was set but connecting to the local emulator failed. '
                  'Refusing to start rather than risk silently running against production.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(error, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ADMR-76: a real, in-app, tool-independent visible indicator. ADMR-75's
/// own checklist entry mistakenly credited a "Running in emulator mode..."
/// banner seen during a browser-driven check to this app's own emulator
/// wiring -- a fresh grep across the whole source tree found zero matches
/// for that text anywhere in this codebase. That banner was injected by the
/// browser tooling used to view the page, NOT the app itself, so it would
/// NOT appear on a real device or a different browser. This widget closes
/// that gap for real: it renders from the app's OWN widget tree, so it
/// appears identically on web, Android and iOS whenever emulator mode is
/// genuinely active.
class _EmulatorModeBanner extends StatelessWidget {
  const _EmulatorModeBanner({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  color: Colors.red.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text(
                    'TEST MODE — connected to local emulator, not production',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
