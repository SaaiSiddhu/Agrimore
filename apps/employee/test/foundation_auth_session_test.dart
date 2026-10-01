@TestOn('vm')
library;

import 'dart:async';
import 'package:employee/providers/auth_provider.dart';
import 'package:agrimore_services/agrimore_services.dart';
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
      case 184:
      case 185:
        return readValue(buffer);
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
  String? get phoneNumber => 'sdk-$uid';
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

class _AuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firebase implements FirebaseAuth {
  String? uid = 'owner_a';
  final stream = _Stream();
  final signouts = <String?>[];
  Completer<void>? signoutPending;
  @override
  Future<void> signOut() async {
    final owner = uid;
    signouts.add(owner);
    await signoutPending?.future;
    if (uid == owner) emit(null);
  }

  @override
  User? get currentUser => uid == null ? null : _User(uid!);
  @override
  Stream<User?> authStateChanges() => stream;
  void emit(String? owner) {
    uid = owner;
    stream.subscriptions.last.data?.call(currentUser);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const readChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const writeChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
      fs.FirebaseFirestoreHostApi.codec);
  const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Firebase firebase;
  late EmployeeAuthProvider auth;
  late List<fs.DocumentReferenceRequest> reads, writes;
  late Future<List<Object?>> Function(fs.DocumentReferenceRequest) read;
  late Future<String?> Function() token;
  var disposed = false, tokenReads = 0;
  const emulator =
      bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
  List<Object?> document(String path, Map<String, Object?>? data) => [
        fs.PigeonDocumentSnapshot(
            path: path,
            data: data,
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
  List<Object?> approved(fs.DocumentReferenceRequest r,
          {String role = 'employee',
          String status = 'approved',
          String name = 'Current'}) =>
      document(
          r.path,
          r.path.startsWith('users/')
              ? {
                  'role': role,
                  'name': name,
                  'email': 'fixture@example.invalid',
                  'phone': 'profile-${r.path.split('/').last}'
                }
              : {'status': status});
  Future<void> drain() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  EmployeeAuthProvider make() =>
      EmployeeAuthProvider(firebaseAuth: firebase, authService: _AuthService());
  void hidden({bool loading = false}) {
    expect(auth.user, isNull);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.isEmployee, isFalse);
    expect(auth.isLoading, loading);
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    firebase = _Firebase();
    reads = [];
    writes = [];
    disposed = false;
    tokenReads = 0;
    read = (r) async => approved(r);
    token = () async => 'fixture-token';
    messenger.setMockDecodedMessageHandler<Object?>(readChannel,
        (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      reads.add(r);
      return read(r);
    });
    messenger.setMockMessageHandler(writeChannel.name, (message) async {
      final r = (const _WriteRequestCodec().decodeMessage(message)! as List)[1]
          as fs.DocumentReferenceRequest;
      writes.add(r);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMethodCallHandler(messaging, (call) async {
      if (call.method == 'Messaging#getToken') {
        tokenReads++;
        return {'token': await token()};
      }
      return null;
    });
    auth = make();
  });
  tearDown(() async {
    if (!disposed) auth.dispose();
    await drain();
    messenger.setMockDecodedMessageHandler<Object?>(readChannel, null);
    messenger.setMockMessageHandler(writeChannel.name, null);
    messenger.setMockMethodCallHandler(messaging, null);
  });
  test('current approved employee reads records and registers own native push',
      () async {
    firebase.emit('owner_a');
    await drain();
    expect(auth.user?.uid, 'owner_a');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.isEmployee, isTrue);
    expect(auth.error, isNull);
    expect(auth.isLoading, isFalse);
    expect(reads.map((r) => r.path),
        containsAll(['users/owner_a', 'employees/owner_a']));
    expect(writes.map((r) => r.path), emulator ? [] : ['users/owner_a']);
    if (!emulator) {
      expect(writes.single.data?['fcmTokens'], ['fixture-token']);
    }
    expect(firebase.signouts, isEmpty);
  });
  for (final status in ['pending', 'suspended', 'rejected']) {
    test('$status employee retains explanation but no workspace or push',
        () async {
      read = (r) async => approved(r, status: status);
      firebase.emit('owner_a');
      await drain();
      expect(auth.user?.uid, 'owner_a');
      expect(auth.isAuthenticated, isFalse);
      expect(auth.error,
          contains(status == 'suspended' ? 'suspended' : 'pending'));
      expect(writes, isEmpty);
      expect(tokenReads, 0);
      expect(firebase.signouts, isEmpty);
    });
  }
  for (final role in ['user', 'seller', 'admin', 'rider']) {
    test('$role is refused and own sign-out preserves safe reason', () async {
      read = (r) async => approved(r, role: role);
      firebase.emit('owner_a');
      await drain();
      hidden();
      expect(firebase.signouts, ['owner_a']);
      expect(auth.error, contains("isn't registered"));
      expect(auth.error, isNot(contains('pending')));
      expect(auth.error, isNot(contains('suspended')));
      expect(writes, isEmpty);
    });
  }
  test('missing associate profile signs out current owner and keeps reason',
      () async {
    read = (r) async =>
        r.path.startsWith('employees/') ? document(r.path, null) : approved(r);
    firebase.emit('owner_a');
    await drain();
    hidden();
    expect(firebase.signouts, ['owner_a']);
    expect(auth.error, contains('could not find'));
    expect(writes, isEmpty);
  });
  test('missing user record refuses and keeps non-associate reason', () async {
    read = (r) async => document(r.path, null);
    firebase.emit('owner_a');
    await drain();
    hidden();
    expect(firebase.signouts, ['owner_a']);
    expect(auth.error, contains("isn't registered"));
  });
  test(
      'SDK owner changes before event immediately hide old identity and authority',
      () async {
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    hidden(loading: true);
    expect(auth.error, isNull);
    firebase.uid = null;
    hidden();
  });
  test('cached user alone never grants employee authority before approval',
      () async {
    final pending = Completer<List<Object?>>();
    read = (r) async => r.source == fs.Source.cache
        ? approved(r, status: 'pending')
        : pending.future;
    firebase.emit('owner_a');
    await drain();
    final authenticated = auth.isAuthenticated;
    final exposed = auth.user;
    firebase.emit(null);
    pending.complete(document('users/owner_a', null));
    await drain();
    expect(authenticated, isFalse);
    expect(exposed, isNull);
    expect(writes, isEmpty);
  });
  test('owned user remains private while employee approval read is unsettled',
      () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path.startsWith('employees/') ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    final exposed = auth.user;
    final authenticated = auth.isAuthenticated;
    pending.complete(document('employees/owner_a', {'status': 'pending'}));
    await drain();
    expect(exposed, isNull);
    expect(authenticated, isFalse);
    expect(auth.error, contains('pending'));
  });
  test('old pending approval cannot overwrite new approved owner or loading',
      () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path == 'employees/owner_a' ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    firebase.emit('owner_b');
    await drain();
    pending.complete(document('employees/owner_a', {'status': 'suspended'}));
    await drain();
    expect(auth.user?.uid, 'owner_b');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, isNull);
    expect(auth.isLoading, isFalse);
  });
  test(
      'old cached employee read cannot publish after SDK changes without event',
      () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path == 'employees/owner_a' ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    pending.complete(document('employees/owner_a', {'status': 'approved'}));
    await drain();
    hidden(loading: true);
    expect(writes, isEmpty);
  });
  test('same UID auth renewal keeps only the latest approval response',
      () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path.startsWith('employees/') ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    read = (r) async => approved(r, name: 'Renewed');
    firebase.emit('owner_a');
    await drain();
    pending.complete(document('employees/owner_a', {'status': 'suspended'}));
    await drain();
    expect(auth.user?.name, 'Renewed');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, isNull);
  });
  test('superseded auth callback starts no reads or logout', () async {
    firebase.uid = 'owner_b';
    firebase.stream.subscriptions.single.data?.call(_User('owner_a'));
    await drain();
    expect(reads, isEmpty);
    expect(firebase.signouts, isEmpty);
    hidden(loading: true);
  });
  test('old failure cannot revoke newer employee', () async {
    final pending = Completer<List<Object?>>();
    read =
        (r) async => r.path == 'users/owner_a' ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    firebase.emit('owner_b');
    await drain();
    pending.complete(['unavailable', 'PRIVATE_FIXTURE', null]);
    await drain();
    expect(auth.user?.uid, 'owner_b');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, isNull);
  });
  test('current failed approval refuses even after cached employee profile',
      () async {
    read = (r) async => r.path.startsWith('employees/')
        ? ['unavailable', 'PRIVATE_FIXTURE', null]
        : approved(r);
    firebase.emit('owner_a');
    await drain();
    hidden();
    expect(auth.error, isNotNull);
    expect(auth.error, isNot(contains('PRIVATE_FIXTURE')));
    expect(writes, isEmpty);
  });
  test('old non-associate response cannot sign out the new owner', () async {
    final pending = Completer<List<Object?>>();
    read =
        (r) async => r.path == 'users/owner_a' ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    firebase.emit('owner_b');
    await drain();
    pending.complete(document('users/owner_a', {'role': 'user'}));
    await drain();
    expect(firebase.signouts, isEmpty);
    expect(auth.user?.uid, 'owner_b');
    expect(auth.isAuthenticated, isTrue);
  });
  test('new owner survives completion of already dispatched refusal logout',
      () async {
    firebase.signoutPending = Completer<void>();
    read = (r) async =>
        approved(r, role: r.path.endsWith('owner_a') ? 'user' : 'employee');
    firebase.emit('owner_a');
    await drain();
    expect(firebase.signouts, ['owner_a']);
    firebase.emit('owner_b');
    await drain();
    firebase.signoutPending!.complete();
    await drain();
    expect(auth.user?.uid, 'owner_b');
    expect(auth.error, isNull);
    expect(auth.isAuthenticated, isTrue);
  });
  test('old push token read cannot write under a changed SDK owner', () async {
    final pending = Completer<String?>();
    token = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    pending.complete('old-token');
    await drain();
    expect(writes, isEmpty);
    hidden(loading: true);
  });
  test('same UID renewal invalidates old push token read', () async {
    final pending = Completer<String?>();
    token = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    token = () async => 'new-token';
    firebase.emit('owner_a');
    await drain();
    pending.complete('old-token');
    await drain();
    expect(
        writes.map((r) => r.data?['fcmToken']), emulator ? [] : ['new-token']);
  });
  test('disposed profile completion neither publishes nor notifies', () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path.startsWith('employees/') ? pending.future : approved(r);
    var notifications = 0;
    auth.addListener(() {
      notifications++;
    });
    firebase.emit('owner_a');
    await drain();
    final count = notifications;
    auth.dispose();
    disposed = true;
    pending.complete(document('employees/owner_a', {'status': 'approved'}));
    await drain();
    hidden();
    expect(notifications, count);
    expect(writes, isEmpty);
    expect(firebase.stream.subscriptions.single.cancelled, 1);
  });
  test('disposed push token completion cannot write', () async {
    final pending = Completer<String?>();
    token = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    auth.dispose();
    disposed = true;
    pending.complete('old-token');
    await drain();
    expect(writes, isEmpty);
    hidden();
  });
  test('signed-out event fences old profile and approval', () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path.startsWith('employees/') ? pending.future : approved(r);
    firebase.emit('owner_a');
    await drain();
    firebase.emit(null);
    pending.complete(document('employees/owner_a', {'status': 'approved'}));
    await drain();
    hidden();
    expect(writes, isEmpty);
  });

  test('default missing approval status remains pending without push',
      () async {
    read = (r) async =>
        r.path.startsWith('employees/') ? document(r.path, {}) : approved(r);
    firebase.emit('owner_a');
    await drain();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.error, contains('pending'));
    expect(writes, isEmpty);
  });
  test('latest refresh wins over an older same-owner approval read', () async {
    firebase.emit('owner_a');
    await drain();
    final pending = Completer<List<Object?>>();
    read = (r) async => r.path.startsWith('employees/')
        ? pending.future
        : approved(r, name: 'Older');
    final old = auth.refreshUserData();
    await drain();
    read = (r) async => approved(r, name: 'Latest');
    await auth.refreshUserData();
    pending.complete(document('employees/owner_a', {'status': 'suspended'}));
    await old;
    expect(auth.user?.name, 'Latest');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, isNull);
  });
  test('latest refresh failure cannot be overwritten by older approval',
      () async {
    firebase.emit('owner_a');
    await drain();
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path.startsWith('employees/') ? pending.future : approved(r);
    final old = auth.refreshUserData();
    await drain();
    read = (_) async => ['unavailable', 'PRIVATE', null];
    await auth.refreshUserData();
    pending.complete(document('employees/owner_a', {'status': 'approved'}));
    await old;
    hidden();
    expect(auth.error, 'Failed to load user data');
  });
  test('successful refresh clears current profile failure', () async {
    read = (_) async => ['unavailable', 'PRIVATE', null];
    firebase.emit('owner_a');
    await drain();
    hidden();
    read = (r) async => approved(r);
    await auth.refreshUserData();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, isNull);
  });
  for (final close in [false, true]) {
    test(
        'auth ${close ? 'close' : 'error'} clears authority and refresh retries once',
        () async {
      firebase.emit('owner_a');
      await drain();
      final old = firebase.stream.subscriptions.single;
      if (close) {
        old.done?.call();
      } else if (old.error != null) {
        Function.apply(old.error!, [StateError('PRIVATE_STREAM')]);
      }
      await drain();
      hidden();
      expect(auth.error, contains('paused'));
      expect(old.cancelled, 1);
      await auth.refreshUserData();
      await drain();
      expect(auth.isAuthenticated, isTrue);
      expect(firebase.stream.subscriptions, hasLength(2));
      final count = reads.length;
      old.data?.call(_User('owner_a'));
      await drain();
      expect(reads, hasLength(count));
    });
  }
  test('sync auth close cancels returned listener then refresh recovers',
      () async {
    auth.dispose();
    firebase.stream.onListen = (sub) => sub.done?.call();
    auth = make();
    await drain();
    expect(firebase.stream.subscriptions.last.cancelled, 1);
    hidden();
    firebase.stream.onListen = null;
    final count = firebase.stream.subscriptions.length;
    await auth.refreshUserData();
    await drain();
    expect(auth.isAuthenticated, isTrue);
    expect(firebase.stream.subscriptions, hasLength(count + 1));
  });
  test('disposed retry and late stream callbacks perform no work', () async {
    final old = firebase.stream.subscriptions.single;
    auth.dispose();
    disposed = true;
    await auth.refreshUserData();
    old.data?.call(_User('owner_a'));
    await drain();
    expect(reads, isEmpty);
    expect(old.cancelled, 1);
    hidden();
  });
  test('reentrant SDK change before read dispatch preserves owner boundary',
      () async {
    auth.addListener(() {
      if (auth.isLoading) firebase.uid = 'owner_b';
    });
    firebase.emit('owner_a');
    await drain();
    expect(reads, isEmpty);
    hidden(loading: true);
  });
  test('reentrant SDK change on approval cannot start token dispatch',
      () async {
    auth.addListener(() {
      if (auth.isAuthenticated) firebase.uid = 'owner_b';
    });
    firebase.emit('owner_a');
    await drain();
    expect(tokenReads, 0);
    expect(writes, isEmpty);
    hidden(loading: true);
  });
  test('clearError cannot turn pending approval into authenticated workspace',
      () async {
    read = (r) async => approved(r, status: 'pending');
    firebase.emit('owner_a');
    await drain();
    auth.clearError();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.error, contains('pending'));
  });
  test(
      'non-associate refusal remains subject to current owner after notification',
      () async {
    read = (r) async => approved(r, role: 'user');
    auth.addListener(() {
      if (auth.error?.contains("isn't registered") == true) {
        firebase.uid = 'owner_b';
      }
    });
    firebase.emit('owner_a');
    await drain();
    expect(firebase.signouts, isEmpty);
    hidden(loading: true);
  });
  test('owned sign-out completion cannot clear a newer approved profile',
      () async {
    firebase.emit('owner_a');
    await drain();
    firebase.signoutPending = Completer<void>();
    final old = auth.signOut();
    firebase.emit('owner_b');
    await drain();
    firebase.signoutPending!.complete();
    await old;
    expect(auth.user?.uid, 'owner_b');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, isNull);
  });
  test('bounded read timeout still falls back to owned cached user', () async {
    final pending = Completer<List<Object?>>();
    read = (r) async =>
        r.path.startsWith('users/') && r.source != fs.Source.cache
            ? pending.future
            : approved(r);
    firebase.emit('owner_a');
    await Future<void>.delayed(const Duration(milliseconds: 2700));
    await drain();
    expect(auth.isAuthenticated, isTrue);
    expect(
        reads.where(
            (r) => r.path == 'users/owner_a' && r.source == fs.Source.cache),
        hasLength(1));
    pending.complete(document('users/owner_a', null));
    await drain();
    expect(auth.isAuthenticated, isTrue);
  });
  test('stale timeout cannot dispatch cache fallback under new owner',
      () async {
    final pending = Completer<List<Object?>>();
    read = (r) async => r.path == 'users/owner_a' && r.source != fs.Source.cache
        ? pending.future
        : approved(r);
    firebase.emit('owner_a');
    await drain();
    firebase.emit('owner_b');
    await drain();
    await Future<void>.delayed(const Duration(milliseconds: 2700));
    await drain();
    expect(
        reads.where(
            (r) => r.path == 'users/owner_a' && r.source == fs.Source.cache),
        isEmpty);
    expect(auth.user?.uid, 'owner_b');
    expect(auth.isAuthenticated, isTrue);
    pending.complete(document('users/owner_a', null));
    await drain();
  });
}
