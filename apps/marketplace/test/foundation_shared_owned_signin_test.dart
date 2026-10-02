@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends FirebaseAuthPlatform {
  String? uid;
  final events = StreamController<UserPlatform?>.broadcast();
  int listening = 0, cancelled = 0;
  final calls = <String>[];
  Future<void> Function(String)? hold;
  String resultUid = 'signed_in';
  bool emitResult = true, publishResult = true, closeOnListen = false;
  Object? sdkError;
  final endings = StreamController<void>.broadcast();
  String? lastEmail, lastPassword;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);
  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.multi((sink) {
        listening++;
        sink.add(currentUser);
        if (closeOnListen) {
          sink.onCancel = () {
            cancelled++;
          };
          sink.close();
          return;
        }
        final ending = endings.stream.listen((_) => sink.close());
        final sub = events.stream
            .listen(sink.add, onError: sink.addError, onDone: sink.close);
        sink.onCancel = () async {
          cancelled++;
          await sub.cancel();
          await ending.cancel();
        };
      });
  void emit(String? owner) {
    uid = owner;
    events.add(currentUser);
  }

  Future<UserCredentialPlatform> login(String method) async {
    calls.add(method);
    await hold?.call('sdk');
    if (sdkError != null) throw sdkError!;
    if (emitResult) {
      uid = resultUid;
      if (publishResult) events.add(currentUser);
    }
    return _Credential(this, _User(this, resultUid));
  }

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
      String email, String password) {
    lastEmail = email;
    lastPassword = password;
    return login('register');
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
      String email, String password) {
    lastEmail = email;
    lastPassword = password;
    return login('email');
  }

  @override
  Future<UserCredentialPlatform> signInWithCredential(
          AuthCredential credential) =>
      login('credential');
  @override
  Future<UserCredentialPlatform> signInWithCustomToken(String token) =>
      login('phone');
}

class _Credential extends UserCredentialPlatform {
  _Credential(FirebaseAuthPlatform auth, UserPlatform user)
      : super(auth: auth, user: user);
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(this.owner, String uid)
      : super(
            owner,
            _Factor(owner),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid,
                    isAnonymous: false,
                    isEmailVerified: true,
                    email: '$uid@example.invalid',
                    displayName: 'SDK user'),
                providerData: []));
  final _Auth owner;
  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    owner.calls.add('displayName');
    await owner.hold?.call('displayName');
  }
}

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  Future<void> Function(String, Object)? beforeSet;
  Future<void> Function(String)? beforeRemove;
  String? failSetKey;
  final sets = <String>[], removals = <String>[];
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    sets.add(key);
    await beforeSet?.call(key, value);
    if (key == failSetKey) return false;
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    removals.add(key);
    await beforeRemove?.call(key);
    return super.remove(key);
  }
}

