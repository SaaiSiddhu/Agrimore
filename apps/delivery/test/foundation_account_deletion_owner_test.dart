@TestOn('vm')
library;

import 'package:delivery/account/rider_account.dart';
import 'package:firebase_core/firebase_core.dart';
// Cached official local platform harness; no Firebase/provider network.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends FirebaseAuthPlatform {
  String? uid = 'rider_a';
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth, String uid)
      : super(
            auth,
            _Factor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid, isAnonymous: false, isEmailVerified: true),
                providerData: []));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const callable = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Auth auth;
  late List<Map> calls;
  late CallableRiderAccountBackend backend;
  late Future<List<Object?>> Function(Map) reply;
  setUpAll(() async {
    await Firebase.initializeApp();
    auth = _Auth();
    FirebaseAuthPlatform.instance = auth;
  });
  setUp(() {
    auth.uid = 'rider_a';
    calls = [];
    reply = (_) async => [
          {'success': true}
        ];
    backend = CallableRiderAccountBackend();
    messenger.setMockDecodedMessageHandler(callable, (message) async {
      final data = (message as List).single as Map;
      calls.add(data);
      return reply(data);
    });
  });
  tearDown(() {
    messenger.setMockDecodedMessageHandler(callable, null);
  });
  test('confirmed own deletion forwards captured owner', () async {
    await backend.deleteAccount();
    expect(calls.single['functionName'], 'deleteUserData');
    expect(calls.single['parameters'], {'expectedOwnerId': 'rider_a'});
  });
  test('signed-out rider cannot send deletion', () async {
    auth.uid = null;
    await expectLater(
        backend.deleteAccount(), throwsA(isA<AccountActionException>()));
    expect(calls, isEmpty);
  });
  test('new rider during response prevents old success handoff', () async {
    reply = (_) async {
      auth.uid = 'rider_b';
      return [
        {'success': true}
      ];
    };
    await expectLater(
        backend.deleteAccount(), throwsA(isA<AccountActionException>()));
    expect(calls.single['parameters'], {'expectedOwnerId': 'rider_a'});
    expect(auth.uid, 'rider_b');
  });
  test('confirmed deletion with own Auth sign-out remains usable', () async {
    reply = (_) async {
      auth.uid = null;
      return [
        {'success': true}
      ];
    };
    await backend.deleteAccount();
  });
  for (final data in [
    {'success': false},
    <String, Object>{},
    {'success': 'true'},
    null,
    'unexpected'
  ]) {
    test('unconfirmed response $data cannot become deletion success', () async {
      reply = (_) async => [data];
      await expectLater(
          backend.deleteAccount(), throwsA(isA<AccountActionException>()));
    });
  }
  for (final reason in [
    'rider_active_order',
    'rider_cash_held',
    'rider_pay_owed'
  ]) {
    test('owned deletion preserves typed $reason refusal', () async {
      reply = (_) async => [
            'functions-error',
            'Fixture refusal',
            {
              'code': 'failed-precondition',
              'message': 'Fixture refusal',
              'additionalData': {'reason': reason}
            }
          ];
      await expectLater(
          backend.deleteAccount(),
          throwsA(isA<AccountActionException>().having((e) => e.failure,
              'failure', accountFailureOf('failed-precondition', reason))));
    });
  }
  test('contact action payload remains unchanged', () async {
    await backend.updateContact({'phone': 'fixture'});
    expect(calls.single['functionName'], 'updateRiderContact');
    expect(calls.single['parameters'], {'phone': 'fixture'});
  });
}
