// Phase DLV-A2 — the rider's own account: refusals worded from stable
// reasons, identifiers masked, documents' state, who may resubmit, contact
// edits through the server, and a resubmission prefilled from the record.
import 'dart:typed_data';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/account/rider_account.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:delivery/screens/auth/pending_approval_screen.dart' show canResubmit;
import 'package:delivery/screens/auth/rider_registration_screen.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeAccount implements RiderAccountBackend {
  Map<String, dynamic>? saved;
  AccountActionException? fail;
  @override
  Future<void> updateContact(Map<String, dynamic> contact) async {
    if (fail != null) throw fail!;
    saved = contact;
  }

  @override
  Future<void> deleteAccount() async {}
}

class FakeReg implements RegistrationBackend {
  @override
  String? get currentUid => 'u1';
  final log = <String>[];
  @override
  Future<String> createAccount(String email, String password) async => 'u1';
  @override
  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType) async => log.add(path);
  @override
  Future<void> submit(Map<String, dynamic> payload) async => log.add('submit ${payload['city']}');
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

void main() {
  test('refusal reasons map to specific wording keys', () {
    expect(accountFailureOf('failed-precondition', 'rider_active_order'), AccountActionFailure.activeOrder);
    expect(accountFailureOf('failed-precondition', 'rider_cash_held'), AccountActionFailure.cashHeld);
    expect(accountFailureOf('failed-precondition', 'rider_pay_owed'), AccountActionFailure.payOwed);
    expect(accountFailureOf('failed-precondition', null), AccountActionFailure.otherBalance);
    expect(accountFailureOf('invalid-argument', 'invalid'), AccountActionFailure.invalid);
    expect(accountFailureOf('unavailable', null), AccountActionFailure.network);
  });

  test('identifiers are masked; documents on file by path or old URL', () {
    expect(maskTail('123456789012'), '•••• 9012');
    expect(maskTail(''), '');
    final on = documentsOnFile({
      'kycDocuments': {'aadhaarFront': 'delivery_documents/u/aadhaarFront'},
      'licenseImage': 'https://old',
    });
    expect(on[RiderDocument.aadhaarFront], isTrue);
    expect(on[RiderDocument.license], isTrue);
    expect(on[RiderDocument.selfie], isFalse);
  });

  test('only pending and rejected riders may resubmit', () {
    expect(canResubmit(RiderKycStatus.pending), isTrue);
    expect(canResubmit(RiderKycStatus.rejected), isTrue);
    expect(canResubmit(RiderKycStatus.approved), isFalse);
    expect(canResubmit(RiderKycStatus.suspended), isFalse);
  });

  testWidgets('contact edit: server problems marked on the field; success saves exactly the four fields', (t) async {
    final b = FakeAccount()..fail = const AccountActionException(AccountActionFailure.invalid, ['pincode']);
    await t.pumpWidget(host(ContactEditSheet(initial: const {'city': 'Madurai', 'pincode': '1'}, backend: b)));
    await t.tap(find.byKey(const ValueKey('contact-save')));
    await t.pumpAndSettle();
    expect(find.text('Enter a 6-digit PIN code'), findsOneWidget);
    b.fail = null;
    await t.enterText(find.byKey(const ValueKey('contact-pincode')), '625020');
    await t.tap(find.byKey(const ValueKey('contact-save')));
    await t.pumpAndSettle();
    expect(b.saved, {'altPhone': '', 'address': '', 'city': 'Madurai', 'pincode': '625020'});
  });

  testWidgets('resubmission is prefilled; photos on file need no new upload', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    final reg = FakeReg();
    await t.pumpWidget(host(RiderRegistrationScreen(
      service: RegistrationService(reg),
      initial: const {
        'name': 'Ravi Kumar', 'phone': '9876543210', 'vehicleType': 'bike', 'vehicleNumber': 'TN58AB1234',
        'licenseNumber': 'TN5820200001234', 'aadhaarNumber': '234567890123', 'address': '12, Main Road',
        'city': 'Madurai', 'pincode': '625020',
        'kycDocuments': {
          'aadhaarFront': 'delivery_documents/u1/aadhaarFront', 'aadhaarBack': 'delivery_documents/u1/aadhaarBack',
          'selfie': 'delivery_documents/u1/selfie', 'license': 'delivery_documents/u1/license',
        },
      },
    )));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Ravi Kumar'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('field-city')), 'Chennai');
    for (final step in [1, 2, 3, 4]) {
      await t.tap(find.byKey(ValueKey('registration-continue-$step')));
      await t.pumpAndSettle();
    }
    expect(reg.log, ['submit Chennai'], reason: 'no photo re-uploaded; corrected city submitted');
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
