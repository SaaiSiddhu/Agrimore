// DLVID4: durable interrupted-registration recovery, at the screen level --
// the resume-or-start-over prompt, restoring fields/step/photos, the
// missing-local-file indicator, explicit discard, clearing the draft on a
// real success, and the targeted (not blanket) clear on a documentsMissing
// refusal that names specific documents. The store here still round-trips
// through jsonEncode/decode (not the bare Dart object), so a bug in
// RegistrationDraft's own JSON shape would show up here too, not just in
// registration_draft_test.dart.
import 'dart:convert';
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/design_system/design_system.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/registration/registration_draft.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:delivery/screens/auth/rider_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A JSON-string-backed store, matching what real secure storage holds --
/// every test here exercises the real toJson()/jsonEncode()/jsonDecode()/
/// fromJson() path, not a shortcut that hands the Dart object straight back.
class InMemoryDraftStore implements RegistrationDraftStore {
  final Map<String, String> disk = {};

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
  Future<void> clear(String key) async {
    disk.remove(key);
  }
}

class FakeBackend implements RegistrationBackend {
  String? uid;
  RegistrationException? failSubmit;
  final log = <String>[];

  @override
  String? get currentUid => uid;
  @override
  Future<String> createAccount(String email, String password) async => uid = 'u1';
  @override
  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType) async {
    log.add('upload $path');
  }

  @override
  Future<void> submit(Map<String, dynamic> payload) async {
    log.add('submit');
    final f = failSubmit;
    failSubmit = null;
    if (f != null) throw f;
  }
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

Widget host(Widget child) => ChangeNotifierProvider<DeliveryAuthProvider>(
      create: (_) => DeliveryAuthProvider(gateway: _NoAuth(), store: _NoStore(), pushTokens: _NoPush()),
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

const _png = <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
  31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 218, 99, 100, 96, 248, 95, 15, 0, 2, 135, 1, 128,
  235, 71, 186, 146, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
];

