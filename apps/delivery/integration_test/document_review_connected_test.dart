// Phase DLVC2 — the FIRST genuinely connected document-review acceptance
// journey (closure brief C2 5.1): real Firebase emulators (Auth+Firestore+
// Storage+Functions), the real RiderProfileScreen widget tree bound to the
// real CallableRiderDocumentReviewBackend (no injected fake backend), a
// real Firestore snapshot driving the pending/rejected/re-approved states,
// a real Storage upload for the staged replacement photo, and the real
// `submitDocumentReplacement`/`reviewDocumentSubmission` onCall callables --
// not the DLVDOC2 backend suite's own direct-core-function calls with fake
// Storage. DLVDOC1/2/3 are each independently correct (their own evidence);
// this proves them connected, the exact gap this closure brief exists to
// close (mirrors DLVR2's own reason for existing).
//
// The ONE piece deliberately still faked: `pickReplacementPhoto`, the
// screen's own existing injectable seam for `image_picker` (which has no
// test-friendly platform channel -- the same constraint DLVSUP1/DLVMAP2
// already hit and solved the same way). Real Storage upload, real
// callable, real Firestore, real stream -- only the OS picker UI itself is
// bypassed, exactly as this screen's own constructor already anticipates.
//
// Sign-in deliberately never touches the real phone-OTP UI (this
// repository's own recorded near-miss, agrimore-near-miss-real-otp-via-
// partial-emulator-isolation, says to always use the harness-bypass
// pattern instead) -- a custom token minted by the fixture script signs
// FirebaseAuth in directly, reaching zero OTP code.
//
// The admin approve/reject action goes through the REAL `reviewDocument
// Submission` callable via a SEPARATE, independently-signed-in Firebase App
// instance (mirrors phaseDLVR2_active_delivery_fixtures.js's own admin
// pattern) -- not the admin Flutter app's own UI, and not a raw Firestore
// write (unlike DLVR2's reassignment scenario, this action is
// callable-gated, not a plain rules-authorized write).
//
// Run with (Firestore, Auth, Storage AND Functions emulators, plus the
// fixtures seeded first):
//   flutter test integration_test/document_review_connected_test.dart \
//     -d <device> \
//     --dart-define=DLVC2_FIXTURES_JSON=<seed script's JSON output> \
//     --dart-define=FIREBASE_EMULATOR_HOST=<host> \
//     --dart-define=FIRESTORE_EMULATOR_PORT=<port> \
//     --dart-define=AUTH_EMULATOR_PORT=9099 \
//     --dart-define=FUNCTIONS_EMULATOR_PORT=5001 \
//     --dart-define=STORAGE_EMULATOR_PORT=9199
import 'dart:convert';
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:delivery/auth/rider_account_source.dart' show RiderPushTokens;
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

/// Real FCM push-token registration is orthogonal to this journey (document
/// review, not notifications delivery) and is a known source of emulator-
/// specific hangs -- faked here the same way rider_profile_screen_test.dart's
/// own _NoPush does, so DeliveryAuthProvider's otherwise-real gateway/store
/// aren't blocked waiting on a real device capability this test never needs.
class _NoPush implements RiderPushTokens {
  @override
  Future<String?> current() async => null;
  @override
  Stream<String> get refreshed => const Stream.empty();
  @override
  Future<void> forget() async {}
}

const _fixturesJson = String.fromEnvironment('DLVC2_FIXTURES_JSON', defaultValue: '{}');
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const _firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const _authEmulatorPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const _functionsEmulatorPort = int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const _storageEmulatorPort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

/// The minimal valid JPEG byte sequence (SOI + EOI markers only) -- real
/// bytes genuinely uploaded to real Storage, not a placeholder string; the
/// server's own storageLookup only checks contentType/size bounds
/// (functions/src/delivery/riderApplication.ts:161), never decodes the
/// image, so this is a faithful stand-in for "the rider picked a photo".
final Uint8List _fakeJpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

