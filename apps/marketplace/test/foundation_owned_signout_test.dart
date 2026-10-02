@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
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
  String? uid = 'owner_a';
  final stream = _Stream();
  final reply = Completer<void>();
  int calls = 0;
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => stream;
  @override
  Future<UserModel> getUserData(String uid) async => _profile(uid);
  @override
  Future<void> signOut() {
    calls++;
    return reply.future.timeout(const Duration(seconds: 1));
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
  var disposed = false;
  late List<Map<String, Object?>> audits;
  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'remember_email': 'owner_a@example.invalid'});
    disposed = false;
    service = _Auth();
    audits = [];
    messenger.setMockMessageHandler(
        updateChannel,
        (message) async =>
            fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]));
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      if (request.path.startsWith('auth_logs/'))
        audits.add(Map<String, Object?>.from(request.data!));
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    auth = AuthProvider(authService: service);
    service.emit('owner_a');
    await drain();
    expect(auth.userUid, 'owner_a');
  });
  tearDown(() async {
    if (!disposed) {
      auth.dispose();
    }
    await drain();
    messenger.setMockMessageHandler(updateChannel, null);
    messenger.setMockMessageHandler(setChannel, null);
  });
  test('owned observed signout remains usable and audit retains opening owner',
      () async {
    final result = auth.signOut();
    service.emit(null);
    service.reply.complete();
    await result;
    expect(service.calls, 1);
    expect(auth.currentUser, isNull);
    expect(auth.error, isNull);
    expect((await SharedPreferences.getInstance()).getString('remember_email'), isNull);
    expect(audits.single['event'], 'logout');
    expect(audits.single['uid'], 'owner_a');
  });
  for (final scenario in [
    'switch',
    'sdk-switch',
    'renew',
    'dispose',
    'paused',
    'restarted'
  ]) {
    for (final fail in [false, true]) {
      test('$scenario suppresses late ${fail ? 'failure' : 'success'}',
          () async {
        final result = auth.signOut();
        switch (scenario) {
          case 'switch':
            service.emit('owner_b');
            break;
          case 'sdk-switch':
            service.uid = 'owner_b';
            break;
          case 'renew':
            service.emit('owner_a');
            break;
          case 'dispose':
            auth.dispose();
            disposed = true;
            break;
          case 'paused':
            service.stream.subscriptions.last.done?.call();
            break;
          case 'restarted':
            service.stream.subscriptions.last.done?.call();
            await auth.refreshUserData();
            break;
        }
        await drain();
        final profile = auth.currentUser;
        final error = auth.error;
        if (fail) {
          service.reply.completeError(StateError('PRIVATE fixture details'));
        } else {
          service.reply.complete();
        }
        await result;
        expect(auth.currentUser, same(profile));
        expect(auth.error, error);
        expect(audits, isEmpty);
      });
    }
  }
  test('duplicate pending taps dispatch only once', () async {
    final first = auth.signOut(), second = auth.signOut();
    expect(service.calls, 1);
    service.emit(null);
    service.reply.complete();
    await first;
    await second;
    expect(audits.length, 1);
  });
  test('disposed provider refuses initial dispatch', () async {
    auth.dispose();
    disposed = true;
    await auth.signOut();
    expect(service.calls, 0);
    expect(audits, isEmpty);
  });
  test('signedout provider refuses initial dispatch', () async {
    service.emit(null);
    await drain();
    await auth.signOut();
    expect(service.calls, 0);
    expect(audits, isEmpty);
  });
  test('paused provider refuses initial dispatch', () async {
    service.stream.subscriptions.last.done?.call();
    await auth.signOut();
    expect(service.calls, 0);
    expect(audits, isEmpty);
  });
  test('unconfirmed service completion preserves existing profile', () async {
    final result = auth.signOut();
    service.reply.complete();
    await result;
    expect(auth.userUid, 'owner_a');
    expect(audits, isEmpty);
  });
  test('owned failure uses safe static copy and retains profile', () async {
    final result = auth.signOut();
    service.reply.completeError(StateError('PRIVATE fixture details'));
    await result;
    expect(auth.userUid, 'owner_a');
    expect(auth.error, 'Unable to sign out. Please try again.');
    expect(audits, isEmpty);
  });
  test('held logout audit never clears new account after write returns',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      audits.add(Map<String, Object?>.from(request.data!));
      entered.complete();
      await release.future;
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    final result = auth.signOut();
    service.emit(null);
    service.reply.complete();
    await entered.future;
    expect(audits.single['uid'], 'owner_a');
    service.emit('owner_b');
    await drain();
    release.complete();
    await result;
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
  });
}