void main() {
  Future<void> pumpApp(
    WidgetTester t, {
    RegistrationDraftStore? draftStore,
    RegistrationBackend? backend,
    Map<String, dynamic>? initial,
    Future<PickedPhoto?> Function(RiderDocument doc)? pickPhoto,
    Future<PickedPhoto?> Function(DraftPhoto stored)? resolveDraftPhoto,
  }) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(RiderRegistrationScreen(
      service: RegistrationService(backend ?? FakeBackend()),
      draftStore: draftStore ?? InMemoryDraftStore(),
      initial: initial,
      pickPhoto: pickPhoto,
      // flutter_test's fake-async zone can stall a real dart:io read
      // triggered from inside a post-frame callback's continuation, so
      // every test resolves draft photos in plain memory instead.
      resolveDraftPhoto: resolveDraftPhoto ??
          (stored) async => stored.path.startsWith('missing:')
              ? null
              : (bytes: Uint8List.fromList(_png), contentType: stored.contentType, path: stored.path),
    )));
    await t.pumpAndSettle();
  }

  group('no draft', () {
    testWidgets('nothing to resume: the wizard opens straight to step 1, no dialog', (t) async {
      await pumpApp(t, draftStore: InMemoryDraftStore());
      expect(find.text('Resume registration?'), findsNothing);
      expect(find.byKey(const ValueKey('field-name')), findsOneWidget);
    });
  });

  group('resuming a draft', () {
    testWidgets('a found draft offers to resume; accepting restores fields, step and photo', (t) async {
      final store = InMemoryDraftStore();
      await store.save(
        '_pending',
        RegistrationDraft(
          step: 3,
          form: RiderApplicationForm()
            ..name = 'Ravi Kumar'
            ..phone = '9876543210'
            ..address = '12, Main Road'
            ..city = 'Madurai'
            ..pincode = '625020'
            ..aadhaarNumber = '234567890123',
          photos: {RiderDocument.selfie: const DraftPhoto(path: 'ok:selfie.jpg', contentType: 'image/jpeg')},
          savedAt: DateTime.now(),
        ),
      );

      await pumpApp(t, draftStore: store);
      expect(find.text('Resume registration?'), findsOneWidget);

      await t.tap(find.text('Resume'));
      await t.pumpAndSettle();

      expect(find.text('Resume registration?'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Ravi Kumar'), findsOneWidget);
      // Step 3 (documents) is now active -- the aadhaar field lives there.
      expect(find.widgetWithText(TextFormField, '234567890123'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-selfie')), findsOneWidget);
      expect(find.text('Add photo'), findsNWidgets(3)); // the other 3 docs, not selfie
    });

    testWidgets('declining ("Start over") discards the draft -- a later mount finds nothing', (t) async {
      final store = InMemoryDraftStore();
      await store.save(
        '_pending',
        RegistrationDraft(step: 1, form: RiderApplicationForm()..name = 'Old Draft', photos: const {}, savedAt: DateTime.now()),
      );

      await pumpApp(t, draftStore: store);
      await t.tap(find.text('Start over'));
      await t.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Old Draft'), findsNothing);
      expect(await store.load('_pending'), isNull);
    });

    testWidgets('a stored photo whose file no longer exists is flagged, not silently reused', (t) async {
      final store = InMemoryDraftStore();
      await store.save(
        '_pending',
        RegistrationDraft(
          step: 3,
          form: RiderApplicationForm()..aadhaarNumber = '234567890123',
          photos: {RiderDocument.license: const DraftPhoto(path: 'missing:gone.jpg', contentType: 'image/jpeg')},
          savedAt: DateTime.now(),
        ),
      );

      await pumpApp(t, draftStore: store);
      await t.tap(find.text('Resume'));
      await t.pumpAndSettle();

      expect(find.text('Please re-select this photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-license')), findsOneWidget);
    });

    testWidgets('a resubmission (existing server record) never offers a local draft', (t) async {
      final store = InMemoryDraftStore();
      await store.save(
        '_pending',
        RegistrationDraft(step: 1, form: RiderApplicationForm()..name = 'Stale Draft', photos: const {}, savedAt: DateTime.now()),
      );
      await pumpApp(t, draftStore: store, initial: const {'name': 'Server Copy'});
      expect(find.text('Resume registration?'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Server Copy'), findsOneWidget);
    });
  });

  group('saving and clearing', () {
    testWidgets('advancing a step persists a draft that a fresh load can see', (t) async {
      final store = InMemoryDraftStore();
      final backend = FakeBackend()..uid = 'u1'; // already signed in -> starts at step 1
      await pumpApp(t, draftStore: store, backend: backend);

      await t.enterText(find.byKey(const ValueKey('field-name')), 'Priya S');
      await t.enterText(find.byKey(const ValueKey('field-phone')), '9876543210');
      await t.enterText(find.byKey(const ValueKey('field-address')), '1 Anna Salai');
      await t.enterText(find.byKey(const ValueKey('field-city')), 'Chennai');
      await t.enterText(find.byKey(const ValueKey('field-pincode')), '600001');
      await t.tap(find.byKey(const ValueKey('registration-continue-1')));
      await t.pumpAndSettle();

      final saved = await store.load('u1');
      expect(saved, isNotNull);
      expect(saved!.step, 2);
      expect(saved.form.name, 'Priya S');
    });

    testWidgets('reaching a real success clears the draft under both keys', (t) async {
      final store = InMemoryDraftStore();
      final backend = FakeBackend()..uid = 'u1'; // account already exists from an earlier attempt
      await pumpApp(
        t,
        draftStore: store,
        backend: backend,
        pickPhoto: (_) async => (bytes: Uint8List.fromList(_png), contentType: 'image/png', path: null),
      );

      await t.enterText(find.byKey(const ValueKey('field-name')), 'Priya S');
      await t.enterText(find.byKey(const ValueKey('field-phone')), '9876543210');
      await t.enterText(find.byKey(const ValueKey('field-address')), '1 Anna Salai');
      await t.enterText(find.byKey(const ValueKey('field-city')), 'Chennai');
      await t.enterText(find.byKey(const ValueKey('field-pincode')), '600001');
      await t.tap(find.byKey(const ValueKey('registration-continue-1')));
      await t.pumpAndSettle();

      // Mid-flow: a draft exists, in case the app dies before the real submit.
      expect(await store.load('u1'), isNotNull);

      await t.enterText(find.byKey(const ValueKey('field-vehicleNumber')), 'TN58AB1234');
      await t.enterText(find.byKey(const ValueKey('field-licenseNumber')), 'TN5820200001234');
      await t.tap(find.byKey(const ValueKey('registration-continue-2')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('field-aadhaarNumber')), '234567890123');
      for (final key in ['aadhaarFront', 'aadhaarBack', 'selfie', 'license']) {
        await t.tap(find.byKey(ValueKey('photo-$key')));
        await t.pumpAndSettle();
      }
      await t.tap(find.byKey(const ValueKey('registration-continue-3')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('registration-continue-4')));
      await t.pumpAndSettle();

      expect(backend.log, contains('submit'));
      expect(await store.load('u1'), isNull);
      expect(await store.load('_pending'), isNull);
    });

    testWidgets('explicit "Start over" from the AppBar asks first, then clears everything', (t) async {
      final store = InMemoryDraftStore();
      final backend = FakeBackend()..uid = 'u1';
      await pumpApp(t, draftStore: store, backend: backend);
      await t.enterText(find.byKey(const ValueKey('field-name')), 'Priya S');
      await t.pump();

      await t.tap(find.text('Start over'));
      await t.pumpAndSettle();
      expect(find.text('Start over?'), findsOneWidget);
      await t.tap(find.widgetWithText(DeliveryButton, 'Start over'));
      await t.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Priya S'), findsNothing);
      expect(await store.load('u1'), isNull);
    });
  });

  group('documentsMissing narrows to the specific documents named', () {
    const resubmission = {
      'name': 'Ravi Kumar', 'phone': '9876543210', 'vehicleType': 'bike', 'vehicleNumber': 'TN58AB1234',
      'licenseNumber': 'TN5820200001234', 'aadhaarNumber': '234567890123', 'address': '12, Main Road',
      'city': 'Madurai', 'pincode': '625020',
      'kycDocuments': {
        'aadhaarFront': 'delivery_documents/u1/aadhaarFront', 'aadhaarBack': 'delivery_documents/u1/aadhaarBack',
        'selfie': 'delivery_documents/u1/selfie', 'license': 'delivery_documents/u1/license',
      },
    };

    testWidgets('server names only "selfie" -- the other 3 on-file docs are left alone', (t) async {
      final backend = FakeBackend()
        ..uid = 'u1'
        ..failSubmit = const RegistrationException(RegistrationFailure.documentsMissing, ['documents.selfie']);
      await pumpApp(t, backend: backend, initial: resubmission);

      // Walk steps 1 (about) -> 2 (vehicle) -> 3 (documents) -> 4 (payout) -> submit.
      await t.tap(find.byKey(const ValueKey('registration-continue-1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('registration-continue-2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('registration-continue-3')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('registration-continue-4')));
      await t.pumpAndSettle();

      // Back on step 3: selfie is now flagged, the other three still show
      // their on-file "Change" state -- not reset to "Add photo".
      expect(find.text('Add this photo'), findsOneWidget);
      expect(find.text('Change'), findsNWidgets(3));
      expect(find.text('Add photo'), findsNothing);
    });
  });
}
