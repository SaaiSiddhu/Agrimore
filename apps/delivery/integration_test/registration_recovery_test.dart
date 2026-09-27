// DLVID4: proof that registration recovery survives a genuine process
// restart, not just a rebuilt widget. "Reconstructing the same in-memory
// widget is not proof of durable recovery" -- so this test:
//   1. builds widget tree A, with its OWN RegistrationService/backend/form,
//   2. saves a draft by exercising the real save path (advancing a step),
//   3. fully unmounts A (a SizedBox.shrink() pump, forcing Flutter to
//      dispose the Element/State entirely -- see DLVTOUR1's own note on why
//      an unkeyed same-type pumpWidget is an update, not a replacement),
//   4. builds widget tree B from scratch -- its own State, its own
//      RiderApplicationForm, its own backend instance; nothing from A is
//      reused except the store, which round-trips through real JSON
//      (jsonEncode/jsonDecode), simulating "the app died and came back,
//      reading the same on-disk file" rather than "the same object survived
//      in memory".
// A store instance stands in for the OS keychain here (real
// flutter_secure_storage needs a platform channel this binding doesn't
// provide) -- what makes this durable-recovery proof rather than a widget
// rebuild is that A and B share NO Dart object graph, only serialized bytes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/registration/registration_draft.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:delivery/screens/auth/rider_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

class _DiskBackedDraftStore implements RegistrationDraftStore {
  _DiskBackedDraftStore(this.disk);
  final Map<String, String> disk; // the "keychain" -- outlives any one widget tree

  @override
  Future<RegistrationDraft?> load(String key) async {
    final raw = disk[key];
    if (raw == null) return null;
    return RegistrationDraft.fromJson(jsonDecode(raw));
  }

  @override
  Future<void> save(String key, RegistrationDraft draft) async {
    disk[key] = jsonEncode(draft.toJson());
  }

  @override
  Future<void> clear(String key) async => disk.remove(key);
}

class _FakeBackend implements RegistrationBackend {
  String? uid;
  @override
  String? get currentUid => uid;
  @override
  Future<String> createAccount(String email, String password) async => uid = 'u1';
  @override
  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType) async {}
  @override
  Future<void> submit(Map<String, dynamic> payload) async {}
}

