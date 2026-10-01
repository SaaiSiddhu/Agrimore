@TestOn('vm')
library;

import 'dart:async';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/app/emulator.dart';
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

class _Firebase implements FirebaseAuth {
  String? uid = 'owner_a';
  final stream = _Stream();
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
  const readsChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
    fs.FirebaseFirestoreHostApi.codec,
  );
  const writesChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet',
    fs.FirebaseFirestoreHostApi.codec,
  );
  const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Firebase firebase;
  late SellerAuthProvider auth;
  late List<String> reads, flushes;
  late List<fs.DocumentReferenceRequest> writes;
  late Future<List<Object?>> Function(String) read;
  late Future<void> Function() write;
  late Future<String?> Function() token;
  var tokenReads = 0;
  var disposed = false;
  Map<String, Object?> profile(String uid,
          {String role = 'seller', String name = 'Current'}) =>
      {
        'email': '$uid@example.invalid',
        'name': name,
        'role': role,
        'phone': 'profile-$uid',
      };
  List<Object?> document(String path, Map<String, Object?>? data) => [
        fs.PigeonDocumentSnapshot(
            path: path,
            data: data,
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false)),
      ];
  List<Object?> approved(String path, {String name = 'Current'}) => document(
      path,
      path.startsWith('users/')
          ? profile(path.split('/').last, name: name)
          : path.startsWith('sellers/')
              ? {'status': 'approved'}
              : null);
  Future<void> drain() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  SellerAuthProvider make() => SellerAuthProvider(
      firebaseAuth: firebase,
      savePendingPushToken: (uid) async {
        flushes.add(uid);
      });
  void hidden({SellerAccess access = SellerAccess.loading}) {
    expect(auth.currentUser, isNull);
    expect(auth.access, access);
    expect(auth.lastErrorMessage, isNull);
    expect(auth.retryAfterMs, isNull);
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    firebase = _Firebase();
    reads = [];
    writes = [];
    flushes = [];
    tokenReads = 0;
    disposed = false;
    read = (path) async => approved(path);
    write = () async {};
    token = () async => 'fixture-token';
    messenger.setMockDecodedMessageHandler<Object?>(readsChannel,
        (message) async {
      final request = (message! as List)[1] as fs.DocumentReferenceRequest;
      reads.add(request.path);
      return read(request.path);
    });
    messenger.setMockMessageHandler(writesChannel.name, (message) async {
      final request = (const _WriteRequestCodec().decodeMessage(message)!
          as List)[1] as fs.DocumentReferenceRequest;
      writes.add(request);
      await write();
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
    messenger.setMockDecodedMessageHandler<Object?>(readsChannel, null);
    messenger.setMockMessageHandler(writesChannel.name, null);
    messenger.setMockMethodCallHandler(messaging, null);
  });
  test('owned approved seller reads all records and registers own native token',
      () async {
    firebase.emit('owner_a');
    await drain();
    expect(auth.access, SellerAccess.approved);
    expect(auth.currentUser?.uid, 'owner_a');
    expect(auth.signedInPhone, 'profile-owner_a');
    expect(reads.toSet(),
        {'users/owner_a', 'sellers/owner_a', 'sellerRequests/owner_a'});
    expect(tokenReads, kSellerUsesEmulator ? 0 : 1);
    expect(writes.map((r) => r.path),
        kSellerUsesEmulator ? [] : ['users/owner_a']);
    if (!kSellerUsesEmulator) {
      expect(writes.single.data?['fcmToken'], 'fixture-token');
      expect(writes.single.data?['fcmTokens'], ['fixture-token']);
      expect(writes.single.option?.merge, isTrue);
    }
    expect(flushes, kSellerUsesEmulator ? [] : ['owner_a']);
  });
  test('legacy seller remains approved without a sellers record', () async {
    read = (path) async =>
        document(path, path.startsWith('users/') ? profile('owner_a') : null);
    firebase.emit('owner_a');
    await drain();
    expect(auth.access, SellerAccess.approved);
  });
  for (final status in [
    'pending',
    'suspended',
    'rejected',
    'draft',
    'absent'
  ]) {
    test('$status eligibility keeps existing route without push work',
        () async {
      read = (path) async => document(
          path,
          path.startsWith('users/')
              ? profile('owner_a', role: 'user')
              : path.startsWith('sellers/') &&
                      status != 'draft' &&
                      status != 'absent'
                  ? {'status': status}
                  : path.startsWith('sellerRequests/') && status == 'draft'
                      ? {'status': 'draft'}
                      : null);
      firebase.emit('owner_a');
      await drain();
      expect(
          auth.access,
          status == 'absent'
              ? SellerAccess.noApplication
              : SellerAccess.values.byName(status));
      expect(writes, isEmpty);
      expect(flushes, isEmpty);
      expect(tokenReads, 0);
    });
  }
  test('SDK changes before auth event hide old approval profile and phone',
      () async {
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    hidden();
    expect(auth.signedInPhone, 'sdk-owner_b');
    firebase.uid = null;
    hidden(access: SellerAccess.signedOut);
    expect(auth.signedInPhone, isNull);
  });
  test('old parallel profile reply cannot override new approved owner',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path == 'users/owner_a' ? pending.future : approved(path);
    firebase.emit('owner_a');
    await drain();
    firebase.emit('owner_b');
    await drain();
    pending.complete(approved('users/owner_a'));
    await drain();
    expect(auth.currentUser?.uid, 'owner_b');
    expect(auth.access, SellerAccess.approved);
    expect(writes.any((r) => r.path == 'users/owner_a'), isFalse);
  });
  test('late profile before next auth event cannot start old token read',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path == 'users/owner_a' ? pending.future : approved(path);
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    pending.complete(approved('users/owner_a'));
    await drain();
    hidden();
    expect(tokenReads, 0);
    expect(writes, isEmpty);
  });
  test('latest refresh wins over older same-owner result', () async {
    firebase.emit('owner_a');
    await drain();
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? pending.future : approved(path);
    final old = auth.refresh();
    await drain();
    read = (path) async => approved(path, name: 'Latest');
    await auth.refresh();
    pending.complete(approved('users/owner_a', name: 'Old'));
    await old;
    expect(auth.currentUser?.name, 'Latest');
  });
  test('same UID auth renewal invalidates earlier profile response', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? pending.future : approved(path);
    firebase.emit('owner_a');
    await drain();
    read = (path) async => approved(path, name: 'Renewed');
    firebase.emit('owner_a');
    await drain();
    pending.complete(approved('users/owner_a', name: 'Old'));
    await drain();
    expect(auth.currentUser?.name, 'Renewed');
  });
  test('old failed read leaves new route and error untouched', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path == 'users/owner_a' ? pending.future : approved(path);
    firebase.emit('owner_a');
    await drain();
    firebase.emit('owner_b');
    await drain();
    pending.complete(['unavailable', 'PRIVATE_FIXTURE', null]);
    await drain();
    expect(auth.currentUser?.uid, 'owner_b');
    expect(auth.access, SellerAccess.approved);
    expect(auth.lastError, SellerAuthError.none);
  });
  test('current read failure remains safe and refresh clears network error',
      () async {
    read = (_) async => ['unavailable', 'PRIVATE_FIXTURE', null];
    firebase.emit('owner_a');
    await drain();
    expect(auth.access, SellerAccess.noApplication);
    expect(auth.lastError, SellerAuthError.network);
    expect(auth.lastErrorMessage, isNull);
    read = (path) async => approved(path);
    await auth.refresh();
    expect(auth.access, SellerAccess.approved);
    expect(auth.lastError, SellerAuthError.none);
  });
  test('old error is hidden immediately on SDK owner change', () async {
    read = (_) async => ['unavailable', 'PRIVATE_FIXTURE', null];
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    expect(auth.lastError, SellerAuthError.none);
    hidden();
  });
  test('latest failing refresh prevents older approval from returning',
      () async {
    firebase.emit('owner_a');
    await drain();
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? pending.future : approved(path);
    final old = auth.refresh();
    await drain();
    read = (_) async => ['unavailable', 'PRIVATE_FIXTURE', null];
    await auth.refresh();
    pending.complete(approved('users/owner_a'));
    await old;
    expect(auth.access, SellerAccess.noApplication);
    expect(auth.lastError, SellerAuthError.network);
  });
  test('native SDK binds snapshot identity to the requested owner path',
      () async {
    // The cached native SDK constructs identity from the requested reference,
    // not the reply's path. This is a transport control, not a foreign-read probe.
    read = (path) async =>
        path.startsWith('users/') ? approved('users/foreign') : approved(path);
    firebase.emit('owner_a');
    await drain();
    expect(auth.currentUser?.uid, 'owner_a');
    expect(reads, contains('users/owner_a'));
    expect(writes.every((request) => request.path == 'users/owner_a'), isTrue);
  });
  test('null token keeps approval without write or pending flush', () async {
    token = () async => null;
    firebase.emit('owner_a');
    await drain();
    expect(auth.access, SellerAccess.approved);
    expect(writes, isEmpty);
    expect(flushes, isEmpty);
  });
  test('held token read cannot write after SDK changes without event',
      () async {
    final pending = Completer<String?>();
    token = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    firebase.uid = 'owner_b';
    pending.complete('old-token');
    await drain();
    expect(writes, isEmpty);
    expect(flushes, isEmpty);
    hidden();
  });
  test('issued token write may finish but cannot flush under new owner',
      () async {
    final pending = Completer<void>();
    write = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    expect(writes, hasLength(1));
    firebase.uid = 'owner_b';
    pending.complete();
    await drain();
    expect(flushes, isEmpty);
    hidden();
  }, skip: kSellerUsesEmulator);
  test('newer same-owner refresh invalidates old token read', () async {
    final pending = Completer<String?>();
    token = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    token = () async => 'latest-token';
    await auth.refresh();
    await drain();
    pending.complete('old-token');
    await drain();
    expect(writes.map((r) => r.data?['fcmToken']),
        kSellerUsesEmulator ? [] : ['latest-token']);
  });
  test('disposed profile reply performs no push or notifications', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? pending.future : approved(path);
    var notifications = 0;
    auth.addListener(() {
      notifications++;
    });
    firebase.emit('owner_a');
    await drain();
    final before = notifications;
    auth.dispose();
    disposed = true;
    pending.complete(approved('users/owner_a'));
    await drain();
    hidden(access: SellerAccess.signedOut);
    expect(notifications, before);
    expect(writes, isEmpty);
    expect(tokenReads, 0);
  });
  test('disposed token read cannot write', () async {
    final pending = Completer<String?>();
    token = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    auth.dispose();
    disposed = true;
    pending.complete('old-token');
    await drain();
    expect(writes, isEmpty);
    expect(flushes, isEmpty);
  });
  test('disposed issued write cannot flush pending token', () async {
    final pending = Completer<void>();
    write = () => pending.future;
    firebase.emit('owner_a');
    await drain();
    auth.dispose();
    disposed = true;
    pending.complete();
    await drain();
    expect(flushes, isEmpty);
  });
  for (final close in [false, true]) {
    test(
        'auth ${close ? 'close' : 'error'} revokes authority and refresh resubscribes',
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
      hidden(access: SellerAccess.noApplication);
      expect(auth.lastError, SellerAuthError.network);
      expect(old.cancelled, 1);
      await auth.refresh();
      await drain();
      expect(auth.access, SellerAccess.approved);
      expect(firebase.stream.subscriptions, hasLength(2));
      final count = reads.length;
      old.data?.call(_User('owner_a'));
      await drain();
      expect(reads, hasLength(count));
    });
  }
  test('synchronous auth close cancels returned subscription and permits retry',
      () async {
    auth.dispose();
    firebase.stream.onListen = (sub) => sub.done?.call();
    auth = make();
    await drain();
    expect(firebase.stream.subscriptions.last.cancelled, 1);
    hidden(access: SellerAccess.noApplication);
    firebase.stream.onListen = null;
    final count = firebase.stream.subscriptions.length;
    await auth.refresh();
    await drain();
    expect(firebase.stream.subscriptions, hasLength(count + 1));
    expect(auth.access, SellerAccess.approved);
  });
  test('superseded auth callback performs no foreign reads', () async {
    firebase.uid = 'owner_b';
    firebase.stream.subscriptions.single.data?.call(_User('owner_a'));
    await drain();
    expect(reads, isEmpty);
    hidden();
  });
  test('disposed refresh and callbacks never dispatch reads', () async {
    final old = firebase.stream.subscriptions.single;
    auth.dispose();
    disposed = true;
    await auth.refresh();
    old.data?.call(_User('owner_a'));
    await drain();
    expect(reads, isEmpty);
    expect(old.cancelled, 1);
    hidden(access: SellerAccess.signedOut);
  });
  test('reentrant SDK change on loading prevents initial profile dispatch',
      () async {
    auth.addListener(() {
      if (auth.access == SellerAccess.loading) firebase.uid = 'owner_b';
    });
    firebase.emit('owner_a');
    await drain();
    expect(reads, isEmpty);
    hidden();
  });
  test('reentrant SDK change on approval prevents token dispatch', () async {
    auth.addListener(() {
      if (auth.access == SellerAccess.approved) firebase.uid = 'owner_b';
    });
    firebase.emit('owner_a');
    await drain();
    expect(tokenReads, 0);
    expect(writes, isEmpty);
    hidden();
  });
  test('signed-out event clears profile and ignores late previous read',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? pending.future : approved(path);
    firebase.emit('owner_a');
    await drain();
    firebase.emit(null);
    pending.complete(approved('users/owner_a'));
    await drain();
    hidden(access: SellerAccess.signedOut);
    expect(auth.signedInPhone, isNull);
    expect(writes, isEmpty);
  });
  test('preview preserves frozen approval and phone without SDK transport',
      () async {
    final preview = SellerAuthProvider.preview(
        access: SellerAccess.approved,
        phone: 'preview-phone',
        error: SellerAuthError.rateLimited,
        pendingPhone: 'pending-phone',
        testOtp: 'fixture');
    await preview.refresh();
    expect(preview.access, SellerAccess.approved);
    expect(preview.signedInPhone, 'preview-phone');
    expect(preview.lastError, SellerAuthError.rateLimited);
    expect(preview.testOtp, 'fixture');
    expect(preview.pendingPhone, 'pending-phone');
    expect(reads, isEmpty);
    expect(writes, isEmpty);
    preview.dispose();
  });
}
