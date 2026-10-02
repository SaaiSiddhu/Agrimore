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
  final reads = <String>[];
  int restores = 0;
  late Future<UserModel> Function(String) read;
  late Future<UserModel?> Function() restore;
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => stream;
  @override
  Future<UserModel> getUserData(String uid) {
    reads.add(uid);
    return read(uid);
  }

  @override
  Future<UserModel?> restoreSession() {
    restores++;
    return restore();
  }

  final calls = <String>[];
  final arguments = <Map<String, Object?>>[];
  late Future<UserModel?> Function(String, Map<String, Object?>) command;
  Future<UserModel?> _call(String method, Map<String, Object?> args) {
    calls.add(method);
    arguments.add(args);
    return command(method, args);
  }

  @override
  Future<void> sendEmailOtpForProfile(String email) async {
    await _call('send', {'email': email});
  }

  @override
  Future<void> verifyEmailOtpForProfile(
      {required String email, required String otp}) async {
    await _call('verify', {'email': email, 'otp': otp});
  }

  @override
  Future<UserModel> completeUserProfile(
          {required String name,
          required String email,
          required DateTime dateOfBirth,
          required String gender}) async =>
      (await _call('complete', {
        'name': name,
        'email': email,
        'dateOfBirth': dateOfBirth,
        'gender': gender
      }))!;
  @override
  Future<UserModel> changePhoneNumber(
          {required String phone, required String otp}) async =>
      (await _call('phone', {'phone': phone, 'otp': otp}))!;
  @override
  Future<UserModel> changeEmailAddress({required String email}) async =>
      (await _call('email', {'email': email}))!;
  @override
  Future<UserModel> changeDateOfBirth({required DateTime dateOfBirth}) async =>
      (await _call('dob', {'dateOfBirth': dateOfBirth}))!;

  void emit(String? owner) {
    uid = owner;
    stream.subscriptions.last.data?.call(owner == null ? null : _User(owner));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _profile(String uid,
        {String role = 'admin',
        String name = 'Current',
        bool complete = true}) =>
    UserModel(
      uid: uid,
      email: '$uid@example.invalid',
      name: name,
      role: role,
      phone: '+910000000000',
      photoUrl: 'https://example.invalid/fixture',
      createdAt: DateTime(2026),
      profileCompleted: complete,
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const updateChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate';
  const setChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final methods = ['send', 'verify', 'complete', 'phone', 'email', 'dob'];
  late _Auth service;
  late AuthProvider auth;
  late List<Map<String, Object?>> audits;
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<bool> invoke(String method) {
    switch (method) {
      case 'send':
        return auth.sendEmailOtpForProfile('changed@example.invalid');
      case 'verify':
        return auth.verifyEmailOtpForProfile(
            email: 'changed@example.invalid', otp: 'fixture');
      case 'complete':
        return auth.completeUserProfile(
            name: 'Changed',
            email: 'changed@example.invalid',
            dateOfBirth: DateTime(1990, 2, 3),
            gender: 'other');
      case 'phone':
        return auth.changePhoneNumber(phone: '+910000000001', otp: 'fixture');
      case 'email':
        return auth.changeEmailAddress(email: 'changed@example.invalid');
      case 'dob':
        return auth.changeDateOfBirth(dateOfBirth: DateTime(1990, 2, 3));
      default:
        throw StateError('Unknown fixture operation');
    }
  }

  Future<ByteData?> auditReply(ByteData? message) async {
    final args = const _WriteRequestCodec().decodeMessage(message) as List;
    final request = args[1] as fs.DocumentReferenceRequest;
    if (request.path.startsWith('auth_logs/')) {
      audits.add(Map<String, Object?>.from(request.data!));
    }
    return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _Auth();
    audits = [];
    service.read = (uid) async => _profile(uid);
    service.restore = () async => _profile(service.uid!);
    service.command =
        (method, args) async => _profile(service.uid!, name: 'Changed');
    messenger.setMockMessageHandler(
        updateChannel,
        (message) async =>
            fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]));
    messenger.setMockMessageHandler(setChannel, auditReply);
    auth = AuthProvider(authService: service);
    service.emit('owner_a');
    await drain();
    expect(auth.userUid, 'owner_a');
  });
  tearDown(() async {
    auth.dispose();
    await drain();
    messenger.setMockMessageHandler(updateChannel, null);
    messenger.setMockMessageHandler(setChannel, null);
  });
  for (final method in methods) {
    test(
        '$method legitimate current command preserves arguments and confirmed presentation',
        () async {
      expect(await invoke(method), isTrue);
      expect(service.calls, [method]);
      final args = service.arguments.single;
      if (method == 'phone') {
        expect(args, {'phone': '+910000000001', 'otp': 'fixture'});
      } else if (method != 'dob') {
        expect(args['email'], 'changed@example.invalid');
      }
      if (method == 'complete' || method == 'dob') {
        expect(args['dateOfBirth'], DateTime(1990, 2, 3));
      }
      if (method == 'complete') {
        expect(args['name'], 'Changed');
        expect(args['gender'], 'other');
      }
      expect(auth.userName,
          method == 'send' || method == 'verify' ? 'Current' : 'Changed');
      expect(auth.isAdmin, isTrue);
      expect(auth.isLoading, isFalse);
      expect(auth.error, isNull);
      expect(auth.errorCode, isNull);
      expect(audits.length, method == 'complete' ? 1 : 0);
      if (audits.isNotEmpty) {
        expect(audits.single['uid'], 'owner_a');
        expect(audits.single['success'], isTrue);
      }
    });
    test('$method signed-out cannot dispatch', () async {
      service.emit(null);
      await drain();
      expect(await invoke(method), isFalse);
      expect(service.calls, isEmpty);
      expect(audits, isEmpty);
    });
    test('$method owner mismatch before auth event cannot dispatch', () async {
      service.uid = 'owner_b';
      expect(await invoke(method), isFalse);
      expect(service.calls, isEmpty);
      expect(audits, isEmpty);
    });
    test('$method missing owned profile cannot dispatch', () async {
      service.read = (uid) => Future.error(StateError('private fixture read'));
      service.emit('owner_a');
      await drain();
      expect(auth.currentUser, isNull);
      expect(await invoke(method), isFalse);
      expect(service.calls, isEmpty);
    });
    test('$method preserves current typed validation refusal code', () async {
      service.command = (method, args) => Future.error(AuthException(
          'Owned validation refusal',
          code: 'failed-precondition'));
      expect(await invoke(method), isFalse);
      expect(auth.error, 'Owned validation refusal');
      expect(auth.errorCode, 'failed-precondition');
      expect(auth.userName, 'Current');
      expect(auth.isLoading, isFalse);
      if (method == 'complete') {
        expect(audits.single['success'], isFalse);
        expect(audits.single['uid'], 'owner_a');
      }
    });
    test('$method generic failure hides runtime internals', () async {
      service.command = (method, args) =>
          Future.error(StateError('private runtime fixture detail'));
      expect(await invoke(method), isFalse);
      expect(auth.error, 'Unable to update your profile. Please try again.');
      expect(auth.errorCode, isNull);
      expect(auth.userName, 'Current');
      expect(auth.isLoading, isFalse);
    });
    for (final transition in [
      'switch',
      'renewal',
      'error',
      'done',
      'dispose',
      'before_event'
    ]) {
      for (final failure in [false, true]) {
        test(
            '$method late ${failure ? 'refusal' : 'success'} after $transition cannot update session',
            () async {
          final pending = Completer<UserModel?>();
          service.command = (method, args) => pending.future;
          var notifications = 0;
          auth.addListener(() {
            notifications++;
          });
          final result = invoke(method);
          await drain();
          expect(service.calls, [method]);
          switch (transition) {
            case 'switch':
              service.emit('owner_b');
              break;
            case 'renewal':
              service.emit('owner_a');
              break;
            case 'error':
              (service.stream.subscriptions.last.error as void Function(
                  Object))(StateError('fixture stream error'));
              break;
            case 'done':
              service.stream.subscriptions.last.done?.call();
              break;
            case 'dispose':
              auth.dispose();
              break;
            case 'before_event':
              service.uid = 'owner_b';
              break;
          }
          await drain();
          final before = notifications,
              error = auth.error,
              loading = auth.isLoading,
              user = auth.currentUser;
          if (failure) {
            pending.completeError(AuthException('Late private refusal',
                code: 'failed-precondition'));
          } else {
            pending.complete(_profile('owner_a', name: 'Stale'));
          }
          expect(await result, isFalse);
          await drain();
          expect(notifications, before);
          expect(auth.error, error);
          expect(auth.isLoading, loading);
          expect(auth.currentUser, same(user));
          expect(audits, isEmpty);
        });
      }
    }
    test('$method latest command preserves newer profile and loading',
        () async {
      final older = Completer<UserModel?>(), newer = Completer<UserModel?>();
      var count = 0;
      service.command =
          (method, args) => ++count == 1 ? older.future : newer.future;
      final a = invoke(method);
      final b = invoke(method);
      await drain();
      newer.complete(_profile('owner_a', name: 'Latest'));
      expect(await b, isTrue);
      older.complete(_profile('owner_a', name: 'Old'));
      expect(await a, isFalse);
      expect(auth.userName,
          method == 'send' || method == 'verify' ? 'Current' : 'Latest');
      expect(auth.error, isNull);
      expect(auth.isLoading, isFalse);
      expect(audits.length, method == 'complete' ? 1 : 0);
    });
    test('$method refreshed profile supersedes pending command', () async {
      final pending = Completer<UserModel?>();
      service.command = (method, args) => pending.future;
      final result = invoke(method);
      service.read = (uid) async => _profile(uid, name: 'Refreshed');
      await auth.refreshUserData();
      expect(auth.isLoading, isFalse);
      pending.complete(_profile('owner_a', name: 'Old'));
      expect(await result, isFalse);
      expect(auth.userName, 'Refreshed');
      expect(audits, isEmpty);
    });
    test('$method notification account switch blocks dispatch', () async {
      var switched = false;
      auth.addListener(() {
        if (!switched) {
          switched = true;
          service.emit('owner_b');
        }
      });
      expect(await invoke(method), isFalse);
      await drain();
      expect(service.calls, isEmpty);
      expect(auth.userUid, 'owner_b');
      expect(audits, isEmpty);
    });
  }
  for (final method in ['complete', 'phone', 'email', 'dob']) {
    test('$method rejects foreign returned model without exposing its role',
        () async {
      service.command = (method, args) async =>
          _profile('owner_b', name: 'Foreign', role: 'seller');
      expect(await invoke(method), isFalse);
      expect(auth.userUid, 'owner_a');
      expect(auth.userName, 'Current');
      expect(auth.isSeller, isFalse);
      expect(auth.error, 'Unable to update your profile. Please try again.');
      expect(audits.where((a) => a['success'] == true), isEmpty);
    });
  }
  for (final method in methods) {
    for (final failure in [false, true]) {
      test(
          '$method old ${failure ? 'refusal' : 'success'} cannot clear newer pending loading',
          () async {
        final older = Completer<UserModel?>(), newer = Completer<UserModel?>();
        var count = 0;
        service.command =
            (method, args) => ++count == 1 ? older.future : newer.future;
        final a = invoke(method), b = invoke(method);
        expect(auth.isLoading, isTrue);
        if (failure) {
          older.completeError(AuthException('Old refusal', code: 'old-code'));
        } else {
          older.complete(_profile('owner_a', name: 'Old'));
        }
        expect(await a, isFalse);
        expect(auth.isLoading, isTrue);
        expect(auth.error, isNull);
        expect(auth.userName, 'Current');
        expect(audits, isEmpty);
        newer.complete(_profile('owner_a', name: 'Latest'));
        expect(await b, isTrue);
        expect(auth.isLoading, isFalse);
      });
    }
    test('$method success notification switch does not return old-page success',
        () async {
      var started = false, switched = false;
      auth.addListener(() {
        if (auth.isLoading) {
          started = true;
        } else if (started && !switched) {
          switched = true;
          service.emit('owner_b');
        }
      });
      expect(await invoke(method), isFalse);
      await drain();
      expect(service.calls, [method]);
      expect(auth.userUid, 'owner_b');
      expect(auth.userName, 'Current');
    });
    test('$method command supersedes older pending profile read', () async {
      final read = Completer<UserModel>();
      service.read = (uid) => read.future;
      final refresh = auth.refreshUserData();
      expect(await invoke(method), isTrue);
      read.complete(_profile('owner_a', name: 'Old read'));
      await refresh;
      expect(auth.userName,
          method == 'send' || method == 'verify' ? 'Current' : 'Changed');
      expect(auth.isLoading, isFalse);
    });
    test('$method paused stream refuses dispatch without erasing pause message',
        () async {
      service.stream.subscriptions.last.done?.call();
      await drain();
      final error = auth.error;
      expect(await invoke(method), isFalse);
      expect(service.calls, isEmpty);
      expect(auth.error, error);
    });
    test('$method success clears previous validation code', () async {
      service.command = (method, args) => Future.error(
          AuthException('Owned refusal', code: 'failed-precondition'));
      expect(await invoke(method), isFalse);
      expect(auth.errorCode, 'failed-precondition');
      service.command =
          (method, args) async => _profile('owner_a', name: 'Changed');
      expect(await invoke(method), isTrue);
      expect(auth.error, isNull);
      expect(auth.errorCode, isNull);
    });
  }
  test(
      'screen ticket checks SDK owner immediately and same-UID session renewal',
      () async {
    final version = auth.sessionVersion;
    expect(auth.isSessionCurrent('owner_a', version), isTrue);
    expect(auth.isSessionCurrent('owner_b', version), isFalse);
    service.uid = 'owner_b';
    expect(auth.isSessionCurrent('owner_a', version), isFalse);
    service.uid = 'owner_a';
    service.emit('owner_a');
    await drain();
    expect(auth.sessionVersion, greaterThan(version));
    expect(auth.isSessionCurrent('owner_a', version), isFalse);
    expect(auth.isSessionCurrent('owner_a', auth.sessionVersion), isTrue);
  });
  test('screen ticket is revoked by stream closure and disposal', () async {
    final version = auth.sessionVersion;
    service.stream.subscriptions.last.done?.call();
    expect(auth.isSessionCurrent('owner_a', version), isFalse);
    await auth.refreshUserData();
    final newVersion = auth.sessionVersion;
    expect(auth.isSessionCurrent('owner_a', newVersion), isTrue);
    auth.dispose();
    expect(auth.isSessionCurrent('owner_a', newVersion), isFalse);
  });
  test('held failed completion audit does not publish error into newer account',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    service.command = (method, args) => Future.error(
        AuthException('Owned refusal', code: 'failed-precondition'));
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      audits.add(Map<String, Object?>.from(request.data!));
      entered.complete();
      await release.future;
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    final result = invoke('complete');
    await entered.future;
    expect(audits.single['uid'], 'owner_a');
    expect(audits.single['success'], isFalse);
    service.emit('owner_b');
    await drain();
    release.complete();
    expect(await result, isFalse);
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
    expect(auth.errorCode, isNull);
  });
  test(
      'held completion audit keeps captured UID and cannot repaint new account',
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
    final result = invoke('complete');
    await entered.future;
    expect(auth.userName, 'Current');
    expect(audits.single['uid'], 'owner_a');
    service.emit('owner_b');
    await drain();
    release.complete();
    expect(await result, isFalse);
    expect(auth.userUid, 'owner_b');
    expect(auth.userName, 'Current');
    expect(auth.error, isNull);
  });
  test('soft audit refusal retains confirmed profile success', () async {
    messenger.setMockMessageHandler(
        setChannel,
        (message) async => fs.FirebaseFirestoreHostApi.codec.encodeMessage(
            ['permission-denied', 'fixture audit refusal', null]));
    expect(await invoke('complete'), isTrue);
    expect(auth.userName, 'Changed');
    expect(auth.error, isNull);
  });
  for (final event in ['done', 'error']) {
    test(
        'synchronous listen $event releases returned subscription and can retry',
        () async {
      auth.dispose();
      service = _Auth();
      service.read = (uid) async => _profile(uid);
      service.restore = () async => _profile('owner_a');
      service.stream.onListen = (sub) {
        if (event == 'done') {
          sub.done?.call();
        } else {
          (sub.error as void Function(
              Object))(StateError('fixture sync close'));
        }
      };
      auth = AuthProvider(authService: service);
      await drain();
      expect(service.stream.subscriptions.single.cancelled, 1);
      expect(auth.currentUser, isNull);
      service.stream.onListen = null;
      await auth.refreshUserData();
      expect(service.stream.subscriptions.length, 2);
      expect(auth.userUid, 'owner_a');
      auth.dispose();
      await drain();
      expect(service.stream.subscriptions.last.cancelled, 1);
    });
  }
}
