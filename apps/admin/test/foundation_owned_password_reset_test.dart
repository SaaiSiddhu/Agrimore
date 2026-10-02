@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_admin/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show User, FirebaseAuthException;
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
      case 187:
        return 'fixture_server_timestamp';
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

class _Auth implements AuthService {
  String? uid;
  final stream = _Stream();
  final reply = Completer<void>();
  final loginReply = Completer<UserModel>();
  int resets = 0, logins = 0;
  String? requestedEmail;
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => stream;
  @override
  Future<UserModel> getUserData(String uid) async => _profile(uid);
  @override
  Future<void> sendPasswordResetEmail(String email) {
    resets++;
    requestedEmail = email;
    return reply.future.timeout(const Duration(seconds: 2));
  }

  @override
  Future<UserModel> signInWithEmail(
      {required String email, required String password}) {
    logins++;
    return loginReply.future.timeout(const Duration(seconds: 2));
  }

  @override
  Future<UserModel> signInWithGoogle() {
    logins++;
    return loginReply.future.timeout(const Duration(seconds: 2));
  }

  void emit(String? owner) {
    uid = owner;
    stream.subscriptions.last.data?.call(owner == null ? null : _User(owner));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _profile(String uid) => UserModel(
    uid: uid,
    email: '$uid@example.invalid',
    name: uid,
    role: 'admin',
    createdAt: DateTime(2026));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const updateChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate';
  const setChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Auth service;
  late AuthProvider auth;
  late List<Map<String, Object?>> audits;
  Completer<void>? auditHold;
  var disposed = false;
  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> invalidate(String scenario) async {
    switch (scenario) {
      case 'switch':
        service.emit('owner_b');
      case 'sdk-switch':
        service.uid = 'owner_b';
      case 'renew':
        service.emit(service.uid);
      case 'dispose':
        auth.dispose();
        disposed = true;
      case 'paused':
        service.stream.subscriptions.last.done?.call();
      case 'restarted':
        service.stream.subscriptions.last.done?.call();
        await auth.refreshUserData();
      case 'new-read':
        await auth.refreshUserData();
    }
    await drain();
  }

  Future<bool> reset() =>
      auth.sendPasswordResetEmail(' owner_a@example.invalid ');
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _Auth();
    disposed = false;
    audits = [];
    auditHold = null;
    messenger.setMockMessageHandler(
        updateChannel,
        (message) async =>
            fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]));
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
    service.emit(null);
    await drain();
  });
  tearDown(() async {
    if (!disposed) {
      auth.dispose();
    }
    await drain();
    messenger.setMockMessageHandler(updateChannel, null);
    messenger.setMockMessageHandler(setChannel, null);
  });
  for (final owner in [null, 'owner_a']) {
    test('current $owner reset confirms and captures audit owner', () async {
      service.emit(owner);
      await drain();
      final user = auth.currentUser;
      final result = reset();
      service.reply.complete();
      expect(await result, isTrue);
      expect(service.resets, 1);
      expect(service.requestedEmail, 'owner_a@example.invalid');
      expect(audits.single['uid'], owner);
      expect(audits.single['success'], isTrue);
      expect(auth.currentUser, same(user));
      expect(auth.error, isNull);
      expect(auth.isLoading, isFalse);
    });
  }
  for (final scenario in [
    'switch',
    'sdk-switch',
    'renew',
    'dispose',
    'paused',
    'restarted',
    'new-read'
  ]) {
    for (final failed in [false, true]) {
      test('$scenario suppresses late reset ${failed ? 'failure' : 'success'}',
          () async {
        final result = reset();
        await invalidate(scenario);
        final user = auth.currentUser;
        final error = auth.error;
        if (failed) {
          service.reply
              .completeError(StateError('fixture private reset detail'));
        } else {
          service.reply.complete();
        }
        expect(await result, isFalse);
        expect(auth.currentUser, same(user));
        expect(auth.error, error);
        expect(audits, isEmpty);
      });
    }
  }
  for (final scenario in [
    'switch',
    'sdk-switch',
    'renew',
    'dispose',
    'paused'
  ]) {
    for (final failed in [false, true]) {
      test(
          '$scenario suppresses held reset ${failed ? 'failure' : 'success'} audit completion',
          () async {
        auditHold = Completer<void>();
        final result = reset();
        if (failed) {
          service.reply
              .completeError(StateError('fixture private reset detail'));
        } else {
          service.reply.complete();
        }
        await drain();
        expect(audits.length, 1);
        expect(audits.single['uid'], isNull);
        await invalidate(scenario);
        final user = auth.currentUser;
        final error = auth.error;
        auditHold!.complete();
        expect(await result, isFalse);
        expect(auth.currentUser, same(user));
        expect(auth.error, error);
      });
    }
  }
  for (final failed in [false, true]) {
    test('held reset audit cannot clear newer account command loading $failed',
        () async {
      auditHold = Completer<void>();
      final result = reset();
      if (failed) {
        service.reply.completeError(StateError('fixture private reset detail'));
      } else {
        service.reply.complete();
      }
      await drain();
      service.emit('owner_b');
      await drain();
      final updateHold = Completer<void>();
      messenger.setMockMessageHandler(updateChannel, (message) async {
        await updateHold.future;
        return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
      });
      final command = auth.updateUserProfile(name: 'new intent');
      expect(auth.isLoading, isTrue);
      auditHold!.complete();
      expect(await result, isFalse);
      final loading = auth.isLoading;
      updateHold.complete();
      expect(await command, isTrue);
      expect(loading, isTrue);
      expect(auth.currentUser?.name, 'new intent');
    });
  }
  test('duplicate reset refuses second dispatch', () async {
    final first = reset();
    final second = reset();
    final count = service.resets;
    service.reply.complete();
    expect(await second, isFalse);
    await first;
    expect(count, 1);
  });
  for (final kind in ['firebase', 'auth', 'generic']) {
    test('owned $kind reset failure keeps safe feedback and audit', () async {
      final result = reset();
      final Object failure = kind == 'firebase'
          ? FirebaseAuthException(
              code: 'invalid-email', message: 'fixture private reset detail')
          : kind == 'auth'
              ? AuthException('fixture private reset detail')
              : StateError('fixture private reset detail');
      service.reply.completeError(failure);
      expect(await result, isFalse);
      expect(auth.error, isNot(contains('private reset')));
      expect(audits.single['error'], isNot(contains('private reset')));
      expect(auth.isLoading, isFalse);
    });
  }
  for (final scenario in ['paused', 'dispose']) {
    test('$scenario reset refuses initial dispatch', () async {
      await invalidate(scenario);
      final error = auth.error;
      expect(await reset(), isFalse);
      expect(service.resets, 0);
      expect(auth.error, error);
    });
  }
  for (final method in ['email', 'google']) {
    test('pending reset refuses $method login dispatch', () async {
      final result = reset();
      final login = method == 'email'
          ? auth.signInWithEmail(
              email: 'owner_a@example.invalid', password: 'fixture-password')
          : auth.signInWithGoogle();
      await drain();
      final calls = service.logins;
      if (calls > 0) {
        service.emit('owner_a');
        service.loginReply.complete(_profile('owner_a'));
      }
      service.reply.complete();
      expect(await login, isFalse);
      await result;
      expect(calls, 0);
    });
    test('pending $method login refuses reset dispatch', () async {
      final login = method == 'email'
          ? auth.signInWithEmail(
              email: 'owner_a@example.invalid', password: 'fixture-password')
          : auth.signInWithGoogle();
      final result = reset();
      await drain();
      final calls = service.resets;
      service.reply.complete();
      expect(await result, isFalse);
      service.emit('owner_a');
      service.loginReply.complete(_profile('owner_a'));
      expect(await login, isTrue);
      expect(calls, 0);
    });
  }
  test('reentrant account switch before dispatch cancels reset', () async {
    var changed = false;
    auth.addListener(() {
      if (!changed && auth.isLoading) {
        changed = true;
        service.emit('owner_b');
      }
    });
    final result = reset();
    await drain();
    final calls = service.resets;
    service.reply.complete();
    expect(await result, isFalse);
    expect(calls, 0);
    expect(auth.userUid, 'owner_b');
    expect(audits, isEmpty);
  });
}
