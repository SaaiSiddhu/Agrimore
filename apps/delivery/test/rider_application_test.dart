// Phase DLV-A1 — registration: the same field rules and problem keys as the
// server; the account is created once and never deleted; photos go to fixed
// paths and are not re-uploaded on retry unless changed; the password is
// used exactly as typed; a failure keeps everything the rider entered.
import 'dart:typed_data';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:delivery/screens/auth/rider_registration_screen.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RiderApplicationForm goodForm() => RiderApplicationForm()
  ..email = 'r@x.in'
  ..password = ' pass with spaces '
  ..name = 'Ravi Kumar'
  ..phone = '+91 98765-43210'
  ..vehicleType = VehicleType.bike
  ..vehicleNumber = 'tn 58 ab 1234'
  ..licenseNumber = 'TN58-2020-0001234'
  ..aadhaarNumber = '2345 6789 0123'
  ..address = '12, Main Road'
  ..city = 'Madurai'
  ..pincode = '625020';

class FakeBackend implements RegistrationBackend {
  String? uid;
  final log = <String>[];
  RegistrationException? failSubmit;
  RegistrationException? failUploadOf;
  String? failPath;
  int creates = 0;
  String? passwordSeen;

  @override
  String? get currentUid => uid;

  @override
  Future<String> createAccount(String email, String password) async {
    creates++;
    passwordSeen = password;
    return uid = 'u1';
  }

  @override
  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType) async {
    if (path == failPath) {
      failPath = null;
      throw failUploadOf!;
    }
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

// A real 1x1 PNG (Image.memory decodes it on the photo tile).
final photo = (bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 218, 99, 100, 96, 248, 95, 15, 0, 2, 135, 1, 128, 235, 71, 186, 146, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]), contentType: 'image/png');
Map<RiderDocument, PickedPhoto> allPhotos() => {for (final d in RiderDocument.values) d: photo};

