// Phase DLVR2 Section 6 (2026-09-28 continuation review) — account-switch
// isolation, connected: the REAL DeliveryApp (main.dart's own top-level
// widget -- the exact one main() boots into, with its real
// DeliveryAuthProvider/DeliveryOrderProvider/LocationProvider/OfferProvider,
// no fakes), real Firebase emulators, real sign-ins via custom tokens.
//
// DeliveryAuthProvider's own cross-session isolation is already covered
// (auth_session_test.dart) and DeliveryOrderProvider's own
// (order_provider_test.dart, plus Section 5's advanceStep/releaseOrder
// generation guard) -- both at the PROVIDER level, with controlled fakes.
// What neither can reach is RiderSessionGate itself (app/app.dart
// _RiderSessionGateState._sync): the widget that WIRES them together --
// binds the order provider, pops the nav stack, clears offer launch, stops
// location tracking, cancels notifications. A plain widget test can't
// reach it either: DeliveryShell's default construction (which
// RiderSessionGate hard-codes, not injectable) touches real Firestore
// (inbox/earnings/account sources), so it needs a real backend regardless
// -- this is deliberately a CONNECTED test, not a fake-heavy one forced
// onto a widget tree that was never designed to run without Firebase.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:delivery/main.dart' show DeliveryApp;
import 'package:delivery/offers/offer_launch.dart' show deliveryNavigatorKey;
import 'package:delivery/screens/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _fixturesJson = String.fromEnvironment('DLVR2_FIXTURES_JSON', defaultValue: '{}');
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const _firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const _authEmulatorPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const _functionsEmulatorPort = int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const _storageEmulatorPort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> fixtures;

  setUpAll(() async {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authEmulatorPort);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
    FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, _functionsEmulatorPort);
    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, _storageEmulatorPort);

    fixtures = jsonDecode(_fixturesJson) as Map<String, dynamic>;
    expect(fixtures['riderB'], isNotNull,
        reason: 'DLVR2_FIXTURES_JSON dart-define was not provided -- run the seed script first and pass its output');
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('DLVR2 Section 6: switching riders pops the nav stack -- a screen opened under rider A does not survive',
      (tester) async {
    final riderA = fixtures['riderA'] as String;
    final riderB = fixtures['riderB'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenA'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderA);

    await tester.pumpWidget(const DeliveryApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    deliveryNavigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('Rider A Secret Screen'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rider A Secret Screen'), findsOneWidget, reason: 'the push itself must have worked');

    // A second, real sign-in switches the CURRENT Firebase user directly
    // (standard SDK behaviour) -- exactly "someone else now uses this
    // device", not a sign-out followed by a separate sign-in.
    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenB'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderB);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'the real account-switch cascade must not throw');

    expect(find.text('Rider A Secret Screen'), findsNothing,
        reason: 'a screen opened under rider A\'s session must not survive into rider B\'s -- '
            'RiderSessionGate must have popped the nav stack back to itself');
  });

  testWidgets('DLVR2 Section 6: a missing user (sign-out) routes to sign-in, never treated as the previous rider',
      (tester) async {
    final riderA = fixtures['riderA'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenA'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderA);

    await tester.pumpWidget(const DeliveryApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsNothing, reason: 'signed in -- must not be on the login screen yet');

    deliveryNavigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('Rider A Secret Screen'))),
    ));
    await tester.pumpAndSettle();

    await FirebaseAuth.instance.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'the real sign-out cascade must not throw');

    expect(find.text('Rider A Secret Screen'), findsNothing,
        reason: 'a missing user must pop back to the gate too, not leave rider A\'s screen reachable');
    expect(find.byType(LoginScreen), findsOneWidget,
        reason: 'a missing user must route to sign-in, never be treated as still being rider A');
  });
}
