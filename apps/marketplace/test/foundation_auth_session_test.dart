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
  const updates = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
    fs.FirebaseFirestoreHostApi.codec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Auth service;
  late AuthProvider auth;
  late List<String> writes;
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  void expectPrivateHidden() {
    expect(auth.currentUser, isNull);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.isAdmin, isFalse);
    expect(auth.isSeller, isFalse);
    expect(auth.isBuyer, isFalse);
    expect(auth.userUid, isNull);
    expect(auth.userEmail, isNull);
    expect(auth.userName, isNull);
    expect(auth.userPhone, isNull);
    expect(auth.userPhotoUrl, isNull);
    expect(auth.isNewUser, isFalse);
    expect(auth.needsProfileCompletion, isFalse);
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _Auth();
    writes = [];
    service.read = (uid) async => _profile(uid);
    service.restore =
        () async => service.uid == null ? null : _profile(service.uid!);
    messenger.setMockMessageHandler(updates.name, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      writes.add(request.path);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    auth = AuthProvider(authService: service);
  });
  tearDown(() async {
    auth.dispose();
    await drain();
    messenger.setMockMessageHandler(updates.name, null);
  });

  test('valid initial owner profile and last-login update become available',
      () async {
    expect(auth.isInitializing, isTrue);
    service.emit('owner_a');
    await drain();
    expect(auth.userUid, 'owner_a');
    expect(auth.isAdmin, isTrue);
    expect(auth.isInitializing, isFalse);
    expect(writes, ['users/owner_a']);
  });
  for (final role in ['admin', 'seller', 'user']) {
    test('$role identity is hidden immediately when UID changes before event',
        () async {
      service.read = (uid) async => _profile(uid, role: role);
      service.emit('owner_a');
      await drain();
      expect(auth.isLoggedIn, isTrue);
      service.uid = 'owner_b';
      expectPrivateHidden();
      expect(auth.error, isNull);
      expect(auth.errorCode, isNull);
      expect(auth.isInitializing, isTrue);
    });
  }
  test('logout hides private profile before event and finishes initialization',
      () async {
    service.emit('owner_a');
    await drain();
    service.uid = null;
    expectPrivateHidden();
    expect(auth.isInitializing, isFalse);
    service.emit(null);
    await drain();
    expectPrivateHidden();
  });
  test('late account A profile cannot overwrite account B or write last-login',
      () async {
    final old = Completer<UserModel>();
    service.read = (uid) => uid == 'owner_a'
        ? old.future
        : Future.value(_profile(uid, role: 'user'));
    service.emit('owner_a');
    service.emit('owner_b');
    await drain();
    old.complete(_profile('owner_a'));
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(auth.isAdmin, isFalse);
    expect(writes, ['users/owner_b']);
  });
  test('late read failure does not publish old error into next owner',
      () async {
    final old = Completer<UserModel>();
    service.read =
        (uid) => uid == 'owner_a' ? old.future : Future.value(_profile(uid));
    service.emit('owner_a');
    service.emit('owner_b');
    await drain();
    old.completeError(StateError('PRIVATE_OWNER_A_ERROR'));
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
    expect(auth.isInitializing, isFalse);
  });
  test('same UID auth renewal invalidates earlier profile reply', () async {
    final old = Completer<UserModel>();
    var count = 0;
    service.read = (uid) =>
        count++ == 0 ? old.future : Future.value(_profile(uid, role: 'user'));
    service.emit('owner_a');
    service.emit('owner_a');
    await drain();
    old.complete(_profile('owner_a'));
    await drain();
    expect(auth.isAdmin, isFalse);
    expect(auth.isBuyer, isTrue);
    expect(writes, ['users/owner_a']);
  });
  test('foreign model from current read fails closed with safe error',
      () async {
    service.read = (_) async => _profile('foreign_owner');
    service.emit('owner_a');
    await drain();
    expectPrivateHidden();
    expect(auth.error, 'Unable to load your account. Please try again.');
    expect(writes, isEmpty);
  });
  test('profile failure closes initialization and can be retried', () async {
    service.read = (_) async => throw StateError('PRIVATE_FIXTURE_ERROR');
    service.emit('owner_a');
    await drain();
    expectPrivateHidden();
    expect(auth.error, isNot(contains('PRIVATE')));
    expect(auth.isInitializing, isFalse);
    service.read = (uid) async => _profile(uid);
    await auth.refreshUserData();
    expect(auth.userUid, 'owner_a');
    expect(auth.error, isNull);
  });
  test('newer refresh wins over initial reply including role and last-login',
      () async {
    final old = Completer<UserModel>();
    service.read = (_) => old.future;
    service.emit('owner_a');
    service.read = (uid) async => _profile(uid, role: 'user');
    await auth.refreshUserData();
    old.complete(_profile('owner_a'));
    await drain();
    expect(auth.isBuyer, isTrue);
    expect(auth.isAdmin, isFalse);
    expect(writes, isEmpty);
  });
  test('newer refresh wins over older refresh on same owner', () async {
    service.emit('owner_a');
    await drain();
    final old = Completer<UserModel>();
    service.read = (_) => old.future;
    final pending = auth.refreshUserData();
    service.read = (uid) async => _profile(uid, name: 'Latest');
    await auth.refreshUserData();
    old.complete(_profile('owner_a', name: 'Old'));
    await pending;
    expect(auth.userName, 'Latest');
  });
  test('older refresh failure does not clear newest profile', () async {
    final old = Completer<UserModel>();
    service.read = (_) => old.future;
    final pending = auth.refreshUserData();
    service.read = (uid) async => _profile(uid);
    await auth.refreshUserData();
    old.completeError(StateError('PRIVATE'));
    await pending;
    expect(auth.userUid, 'owner_a');
    expect(auth.error, isNull);
  });
  test('latest refresh failure clears stale role until valid retry', () async {
    service.emit('owner_a');
    await drain();
    service.read = (_) async => throw StateError('PRIVATE');
    await auth.refreshUserData();
    expectPrivateHidden();
    expect(auth.isInitializing, isFalse);
  });
  test(
      'restore valid owner keeps existing role and profile completion semantics',
      () async {
    service.restore =
        () async => _profile('owner_a', role: 'user', complete: false);
    await auth.restoreSession();
    expect(auth.isBuyer, isTrue);
    expect(auth.needsProfileCompletion, isTrue);
    expect(auth.isInitializing, isFalse);
    expect(service.restores, 1);
  });
  test('restore without authenticated owner avoids service IO', () async {
    service.uid = null;
    await auth.restoreSession();
    expectPrivateHidden();
    expect(service.restores, 0);
    expect(auth.isInitializing, isFalse);
  });
  test('restored foreign profile is rejected', () async {
    service.restore = () async => _profile('foreign');
    await auth.restoreSession();
    expectPrivateHidden();
    expect(auth.error, isNotNull);
  });
  test('late restore cannot overwrite a new account', () async {
    final old = Completer<UserModel?>();
    service.restore = () => old.future;
    final pending = auth.restoreSession();
    service.emit('owner_b');
    await drain();
    old.complete(_profile('owner_a'));
    await pending;
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
  });
  test('newer refresh supersedes same-owner restore', () async {
    final old = Completer<UserModel?>();
    service.restore = () => old.future;
    final pending = auth.restoreSession();
    await auth.refreshUserData();
    old.complete(_profile('owner_a', role: 'seller'));
    await pending;
    expect(auth.isAdmin, isTrue);
    expect(auth.isSeller, isFalse);
    expect(auth.isInitializing, isFalse);
  });
  test('older restore finally cannot hide newer pending initialization',
      () async {
    final old = Completer<UserModel?>(), latest = Completer<UserModel?>();
    service.restore = () => old.future;
    final first = auth.restoreSession();
    service.restore = () => latest.future;
    final second = auth.restoreSession();
    old.complete(_profile('owner_a'));
    await first;
    expect(auth.isInitializing, isTrue);
    latest.complete(_profile('owner_a'));
    await second;
    expect(auth.isInitializing, isFalse);
  });
  test('restore failure publishes static recoverable error', () async {
    service.restore = () async => throw StateError('PRIVATE_RESTORE');
    await auth.restoreSession();
    expectPrivateHidden();
    expect(auth.error, isNot(contains('PRIVATE')));
    expect(auth.isInitializing, isFalse);
  });
  test('latest null restore clears previous profile', () async {
    service.emit('owner_a');
    await drain();
    service.restore = () async => null;
    await auth.restoreSession();
    expectPrivateHidden();
  });
  test('cancelled stream event cannot revive a disposed provider', () async {
    final old = service.stream.subscriptions.single;
    auth.dispose();
    old.data?.call(_User('owner_a'));
    await drain();
    expect(service.reads, isEmpty);
    expect(old.cancelled, 1);
    expectPrivateHidden();
    expect(auth.isInitializing, isFalse);
  });
  test('disposal during profile read prevents all late notification and writes',
      () async {
    final pending = Completer<UserModel>();
    service.read = (_) => pending.future;
    var notifications = 0;
    auth.addListener(() {
      notifications++;
    });
    service.emit('owner_a');
    final before = notifications;
    auth.dispose();
    pending.complete(_profile('owner_a'));
    await drain();
    expect(notifications, before);
    expect(writes, isEmpty);
    expectPrivateHidden();
  });
  test('read failure after disposal is safely absorbed', () async {
    final pending = Completer<UserModel>();
    service.read = (_) => pending.future;
    service.emit('owner_a');
    auth.dispose();
    pending.completeError(StateError('PRIVATE'));
    await drain();
    expect(auth.error, isNull);
  });
  test('public read methods after disposal issue no service IO', () async {
    auth.dispose();
    await auth.refreshUserData();
    await auth.restoreSession();
    expect(service.reads, isEmpty);
    expect(service.restores, 0);
  });
  for (final failure in ['error', 'done']) {
    test(
        'auth stream $failure invalidates pending reads, cancels and permits retry',
        () async {
      final pending = Completer<UserModel>();
      service.read = (_) => pending.future;
      service.emit('owner_a');
      final old = service.stream.subscriptions.single;
      if (failure == 'error') {
        Function.apply(old.error!, [StateError('PRIVATE')]);
      } else {
        old.done?.call();
      }
      expect(old.cancelled, 1);
      expect(auth.isInitializing, isFalse);
      expectPrivateHidden();
      service.read = (uid) async => _profile(uid, role: 'user');
      await auth.refreshUserData();
      pending.complete(_profile('owner_a'));
      await drain();
      expect(auth.isBuyer, isTrue);
      expect(auth.error, isNull);
      old.data?.call(_User('owner_a'));
      await drain();
      expect(service.reads.length, 2);
      expect(service.stream.subscriptions.length, 2);
    });
  }
  test('stale event UID is ignored before it can clear new profile', () async {
    service.emit('owner_b');
    await drain();
    service.stream.subscriptions.single.data?.call(_User('owner_a'));
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(service.reads, ['owner_b']);
  });
  test('reentrant owner change during notification prevents profile read',
      () async {
    auth.addListener(() {
      service.uid = 'owner_b';
    });
    service.emit('owner_a');
    await drain();
    expect(service.reads, isEmpty);
    expectPrivateHidden();
    expect(writes, isEmpty);
  });
  test('stream failure after UID switch settles into safe retry state',
      () async {
    service.emit('owner_a');
    await drain();
    service.uid = 'owner_b';
    final old = service.stream.subscriptions.single;
    Function.apply(old.error!, [StateError('PRIVATE')]);
    expectPrivateHidden();
    expect(auth.isInitializing, isFalse);
    expect(auth.error, 'Account updates paused. Please refresh your account.');
    await auth.refreshUserData();
    expect(auth.userUid, 'owner_b');
  });
  test('late restore failure cannot clear new account or publish its error',
      () async {
    final old = Completer<UserModel?>();
    service.restore = () => old.future;
    final pending = auth.restoreSession();
    service.emit('owner_b');
    await drain();
    old.completeError(StateError('PRIVATE_RESTORE'));
    await pending;
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
    expect(auth.isInitializing, isFalse);
  });
}