class _NoAuth implements RiderAuthGateway {
  @override
  Stream<String?> get uidChanges => Stream.value(null);
  @override
  String? get currentUid => null;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> refreshClaims() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _NoStore implements RiderAccountStore {
  @override
  Future<ProfileRead> user(String uid) async => const ProfileRead(exists: false, fromCache: false);
  @override
  Future<ProfileRead> partner(String uid) async => const ProfileRead(exists: false, fromCache: false);
  @override
  Stream<ProfileRead> watchPartner(String uid) => const Stream.empty();
  @override
  Future<void> addToken(String uid, String token) async {}
  @override
  Future<void> removeToken(String uid, String token) async {}
}

class _NoPush implements RiderPushTokens {
  @override
  Future<String?> current() async => null;
  @override
  Stream<String> get refreshed => const Stream.empty();
  @override
  Future<void> forget() async {}
}

Widget _independentApp({
  required RegistrationDraftStore draftStore,
  required RegistrationBackend backend,
}) {
  // Deliberately not shared with any other tree: its own provider, its own
  // MaterialApp, its own RegistrationService wrapping its own backend.
  return ChangeNotifierProvider<DeliveryAuthProvider>(
    create: (_) => DeliveryAuthProvider(gateway: _NoAuth(), store: _NoStore(), pushTokens: _NoPush()),
    child: MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RiderRegistrationScreen(
          service: RegistrationService(backend),
          draftStore: draftStore,
          resolveDraftPhoto: (stored) async =>
              (bytes: Uint8List.fromList(const [1, 2, 3]), contentType: stored.contentType, path: stored.path),
        ),
      ),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a draft saved by one widget tree resumes correctly in a completely independent one',
    (tester) async {
      final disk = <String, String>{}; // the only thing tree A and tree B share
      final storeA = _DiskBackedDraftStore(disk);
      final backendA = _FakeBackend();

      // --- Tree A: fill in step 1, advance, which persists a draft. ---
      await tester.pumpWidget(_independentApp(draftStore: storeA, backend: backendA));
      await tester.pumpAndSettle();
      expect(find.text('Resume registration?'), findsNothing); // disk starts empty

      await tester.enterText(find.byKey(const ValueKey('field-email')), 'ravi@example.com');
      await tester.enterText(find.byKey(const ValueKey('field-password')), 'correct-horse-1');
      await tester.ensureVisible(find.byKey(const ValueKey('registration-continue-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('registration-continue-0')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('field-name')), 'Ravi Kumar');
      await tester.enterText(find.byKey(const ValueKey('field-phone')), '9876543210');
      await tester.enterText(find.byKey(const ValueKey('field-address')), '12, Main Road');
      await tester.enterText(find.byKey(const ValueKey('field-city')), 'Madurai');
      await tester.enterText(find.byKey(const ValueKey('field-pincode')), '625020');
      await tester.ensureVisible(find.byKey(const ValueKey('registration-continue-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('registration-continue-1')));
      await tester.pumpAndSettle();

      // A genuinely-saved snapshot exists on "disk" before tree A ever
      // disposes -- proves the save path, not just that A holds state.
      expect(disk.containsKey('_pending'), isTrue);
      final onDisk = RegistrationDraft.fromJson(jsonDecode(disk['_pending']!));
      expect(onDisk!.step, 2);
      expect(onDisk.form.name, 'Ravi Kumar');
      expect(onDisk.form.email, 'ravi@example.com');
      expect(disk['_pending']!.contains('correct-horse-1'), isFalse); // never the password

      // --- Force a full teardown: not a rebuild of the same Element. ---
      // Mirrors DLVTOUR1's own fix: pumping a brand-new same-type widget in
      // the same slot is an UPDATE, not a replacement, and can leave old
      // Navigator/State alive underneath. A structurally unrelated widget
      // forces Flutter to dispose the old tree before anything new exists.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byType(RiderRegistrationScreen), findsNothing);

      // --- Tree B: a completely independent app, form, service, backend. ---
      // Its only connection to tree A is `disk` -- the same Map object,
      // standing in for "the same physical keychain file on the same
      // device", read back through real JSON, not a shared Dart reference
      // to A's own RiderApplicationForm/_photos/State.
      final storeB = _DiskBackedDraftStore(disk);
      final backendB = _FakeBackend();
      await tester.pumpWidget(_independentApp(draftStore: storeB, backend: backendB));
      await tester.pumpAndSettle();

      expect(find.text('Resume registration?'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Ravi Kumar'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '9876543210'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '12, Main Road'), findsOneWidget);

      // Tree A had already advanced past step 1 before teardown, so the
      // restored draft resumes at step 2 (vehicle), not step 1 -- confirms
      // _step itself survived, not just the form fields.
      expect(find.byKey(const ValueKey('field-licenseNumber')), findsOneWidget);
    },
  );

  testWidgets(
    'declining resume in one tree leaves nothing for the next independent tree to find',
    (tester) async {
      final disk = <String, String>{};
      await tester.pumpWidget(_independentApp(draftStore: _DiskBackedDraftStore(disk), backend: _FakeBackend()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('field-email')), 'a@b.com');
      await tester.enterText(find.byKey(const ValueKey('field-password')), 'password1');
      await tester.ensureVisible(find.byKey(const ValueKey('registration-continue-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('registration-continue-0')));
      await tester.pumpAndSettle();
      expect(disk.containsKey('_pending'), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(_independentApp(draftStore: _DiskBackedDraftStore(disk), backend: _FakeBackend()));
      await tester.pumpAndSettle();
      expect(find.text('Resume registration?'), findsOneWidget);
      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();

      expect(disk.containsKey('_pending'), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_independentApp(draftStore: _DiskBackedDraftStore(disk), backend: _FakeBackend()));
      await tester.pumpAndSettle();
      expect(find.text('Resume registration?'), findsNothing);
    },
  );
}