/// A SEPARATE, independently-authenticated Firebase App instance signed in
/// as the fixture's own admin test user -- calls the REAL
/// reviewDocumentSubmission callable, entirely independent of the rider's
/// own already-signed-in main app instance. Mirrors phaseDLVR2_active_
/// delivery_fixtures.js's own admin pattern exactly.
Future<FirebaseFunctions> _adminFunctions(String tokenAdmin) async {
  final adminApp = await Firebase.initializeApp(
    name: 'dlvc2-admin-${DateTime.now().microsecondsSinceEpoch}',
    options: Firebase.app().options,
  );
  final adminAuth = FirebaseAuth.instanceFor(app: adminApp);
  await adminAuth.useAuthEmulator(_emulatorHost, _authEmulatorPort);
  final adminFunctions = FirebaseFunctions.instanceFor(app: adminApp);
  adminFunctions.useFunctionsEmulator(_emulatorHost, _functionsEmulatorPort);
  await adminAuth.signInWithCustomToken(tokenAdmin);
  return adminFunctions;
}

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
    expect(fixtures['riderId'], isNotNull,
        reason: 'DLVC2_FIXTURES_JSON dart-define was not provided -- run the seed script first and pass its output');
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  testWidgets(
      'DLVC2: submit a document replacement, admin rejects, resubmit, admin approves -- all real, all connected',
      (tester) async {
    final riderId = fixtures['riderId'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenRider'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderId, reason: 'signed in via custom token, never the OTP UI');

    // RiderProfileScreen's own `late final _partner` stream is created
    // exactly once, the first time its State is built, from whatever
    // DeliveryAuthProvider.user is AT THAT INSTANT -- if that instant is
    // before the provider's own async uidChanges listener has fired, it
    // permanently captures a one-shot Stream.value(null) that never emits
    // again (the screen's own `data == null` branch reads that as "still
    // loading" forever: a genuine bug, the same class DLVSUP1 already found
    // and fixed once for SupportRequestStatusScreen's `!snap.hasData`
    // check). rider_profile_screen_test.dart's own established fixture
    // already works around exactly this by resolving auth BEFORE ever
    // pumping the screen -- mirrored here rather than pumping both at once.
    final auth = DeliveryAuthProvider(pushTokens: _NoPush());
    addTearDown(auth.dispose);
    for (var i = 0; i < 20 && auth.user == null; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(auth.user?.uid, riderId, reason: 'auth must resolve BEFORE RiderProfileScreen is ever built, not racing it');

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RiderProfileScreen(pickReplacementPhoto: (_) async => (bytes: _fakeJpegBytes, contentType: 'image/jpeg')),
      ),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    // Before anything: the real fixture's aadhaarFront is on file, no
    // review in progress -- a real Firestore read, not a fixture-
    // independent placeholder.
    expect(find.text('Submitted'), findsOneWidget,
        reason: 'the live delivery_partners read must have genuinely resolved onFile from the real emulator');
    final replaceButton = find.byKey(const ValueKey('replace-aadhaarFront'));
    expect(replaceButton, findsOneWidget);
    expect(tester.widget<TextButton>(replaceButton).onPressed, isNotNull, reason: 'not pending yet -- Replace must be enabled');

    // 1) Submit a replacement: real Storage upload + real
    // submitDocumentReplacement callable, triggered by the real tap.
    await tester.tap(replaceButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'a real Storage upload + real callable dispatch must not throw');
    expect(find.text('Pending review'), findsOneWidget,
        reason: 'a REAL Firestore snapshot, not an injected stream event, must have pushed the pending state');
    expect(tester.widget<TextButton>(replaceButton).onPressed, isNull,
        reason: 'the UI itself must refuse a second submission while one is pending, matching DLVDOC2\'s own server-side guard');

    // The submission id the server itself just wrote -- read back from the
    // real delivery_partners doc (documentReviewPending), not guessed or
    // reconstructed client-side.
    final afterSubmit = await FirebaseFirestore.instance.collection('delivery_partners').doc(riderId).get();
    final submissionId1 = (afterSubmit.data()?['documentReviewPending'] as Map?)?['aadhaarFront'] as String?;
    expect(submissionId1, isNotNull, reason: 'the real callable must have recorded a pending submission id');

    // 2) Admin rejects, via the REAL reviewDocumentSubmission callable
    // (never the admin Flutter app's own UI, never a raw Firestore write --
    // this action is callable-gated, unlike DLVR2's reassignment scenario).
    final adminFunctions = await _adminFunctions(fixtures['tokenAdmin'] as String);
    final rejectResult = await adminFunctions.httpsCallable('reviewDocumentSubmission').call<dynamic>({
      'submissionId': submissionId1,
      'approve': false,
      'reason': 'Photo is blurry',
    });
    expect((rejectResult.data as Map)['status'], 'rejected');

    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'the real rejection round trip must not throw in the rider\'s own widget tree');
    expect(find.text('Not approved'), findsOneWidget,
        reason: 'the REAL admin callable\'s write must have reached the rider\'s own real-time stream');
    expect(find.text('Photo is blurry'), findsOneWidget, reason: 'the real rejection reason, not a generic message');
    expect(tester.widget<TextButton>(replaceButton).onPressed, isNotNull,
        reason: 'DLVDOC2\'s dr11 property, proven through the connected UI: a decided submission unblocks a fresh one');

    // 3) Resubmit, then admin approves -- the full round trip back to the
    // base "on file" state, proven connected both directions. The rejection
    // reason text just added above pushes this row far enough down the
    // ListView that it can sit below this device's fold -- the same
    // below-the-fold class of gap this codebase already has a name for
    // (agrimore-flutter-finder-skipoffstage-below-fold): find.byKey finds
    // the widget in the tree regardless, but tap()'s own computed offset
    // can fall outside the actual rendered viewport, confirmed by this
    // exact test on its first run (a hit-test warning citing an offset
    // beyond the render tree's own height). ensureVisible scrolls it into
    // the real viewport first.
    await tester.ensureVisible(replaceButton);
    await tester.pumpAndSettle();
    await tester.tap(replaceButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('Pending review'), findsOneWidget);

    final afterResubmit = await FirebaseFirestore.instance.collection('delivery_partners').doc(riderId).get();
    final submissionId2 = (afterResubmit.data()?['documentReviewPending'] as Map?)?['aadhaarFront'] as String?;
    expect(submissionId2, isNotNull);
    expect(submissionId2, isNot(submissionId1), reason: 'a genuinely new submission, not the same rejected one reused');

    final approveResult = await adminFunctions.httpsCallable('reviewDocumentSubmission').call<dynamic>({
      'submissionId': submissionId2,
      'approve': true,
    });
    expect((approveResult.data as Map)['status'], 'approved');

    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('Submitted'), findsOneWidget,
        reason: 'approved collapses back to the base on-file label (no distinct "Approved" copy exists) -- the real end state');
    expect(find.text('Photo is blurry'), findsNothing, reason: 'the earlier rejection reason must not linger after a fresh approval');
    expect(tester.widget<TextButton>(replaceButton).onPressed, isNotNull, reason: 'decided again -- Replace re-enabled');
  });
}