void main() {
  group('field rules (same keys as the server)', () {
    test('a good form is clean', () => expect(applicationProblems(goodForm()), isEmpty));
    test('empty form lists every required field', () {
      final p = applicationProblems(RiderApplicationForm()..vehicleType = VehicleType.bike);
      expect(p, containsAll(['name', 'phone', 'vehicleNumber', 'licenseNumber', 'aadhaarNumber', 'address', 'city', 'pincode']));
    });
    test('bicycle needs no plate; bank is all-or-nothing; alt phone must differ', () {
      expect(applicationProblems(goodForm()..vehicleType = VehicleType.bicycle..vehicleNumber = ''), isEmpty);
      expect(applicationProblems(goodForm()..bankAccountNumber = '123456789012'),
          containsAll(['accountHolderName', 'ifscCode']));
      expect(applicationProblems(goodForm()..altPhone = '9876543210'), contains('altPhone'));
    });
    test('phone normalisation and Aadhaar masking', () {
      expect(normPhone('+91 98765-43210'), '9876543210');
      expect(normPhone('09876543210'), '9876543210');
      expect(maskAadhaar('2345 6789 0123'), 'XXXX XXXX 0123');
    });
    test('password is checked, never trimmed', () {
      expect(accountProblems(goodForm(), needsAccount: true), isEmpty);
      expect(accountProblems(goodForm()..password = '12345', needsAccount: true), contains('password'));
      expect(goodForm().toPayload().containsKey('password'), isFalse, reason: 'credentials never reach the callable');
    });
  });

  group('RegistrationService', () {
    test('creates the account once, password as typed, fixed paths, then submits', () async {
      final b = FakeBackend();
      await RegistrationService(b).submitAll(goodForm(), allPhotos());
      expect(b.creates, 1);
      expect(b.passwordSeen, ' pass with spaces ');
      expect(b.log, [
        'upload delivery_documents/u1/aadhaarFront',
        'upload delivery_documents/u1/aadhaarBack',
        'upload delivery_documents/u1/selfie',
        'upload delivery_documents/u1/license',
        'submit',
      ]);
    });

    test('a failed upload then retry: account reused, finished photos not re-sent', () async {
      final b = FakeBackend()
        ..failPath = 'delivery_documents/u1/selfie'
        ..failUploadOf = const RegistrationException(RegistrationFailure.uploadFailed);
      final s = RegistrationService(b);
      await expectLater(s.submitAll(goodForm(), allPhotos()), throwsA(isA<RegistrationException>()));
      expect(b.uid, 'u1', reason: 'the account is kept, never deleted');
      b.log.clear();
      await s.submitAll(goodForm(), allPhotos());
      expect(b.creates, 1);
      expect(b.log, ['upload delivery_documents/u1/selfie', 'upload delivery_documents/u1/license', 'submit']);
    });

    test('a resumed registration (already signed in) never creates an account', () async {
      final b = FakeBackend()..uid = 'existing';
      await RegistrationService(b).submitAll(goodForm(), allPhotos());
      expect(b.creates, 0);
      expect(b.log.first, 'upload delivery_documents/existing/aadhaarFront');
    });
  });

  group('screen', () {
    Future<(FakeBackend, RegistrationService)> pump(WidgetTester t, {String? uid}) async {
      final b = FakeBackend()..uid = uid;
      final s = RegistrationService(b);
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(ChangeNotifierProvider<DeliveryAuthProvider>(
        create: (_) => DeliveryAuthProvider(gateway: _NoAuth(), store: _NoStore(), pushTokens: _NoPush()),
        child: MaterialApp(
          theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RiderRegistrationScreen(service: s, pickPhoto: (_) async => photo),
        ),
      ));
      await t.pumpAndSettle();
      return (b, s);
    }

    testWidgets('a resumed registration skips the account step and says why', (t) async {
      await pump(t, uid: 'u9');
      expect(find.text('Your account is ready — finish your details to apply.'), findsOneWidget);
      expect(find.byKey(const ValueKey('field-email')), findsNothing);
      expect(find.byKey(const ValueKey('field-name')), findsOneWidget);
    });

    testWidgets('Next marks the step\'s problems; a server refusal keeps every field', (t) async {
      final (b, _) = await pump(t, uid: 'u9');
      await t.tap(find.byKey(const ValueKey('registration-continue-1')));
      await t.pumpAndSettle();
      expect(find.text('Enter your full name'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('field-name')), 'Ravi Kumar');
      await t.enterText(find.byKey(const ValueKey('field-phone')), '9876543210');
      await t.enterText(find.byKey(const ValueKey('field-address')), '12, Main Road');
      await t.enterText(find.byKey(const ValueKey('field-city')), 'Madurai');
      await t.enterText(find.byKey(const ValueKey('field-pincode')), '625020');
      await t.tap(find.byKey(const ValueKey('registration-continue-1')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('field-vehicleNumber')), 'TN58AB1234');
      await t.enterText(find.byKey(const ValueKey('field-licenseNumber')), 'TN5820200001234');
      await t.tap(find.byKey(const ValueKey('registration-continue-2')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('field-aadhaarNumber')), '234567890123');
      for (final d in RiderDocument.values) {
        await t.tap(find.byKey(ValueKey('photo-${d.key}')));
        await t.pumpAndSettle();
      }
      await t.tap(find.byKey(const ValueKey('registration-continue-3')));
      await t.pumpAndSettle();
      b.failSubmit = const RegistrationException(RegistrationFailure.invalidDetails, ['pincode']);
      await t.tap(find.byKey(const ValueKey('registration-continue-4')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('registration-failure')), findsOneWidget);
      expect(find.text('Enter a 6-digit PIN code'), findsOneWidget, reason: 'jumped to the refused field');
      expect(find.widgetWithText(TextFormField, 'Ravi Kumar'), findsOneWidget, reason: 'nothing typed was lost');
      expect(b.log.where((e) => e.startsWith('upload')).length, 4);
    });
  });
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
