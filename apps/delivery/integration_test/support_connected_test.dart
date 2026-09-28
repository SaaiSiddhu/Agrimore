// Phase DLVC4 — the FIRST genuinely connected support-ticket acceptance
// journey (closure brief C2 5.2, section 7): real Firebase emulators
// (Auth+Firestore+Storage+Functions), the real HelpSupportScreen ->
// SubmitSupportRequestScreen -> SupportRequestStatusScreen ->
// MySupportRequestsScreen widget tree bound to the real
// CallableRiderSupportBackend (no injected fake backend), the real
// submitSupportRequest/updateSupportRequest onCall callables. DLVSUP1/DLVSUP2
// are each independently correct (their own evidence, rider_support_test.dart
// and phaseDLVSUP*_test.js); this proves them connected end to end, the exact
// gap this closure brief exists to close (mirrors DLVC2's/DLVR2's own reason
// for existing).
//
// Scope, disclosed rather than assumed:
// - The ONE piece deliberately faked: `pickImage`, the submit screen's own
//   existing injectable seam for `image_picker` (no test-friendly platform
//   channel -- the same constraint DLVSUP1/DLVMAP2/DLVC2 already hit and
//   solved the same way). Real Storage upload, real callable, real
//   Firestore, real stream -- only the OS picker UI itself is bypassed.
//   HelpSupportScreen itself never exposed this seam before this phase (it
//   built SubmitSupportRequestScreen/MySupportRequestsScreen directly,
//   forwarding nothing) -- fixed so this test can drive the real
//   entry-point navigation, not a screen pumped in isolation.
// - The admin mark-seen/close actions go through the REAL
//   updateSupportRequest callable via a SEPARATE, independently-signed-in
//   Firebase App instance (mirrors DLVC2's/DLVR2's own admin pattern) -- not
//   the admin Flutter app's own UI. The same pattern signs in rider 2 for
//   the cross-rider-denial scenario, without disturbing rider 1's own
//   already-signed-in main app session.
// - "App terminated and relaunched" (the brief's own step 5) is simulated by
//   fully unmounting the widget tree (pumping an unrelated placeholder) and
//   mounting a BRAND NEW HelpSupportScreen with a brand new backend
//   instance -- no Dart object or in-memory state survives, only what is
//   genuinely persisted server-side (Firestore) can make the ticket
//   reachable again. A real OS-process kill is not possible from inside a
//   `flutter test` harness; this is the honest, already-documented meaning
//   "restart" has in this test suite.
// - Step 9 ("notification opens the exact ticket") is proven in two real,
//   connected halves rather than also standing up InboxScreen's own full
//   widget tree: (a) the REAL notice document Cloud Functions writes
//   (users/{uid}/notifications) is read back and its `data.ticketId`
//   checked against the real ticket id, and (b) a freshly-pushed
//   SupportRequestStatusScreen(ticketId: thatExactId) -- exactly what
//   InboxScreen's own already-verified-by-direct-source-read
//   `_openSupportTicket(n.ticketId!)` one-line switch case pushes -- is
//   proven to render that EXACT ticket's own state, distinct from a newer
//   ticket that exists at the same time. InboxScreen pulls in unrelated
//   order/history/money dependencies for a screen already confirmed correct
//   and unchanged by this phase; standing up its full constructor to
//   re-prove a one-line switch statement already read fresh from source is
//   not attempted.
// - "Order/statement context is attached where supported" (the brief's own
//   step 2) is disclosed, not fabricated: SubmitSupportRequestScreen has
//   never offered a picker UI for `relatedTo` (its own header comment
//   already records this as a DLVSUP1 scoping decision) -- this test does
//   not attempt to drive one. The backend plumbing for `relatedTo` (already
//   present end-to-end in RiderSupportBackend/submitSupportRequestCore) is
//   proven directly instead, honestly labelled as backend-only proof.
// - Pagination is not exercised as a boundary: `tickets()` has no `.limit()`
//   anywhere in the current implementation (confirmed by direct source
//   read) -- there is no page edge to hit. Verified instead that several
//   tickets all appear, correctly sorted newest-first, with no truncation.
//
// Sign-in deliberately never touches the real phone-OTP UI (this
// repository's own recorded near-miss, agrimore-near-miss-real-otp-via-
// partial-emulator-isolation, says to always use the harness-bypass pattern
// instead) -- a custom token minted by the fixture script signs FirebaseAuth
// in directly, reaching zero OTP code.
//
// Run with (Firestore, Auth, Storage AND Functions emulators, plus the
// fixtures seeded first):
//   flutter test integration_test/support_connected_test.dart \
//     -d <device> \
//     --dart-define=DLVC4_FIXTURES_JSON=<seed script's JSON output> \
//     --dart-define=FIREBASE_EMULATOR_HOST=<host> \
//     --dart-define=FIRESTORE_EMULATOR_PORT=<port> \
//     --dart-define=AUTH_EMULATOR_PORT=9099 \
//     --dart-define=FUNCTIONS_EMULATOR_PORT=5001 \
//     --dart-define=STORAGE_EMULATOR_PORT=9199
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/support/help_support_screen.dart';
import 'package:delivery/screens/support/my_support_requests_screen.dart';
import 'package:delivery/screens/support/support_request_status_screen.dart';
import 'package:delivery/support/rider_support.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _fixturesJson = String.fromEnvironment('DLVC4_FIXTURES_JSON', defaultValue: '{}');
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
const _firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const _authEmulatorPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const _functionsEmulatorPort = int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const _storageEmulatorPort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

