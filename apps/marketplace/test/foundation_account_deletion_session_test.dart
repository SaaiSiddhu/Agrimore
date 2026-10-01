@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart' as app;
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_core/firebase_core.dart';
// Cached official native transports; no network or production accounts.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends FirebaseAuthPlatform {
  String? uid = 'owner_a';
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser =>
      uid == null ? null : _PlatformUser(this, uid!);
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _PlatformUser extends UserPlatform {
  _PlatformUser(FirebaseAuthPlatform auth, String uid)
      : super(
            auth,
            _Factor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid, isAnonymous: false, isEmailVerified: true),
                providerData: []));
}

class _EventUser implements User {
  _EventUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service implements AuthService {
  String? uid = 'owner_a';
  final events = StreamController<User?>.broadcast();
  final deletions = <String?>[];
  Future<void> Function()? deleting;
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => events.stream;
  @override
  Future<UserModel> getUserData(String uid) async => UserModel(
      uid: uid,
      email: '$uid@example.invalid',
      name: uid,
      role: 'user',
      createdAt: DateTime(2026),
      profileCompleted: true);
  @override
  Future<void> deleteAccount({String? expectedOwnerId}) async {
    deletions.add(expectedOwnerId);
    await deleting?.call();
  }

  void switchTo(String? owner) {
    uid = owner;
    events.add(owner == null ? null : _EventUser(owner));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends InMemorySharedPreferencesStore {
  _Preferences() : super.empty();
  final removals = <String>[];
  Future<void> Function(String)? afterRemove;
  @override
  Future<bool> remove(String key) async {
    removals.add(key);
    final result = await super.remove(key);
    await afterRemove?.call(key);
    return result;
  }
}

// Request-only decoder: Dart's production codec decodes native replies,
// while outbound auth-log writes carry server-timestamp tags.
class _WriteCodec extends StandardMessageCodec {
  const _WriteCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) => switch (type) {
        130 => fs.DocumentReferenceRequest.decode(readValue(buffer)!),
        131 => fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!),
        135 => fs.PigeonFirebaseSettings.decode(readValue(buffer)!),
        187 => 'fixture_server_timestamp',
        _ => super.readValueOfType(type, buffer),
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const callable = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  const writes = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet',
      fs.FirebaseFirestoreHostApi.codec);
  late _Auth transport;
  late _Preferences store;
  late List<Map> calls;
  late List<fs.DocumentReferenceRequest> logs;
  late Future<List<Object?>> Function(Map) reply;
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> seedSession(String uid) =>
      SharedPreferencesService.saveUserSession(
          userId: uid, email: '$uid@example.invalid', name: uid, role: 'user');
  setUpAll(() async {
    await Firebase.initializeApp();
    transport = _Auth();
    FirebaseAuthPlatform.instance = transport;
  });
  setUp(() async {
    transport.uid = 'owner_a';
    SharedPreferences.setMockInitialValues({});
    store = _Preferences();
    SharedPreferencesStorePlatform.instance = store;
    await SharedPreferencesService.init();
    await seedSession('owner_a');
    calls = [];
    logs = [];
    reply = (_) async => [
          {'success': true}
        ];
    messenger.setMockDecodedMessageHandler(callable, (message) async {
      final data = (message as List).single as Map;
      calls.add(data);
      return reply(data);
    });
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
        (_) async => fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]));
    messenger.setMockMessageHandler(writes.name, (message) async {
      final request = (const _WriteCodec().decodeMessage(message) as List)[1]
          as fs.DocumentReferenceRequest;
      logs.add(request);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
  });
  tearDown(() {
    messenger.setMockDecodedMessageHandler(callable, null);
    messenger.setMockMessageHandler(writes.name, null);
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
        null);
  });

  group('actual shared deletion service', () {
    test(
        'captures current owner in payload and clears confirmed own persisted session',
        () async {
      await AuthService().deleteAccount();
      expect(calls.single['functionName'], 'deleteUserData');
      expect(calls.single['parameters'], {'expectedOwnerId': 'owner_a'});
      expect(SharedPreferencesService.getUserId(), isNull);
      expect(SharedPreferencesService.isLoggedIn(), isFalse);
    });
    test('caller expected owner mismatch stops before callable IO', () async {
      await expectLater(AuthService().deleteAccount(expectedOwnerId: 'owner_b'),
          throwsA(isA<AuthException>()));
      expect(calls, isEmpty);
      expect(SharedPreferencesService.getUserId(), 'owner_a');
    });
    test('signed-out caller cannot send deletion', () async {
      transport.uid = null;
      await expectLater(
          AuthService().deleteAccount(), throwsA(isA<UnauthorizedException>()));
      expect(calls, isEmpty);
    });
    for (final result in [
      {'success': false},
      <String, dynamic>{},
      {'success': 'true'}
    ]) {
      test('unconfirmed response $result cannot clear session', () async {
        reply = (_) async => [result];
        await expectLater(
            AuthService().deleteAccount(), throwsA(isA<AuthException>()));
        expect(SharedPreferencesService.getUserId(), 'owner_a');
        expect(store.removals, isEmpty);
      });
    }
    test('network failure and server refusal preserve session and refusal code',
        () async {
      reply = (_) async => [
            'functions-error',
            'You have a pending payout request.',
            {
              'code': 'failed-precondition',
              'message': 'You have a pending payout request.'
            }
          ];
      await expectLater(
          AuthService().deleteAccount(),
          throwsA(isA<AuthException>()
              .having((e) => e.code, 'code', 'failed-precondition')));
      expect(store.removals, isEmpty);
      expect(SharedPreferencesService.getUserId(), 'owner_a');
    });
    test(
        'account changes during callable reply preserve newer persisted identity',
        () async {
      reply = (_) async {
        transport.uid = 'owner_b';
        await seedSession('owner_b');
        return [
          {'success': true}
        ];
      };
      await expectLater(
          AuthService().deleteAccount(),
          throwsA(isA<AuthException>()
              .having((e) => e.code, 'code', 'session-changed')));
      expect(calls.single['parameters'], {'expectedOwnerId': 'owner_a'});
      expect(SharedPreferencesService.getUserId(), 'owner_b');
      expect(store.removals, isEmpty);
    });
    test(
        'confirmed own deletion with Auth sign-out clears own stale preferences',
        () async {
      reply = (_) async {
        transport.uid = null;
        return [
          {'success': true}
        ];
      };
      await AuthService().deleteAccount();
      expect(SharedPreferencesService.getUserId(), isNull);
    });
    test(
        'foreign stored identity is preserved even if active transport owner is unchanged',
        () async {
      await seedSession('owner_b');
      await AuthService().deleteAccount();
      expect(SharedPreferencesService.getUserId(), 'owner_b');
      expect(store.removals, isEmpty);
    });
    test(
        'account switch while cleanup reply is delayed stops all remaining removals',
        () async {
      store.afterRemove = (_) async {
        store.afterRemove = null;
        transport.uid = 'owner_b';
        await seedSession('owner_b');
      };
      await expectLater(
          AuthService().deleteAccount(), throwsA(isA<AuthException>()));
      expect(store.removals.length, 1);
      expect(SharedPreferencesService.getUserId(), 'owner_b');
      expect(
          SharedPreferencesService.getUserEmail(), 'owner_b@example.invalid');
      expect(SharedPreferencesService.isLoggedIn(), isTrue);
    });
  });
  group('persisted cleanup compatibility', () {
    test('legacy cleanup without guard still clears all previous session keys',
        () async {
      await SharedPreferencesService.clearUserSession();
      expect(store.removals.length, 8);
      expect(SharedPreferencesService.getUserId(), isNull);
    });
    test('false session predicate prevents any removal', () async {
      await SharedPreferencesService.clearUserSession(
          expectedUserId: 'owner_a', isSessionCurrent: () => false);
      expect(store.removals, isEmpty);
    });
    test(
        'stored owner changes mid-cleanup independently prevent remaining removals',
        () async {
      store.afterRemove = (_) async {
        store.afterRemove = null;
        await seedSession('owner_b');
      };
      await SharedPreferencesService.clearUserSession(
          expectedUserId: 'owner_a');
      expect(store.removals.length, 1);
      expect(SharedPreferencesService.getUserId(), 'owner_b');
      expect(SharedPreferencesService.isLoggedIn(), isTrue);
    });
  });
  group('actual marketplace deletion provider', () {
    late _Service service;
    late app.AuthProvider auth;
    setUp(() async {
      service = _Service();
      auth = app.AuthProvider(authService: service);
      service.switchTo('owner_a');
      await drain();
      logs.clear();
    });
    tearDown(() async {
      auth.dispose();
      await service.events.close();
    });
    test(
        'valid deletion carries initiating UID and reports success only for current session',
        () async {
      expect(await auth.deleteAccount(), isTrue);
      expect(service.deletions, ['owner_a']);
      expect(auth.currentUser, isNull);
      expect(auth.isLoading, isFalse);
    });
    test('no owned profile cannot start deletion', () async {
      service.uid = 'owner_b';
      expect(await auth.deleteAccount(), isFalse);
      expect(service.deletions, isEmpty);
    });
    test('reentrant account switch during busy notification prevents dispatch',
        () async {
      auth.addListener(() {
        if (auth.isLoading) service.uid = 'owner_b';
      });
      expect(await auth.deleteAccount(), isFalse);
      expect(service.deletions, isEmpty);
    });
    test('second concurrent delete action cannot issue a duplicate command',
        () async {
      final pending = Completer<void>();
      service.deleting = () => pending.future;
      final first = auth.deleteAccount();
      expect(await auth.deleteAccount(), isFalse);
      expect(service.deletions, ['owner_a']);
      pending.complete();
      expect(await first, isTrue);
    });
    test(
        'late delete success preserves new account and returns no stale success',
        () async {
      final pending = Completer<void>();
      service.deleting = () => pending.future;
      final old = auth.deleteAccount();
      service.switchTo('owner_b');
      await drain();
      pending.complete();
      expect(await old, isFalse);
      expect(auth.userUid, 'owner_b');
      expect(auth.error, isNull);
      expect(logs, isEmpty);
    });
    test('late failure cannot publish error or clear new account', () async {
      final pending = Completer<void>();
      service.deleting = () => pending.future;
      final old = auth.deleteAccount();
      service.switchTo('owner_b');
      await drain();
      pending.completeError(
          AuthException('OLD_ACCOUNT_REFUSAL', code: 'failed-precondition'));
      expect(await old, isFalse);
      expect(auth.userUid, 'owner_b');
      expect(auth.error, isNull);
    });
    test(
        'same-owner session renewal prevents stale deletion reply altering renewed profile',
        () async {
      final pending = Completer<void>();
      service.deleting = () => pending.future;
      final old = auth.deleteAccount();
      service.switchTo('owner_a');
      await drain();
      pending.complete();
      expect(await old, isFalse);
      expect(auth.userUid, 'owner_a');
    });
    test('owned refusal retains actionable code and existing profile',
        () async {
      service.deleting = () async => throw AuthException(
          'You have a pending payout request.',
          code: 'failed-precondition');
      expect(await auth.deleteAccount(), isFalse);
      expect(auth.errorCode, 'failed-precondition');
      expect(auth.userUid, 'owner_a');
      expect(auth.isLoading, isFalse);
    });
    test('unexpected owned failure uses safe static copy', () async {
      service.deleting = () async => throw StateError('PRIVATE_DETAIL');
      expect(await auth.deleteAccount(), isFalse);
      expect(auth.error, 'Failed to delete account. Please try again.');
      expect(auth.errorCode, isNull);
    });
    test('confirmed own Auth sign-out remains a valid deletion outcome',
        () async {
      service.deleting = () async {
        service.switchTo(null);
        await drain();
      };
      expect(await auth.deleteAccount(), isTrue);
      expect(auth.currentUser, isNull);
      expect(auth.isLoading, isFalse);
    });
    test('disposal in flight absorbs success without notifications or logs',
        () async {
      final pending = Completer<void>();
      service.deleting = () => pending.future;
      final old = auth.deleteAccount();
      auth.dispose();
      pending.complete();
      expect(await old, isFalse);
      expect(logs, isEmpty);
    });
    test('disposed provider cannot start deletion', () async {
      auth.dispose();
      expect(await auth.deleteAccount(), isFalse);
      expect(service.deletions, isEmpty);
    });
  });
}
