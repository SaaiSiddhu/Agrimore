@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_admin/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, FirebaseAuth;
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
      case 188:
        return fs.Timestamp(buffer.getInt64(), buffer.getInt32());
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
  final passwordReply = Completer<void>();
  final passwordOwners = <String?>[];
  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) {
    passwordOwners.add(uid);
    return passwordReply.future;
  }

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

class _Firebase implements FirebaseAuth {
  _Firebase(this.service);
  final _Auth service;
  final signouts = <String?>[];
  Completer<void>? pending;
  @override
  User? get currentUser => service.uid == null ? null : _User(service.uid!);
  @override
  Future<void> signOut() async {
    final owner = service.uid;
    signouts.add(owner);
    await pending?.future;
    if (service.uid == owner) service.emit(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  late _Firebase firebase;
  late AuthProvider auth;
  late List<String> writes;
  var disposed = false;
  final audits = <Map<String, Object?>>[];
  Completer<void>? pendingProfile;
  Completer<void>? pendingAudit;
  const auditChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet',
    fs.FirebaseFirestoreHostApi.codec,
  );
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  void hidden() {
    expect(auth.currentUser, isNull);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.isAdmin, isFalse);
    expect(auth.isSeller, isFalse);
    expect(auth.isBuyer, isFalse);
    expect(auth.userUid, isNull);
    expect(auth.userName, isNull);
    expect(auth.userEmail, isNull);
    expect(auth.userPhone, isNull);
    expect(auth.userPhotoUrl, isNull);
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    disposed = false;
    SharedPreferences.setMockInitialValues({});
    service = _Auth();
    service.read = (uid) async => _profile(uid);
    service.restore =
        () async => service.uid == null ? null : _profile(service.uid!);
    firebase = _Firebase(service);
    writes = [];
    audits.clear();
    pendingProfile = null;
    pendingAudit = null;
    messenger.setMockMessageHandler(auditChannel.name, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      if (request.path.startsWith('auth_logs/')) {
        audits.add(Map<String, Object?>.from(request.data!));
        await pendingAudit?.future;
      }
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMessageHandler(updates.name, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      writes.add(request.path);
      if (request.data?.containsKey('name') == true) {
        try {
          await pendingProfile?.future;
        } catch (_) {
          return fs.FirebaseFirestoreHostApi.codec
              .encodeMessage(['fixture-code', 'PRIVATE', null]);
        }
      }
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    auth = AuthProvider(authService: service, firebaseAuth: firebase);
  });
  tearDown(() async {
    if (!disposed) auth.dispose();
    await drain();
    messenger.setMockMessageHandler(updates.name, null);
    messenger.setMockMessageHandler(auditChannel.name, null);
  });
  test('owned admin initial profile and native lastLogin remain usable',
      () async {
    service.emit('owner_a');
    await drain();
    expect(auth.userUid, 'owner_a');
    expect(auth.isAdmin, isTrue);
    expect(auth.isInitializing, isFalse);
    expect(writes, ['users/owner_a']);
    expect(firebase.signouts, isEmpty);
  });
  test('SDK owner change immediately hides all previous admin identity',
      () async {
    service.emit('owner_a');
    await drain();
    service.uid = 'owner_b';
    hidden();
    expect(auth.isInitializing, isTrue);
    expect(auth.error, isNull);
  });
  test('SDK signout hides profile before the queued auth event', () async {
    service.emit('owner_a');
    await drain();
    service.uid = null;
    hidden();
    expect(auth.isInitializing, isFalse);
  });
  test('late admin A cannot overwrite B or write A lastLogin', () async {
    final old = Completer<UserModel>();
    service.read = (uid) =>
        uid == 'owner_a' ? old.future : Future.value(_profile(uid, name: 'B'));
    service.emit('owner_a');
    service.emit('owner_b');
    await drain();
    old.complete(_profile('owner_a'));
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(auth.userName, 'B');
    expect(writes, ['users/owner_b']);
  });
  test('late nonadmin A before queued SDK event cannot sign out B', () async {
    final old = Completer<UserModel>();
    service.read = (_) => old.future;
    service.emit('owner_a');
    service.uid = 'owner_b';
    old.complete(_profile('owner_a', role: 'user'));
    await drain();
    expect(firebase.signouts, isEmpty);
    expect(service.uid, 'owner_b');
    hidden();
  });
  test('late nonadmin A after B profile cannot sign out current admin',
      () async {
    final old = Completer<UserModel>();
    service.read =
        (uid) => uid == 'owner_a' ? old.future : Future.value(_profile(uid));
    service.emit('owner_a');
    service.emit('owner_b');
    await drain();
    old.complete(_profile('owner_a', role: 'seller'));
    await drain();
    expect(firebase.signouts, isEmpty);
    expect(auth.userUid, 'owner_b');
    expect(auth.isAdmin, isTrue);
  });
  for (final role in ['user', 'seller', 'employee', 'delivery_partner']) {
    test('current owned $role remains refused with safe access denied feedback',
        () async {
      service.read = (uid) async => _profile(uid, role: role);
      service.emit('owner_a');
      await drain();
      hidden();
      expect(firebase.signouts, ['owner_a']);
      expect(service.uid, isNull);
      expect(auth.error, 'Access denied. You are not an admin.');
    });
  }
  test('foreign admin model fails closed without logout or lastLogin',
      () async {
    service.read = (_) async => _profile('foreign');
    service.emit('owner_a');
    await drain();
    hidden();
    expect(writes, isEmpty);
    expect(firebase.signouts, isEmpty);
    expect(auth.error, isNotNull);
  });
  test('same UID renewal rejects older profile name', () async {
    final old = Completer<UserModel>();
    var calls = 0;
    service.read = (uid) =>
        calls++ == 0 ? old.future : Future.value(_profile(uid, name: 'Latest'));
    service.emit('owner_a');
    service.emit('owner_a');
    await drain();
    old.complete(_profile('owner_a', name: 'Old'));
    await drain();
    expect(auth.userName, 'Latest');
    expect(writes, ['users/owner_a']);
  });
  test('late old failure cannot publish errors in B', () async {
    final old = Completer<UserModel>();
    service.read =
        (uid) => uid == 'owner_a' ? old.future : Future.value(_profile(uid));
    service.emit('owner_a');
    service.emit('owner_b');
    await drain();
    old.completeError(StateError('PRIVATE_OWNER_A'));
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
  });
  test('owned profile failure is safe and explicit refresh recovers', () async {
    service.read = (_) async => throw StateError('PRIVATE_FIXTURE');
    service.emit('owner_a');
    await drain();
    hidden();
    expect(auth.error, isNot(contains('PRIVATE')));
    expect(auth.isInitializing, isFalse);
    service.read = (uid) async => _profile(uid);
    await auth.refreshUserData();
    expect(auth.userUid, 'owner_a');
    expect(auth.error, isNull);
  });
  test('old profile completion cannot hide newer pending initialization',
      () async {
    final old = Completer<UserModel>(), next = Completer<UserModel>();
    service.read = (uid) => uid == 'owner_a' ? old.future : next.future;
    service.emit('owner_a');
    service.emit('owner_b');
    old.complete(_profile('owner_a'));
    await drain();
    expect(auth.isInitializing, isTrue);
    hidden();
    expect(writes, isEmpty);
    next.complete(_profile('owner_b'));
    await drain();
    expect(auth.userUid, 'owner_b');
  });
  test('newer refresh wins over older same-owner refresh', () async {
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
  test('latest refresh error clears cached admin authority', () async {
    service.emit('owner_a');
    await drain();
    service.read = (_) async => throw StateError('PRIVATE_REFRESH');
    await auth.refreshUserData();
    hidden();
    expect(auth.error, isNot(contains('PRIVATE')));
  });
  test('valid owned admin restore preserves access', () async {
    await auth.restoreSession();
    expect(auth.userUid, 'owner_a');
    expect(auth.isAdmin, isTrue);
    expect(auth.isInitializing, isFalse);
    expect(service.restores, 1);
  });
  test('restore without SDK owner avoids service IO', () async {
    service.uid = null;
    await auth.restoreSession();
    hidden();
    expect(service.restores, 0);
  });
  test('late nonadmin restore cannot sign out B', () async {
    final old = Completer<UserModel?>();
    service.restore = () => old.future;
    final pending = auth.restoreSession();
    service.emit('owner_b');
    await drain();
    old.complete(_profile('owner_a', role: 'user'));
    await pending;
    expect(firebase.signouts, isEmpty);
    expect(auth.userUid, 'owner_b');
  });
  test('newer refresh supersedes same-owner restored role', () async {
    final old = Completer<UserModel?>();
    service.restore = () => old.future;
    final pending = auth.restoreSession();
    await auth.refreshUserData();
    old.complete(_profile('owner_a', role: 'seller'));
    await pending;
    expect(firebase.signouts, isEmpty);
    expect(auth.isAdmin, isTrue);
  });
  test('disposed late profile cannot publish or write lastLogin', () async {
    final old = Completer<UserModel>();
    service.read = (_) => old.future;
    service.emit('owner_a');
    auth.dispose();
    disposed = true;
    old.complete(_profile('owner_a'));
    await drain();
    hidden();
    expect(writes, isEmpty);
    expect(service.stream.subscriptions.single.cancelled, 1);
  });
  test('callback delivered after cancellation cannot revive profile', () async {
    service.emit('owner_a');
    await drain();
    final old = service.stream.subscriptions.single;
    auth.dispose();
    disposed = true;
    old.data?.call(_User('owner_a'));
    await drain();
    hidden();
  });
  for (final closed in [false, true]) {
    test(
        'auth stream ${closed ? 'close' : 'error'} clears authority and retry resubscribes',
        () async {
      service.emit('owner_a');
      await drain();
      final old = service.stream.subscriptions.single;
      if (closed) {
        old.done?.call();
      } else if (old.error != null) {
        Function.apply(old.error!, [StateError('PRIVATE_STREAM')]);
      }
      await drain();
      hidden();
      expect(auth.isInitializing, isFalse);
      expect(old.cancelled, 1);
      await auth.refreshUserData();
      expect(auth.isAdmin, isTrue);
      expect(service.stream.subscriptions, hasLength(2));
      final before = service.reads.length;
      old.data?.call(_User('owner_a'));
      await drain();
      expect(service.reads, hasLength(before));
      expect(auth.isAdmin, isTrue);
    });
  }
  test('stale refresh failure leaves newer admin and error untouched',
      () async {
    service.emit('owner_a');
    await drain();
    final old = Completer<UserModel>();
    service.read = (_) => old.future;
    final pending = auth.refreshUserData();
    service.read = (uid) async => _profile(uid);
    service.emit('owner_b');
    await drain();
    old.completeError(StateError('PRIVATE'));
    await pending;
    expect(auth.userUid, 'owner_b');
    expect(auth.error, isNull);
  });
  test('older restore cannot hide newer same-owner pending restore', () async {
    final first = Completer<UserModel?>(), second = Completer<UserModel?>();
    service.restore = () => first.future;
    final old = auth.restoreSession();
    service.restore = () => second.future;
    final next = auth.restoreSession();
    first.complete(_profile('owner_a', name: 'Old'));
    await old;
    expect(auth.isInitializing, isTrue);
    hidden();
    second.complete(_profile('owner_a', name: 'Latest'));
    await next;
    expect(auth.userName, 'Latest');
  });
  test('foreign restored admin profile refuses without SDK logout', () async {
    service.restore = () async => _profile('foreign');
    await auth.restoreSession();
    hidden();
    expect(firebase.signouts, isEmpty);
    expect(auth.error, isNotNull);
  });
  test('owned refresh role revocation retains the admin-only rule', () async {
    service.emit('owner_a');
    await drain();
    service.read = (uid) async => _profile(uid, role: 'user');
    await auth.refreshUserData();
    await drain();
    hidden();
    expect(firebase.signouts, ['owner_a']);
    expect(auth.error, 'Access denied. You are not an admin.');
  });
  test('new admin survives old refusal completion after SDK dispatch',
      () async {
    firebase.pending = Completer<void>();
    service.read =
        (uid) async => _profile(uid, role: uid == 'owner_a' ? 'user' : 'admin');
    service.emit('owner_a');
    await drain();
    expect(firebase.signouts, ['owner_a']);
    service.emit('owner_b');
    await drain();
    firebase.pending!.complete();
    await drain();
    expect(auth.userUid, 'owner_b');
    expect(auth.isAdmin, isTrue);
    expect(auth.error, isNull);
  });
  test('disposed provider retries perform no additional service work',
      () async {
    service.emit('owner_a');
    await drain();
    final reads = service.reads.length;
    auth.dispose();
    disposed = true;
    await auth.refreshUserData();
    await auth.restoreSession();
    hidden();
    expect(service.reads, hasLength(reads));
    expect(service.restores, 0);
  });
  test('reentrant listener SDK switch fences profile read before dispatch',
      () async {
    auth.addListener(() {
      if (auth.isInitializing) service.uid = 'owner_b';
    });
    service.emit('owner_a');
    await drain();
    expect(service.reads, isEmpty);
    expect(writes, isEmpty);
    expect(firebase.signouts, isEmpty);
    hidden();
  });
  test(
      'stream failure after SDK changes binds current owner and finishes resolving',
      () async {
    service.emit('owner_a');
    await drain();
    final old = service.stream.subscriptions.single;
    service.uid = 'owner_b';
    Function.apply(old.error!, [StateError('PRIVATE')]);
    await drain();
    hidden();
    expect(auth.isInitializing, isFalse);
    expect(auth.error, isNot(contains('PRIVATE')));
  });
  test('synchronous stream close cancels returned listener and allows retry',
      () async {
    auth.dispose();
    service.stream.onListen = (subscription) => subscription.done?.call();
    auth = AuthProvider(authService: service, firebaseAuth: firebase);
    await drain();
    final closed = service.stream.subscriptions.last;
    expect(closed.cancelled, 1);
    hidden();
    expect(auth.isInitializing, isFalse);
    service.stream.onListen = null;
    final before = service.stream.subscriptions.length;
    await auth.refreshUserData();
    expect(service.stream.subscriptions, hasLength(before + 1));
    expect(auth.isAdmin, isTrue);
  });

  Future<bool> command(String kind) => kind == 'password'
      ? auth.changePassword(
          currentPassword: 'fixture_old', newPassword: 'fixture_new')
      : auth.updateUserProfile(name: 'Updated');
  Future<void> startCurrent() async {
    service.emit('owner_a');
    await drain();
    writes.clear();
    audits.clear();
  }

  for (final kind in ['profile', 'password']) {
    test('admin $kind current owner completes and audits own identity',
        () async {
      await startCurrent();
      final result = command(kind);
      await drain();
      if (kind == 'password') {
        service.passwordReply.complete();
      }
      expect(await result, isTrue);
      expect(audits, hasLength(1));
      expect(audits.single['uid'], 'owner_a');
      expect(audits.single['success'], isTrue);
      expect(auth.isLoading, isFalse);
      if (kind == 'profile') {
        expect(auth.userName, 'Updated');
        expect(writes, ['users/owner_a']);
      } else {
        expect(service.passwordOwners, ['owner_a']);
      }
    });
    for (final owner in <String?>['owner_b', null, 'owner_a']) {
      test('admin $kind stale success $owner has no audit or publication',
          () async {
        await startCurrent();
        pendingProfile = Completer<void>();
        final result = command(kind);
        await drain();
        service.emit(owner);
        await drain();
        if (kind == 'password') {
          service.passwordReply.complete();
        } else {
          pendingProfile!.complete();
        }
        expect(await result, isFalse);
        expect(audits, isEmpty);
        expect(auth.userUid, owner);
        expect(auth.userName, owner == null ? null : 'Current');
        expect(auth.error, isNull);
      });
      test('admin $kind stale failure $owner leaves new owner clean', () async {
        await startCurrent();
        pendingProfile = Completer<void>();
        final result = command(kind);
        await drain();
        service.emit(owner);
        await drain();
        if (kind == 'password') {
          service.passwordReply.completeError(StateError('PRIVATE'));
        } else {
          pendingProfile!.completeError(StateError('PRIVATE'));
        }
        expect(await result, isFalse);
        expect(audits, isEmpty);
        expect(auth.error, isNull);
      });
    }
    test('admin $kind disposed entry does not dispatch', () async {
      await startCurrent();
      auth.dispose();
      disposed = true;
      service.passwordReply.complete();
      expect(await command(kind), isFalse);
      expect(service.passwordOwners, isEmpty);
      expect(writes, isEmpty);
      expect(audits, isEmpty);
    });
    test('admin $kind disposed continuation emits no audit', () async {
      await startCurrent();
      pendingProfile = Completer<void>();
      final result = command(kind);
      await drain();
      auth.dispose();
      disposed = true;
      if (kind == 'password') {
        service.passwordReply.complete();
      } else {
        pendingProfile!.complete();
      }
      expect(await result, isFalse);
      expect(audits, isEmpty);
    });
    test('admin $kind reentrant account change prevents dispatch', () async {
      await startCurrent();
      auth.addListener(() {
        if (auth.isLoading) service.uid = 'owner_b';
      });
      final result = command(kind);
      await drain();
      service.passwordReply.complete();
      expect(await result, isFalse);
      expect(service.passwordOwners, isEmpty);
      expect(writes, isEmpty);
      expect(audits, isEmpty);
    });
    test('admin $kind audit await cannot publish to renewed account', () async {
      await startCurrent();
      pendingAudit = Completer<void>();
      final result = command(kind);
      if (kind == 'password') {
        service.passwordReply.complete();
      }
      await drain();
      expect(audits, hasLength(1));
      expect(audits.single['uid'], 'owner_a');
      service.emit('owner_b');
      await drain();
      pendingAudit!.complete();
      expect(await result, isFalse);
      expect(auth.userUid, 'owner_b');
      expect(auth.userName, 'Current');
      expect(auth.error, isNull);
    });
    test('admin $kind lost observer prevents command', () async {
      await startCurrent();
      service.stream.subscriptions.last.done?.call();
      await drain();
      service.passwordReply.complete();
      expect(await command(kind), isFalse);
      expect(writes, isEmpty);
      expect(service.passwordOwners, isEmpty);
      expect(audits, isEmpty);
    });
  }
  test('admin password unexpected failure has static UI and audit detail',
      () async {
    await startCurrent();
    final result = command('password');
    service.passwordReply.completeError(StateError('PRIVATE'));
    expect(await result, isFalse);
    expect(auth.error, isNot(contains('PRIVATE')));
    expect(audits.single['error'], isNot(contains('PRIVATE')));
  });
  test('admin profile refresh supersedes pending profile command', () async {
    await startCurrent();
    pendingProfile = Completer<void>();
    final result = command('profile');
    await drain();
    await auth.refreshUserData();
    pendingProfile!.complete();
    expect(await result, isFalse);
    expect(auth.userName, 'Current');
    expect(audits, isEmpty);
  });

  for (final kind in ['profile', 'password']) {
    test('admin $kind signedout entry does not dispatch', () async {
      service.emit(null);
      await drain();
      service.passwordReply.complete();
      expect(await command(kind), isFalse);
      expect(writes, isEmpty);
      expect(audits, isEmpty);
      expect(service.passwordOwners, isEmpty);
    });
    test('admin $kind SDK drift before stream does not dispatch', () async {
      await startCurrent();
      service.uid = 'owner_b';
      service.passwordReply.complete();
      expect(await command(kind), isFalse);
      expect(writes, isEmpty);
      expect(audits, isEmpty);
      expect(service.passwordOwners, isEmpty);
    });
    test('admin $kind stream close invalidates pending continuation', () async {
      await startCurrent();
      pendingProfile = Completer<void>();
      final result = command(kind);
      await drain();
      service.stream.subscriptions.last.done?.call();
      await drain();
      if (kind == 'password') {
        service.passwordReply.complete();
      } else {
        pendingProfile!.complete();
      }
      expect(await result, isFalse);
      expect(audits, isEmpty);
      expect(auth.currentUser, isNull);
    });
    test('admin $kind later command supersedes older reply', () async {
      await startCurrent();
      pendingProfile = Completer<void>();
      final first = command(kind);
      final second = command(kind);
      await drain();
      if (kind == 'password') {
        service.passwordReply.complete();
      } else {
        pendingProfile!.complete();
      }
      expect(await first, isFalse);
      expect(await second, isTrue);
      expect(audits, hasLength(1));
      expect(audits.single['uid'], 'owner_a');
    });
  }
  test('admin profile unexpected failure has static UI and audit detail',
      () async {
    await startCurrent();
    pendingProfile = Completer<void>();
    final result = command('profile');
    await drain();
    pendingProfile!.completeError(StateError('PRIVATE'));
    expect(await result, isFalse);
    expect(auth.error, isNot(contains('PRIVATE')));
    expect(auth.isLoading, isFalse);
    expect(audits.single['error'], isNot(contains('PRIVATE')));
  });
}
