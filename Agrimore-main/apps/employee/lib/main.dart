// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart'
    hide DefaultFirebaseOptions;
import 'app/app.dart';
import 'providers/auth_provider.dart';

// ============================================
// Phase 16C, Workstream 0 — OPT-IN Firebase emulator wiring.
// ============================================
// Mirrors apps/marketplace/lib/main.dart's Phase 16B-3 pattern exactly, so
// this app can finally be visually verified against a local emulator
// instead of production. `_useFirebaseEmulator` defaults to `false` and
// every constant below is only ever read when it is `true` — a normal
// build (any build that doesn't pass
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } else {
    await Firebase.initializeApp();
  }
  // Phase 16C, Workstream 0: opt-in only, see the constants above. Placed
  // here — after Firebase.initializeApp, before runApp and its provider
  // constructors — so emulator config is guaranteed to be in effect before
  // anything can grab a FirebaseFirestore/FirebaseAuth/FirebaseFunctions
  // singleton.
  if (_useFirebaseEmulator) {
    debugPrint(
        '🧪 USE_FIREBASE_EMULATOR=true — pointing Auth/Firestore/Functions at $_firebaseEmulatorHost');
    await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, _authEmulatorPort);
    FirebaseFirestore.instance
        .useFirestoreEmulator(_firebaseEmulatorHost, _firestoreEmulatorPort);
    FirebaseFunctions.instance
        .useFunctionsEmulator(_firebaseEmulatorHost, _functionsEmulatorPort);
  }
  // Phase 17, Workstream 2: monitoring mode only — see
  // AppCheckService's header comment. Never blocks startup (activate()
  // swallows its own errors internally).
  await AppCheckService.activate();
  await NotificationService.initialize();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const EmployeeApp());
}

class EmployeeApp extends StatelessWidget {
  const EmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmployeeAuthProvider()),
      ],
      child: const App(),
    );
  }
}
