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
      case 188:
        return fs.Timestamp(buffer.getInt64(), buffer.getInt32());
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
  @override
  StreamSubscription<User?> listen(void Function(User?)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final subscription = _Subscription(onData, onError, onDone);
    subscriptions.add(subscription);
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

  late Future<UserModel> Function(String) emailCommand;
  @override
  Future<UserModel> changeEmailAddress({required String email}) =>
      emailCommand(email);

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
      dateOfBirth: DateTime(1990, 2, 3),
      gender: 'other',
      metadata: const {'fixture': 'retained'},
      phoneVerified: true,
      emailVerified: true,
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
  late _Auth service;
  late AuthProvider auth;
  late List<Map<String, Object?>> updates, audits;
  late Future<void> Function(Map<String, Object?>) onUpdate;
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<bool> edit() => auth.updateUserProfile(
      name: 'Changed', phone: '+910000000001', photoUrl: '', gender: 'female');
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _Auth();
    updates = [];
    audits = [];
    service.read = (uid) async => _profile(uid);
    service.restore = () async => _profile(service.uid!);
    onUpdate = (data) async {};
    messenger.setMockMessageHandler(updateChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      if (request.data!.containsKey('name')) {
        final data = Map<String, Object?>.from(request.data!);
        updates.add({'path': request.path, 'data': data});
        await onUpdate(data);
      }
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      audits.add(Map<String, Object?>.from(request.data!));
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
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
  test(
      'ordinary edit preserves full payload, explicit photo removal and captured audit owner',
      () async {
    final original = auth.currentUser!;
    expect(await edit(), isTrue);
    expect(updates.single['path'], 'users/owner_a');
    expect(
        updates.single['data'],
        original
            .copyWith(
                name: 'Changed',
                phone: '+910000000001',
                photoUrl: '',
                gender: 'female')
            .toMap());
    expect(auth.userName, 'Changed');
    expect(auth.userPhotoUrl, '');
    expect(auth.userPhone, '+910000000001');
    expect(auth.currentUser!.dateOfBirth, original.dateOfBirth);
    expect(auth.currentUser!.role, original.role);
    expect(auth.currentUser!.phoneVerified, isTrue);
    expect(auth.currentUser!.emailVerified, isTrue);
    expect(audits.single['event'], 'profile_update');
    expect(audits.single['uid'], 'owner_a');
    expect(audits.single['success'], isTrue);
    expect(auth.error, isNull);
    expect(auth.isLoading, isFalse);
  });
  test(
      'compatibility wrapper still delegates original fields and retains gender',
      () async {
    expect(await auth.updateProfile(name: 'Compat', photoUrl: ''), isTrue);
    expect(auth.userName, 'Compat');
    expect(auth.currentUser!.gender, 'other');
    expect(auth.userPhotoUrl, '');
    expect(updates.single['path'], 'users/owner_a');
    expect(audits.single['uid'], 'owner_a');
  });
  test('null fields remain no-change and all original fields stay intact',
      () async {
    final original = auth.currentUser!;
    expect(await auth.updateUserProfile(), isTrue);
    expect(updates.single['data'], original.toMap());
    expect(auth.currentUser!.toMap(), original.toMap());
  });
  for (final role in ['user', 'admin', 'seller', 'delivery', 'employee']) {
    test(
        'owned server role $role is retained without changing authority fields',
        () async {
      service.read = (uid) async => _profile(uid, role: role);
      await auth.refreshUserData();
      final original = auth.currentUser!;
      expect(await edit(), isTrue);
      final data = updates.single['data'] as Map<String, Object?>;
      expect(data['role'], role);
      expect(data['dateOfBirth'], original.toMap()['dateOfBirth']);
      expect(data['email'], original.email);
      expect(data['metadata'], original.metadata);
      expect(data['profileCompleted'], original.profileCompleted);
    });
  }
  for (final condition in [
    'signed_out',
    'before_event',
    'missing',
    'paused',
    'disposed'
  ]) {
    test('$condition cannot dispatch ordinary profile write or audit',
        () async {
      switch (condition) {
        case 'signed_out':
          service.emit(null);
          break;
        case 'before_event':
          service.uid = 'owner_b';
          break;
        case 'missing':
          service.read =
              (uid) => Future.error(StateError('fixture unavailable'));
          service.emit('owner_a');
          break;
        case 'paused':
          service.stream.subscriptions.last.done?.call();
          break;
        case 'disposed':
          auth.dispose();
          break;
      }
      await drain();
      expect(await edit(), isFalse);
      expect(updates, isEmpty);
      expect(audits, isEmpty);
    });
  }
  for (final transition in [
    'switch',
    'renewal',
    'error',
    'done',
    'dispose',
    'before_event'
  ]) {
    for (final refusal in [false, true]) {
      test(
          'held update ${refusal ? 'refusal' : 'success'} after $transition cannot accept or audit stale profile',
          () async {
        final entered = Completer<void>(), release = Completer<void>();
        onUpdate = (data) async {
          entered.complete();
          await release.future;
          if (refusal) {
            throw StateError('private native fixture failure');
          }
        };
        var notifications = 0;
        auth.addListener(() {
          notifications++;
        });
        final result = edit();
        await entered.future;
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
        final user = auth.currentUser,
            error = auth.error,
            before = notifications;
        release.complete();
        expect(await result, isFalse);
        await drain();
        expect(auth.currentUser, same(user));
        expect(auth.error, error);
        expect(notifications, before);
        expect(audits, isEmpty);
        expect(updates.single['path'], 'users/owner_a');
      });
    }
  }
  test('notification account switch prevents native profile dispatch',
      () async {
    var switched = false;
    auth.addListener(() {
      if (!switched) {
        switched = true;
        service.emit('owner_b');
      }
    });
    expect(await edit(), isFalse);
    await drain();
    expect(updates, isEmpty);
    expect(audits, isEmpty);
    expect(auth.userUid, 'owner_b');
  });
  test('latest ordinary edit leaves newer pending loading intact', () async {
    final entered = Completer<void>(),
        releaseOld = Completer<void>(),
        releaseNew = Completer<void>();
    var count = 0;
    onUpdate = (data) async {
      if (++count == 1) {
        entered.complete();
        await releaseOld.future;
      } else {
        await releaseNew.future;
      }
    };
    final old = edit();
    await entered.future;
    final latest = auth.updateUserProfile(name: 'Latest');
    await drain();
    releaseOld.complete();
    expect(await old, isFalse);
    expect(auth.isLoading, isTrue);
    expect(auth.userName, 'Current');
    expect(audits, isEmpty);
    releaseNew.complete();
    expect(await latest, isTrue);
    expect(auth.userName, 'Latest');
    expect(auth.isLoading, isFalse);
    expect(audits.length, 1);
  });
  test('refreshed profile supersedes held ordinary update', () async {
    final entered = Completer<void>(), release = Completer<void>();
    onUpdate = (data) async {
      entered.complete();
      await release.future;
    };
    final result = edit();
    await entered.future;
    service.read = (uid) async => _profile(uid, name: 'Refreshed');
    await auth.refreshUserData();
    release.complete();
    expect(await result, isFalse);
    expect(auth.userName, 'Refreshed');
    expect(auth.isLoading, isFalse);
    expect(audits, isEmpty);
  });
  test('held ordinary-update audit cannot repaint a new account', () async {
    final entered = Completer<void>(), release = Completer<void>();
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      audits.add(Map<String, Object?>.from(request.data!));
      entered.complete();
      await release.future;
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    final result = edit();
    await entered.future;
    final during = auth.userName;
    service.emit('owner_b');
    await drain();
    release.complete();
    expect(await result, isFalse);
    expect(during, 'Current');
    expect(auth.userUid, 'owner_b');
    expect(auth.userName, 'Current');
    expect(audits.single['uid'], 'owner_a');
  });
  test('current native refusal is safe and preserves old model', () async {
    onUpdate =
        (data) => Future.error(StateError('private native fixture failure'));
    expect(await edit(), isFalse);
    expect(auth.error, 'Unable to update your profile. Please try again.');
    expect(auth.userName, 'Current');
    expect(auth.isLoading, isFalse);
    expect(audits.single['success'], isFalse);
    expect(audits.single['uid'], 'owner_a');
  });
  test('soft ordinary-update audit refusal keeps confirmed success', () async {
    messenger.setMockMessageHandler(
        setChannel,
        (message) async => fs.FirebaseFirestoreHostApi.codec.encodeMessage(
            ['permission-denied', 'fixture audit refusal', null]));
    expect(await edit(), isTrue);
    expect(auth.userName, 'Changed');
    expect(auth.error, isNull);
    expect(auth.isLoading, isFalse);
  });
  test(
      'success notification switch does not return stale ordinary-edit success',
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
    expect(await edit(), isFalse);
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(auth.userName, 'Current');
  });
  test('new verified profile command supersedes held ordinary edit', () async {
    final entered = Completer<void>(), release = Completer<void>();
    onUpdate = (data) async {
      entered.complete();
      await release.future;
    };
    service.emailCommand =
        (email) async => _profile('owner_a', name: 'Verified', role: 'user');
    final old = edit();
    await entered.future;
    expect(await auth.changeEmailAddress(email: 'new@example.invalid'), isTrue);
    release.complete();
    expect(await old, isFalse);
    expect(auth.userName, 'Verified');
    expect(auth.currentUser!.role, 'user');
    expect(auth.isLoading, isFalse);
    expect(audits, isEmpty);
  });
  test('new ordinary edit supersedes held verified profile reply', () async {
    final pending = Completer<UserModel>();
    service.emailCommand = (email) => pending.future;
    final old = auth.changeEmailAddress(email: 'new@example.invalid');
    expect(await edit(), isTrue);
    pending.complete(_profile('owner_a', name: 'Old verified', role: 'seller'));
    expect(await old, isFalse);
    expect(auth.userName, 'Changed');
    expect(auth.currentUser!.role, 'admin');
    expect(auth.isLoading, isFalse);
    expect(audits.length, 1);
  });
}
