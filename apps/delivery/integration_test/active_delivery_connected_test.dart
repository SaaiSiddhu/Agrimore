// Phase DLVR2 — the FIRST genuinely connected active-delivery acceptance
// journey: real Firebase emulators (Auth+Firestore), the real
// ActiveOrderScreen widget tree bound to the real DeliveryOrderProvider
// (no injected fake stream), a real Firestore snapshot driving the
// reassignment-while-viewing reconciliation DLVMAP3 built.
//
// Sign-in deliberately never touches the real phone-OTP UI (this
// repository's own recorded near-miss, agrimore-near-miss-real-otp-via-
// partial-emulator-isolation, says to always use the harness-bypass
// pattern instead) -- a custom token minted by the fixture script signs
// FirebaseAuth in directly, reaching zero OTP code.
//
// Run with (from apps/delivery, both Firestore AND Auth emulators, plus the
// fixtures seeded first -- see scripts/dlvr2_run.sh for the full sequence):
//   flutter test integration_test/active_delivery_connected_test.dart \
//     -d <device> \
//     --dart-define=USE_FIREBASE_EMULATOR=true \
//     --dart-define=FIREBASE_EMULATOR_HOST=<host> \
//     --dart-define=FIRESTORE_EMULATOR_PORT=<port> \
//     --dart-define=AUTH_EMULATOR_PORT=9099
import 'dart:convert';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:delivery/data/rider_history.dart' show historyOrder;
import 'package:delivery/design_system/design_system.dart' show DeliveryIcons;
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

/// The fixture script's own (functions/scripts/
/// phaseDLVR2_active_delivery_fixtures.js `seed`) JSON output -- riderA/
/// riderB/orderId/tokenA/tokenB/tokenAdmin -- passed as a dart-define
/// string, NOT a shared file path: this test may run ON THE DEVICE (the
/// test binary IS the app under test), which has no access to the HOST
/// machine's own filesystem at all.
const _fixturesJson = String.fromEnvironment('DLVR2_FIXTURES_JSON', defaultValue: '{}');

/// Mirrors main.dart's own dart-define reads EXACTLY -- a second, named
/// Firebase App instance (for the admin-style backend action below) has no
/// automatic emulator wiring of its own; it needs the SAME host/ports the
/// main app instance was started with, read independently here since
/// main.dart's own constants are private to that file.
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const _firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const _authEmulatorPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const _functionsEmulatorPort = int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const _storageEmulatorPort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

