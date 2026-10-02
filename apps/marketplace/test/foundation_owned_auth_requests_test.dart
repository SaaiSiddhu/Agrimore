@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show User, AuthCredential, FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart';
// Official cached platform harness; all transports use local fixtures.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Native write requests contain FieldPath/FieldValue tags that the public
// reply codec does not decode in Dart. Decode only the fixture's request tags.
class _WriteRequestCodec extends StandardMessageCodec {
  const _WriteRequestCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 130:
        return fs.DocumentReferenceRequest.decode(readValue(buffer)!);
      case 131:
        return fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!);
      case 135:
        return fs.PigeonFirebaseSettings.decode(readValue(buffer)!);
      case 188:
        return fs.Timestamp(buffer.getInt64(), buffer.getInt32());
      case 187:
        return 'fixture_server_timestamp';
      case 184:
      case 190:
        return readValue(buffer);
      case 192:
        final count = readSize(buffer);
        return List<String>.generate(count, (_) => readValue(buffer)! as String)
            .join('.');
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Can deliberately emit callbacks after cancellation to verify epochs rather
// than relying on normal transport cancellation alone.
class _Subscription implements StreamSubscription<User?> {
  _Subscription(this.data, this.error, this.done);
  final void Function(User?)? data;
  final Function? error;
  final void Function()? done;
  int cancelled = 0;
  @override
  Future<void> cancel() async {
    cancelled++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stream extends Stream<User?> {
  final subscriptions = <_Subscription>[];
  void Function(_Subscription)? onListen;
  @override
  StreamSubscription<User?> listen(void Function(User?)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final subscription = _Subscription(onData, onError, onDone);
    subscriptions.add(subscription);
    onListen?.call(subscription);
    return subscription;
  }
}

final _pending = PendingGoogleIdentity(
    credential:
        const AuthCredential(providerId: 'fixture', signInMethod: 'fixture'),
    idToken: 'local-fixture');
UserModel _profile(String uid) => UserModel(
    uid: uid,
    email: '$uid@example.invalid',
    name: uid,
    role: 'user',
    createdAt: DateTime(2026));
Object? _value(String method) => switch (method) {
      'send' => PhoneOtpSendResult(
          userExists: true, channel: 'voice', testOtp: 'local-fixture'),
      'acquire' => _pending,
      'resolve' =>
        GoogleIdentityResolution(linked: true, expectedUid: 'owner_a'),
      'login' => _profile('owner_a'),
      _ => true,
    };

class _Auth implements AuthService {
  String? uid = 'owner_a';
  final stream = _Stream();
  final calls = <(String, Completer<Object?>)>[];
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => stream;
  @override
  Future<UserModel> getUserData(String uid) async => _profile(uid);
  Future<T> _request<T>(String method) {
    final reply = Completer<Object?>();
    calls.add((method, reply));
    return reply.future.timeout(const Duration(seconds: 2)).then((v) => v as T);
  }

  @override
  Future<PhoneOtpSendResult> sendPhoneOTP(String phone,
          {String channel = 'sms'}) =>
      _request('send');
  @override
  Future<PendingGoogleIdentity?> acquireGoogleCredential() =>
      _request('acquire');
  @override
  Future<GoogleIdentityResolution> resolveGoogleIdentity(
          PendingGoogleIdentity pending) =>
      _request('resolve');
  @override
  Future<bool> linkPendingGoogleCredential(PendingGoogleIdentity pending) =>
      _request('link');
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _request<Object?>('reset');
  }

  @override
  Future<UserModel> signInWithEmail(
          {required String email, required String password}) =>
      _request('login');
  void emit(String? owner) {
    uid = owner;
    stream.subscriptions.last.data?.call(owner == null ? null : _User(owner));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const updateChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate';
  const setChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet';
  late _Auth service;
  late AuthProvider auth;
  late List<Map<String, Object?>> audits;
  Completer<void>? auditHold, profileHold;
  var disposed = false;
  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Object?> run(String method) => switch (method) {
        'send' => auth.sendPhoneOTP('+910000000000', channel: 'voice'),
        'acquire' => auth.acquireGoogleCredential(),
        'resolve' => auth.resolveGoogleIdentity(_pending),
        'link' => auth.linkGoogleToCurrentUser(_pending),
        'reset' => auth.sendPasswordResetEmail('fixture@example.invalid'),
        'login' => auth.signInWithEmail(
            email: 'fixture@example.invalid', password: 'local-fixture'),
        _ => throw StateError('Unknown fixture method'),
      };
  void invalidate(String scenario) {
    switch (scenario) {
      case 'switch':
        service.emit('owner_b');
      case 'return':
        service.emit('owner_b');
        service.emit('owner_a');
      case 'renew':
        service.emit('owner_a');
      case 'sdk-switch':
        service.uid = 'owner_b';
      case 'dispose':
        auth.dispose();
        disposed = true;
      case 'paused':
        service.stream.subscriptions.last.done?.call();
    }
  }

  void complete() {
    for (final (method, reply) in service.calls) {
      if (!reply.isCompleted) {
        reply.complete(_value(method));
      }
    }
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _Auth();
    disposed = false;
    audits = [];
    auditHold = null;
    profileHold = null;
    messenger.setMockMessageHandler(updateChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      if (request.data?.containsKey('name') == true) {
        await profileHold?.future.timeout(const Duration(seconds: 2));
      }
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      if (request.path.startsWith('auth_logs/')) {
        audits.add(Map<String, Object?>.from(request.data!));
        await auditHold?.future.timeout(const Duration(seconds: 2));
      }
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    auth = AuthProvider(authService: service);
    service.emit('owner_a');
    await drain();
  });
  tearDown(() async {
    complete();
    if (!disposed) {
      auth.dispose();
    }
    await drain();
    messenger.setMockMessageHandler(updateChannel, null);
    messenger.setMockMessageHandler(setChannel, null);
  });
  const methods = ['send', 'acquire', 'resolve', 'link', 'reset'];
  for (final method in methods) {
    test('$method current request succeeds with current account preserved',
        () async {
      final user = auth.currentUser;
      final result = run(method);
      expect(service.calls.length, 1);
      complete();
      final value = await result;
      expect(value, isNotNull);
      expect(value, isNot(false));
      expect(auth.currentUser, same(user));
      expect(auth.isLoading, isFalse);
      if (method == 'send') {
        final code = value as PhoneOtpSendResult;
        expect(code.channel, 'voice');
        expect(code.testOtp, 'local-fixture');
      }
      if (method == 'link' || method == 'reset') {
        expect(audits.single['uid'], 'owner_a');
      }
    });
    for (final scenario in [
      'switch',
      'return',
      'renew',
      'sdk-switch',
      'dispose',
      'paused'
    ]) {
      for (final fails in [false, true]) {
        test('$method $scenario suppresses late ${fails ? 'error' : 'result'}',
            () async {
          final result = run(method);
          expect(service.calls.length, 1);
          invalidate(scenario);
          await drain();
          final user = auth.currentUser,
              error = auth.error,
              code = auth.errorCode;
          if (fails) {
            service.calls.single.$2
                .completeError(AuthException('private provider detail'));
          } else {
            complete();
          }
          expect(await result,
              method == 'link' || method == 'reset' ? isFalse : isNull);
          expect(auth.currentUser, same(user));
          expect(auth.error, error);
          expect(auth.errorCode, code);
          expect(audits, isEmpty);
        });
      }
    }
    for (final kind in ['auth', 'generic', 'firebase']) {
      test('$method owned $kind failure uses static feedback', () async {
        final result = run(method);
        service.calls.single.$2.completeError(kind == 'auth'
            ? AuthException('private provider detail')
            : kind == 'firebase'
                ? FirebaseAuthException(
                    code: 'invalid-credential',
                    message: 'private provider detail')
                : StateError('private provider detail'));
        expect(await result,
            method == 'link' || method == 'reset' ? isFalse : isNull);
        expect(auth.error, isNotNull);
        expect(auth.error, isNot(contains('private')));
        expect(auth.isLoading, isFalse);
        for (final audit in audits) {
          expect(audit['error'], isNot(contains('private')));
          expect(audit['uid'], 'owner_a');
        }
        expect(auth.userUid, 'owner_a');
      });
    }
    for (final scenario in ['dispose', 'paused']) {
      test('$method $scenario refuses dispatch', () async {
        invalidate(scenario);
        final result = run(method);
        complete();
        expect(await result,
            method == 'link' || method == 'reset' ? isFalse : isNull);
        expect(service.calls, isEmpty);
      });
    }
    test('$method renewed request releases guard for retry', () async {
      final old = run(method);
      service.emit('owner_a');
      complete();
      expect(
          await old, method == 'link' || method == 'reset' ? isFalse : isNull);
      await drain();
      service.calls.clear();
      final next = run(method);
      expect(service.calls.length, 1);
      complete();
      expect(await next, isNotNull);
    });
  }
  for (final first in methods) {
    for (final second in methods) {
      test('duplicate $first/$second dispatches once', () async {
        final old = run(first), next = run(second);
        final count = service.calls.length;
        complete();
        await old;
        expect(await next,
            second == 'link' || second == 'reset' ? isFalse : isNull);
        expect(count, 1);
      });
    }
    for (final loginFirst in [false, true]) {
      test('auth request $first loginFirst$loginFirst serializes with login',
          () async {
        final old = run(loginFirst ? 'login' : first),
            next = run(loginFirst ? first : 'login');
        final count = service.calls.length;
        complete();
        await old;
        await next;
        expect(count, 1);
      });
    }
  }
  test('Google cancellation is neutral and preserves phone session', () async {
    final user = auth.currentUser;
    final result = run('acquire');
    service.calls.single.$2.complete(null);
    expect(await result, isNull);
    expect(auth.error, isNull);
    expect(auth.currentUser, same(user));
    expect(audits, isEmpty);
  });
  test('Google link conflict preserves already authenticated phone session',
      () async {
    final user = auth.currentUser;
    final result = run('link');
    service.calls.single.$2.complete(false);
    expect(await result, isFalse);
    expect(auth.error, isNull);
    expect(auth.currentUser, same(user));
    expect(audits.single['event'], 'google_link_conflict');
    expect(audits.single['uid'], 'owner_a');
  });
  test('Google linking refuses missing observed owner', () async {
    service.emit(null);
    await drain();
    final result = run('link');
    complete();
    expect(await result, isFalse);
    expect(service.calls, isEmpty);
  });
  for (final method in ['send', 'acquire', 'resolve', 'reset']) {
    test('$method signed-out current session remains usable', () async {
      service.emit(null);
      await drain();
      final result = run(method);
      complete();
      expect(await result, isNotNull);
      expect(auth.currentUser, isNull);
      if (method == 'reset') {
        expect(audits.single['uid'], isNull);
      }
    });
  }
  for (final method in ['link', 'reset']) {
    for (final scenario in ['switch', 'renew', 'dispose', 'paused']) {
      test('$method $scenario held audit cannot complete old request',
          () async {
        auditHold = Completer<void>();
        final result = run(method);
        complete();
        await drain();
        expect(audits.length, 1);
        expect(audits.single['uid'], 'owner_a');
        invalidate(scenario);
        await drain();
        final user = auth.currentUser;
        auditHold!.complete();
        expect(await result, isFalse);
        expect(auth.currentUser, same(user));
      });
    }
    test('$method held audit cannot clear newer profile command loading',
        () async {
      auditHold = Completer<void>();
      final result = run(method);
      complete();
      await drain();
      expect(audits.length, 1);
      profileHold = Completer<void>();
      final command = auth.updateUserProfile(name: 'Fresh profile');
      await drain();
      expect(auth.isLoading, isTrue);
      auditHold!.complete();
      expect(await result, isFalse);
      expect(auth.isLoading, isTrue);
      profileHold!.complete();
      expect(await command, isTrue);
      expect(auth.userName, 'Fresh profile');
    });
  }
  test('password recovery remains usable while OTP sending is locked',
      () async {
    for (var i = 0; i < 5; i++) {
      final result = run('login');
      service.calls.last.$2
          .completeError(AuthException('private provider detail'));
      expect(await result, isFalse);
    }
    expect(auth.isLocked, isTrue);
    service.calls.clear();
    expect(await run('send'), isNull);
    expect(service.calls, isEmpty);
    final recovery = run('reset');
    complete();
    expect(await recovery, isTrue);
    expect(audits.last['event'], 'password_reset_request');
    expect(auth.userUid, 'owner_a');
  });
}