/// The minimal valid JPEG byte sequence (SOI + EOI markers only) -- real
/// bytes genuinely uploaded to real Storage, not a placeholder string;
/// mirrors document_review_connected_test.dart's own established reasoning
/// for why this is a faithful stand-in for "the rider picked a photo".
final Uint8List _fakeJpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

/// A REAL, on-disk temp file backing the returned XFile -- `XFile.fromData`
/// (an in-memory-bytes-backed XFile) was found to hang indefinitely on
/// `readAsBytes()` when driven on a real Android device under
/// `integration_test` (a `pumpAndSettle timed out` after Flutter's own
/// 10-minute internal ceiling, with the Storage emulator's own log never
/// showing the upload request even arrive -- the hang is before the network
/// call, not in it). A real file path is also a more faithful stand-in for
/// what `image_picker`'s own real `pickImage` returns in production, which
/// is always path-backed, never bytes-backed.
Future<XFile> _fakePickedPhoto() async {
  final file = await File('${Directory.systemTemp.path}/dlvc4_proof_${DateTime.now().microsecondsSinceEpoch}.jpg')
      .writeAsBytes(_fakeJpegBytes);
  return XFile(file.path, mimeType: 'image/jpeg', name: 'proof.jpg');
}

/// Each call gets its own `UniqueKey`, deliberately -- consecutive
/// `pumpWidget` calls with a plain `MaterialApp` (no distinguishing key) are
/// RECONCILED in place by Flutter (same widget type at the same tree
/// position), so `WidgetsApp`'s own Navigator, built once behind a stable
/// internal GlobalKey, keeps its EXISTING route stack regardless of a new
/// `home` value -- found the hard way when a "restart" (pump a placeholder,
/// then pump a fresh HelpSupportScreen) kept showing the previous, already
///-pushed SupportRequestStatusScreen. A distinct key forces a genuine
/// teardown and remount every time this test needs a truly fresh tree: the
/// simulated restart, and every freshly-pushed by-id screen later on.
Widget _host(Widget child) => MaterialApp(
      key: UniqueKey(),
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

/// A SEPARATE, independently-authenticated Firebase App instance -- mirrors
/// document_review_connected_test.dart's own admin pattern, generalised to
/// sign in as any fixture identity (admin for mark-seen/close, rider 2 for
/// cross-rider denial) without disturbing the main app instance's own
/// already-signed-in rider 1 session.
Future<({FirebaseFunctions functions, FirebaseFirestore firestore})> _secondIdentity(
  String name,
  String token,
) async {
  final app = await Firebase.initializeApp(
    name: '$name-${DateTime.now().microsecondsSinceEpoch}',
    options: Firebase.app().options,
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(_emulatorHost, _authEmulatorPort);
  final functions = FirebaseFunctions.instanceFor(app: app);
  functions.useFunctionsEmulator(_emulatorHost, _functionsEmulatorPort);
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
  await auth.signInWithCustomToken(token);
  return (functions: functions, firestore: firestore);
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
        reason: 'DLVC4_FIXTURES_JSON dart-define was not provided -- run the seed script first and pass its output');
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  testWidgets(
      'DLVC4: submit with attachment -> restart -> admin seen+closes -> notification opens the exact ticket',
      (tester) async {
    final riderId = fixtures['riderId'] as String;
    final riderId2 = fixtures['riderId2'] as String;

    await FirebaseAuth.instance.signInWithCustomToken(fixtures['tokenRider'] as String);
    expect(FirebaseAuth.instance.currentUser?.uid, riderId, reason: 'signed in via custom token, never the OTP UI');

    // ---- Steps 1, 3, 4: start from the real HelpSupportScreen, attach a
    // real Storage upload, submit via the real callable. ----
    await tester.pumpWidget(_host(HelpSupportScreen(
      pickImage: _fakePickedPhoto,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-topic-delivery-issue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-category')), findsOneWidget,
        reason: 'the real SubmitSupportRequestScreen, reached via real navigation, not pumped standalone');

    await tester.tap(find.byKey(const ValueKey('support-add-attachment')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'a real Storage upload must not throw');
    expect(find.byKey(const ValueKey('support-remove-attachment')), findsOneWidget,
        reason: 'the chip only appears once the real upload has resolved a path');

    await tester.enterText(find.byKey(const ValueKey('support-message')), 'Ticket A: customer refused delivery.');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'a real callable dispatch must not throw');
    // Every _Step's TITLE ("Submitted"/"Seen"/"Closed") always renders
    // regardless of status -- only each step's BODY text is conditional on
    // `done`. The body text is what actually proves the real status.
    expect(find.text('Your request has been recorded.'), findsOneWidget,
        reason: 'pushReplacement to the real SupportRequestStatusScreen, a real Firestore doc already backing it');
    expect(find.text('Your request has been viewed.'), findsNothing, reason: 'not yet seen');

    // The exact ticket id the real callable just created -- read back from
    // Firestore, never guessed or reconstructed client-side.
    final ticketsAfterSubmit =
        await FirebaseFirestore.instance.collection('rider_support_tickets').where('riderId', isEqualTo: riderId).get();
    expect(ticketsAfterSubmit.docs.length, 1, reason: 'exactly one ticket must exist after exactly one submit');
    final ticketAId = ticketsAfterSubmit.docs.single.id;
    final requestIdA = ticketAId.substring(riderId.length + 1);
    final attachmentPathA = ticketsAfterSubmit.docs.single.data()['attachmentPath'] as String?;
    expect(attachmentPathA, isNotNull, reason: 'the real upload path must have been recorded on the real ticket');

    // ---- Duplicate submission / lost response: the SAME requestId again,
    // through the SAME real callable -- must return the SAME ticket, never
    // create a second one. Models a client retrying after presuming its
    // first response was lost, exactly as a real dropped connection would. ----
    final riderBackend = CallableRiderSupportBackend();
    final retryTicketId = await riderBackend.submit(
      requestId: requestIdA,
      category: kSupportCategoryDeliveryIssue,
      message: 'Ticket A: customer refused delivery.',
      attachmentPath: attachmentPathA,
    );
    expect(retryTicketId, ticketAId, reason: 'idempotent by requestId -- a retried/lost-response submit is never a duplicate');
    final ticketsAfterRetry =
        await FirebaseFirestore.instance.collection('rider_support_tickets').where('riderId', isEqualTo: riderId).get();
    expect(ticketsAfterRetry.docs.length, 1, reason: 'still exactly one ticket after the retried submit');

    // ---- Step 5: "app terminated and relaunched" -- fully unmount, then
    // mount a BRAND NEW widget tree with a brand new backend instance. No
    // Dart object state survives; only genuinely persisted server state can
    // make the ticket reachable again. ----
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const HelpSupportScreen()));
    await tester.pumpAndSettle();

    // ---- Step 6: reopen via the real list screen, not a remembered id. ----
    await tester.tap(find.byKey(const ValueKey('help-my-requests')));
    await tester.pumpAndSettle();
    expect(find.text('Ticket A: customer refused delivery.'), findsOneWidget,
        reason: 'DLVSUP2 reachability, proven after a genuine full remount: nothing but Firestore made this findable again');
    await tester.tap(find.text('Ticket A: customer refused delivery.'));
    await tester.pumpAndSettle();
    expect(find.text('Your request has been recorded.'), findsOneWidget);
    expect(find.text('Your request has been viewed.'), findsNothing);

    // ---- Step 7: an authorized admin marks it seen, via the REAL
    // updateSupportRequest callable (never the admin Flutter app's own UI,
    // never a raw Firestore write -- this action is callable-gated). ----
    final admin = await _secondIdentity('dlvc4-admin', fixtures['tokenAdmin'] as String);
    final seenResult = await admin.functions.httpsCallable('updateSupportRequest').call<dynamic>({
      'ticketId': ticketAId,
      'action': 'mark_seen',
    });
    expect((seenResult.data as Map)['status'], 'seen');
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'the real admin write must not throw in the rider\'s own live widget tree');
    expect(find.text('Your request has been viewed.'), findsOneWidget,
        reason: 'the REAL admin callable\'s write reached the rider\'s own real-time stream');

    // ---- Step 8 + 10: admin closes with the required outcome note; the
    // rider sees the correct resolution, live. ----
    final closeResult = await admin.functions.httpsCallable('updateSupportRequest').call<dynamic>({
      'ticketId': ticketAId,
      'action': 'close',
      'note': 'Redelivered the next day; customer confirmed receipt.',
    });
    expect((closeResult.data as Map)['status'], 'closed');
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('Request closed. View the outcome below.'), findsOneWidget);
    expect(find.text('Redelivered the next day; customer confirmed receipt.'), findsOneWidget,
        reason: 'the real resolution note, not a generic outcome message');

    // ---- Step 9: the notification the close action wrote names the EXACT
    // ticket. Read the real notice document back; a stable, ownership-scoped
    // destination, not merely a client-side assumption. ----
    final notices = await FirebaseFirestore.instance
        .collection('users')
        .doc(riderId)
        .collection('notifications')
        .where('type', isEqualTo: 'support_request_closed')
        .get();
    expect(notices.docs.length, 1, reason: 'exactly one close notice for exactly one closed ticket');
    final noticeData = notices.docs.single.data()['data'] as Map<String, dynamic>;
    expect(noticeData['ticketId'], ticketAId, reason: 'the real notice must carry the EXACT ticket id, not a generic pointer');

    // ---- upload-succeeds-submission-fails (a SEPARATE attempt, ticket D):
    // the UI's own category dropdown cannot construct an invalid value, so
    // this proves the backend's own refusal directly -- a real Storage
    // upload followed by a submit the server must refuse, never the form's
    // own client-side validation short-circuiting before either happens. ----
    final requestIdD = newSupportRequestId();
    final attachmentPathD = await riderBackend.uploadAttachment(requestIdD, _fakeJpegBytes, 'image/jpeg');
    await expectLater(
      riderBackend.submit(requestId: requestIdD, category: 'not-a-real-category', message: 'Ticket D attempt', attachmentPath: attachmentPathD),
      throwsA(isA<SupportRequestException>().having((e) => e.failure, 'failure', SupportRequestFailure.invalid)),
      reason: 'the server must refuse an invalid category regardless of a successful upload',
    );
    // The orphaned upload is harmless, not corrupted or deleted:
    await FirebaseStorage.instance.ref(attachmentPathD).getMetadata();
    // A raw client read for a ticket that was never created surfaces as
    // permission-denied, not a clean "not found": firestore.rules reads
    // `resource.data.riderId`, and `resource` is null for a nonexistent
    // document, so the rule itself fails to evaluate rather than allowing a
    // look at an absent doc -- confirmed by hitting exactly this on the real
    // rules-enforcing emulator. This is the SAME real-world shape
    // SupportRequestStatusScreen's own `hasError` fix (above) already
    // handles correctly for a rider; here it just means "no ticket exists"
    // must be read as either a clean absence OR this specific denial.
    var ticketDCreated = true;
    try {
      final doc = await FirebaseFirestore.instance.collection('rider_support_tickets').doc('${riderId}_$requestIdD').get();
      ticketDCreated = doc.exists;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      ticketDCreated = false;
    }
    expect(ticketDCreated, isFalse, reason: 'a refused submit must not have created a ticket');
    // A follow-up submit with the SAME requestId and a valid category must
    // succeed and correctly reuse the already-uploaded attachment:
    final ticketDId = await riderBackend.submit(
      requestId: requestIdD,
      category: kSupportCategoryAccountDocuments,
      message: 'Ticket D: resolved after a valid resubmit.',
      attachmentPath: attachmentPathD,
    );
    final ticketD = await FirebaseFirestore.instance.collection('rider_support_tickets').doc(ticketDId).get();
    expect(ticketD.data()?['attachmentPath'], attachmentPathD, reason: 'the SAME already-uploaded object, never re-uploaded');

    // ---- A newer, still-open ticket (B) -- for the historical-notification
    // contrast below, and to prove the backend's own `relatedTo` plumbing
    // (no picker UI exists for it; the field is verified end to end anyway,
    // honestly as backend-only proof). Small real delays keep createdAt
    // timestamps distinct for the ordering check further down. ----
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final ticketBId = await riderBackend.submit(
      requestId: newSupportRequestId(),
      category: kSupportCategoryEarningsPayouts,
      message: 'Ticket B: newer, still open.',
      relatedTo: const RelatedTo(type: 'order', id: 'dlvc4-order-1'),
    );
    final ticketBFromStream = await riderBackend.ticket(ticketBId).firstWhere((t) => t != null);
    expect(ticketBFromStream?.relatedTo?.type, 'order', reason: 'relatedTo plumbing works end to end even with no picker UI');
    expect(ticketBFromStream?.relatedTo?.id, 'dlvc4-order-1');

    // ---- Historical notification: opening ticket A's notification (a
    // freshly-pushed SupportRequestStatusScreen(ticketId: ticketAId), the
    // EXACT push InboxScreen's own already-verified _openSupportTicket
    // performs) must show A's own closed outcome, never B's newer, still-
    // open state, even though B now exists and is more recent. ----
    await tester.pumpWidget(_host(SupportRequestStatusScreen(ticketId: ticketAId)));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Request closed. View the outcome below.'), findsOneWidget);
    expect(find.text('Redelivered the next day; customer confirmed receipt.'), findsOneWidget);
    await tester.pumpWidget(_host(SupportRequestStatusScreen(ticketId: ticketBId)));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Your request has been recorded.'), findsOneWidget,
        reason: 'B is opened separately and correctly shows ITS OWN, different state');
    expect(find.text('Your request has been viewed.'), findsNothing);
    expect(find.text('Redelivered the next day; customer confirmed receipt.'), findsNothing,
        reason: 'A\'s resolution note must never bleed into B\'s own, separate screen instance');

    // ---- Several tickets, no pagination boundary in the current
    // implementation (confirmed by direct source read: tickets() has no
    // .limit()) -- all three must appear, newest first. ----
    await tester.pumpWidget(_host(MySupportRequestsScreen(riderId: riderId)));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    final rows = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().toList();
    final indexB = rows.indexOf('Ticket B: newer, still open.');
    final indexD = rows.indexOf('Ticket D: resolved after a valid resubmit.');
    final indexA = rows.indexOf('Ticket A: customer refused delivery.');
    expect([indexB, indexD, indexA].every((i) => i >= 0), isTrue, reason: 'all three tickets must appear -- no truncation');
    expect(indexB, lessThan(indexD), reason: 'newest first: B (last submitted) must render above D');
    expect(indexD, lessThan(indexA), reason: 'newest first: D must render above A (first submitted)');

    // ---- Cross-rider denial: rider 2, a SEPARATE signed-in identity, reads
    // ticket A directly and lists their own (empty) tickets. The real
    // ownership rule (firestore.rules: resource.data.riderId ==
    // request.auth.uid, re-verified fresh this phase) must deny the read;
    // the already-fixed unavailable card, not a leaked cross-rider payload,
    // is what the rider actually sees. Also stands in for "account
    // switching": a freshly-pushed screen for a DIFFERENT uid must never
    // show the previous account's data. ----
    final rider2 = await _secondIdentity('dlvc4-rider2', fixtures['tokenRider2'] as String);
    final rider2Backend = CallableRiderSupportBackend(db: rider2.firestore);
    await tester.pumpWidget(_host(SupportRequestStatusScreen(ticketId: ticketAId, backend: rider2Backend)));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Not available'), findsOneWidget, reason: 'a real cross-rider permission-denied read, not a fake one');
    expect(find.text('Redelivered the next day; customer confirmed receipt.'), findsNothing,
        reason: 'rider A\'s real resolution note must never leak to a different signed-in rider');

    await tester.pumpWidget(_host(MySupportRequestsScreen(riderId: riderId2, backend: rider2Backend)));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Ticket A: customer refused delivery.'), findsNothing);
    expect(find.text('Ticket B: newer, still open.'), findsNothing);
    expect(find.text('Ticket D: resolved after a valid resubmit.'), findsNothing);
  });
}