/// A SEPARATE, independently-authenticated Firebase App instance signed in
/// as the fixture's own admin test user -- performs the admin-style
/// backend action (reassignment) via the real client SDK, entirely
/// independent of Rider A's own already-signed-in main app instance. This
/// is the connected-test equivalent of the fixture script's own `reassign`
/// CLI mode; that Admin-SDK version cannot be shelled out to from an
/// on-device integration test (dart:io.Process does not run on-device --
/// the test binary IS the app under test), so this uses the client SDK's
/// own already-authorized isAdmin() rule path instead.
Future<FirebaseFirestore> _adminFirestore(String tokenAdmin) async {
  final adminApp = await Firebase.initializeApp(
    name: 'dlvr2-admin-${DateTime.now().microsecondsSinceEpoch}',
    options: Firebase.app().options,
  );
  final adminAuth = FirebaseAuth.instanceFor(app: adminApp);
  await adminAuth.useAuthEmulator(_emulatorHost, _authEmulatorPort);
  final adminFirestore = FirebaseFirestore.instanceFor(app: adminApp);
  adminFirestore.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
  await adminAuth.signInWithCustomToken(tokenAdmin);
  return adminFirestore;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> fixtures;

  setUpAll(() async {
    // main.dart's own DLVPP1E sequence, mirrored exactly for the DEFAULT
    // app: this test builds the widget tree directly (never runs main()),
    // so nothing else initializes or emulator-wires the default Firebase
    // app otherwise -- FirebaseAuth.instance below would throw
    // [core/no-app] without this.
    await Firebase.initializeApp();
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authEmulatorPort);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
    FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, _functionsEmulatorPort);
    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, _storageEmulatorPort);

    fixtures = jsonDecode(_fixturesJson) as Map<String, dynamic>;
    expect(fixtures['orderId'], isNotNull,
        reason: 'DLVR2_FIXTURES_JSON dart-define was not provided -- run the seed script first and pass its output');
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('DLVR2 4.2: reassignment while the screen is open (real emulator, real widgets)', (tester) async {
    final riderId = fixtures['riderA'] as String;
    final orderId = fixtures['orderId'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenA'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderId, reason: 'signed in via custom token, never the OTP UI');

    final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    expect(orderSnap.exists, isTrue, reason: 'the fixture script must have already seeded this order');
    final order = historyOrder(orderId, orderSnap.data()!);

    final provider = DeliveryOrderProvider()..bind(riderId);
    addTearDown(provider.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
        ChangeNotifierProvider<DeliveryOrderProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActiveOrderScreen(order: order),
      ),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    // Present and correct BEFORE reassignment: the real customer name from
    // the real Firestore read, not a fixture-independent placeholder.
    expect(find.text('Meenakshi Sundaram'), findsOneWidget,
        reason: 'the live query must have genuinely resolved this order from the real emulator');

    // The admin-style action, via a SEPARATE, independently-signed-in
    // Firebase App instance -- no dedicated admin-reassignment callable
    // exists anywhere in this codebase (confirmed by grep before this
    // phase's own claim), so this mirrors exactly what firestore.rules'
    // own isAdmin() branch already authorizes without restriction: the
    // actual mechanism this schema provides for such an action today.
    final adminFirestore = await _adminFirestore(fixtures['tokenAdmin'] as String);
    await adminFirestore.collection('orders').doc(orderId).update({'deliveryPartnerId': null});

    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    // A REAL Firestore snapshot, not an injected stream event, must have
    // reached _onProviderChanged and flipped RecoveryPhase to removed.
    expect(find.text('Meenakshi Sundaram'), findsNothing,
        reason: 'private customer detail must be gone once the real snapshot confirms reassignment');
    expect(find.text('+919876543210'), findsNothing);
    expect(find.byIcon(DeliveryIcons.home), findsOneWidget, reason: 'the removed screen\'s own Back to Dashboard action');

    await tester.tap(find.byIcon(DeliveryIcons.home));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'back navigation must not throw or leave a stale actionable screen');
  });

  testWidgets('DLVR2 4.2 retest: reassignment while the rider is offline, reconciled on reconnect',
      (tester) async {
    final riderId = fixtures['riderA'] as String;
    final orderId = fixtures['orderId'] as String;

    // The previous test left this order reassigned away; restore it to
    // Rider A first, via the same already-proven admin-client mechanism, so
    // this scenario starts from the same clean "actively assigned" state.
    final adminFirestore = await _adminFirestore(fixtures['tokenAdmin'] as String);
    await adminFirestore.collection('orders').doc(orderId).update({'deliveryPartnerId': riderId});

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenA'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderId, reason: 'signed in via custom token, never the OTP UI');

    final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    expect(orderSnap.data()?['deliveryPartnerId'], riderId, reason: 'restored to Rider A before this scenario');
    final order = historyOrder(orderId, orderSnap.data()!);

    final provider = DeliveryOrderProvider()..bind(riderId);
    addTearDown(provider.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
        ChangeNotifierProvider<DeliveryOrderProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActiveOrderScreen(order: order),
      ),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('Meenakshi Sundaram'), findsOneWidget, reason: 'live query resolved the restored assignment');

    // Only the RIDER's own default-app connection goes offline -- the
    // admin app instance above is a separate FirebaseApp with its own
    // independent network state, so its write below still reaches the
    // real emulator. This matches "the rider's phone loses signal while
    // the backend reassignment still happens", not a full device/process
    // network outage (which would also block the admin write itself).
    await FirebaseFirestore.instance.disableNetwork();

    await adminFirestore.collection('orders').doc(orderId).update({'deliveryPartnerId': null});
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(find.text('Meenakshi Sundaram'), findsOneWidget,
        reason: 'still offline -- must not have received the reassignment yet, so the screen must not have changed');

    await FirebaseFirestore.instance.enableNetwork();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('Meenakshi Sundaram'), findsNothing,
        reason: 'reconnected -- the listener must catch up to the CURRENT state, not stay stuck on the stale cached snapshot');
    expect(find.text('+919876543210'), findsNothing);
    expect(find.byIcon(DeliveryIcons.home), findsOneWidget,
        reason: 'the removed screen\'s own Back to Dashboard action, even after a reconnect-driven update');
  });
}
