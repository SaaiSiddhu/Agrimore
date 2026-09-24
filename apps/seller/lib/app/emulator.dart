import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// Decision D13 — OPT-IN local Firebase emulators, same switch as
// apps/marketplace and apps/employee. `kSellerUsesEmulator` defaults to false
// and every constant here is only read when it is true, so a normal build
// (anything not passing `--dart-define=USE_FIREBASE_EMULATOR=true`
// explicitly) is unchanged. THIS MUST NEVER BE ENABLED IN A RELEASE BUILD:
// there is no default, flag or environment variable that turns it on.
//
// With it, Auth, Firestore, Functions and Storage all go to the emulators
// (from an Android emulator the host is 10.0.2.2), the app shows the
// "TEST DATA" ribbon, and App Check / push registration are skipped — so an
// end-to-end run never touches the live project.
const bool kSellerUsesEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
const String _host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const int _firestorePort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const int _authPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const int _functionsPort = int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const int _storagePort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

/// Call right after Firebase.initializeApp, before anything uses Firebase.
Future<void> connectSellerEmulators() async {
  if (!kSellerUsesEmulator) return;
  debugPrint('🧪 USE_FIREBASE_EMULATOR=true — Auth/Firestore/Functions/Storage at $_host');
  await FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
  FirebaseFunctions.instance.useFunctionsEmulator(_host, _functionsPort);
  await FirebaseStorage.instance.useStorageEmulator(_host, _storagePort);
}