class _WriteCodec extends StandardMessageCodec {
  const _WriteCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) => switch (type) {
        130 => fs.DocumentReferenceRequest.decode(readValue(buffer)!),
        131 => fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!),
        135 => fs.PigeonFirebaseSettings.decode(readValue(buffer)!),
        187 => 'fixture_server_timestamp',
        188 => fs.Timestamp(buffer.getInt64(), buffer.getInt32()),
        190 => readValue(buffer),
        192 =>
          List.generate(readSize(buffer), (_) => readValue(buffer)).join('.'),
        _ => super.readValueOfType(type, buffer),
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const documents = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  const prefix =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.';
  late _Auth auth;
  late AuthService service;
  late _Store store;
  late List<String> reads, writes, acquisitions;
  Future<void> Function(String)? hold;
  bool missing = false;
  int listenBase = 0, cancelBase = 0;
  Future<void> drain() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Object?> start(String method, {String? expectedUid}) =>
      http.runWithClient(() async {
        switch (method) {
          case 'register':
            return service.registerWithEmail(
                email: ' MIXED@Example.Invalid ',
                password: ' password ',
                name: ' Name ');
          case 'email':
            return service.signInWithEmail(
                email: ' MIXED@Example.Invalid ', password: ' password ');
          case 'google':
            return service.signInWithGoogle();
          case 'linked':
            return service.signInWithLinkedGoogleCredential(
                PendingGoogleIdentity(
                    credential:
                        GoogleAuthProvider.credential(idToken: 'fixture'),
                    idToken: 'fixture'),
                expectedUid: expectedUid);
          default:
            return service.verifyPhoneOTP(
                phone: '+919999999999', otp: '123456', name: ' Name ');
        }
      },
          () => MockClient((request) async {
                acquisitions.add('http');
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['debugMock'], isTrue);
                expect(body['name'], 'Name');
                await hold?.call('http');
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'token': 'fixture',
                      'isNewUser': true
                    }),
                    200);
              }));
  Future<Object?> captured(String method, {String? expectedUid}) async {
    try {
      return await start(method, expectedUid: expectedUid);
    } catch (e) {
      return e;
    }
  }

  Future<void> seed(String uid) => SharedPreferencesService.saveUserSession(
      userId: uid, email: '$uid@example.invalid', name: 'Seed', role: 'user');
  setUpAll(() async {
    await Firebase.initializeApp();
    auth = _Auth();
    FirebaseAuthPlatform.instance = auth;
    service = AuthService();
  });
  setUp(() async {
    auth.uid = null;
    auth.resultUid = 'signed_in';
    auth.emitResult = true;
    auth.publishResult = true;
    auth.closeOnListen = false;
    auth.sdkError = null;
    auth.calls.clear();
    auth.lastEmail = null;
    auth.lastPassword = null;
    hold = null;
    auth.hold = (stage) async => hold?.call(stage);
    missing = false;
    reads = [];
    writes = [];
    acquisitions = [];
    listenBase = auth.listening;
    cancelBase = auth.cancelled;
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    await SharedPreferencesService.init();
    store.beforeSet = (key, value) async => hold?.call('cache');
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      reads.add(r.path);
      await hold?.call('read');
      return [
        fs.PigeonDocumentSnapshot(
            path: r.path,
            data: missing
                ? null
                : {
                    'name': 'Server',
                    'email': 'signed_in@example.invalid',
                    'role': 'seller',
                  },
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
    });
    for (final operation in [
      'documentReferenceUpdate',
      'documentReferenceSet'
    ]) {
      messenger.setMockMessageHandler('$prefix$operation', (message) async {
        final r = (const _WriteCodec().decodeMessage(message)! as List)[1]
            as fs.DocumentReferenceRequest;
        writes.add('$operation:${r.path}');
        await hold?.call(operation.endsWith('Set') ? 'set' : 'update');
        return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
      });
    }
    messenger.setMockMethodCallHandler(google, (call) async {
      if (call.method == 'signIn') {
        acquisitions.add('google');
        return {
          'email': 'fixture@example.invalid',
          'id': 'fixture',
          'displayName': 'Fixture'
        };
      }
      if (call.method == 'getTokens') {
        acquisitions.add('tokens');
        await hold?.call('tokens');
        return {'idToken': 'fixture', 'accessToken': 'fixture'};
      }
      return null;
    });
  });
  tearDown(() async {
    hold = null;
    await drain();
    expect(auth.cancelled - cancelBase, auth.listening - listenBase,
        reason: 'Temporary SDK listeners must be released');
    messenger.setMockDecodedMessageHandler<Object?>(documents, null);
    for (final operation in [
      'documentReferenceUpdate',
      'documentReferenceSet'
    ]) {
      messenger.setMockMessageHandler('$prefix$operation', null);
    }
    messenger.setMockMethodCallHandler(google, null);
  });
  const methods = ['register', 'email', 'google', 'linked', 'phone'];
  for (final method in methods) {
    test('$method valid sign-in uses server profile and releases observers',
        () async {
      final result = await start(method);
      if (method == 'phone') {
        expect((result as PhoneAuthResult).isNewUser, isTrue);
      }
      expect(SharedPreferencesService.getUserId(), 'signed_in');
      expect(SharedPreferencesService.getUserRole(), 'seller');
      expect(SharedPreferencesService.getUserName(), 'Server');
      if (method == 'register' || method == 'email') {
        expect(auth.lastEmail, 'mixed@example.invalid');
        expect(auth.lastPassword, ' password ');
      }
    });
    test('$method rejects returned UID that is not the current SDK owner',
        () async {
      auth.emitResult = false;
      expect(await captured(method), isException);
      expect(reads, isEmpty);
      expect(writes, isEmpty);
      expect(store.sets, isEmpty);
    });
    for (final stage in [
      'sdk',
      'read',
      'cache',
      if (method == 'register') 'displayName',
      if (method == 'register') 'set',
      if (method == 'email' || method == 'google' || method == 'linked')
        'update',
      if (method == 'phone') 'http',
      if (method == 'google') 'tokens'
    ]) {
      for (final change in [
        'switch',
        'renew',
        'return',
        'signout',
        'error',
        'done'
      ]) {
        test('$method $stage rejects $change before continuing', () async {
          final entered = Completer<void>(), release = Completer<void>();
          var blocked = false;
          hold = (where) async {
            if (where == stage && !blocked) {
              blocked = true;
              entered.complete();
              await release.future;
            }
          };
          final pending = captured(method);
          try {
            await entered.future.timeout(const Duration(seconds: 3));
            final prior = auth.uid;
            if (change == 'done') {
              auth.endings.add(null);
            } else if (change == 'error') {
              auth.events.addError(StateError('fixture'));
            } else if (change == 'renew') {
              auth.emit(prior);
            } else if (change == 'signout') {
              auth.emit(null);
            } else {
              auth.emit('new_owner');
            }
            await drain();
            if (change == 'return') {
              auth.emit(prior);
              await drain();
            }
            final readCount = reads.length, writeCount = writes.length;
            final sdkCount = auth.calls.where((x) => x != 'displayName').length;
            Future<void>? newerCache;
            if (stage == 'cache') {
              store.beforeSet = null;
              newerCache = seed('new_owner');
            }
            release.complete();
            await newerCache;
            expect(await pending, isException);
            expect(reads.length, readCount);
            expect(writes.length, writeCount);
            if (stage == 'http' || stage == 'tokens') {
              expect(
                  auth.calls.where((x) => x != 'displayName').length, sdkCount);
            }
            if (stage == 'cache') {
              expect(SharedPreferencesService.getUserId(), 'new_owner');
            }
          } finally {
            if (!release.isCompleted) release.complete();
            await pending;
          }
        });
      }
    }
    for (final second in methods) {
      test('$method holds the shared gate against $second then allows retry',
          () async {
        final entered = Completer<void>(), release = Completer<void>();
        var first = true;
        hold = (stage) async {
          if (stage == 'sdk' && first) {
            first = false;
            entered.complete();
            await release.future;
          }
        };
        final pending = captured(method);
        try {
          await entered.future.timeout(const Duration(seconds: 3));
          expect(await captured(second), isException);
          expect(auth.calls.where((x) => x != 'displayName').length, 1);
        } finally {
          release.complete();
          await pending;
        }
        hold = null;
        expect(await captured(second), isNot(isException));
      });
    }
  }
  for (final method in methods) {
    test('$method same current UID can perform one intended reauthentication',
        () async {
      auth.uid = 'signed_in';
      expect(await captured(method), isNot(isException));
      expect(SharedPreferencesService.getUserId(), 'signed_in');
    });
    test('$method closed initial observer prevents SDK and acquisition work',
        () async {
      auth.closeOnListen = true;
      expect(await captured(method), isException);
      expect(auth.calls, isEmpty);
      expect(acquisitions, isEmpty);
      auth.closeOnListen = false;
      expect(await captured(method), isNot(isException));
    });
    test('$method SDK failure releases gate and hides raw diagnostic values',
        () async {
      auth.sdkError = FirebaseAuthException(
          code: 'unknown-fixture', message: 'PRIVATE_DIAGNOSTIC');
      final result = await captured(method);
      expect(result, isException);
      expect(result.toString(), isNot(contains('PRIVATE_DIAGNOSTIC')));
      expect(reads, isEmpty);
      expect(writes, isEmpty);
      auth.sdkError = null;
      expect(await captured(method), isNot(isException));
    });
    test('$method foreign current UID differs from returned credential',
        () async {
      auth.uid = 'foreign';
      auth.emitResult = false;
      expect(await captured(method), isException);
      expect(reads, isEmpty);
      expect(writes, isEmpty);
      expect(auth.uid, 'foreign');
    });
    test(
        '$method queued foreign-return cannot substitute its delayed intended event',
        () async {
      auth.publishResult = false;
      final entered = Completer<void>(), release = Completer<void>();
      var held = false;
      hold = (stage) async {
        if (stage == 'read' && !held) {
          held = true;
          entered.complete();
          await release.future;
        }
      };
      final pending = captured(method);
      try {
        await entered.future.timeout(const Duration(seconds: 3));
        expect(auth.uid, 'signed_in');
        // Both callbacks are queued before observers run. The current SDK owner
        // is already back, but the intervening foreign episode must revoke this.
        auth.emit('foreign');
        auth.emit('signed_in');
        await drain();
        final readCount = reads.length, writeCount = writes.length;
        release.complete();
        expect(await pending, isException);
        expect(reads.length, readCount);
        expect(writes.length, writeCount);
        expect(store.sets, isEmpty);
        expect(auth.uid, 'signed_in');
      } finally {
        if (!release.isCompleted) release.complete();
        await pending;
      }
    });
    test('$method SDK result may precede its one intended auth event',
        () async {
      auth.publishResult = false;
      final entered = Completer<void>(), release = Completer<void>();
      var held = false;
      hold = (stage) async {
        if (stage == 'read' && !held) {
          held = true;
          entered.complete();
          await release.future;
        }
      };
      final pending = captured(method);
      try {
        await entered.future.timeout(const Duration(seconds: 3));
        auth.emit('signed_in');
        await drain();
        release.complete();
        expect(await pending, isNot(isException));
      } finally {
        if (!release.isCompleted) release.complete();
        await pending;
      }
    });
  }
  test(
      'linked Google retains resolver UID check without foreign profile writes',
      () async {
    expect(await captured('linked', expectedUid: 'different'), isException);
    expect(reads, isEmpty);
    expect(writes, isEmpty);
  });
  test('email missing server record is created with default user role',
      () async {
    missing = true;
    expect(await captured('email'), isNot(isException));
    expect(SharedPreferencesService.getUserRole(), 'user');
    expect(writes.last, 'documentReferenceSet:users/signed_in');
  });
}
