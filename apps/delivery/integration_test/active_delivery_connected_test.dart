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

/// Polls for a document a server-side trigger writes asynchronously AFTER
/// the callable that caused it already returned (e.g. onRiderDelivery,
/// which fires from a Firestore onUpdate trigger, not from confirmDelivery
/// itself) -- bounded, so a genuine failure to appear fails fast rather
/// than hanging the test's own timeout.
Future<DocumentSnapshot<Map<String, dynamic>>> _waitForDoc(
  DocumentReference<Map<String, dynamic>> ref, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final snap = await ref.get();
    if (snap.exists) return snap;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return ref.get();
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

  testWidgets('DLVR2 4.3: legitimate release ("Seller Not Ready"), before pickup', (tester) async {
    final riderId = fixtures['riderA'] as String;
    final orderId = fixtures['orderIdRelease'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenA'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderId, reason: 'signed in via custom token, never the OTP UI');

    final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    expect(orderSnap.data()?['orderStatus'], 'delivery_accepted',
        reason: 'must start before pickup for the release action to even render');
    final order = historyOrder(orderId, orderSnap.data()!);

    final provider = DeliveryOrderProvider()..bind(riderId);
    addTearDown(provider.dispose);

    // A real push/pop navigation stack -- not ActiveOrderScreen alone as
    // `home:` -- so its own Navigator.pop(context) on a successful release
    // has a genuine underlying route to return to, exactly like the real
    // dashboard -> active-order navigation.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
        ChangeNotifierProvider<DeliveryOrderProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ActiveOrderScreen(order: order)),
                ),
                child: const Text('Open Order'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Order'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    // Renders only before pickup (DeliveryStep.accepted/arrivedAtStore) --
    // confirms the fixture's own status genuinely drives this, not a
    // hardcoded test assumption.
    expect(find.text('Seller not ready'), findsOneWidget);

    // Below the fold in this screen's SingleChildScrollView -- a plain,
    // non-lazy scrollable (unlike DLVH10's Sliver case, everything here is
    // already built, just scrolled away), so ensureVisible alone suffices.
    await tester.ensureVisible(find.text('Seller not ready'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seller not ready'));
    await tester.pumpAndSettle();
    expect(find.text('Release order'), findsOneWidget, reason: 'a real confirm dialog, not a silent action');

    await tester.tap(find.text('Release order'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'the real releaseDeliveryOrder callable dispatch must not throw');

    // No false "reassigned away" alarm: the recovery machine's own masking
    // UI (private-detail-hidden "removed" scaffold) must never appear for a
    // SELF-initiated release -- _leavingByOwnAction suppresses it. Cleanly
    // popped back to the launcher screen instead.
    expect(find.text('Meenakshi Sundaram'), findsNothing, reason: 'popped away, not left on a removed/masked scaffold');
    expect(find.text('Open Order'), findsOneWidget, reason: 'a genuine pop back to the underlying screen');

    // The REAL backend, via the real onCall callable -- not a fake event --
    // confirmed by reading the order back directly.
    final after = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    expect(after.data()?['deliveryPartnerId'], isNull, reason: 'releaseOrderCore deletes deliveryPartnerId on success');
    expect(after.data()?['orderStatus'], 'ready_for_pickup', reason: 'releaseOrderCore resets orderStatus to ready_for_pickup');
    expect(after.data()?['deliveryReleasedBy'], riderId);

    // No duplicate side effects from a genuine retry (e.g. a dropped
    // response the client resends) -- the real callable's own idempotency,
    // not a UI-timing guess: calling it again must report "already", not
    // error, and must not write a second timeline entry. The UI's own
    // button-disable guard (onPressed: null while _isUpdating, set
    // synchronously before the awaited call) already makes a genuine
    // in-app double-tap unreachable by construction; this is the
    // complementary server-side guarantee for a network-level retry.
    final retry = await FirebaseFunctions.instance
        .httpsCallable('releaseDeliveryOrder')
        .call({'orderId': orderId, 'reason': 'seller_not_ready'});
    final retryData = retry.data as Map<Object?, Object?>;
    expect(retryData['alreadyReleased'], isTrue, reason: 'the real callable itself recognizes the already-released state');

    // Read via the admin identity, not Rider A's -- correctly, by rules
    // design, a rider who just released an order is no longer its assigned
    // partner and loses read access to its timeline (owner/seller/current-
    // partner/admin only; unlike the order document itself, there is no
    // isAvailableDeliveryOrder()-style fallback for a released order's
    // timeline). Confirmed against firestore.rules directly, not assumed.
    final adminFirestore = await _adminFirestore(fixtures['tokenAdmin'] as String);
    final timeline = await adminFirestore
        .collection('orders')
        .doc(orderId)
        .collection('timeline')
        .where('status', isEqualTo: 'delivery_released')
        .get();
    expect(timeline.docs.length, 1, reason: 'exactly one release recorded, even after the retry above');
  });

  testWidgets('DLVR2 4.4: legitimate completion (real verification callable)', (tester) async {
    final riderId = fixtures['riderA'] as String;
    final orderId = fixtures['orderIdComplete'] as String;
    final code = fixtures['deliveryCode'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenA'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderId, reason: 'signed in via custom token, never the OTP UI');

    final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    expect(orderSnap.data()?['orderStatus'], 'out_for_delivery',
        reason: 'must start post-pickup, pre-delivered for the completion action to render');
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ActiveOrderScreen(order: order)),
                ),
                child: const Text('Open Order'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Order'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Complete delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Verify delivery'), findsOneWidget, reason: 'a real verification sheet, not a silent completion');

    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
    await tester.ensureVisible(find.text('Verify & complete'));
    await tester.tap(find.text('Verify & complete'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'the real confirmDelivery callable dispatch must not throw');

    // A possible "you seem far from the customer" confirmation only if the
    // test device's own (real or absent) location reads as far from the
    // fixture's Madurai coordinates -- farTapQuestion returns null for a
    // null/unavailable fix, so this is expected to be a no-op here, but
    // handled rather than assumed away.
    final continuePrompt = find.text('Continue');
    if (continuePrompt.evaluate().isNotEmpty) {
      await tester.tap(continuePrompt);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    expect(find.text('Delivery complete'), findsOneWidget,
        reason: 'the real celebration sheet after a genuine server-verified completion -- not claimed from a fake event');
    await tester.tap(find.text('Back to dashboard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'back navigation must not throw');
    expect(find.text('Open Order'), findsOneWidget,
        reason: 'cleanly popped back to the underlying screen -- _leavingByOwnAction suppresses any masked/removed scaffold');

    // The REAL backend, via the real onCall callable -- confirmed by
    // reading the order back directly.
    final after = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    expect(after.data()?['orderStatus'], 'delivered');
    expect(after.data()?['deliveryConfirmedBy'], riderId);

    // onRiderDelivery is a SEPARATE Firestore trigger, not part of
    // confirmDelivery's own transaction -- poll for it rather than assume
    // it already landed the instant the callable returned.
    final earningRef = FirebaseFirestore.instance.collection('rider_earnings').doc(orderId);
    final earning = await _waitForDoc(earningRef);
    expect(earning.exists, isTrue, reason: 'onRiderDelivery must have genuinely fired and recorded this delivery\'s pay');
    expect(earning.data()?['riderId'], riderId);
    final total = (earning.data()?['total'] as num).toDouble();
    expect(total, greaterThan(0), reason: 'a real, nonzero computed rider payout, not a placeholder');
    final firstCreatedAt = earning.data()?['createdAt'];

    final accountRef = FirebaseFirestore.instance.collection('rider_accounts').doc(riderId);
    final account = await accountRef.get();
    expect(account.exists, isTrue);
    final earningsUnsettled = (account.data()?['earningsUnsettled'] as num).toDouble();
    expect(earningsUnsettled, greaterThanOrEqualTo(total), reason: 'the rider account balance reflects this earning');

    // No duplicate earnings from a genuine retry -- the real callable's own
    // idempotency (not a fake event, not a UI-timing guess): calling
    // confirmDelivery again with the SAME code must report
    // alreadyDelivered, and must not create a second earning or increment
    // the balance again.
    final retry = await FirebaseFunctions.instance.httpsCallable('confirmDelivery').call({
      'orderId': orderId,
      'code': code,
    });
    final retryData = retry.data as Map<Object?, Object?>;
    expect(retryData['alreadyDelivered'], isTrue, reason: 'the real callable itself recognizes the already-delivered state');

    final earningAfterRetry = await earningRef.get();
    expect(earningAfterRetry.data()?['createdAt'], firstCreatedAt, reason: 'the SAME earning record, not a new one');
    final accountAfterRetry = await accountRef.get();
    expect((accountAfterRetry.data()?['earningsUnsettled'] as num).toDouble(), earningsUnsettled,
        reason: 'the balance must not double-increment from the retry');
  });
}
