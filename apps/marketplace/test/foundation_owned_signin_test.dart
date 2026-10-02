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
// Official platform fixture; no persistence reaches the device.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

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

class _Auth implements AuthService {
  String? uid;
  final stream = _Stream();
  final replies = <Completer<UserModel>>[];
  Future<UserModel> Function(String)? profileRead;
  String role = 'user';
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => stream;
  @override
  Future<UserModel> getUserData(String uid) =>
      profileRead?.call(uid) ?? Future.value(_profile(uid, role: role));
  Future<UserModel> _login() {
    final reply = Completer<UserModel>();
    replies.add(reply);
    return reply.future.timeout(const Duration(seconds: 2));
  }

  @override
  Future<UserModel> signInWithEmail(
          {required String email, required String password}) =>
      _login();
  @override
  Future<UserModel> signInWithGoogle() => _login();
  @override
  Future<UserModel> registerWithEmail(
          {required String email,
          required String password,
          required String name,
          String? phone}) =>
      _login();
  @override
  Future<UserModel> signInWithLinkedGoogleCredential(
          PendingGoogleIdentity pending,
          {String? expectedUid}) =>
      _login();
  @override
  Future<PhoneAuthResult> verifyPhoneOTP(
          {required String phone, required String otp, String? name}) async =>
      PhoneAuthResult(user: await _login(), isNewUser: true);
  void emit(String? owner) {
    uid = owner;
    stream.subscriptions.last.data?.call(owner == null ? null : _User(owner));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends SharedPreferencesStorePlatform {
  Completer<void>? readHold;
  Completer<void>? writeHold;
  Completer<void>? removeHold;
  Map<String, Object> initial = {};
  final removals = <String>[];
  final entered = Completer<void>();
  final writes = <String>[];
  @override
  Future<Map<String, Object>> getAll() async {
    if (readHold != null) {
      entered.complete();
      await readHold!.future;
    }
    return initial;
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes.add(key);
    if (writeHold != null && type == 'String') {
      entered.complete();
      await writeHold!.future;
    }
    return true;
  }

  @override
  Future<bool> clear() async => true;
  @override
  Future<bool> remove(String key) async {
    removals.add(key);
    if (removeHold != null) {
      entered.complete();
      await removeHold!.future;
    }
    return true;
  }
}

UserModel _profile(String uid, {String role = 'user'}) => UserModel(
    uid: uid,
    email: '$uid@example.invalid',
    name: uid,
    role: role,
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
  Completer<void>? tokenHold;
  late Completer<void> tokenEntered;
  late List<String> tokenWrites;
  var disposed = false;
  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  final pending = PendingGoogleIdentity(
      credential:
          const AuthCredential(providerId: 'fixture', signInMethod: 'fixture'),
      idToken: 'local-fixture');
  Future<bool> login(String method) => switch (method) {
        'email' => auth.signInWithEmail(
            email: 'owner_a@example.invalid', password: 'fixture-password'),
        'google' => auth.signInWithGoogle(),
        'phone' =>
          auth.verifyPhoneOTP(phone: '+910000000000', otp: 'local-fixture'),
        'linked' =>
          auth.signInWithLinkedGoogle(pending, expectedUid: 'owner_a'),
        'register' => auth.registerWithEmail(
            email: 'owner_a@example.invalid',
            password: 'fixture-password',
            name: 'Fixture'),
        _ => throw StateError('Unknown fixture method'),
      };
  void invalidate(String scenario) {
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
    }
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'remember_email': 'untouched@example.invalid'});
    service = _Auth();
    disposed = false;
    audits = [];
    auditHold = null;
    tokenHold = null;
    tokenEntered = Completer<void>();
    tokenWrites = [];
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_messaging'),
        (call) async {
      if (call.method == 'Messaging#getToken') {
        if (!tokenEntered.isCompleted) { tokenEntered.complete(); }
        await tokenHold?.future.timeout(const Duration(seconds: 2));
        return {'token': 'local-fixture-token'};
      }
      return null;
    });
    messenger.setMockMessageHandler(
        updateChannel,
        (message) async =>
            fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]));
    messenger.setMockMessageHandler(setChannel, (message) async {
      final args = const _WriteRequestCodec().decodeMessage(message) as List;
      final request = args[1] as fs.DocumentReferenceRequest;
      if (request.data?.containsKey('fcmTokens') == true) {
        tokenWrites.add(request.path);
      }
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
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_messaging'), null);
  });
  for (final method in ['email', 'google', 'phone', 'linked', 'register']) {
    test('$method invalidated login releases guard for a fresh retry',
        () async {
      final old = login(method);
      service.emit('owner_a');
      service.emit('owner_a');
      service.replies.single.complete(_profile('owner_a'));
      expect(await old, isFalse);
      service.emit(null);
      await drain();
      final retry = login(method);
      service.emit('owner_b');
      expect(service.replies.length, 2);
      service.replies.last.complete(_profile('owner_b'));
      expect(await retry, isTrue);
      expect(auth.userUid, 'owner_b');
    });
    test('$method account switch suppresses held failure audit completion',
        () async {
      auditHold = Completer<void>();
      final result = login(method);
      service.replies.single
          .completeError(AuthException('fixture private provider detail'));
      await drain();
      expect(audits.length, 1);
      service.emit('owner_b');
      await drain();
      final user = auth.currentUser;
      auditHold!.complete();
      expect(await result, isFalse);
      expect(auth.currentUser, same(user));
      expect(auth.error, isNull);
      expect(auth.isLoading, isFalse);
    });
    test('$method current buyer succeeds with captured audit identity',
        () async {
      final result = login(method);
      service.emit('owner_a');
      service.replies.single.complete(_profile('owner_a'));
      expect(await result, isTrue);
      expect(auth.isBuyer, isTrue);
      expect(auth.userUid, 'owner_a');
      expect(tokenWrites, ['users/owner_a']);
      expect(auth.isNewUser, method == 'phone');
      expect(audits.single['uid'], 'owner_a');
      expect(auth.isLoading, isFalse);
    });
    for (final scenario in ['renew', 'return', 'dispose', 'paused']) {
      test('$method $scenario suppresses late successful result', () async {
        final result = login(method);
        service.emit('owner_a');
        await drain();
        if (scenario == 'return') {
          service.emit('owner_b');
          service.emit('owner_a');
        } else {
          invalidate(scenario);
        }
        await drain();
        final user = auth.currentUser;
        final error = auth.error;
        service.replies.single.complete(_profile('owner_a'));
        expect(await result, isFalse);
        expect(auth.currentUser, same(user));
        expect(auth.error, error);
        expect(audits, isEmpty);
      });
    }
    test('$method cold-start null callback then own login remains usable',
        () async {
      final result = login(method);
      service.emit(null);
      service.emit('owner_a');
      service.replies.single.complete(_profile('owner_a'));
      expect(await result, isTrue);
      expect(auth.isBuyer, isTrue);
    });
    for (final role in ['admin', 'user']) {
      test('$method stale $role result cannot replace or sign out new account',
          () async {
        final result = login(method);
        service.emit('owner_b');
        await drain();
        final fresh = auth.currentUser;
        service.replies.single.complete(_profile('owner_a', role: role));
        expect(await result, isFalse);
        expect(auth.currentUser, same(fresh));
        expect(auth.userUid, 'owner_b');
        expect(audits, isEmpty);
      });
    }
    test(
        '$method uses current buyer profile rather than stale returned admin role',
        () async {
      final result = login(method);
      service.emit('owner_a');
      service.replies.single.complete(_profile('owner_a', role: 'admin'));
      expect(await result, isTrue);
      expect(auth.isBuyer, isTrue);
    });
    test('$method wrong fresh profile owner is rejected', () async {
      final result = login(method);
      service.uid = 'owner_a';
      service.profileRead = (_) async => _profile('owner_b');
      service.replies.single.complete(_profile('owner_a'));
      expect(await result, isFalse);
      expect(auth.currentUser, isNull);
      expect(audits, isEmpty);
    });
    for (final scenario in [
      'switch',
      'sdk-switch',
      'renew',
      'dispose',
      'paused'
    ]) {
      test('$method $scenario suppresses late failure', () async {
        final result = login(method);
        invalidate(scenario);
        await drain();
        final error = auth.error;
        final user = auth.currentUser;
        service.replies.single
            .completeError(AuthException('fixture private provider detail'));
        expect(await result, isFalse);
        expect(auth.error, error);
        expect(auth.currentUser, same(user));
        expect(audits, isEmpty);
        expect(auth.isLocked, isFalse);
      });
    }
    for (final scenario in ['switch', 'renew', 'dispose', 'paused']) {
      test(
          '$method $scenario invalidates held audit completion and preference write',
          () async {
        auth.setRememberMe(true);
        auditHold = Completer<void>();
        final result = login(method);
        service.emit('owner_a');
        service.replies.single.complete(_profile('owner_a'));
        await drain();
        expect(audits.length, 1);
        expect(audits.single['uid'], 'owner_a');
        invalidate(scenario);
        await drain();
        final user = auth.currentUser;
        auditHold!.complete();
        expect(await result, isFalse);
        expect(auth.currentUser, same(user));
        expect(
            (await SharedPreferences.getInstance()).getString('remember_email'),
            'untouched@example.invalid');
      });
    }
    test('$method newer profile read supersedes pending login profile',
        () async {
      final pending = Completer<UserModel>();
      final result = login(method);
      service.uid = 'owner_a';
      service.profileRead = (_) => pending.future;
      service.replies.single.complete(_profile('owner_a'));
      await drain();
      service.profileRead =
          (_) async => _profile('owner_a').copyWith(name: 'fresh intent');
      await auth.refreshUserData();
      pending.complete(_profile('owner_a'));
      expect(await result, isFalse);
      expect(auth.currentUser?.name, 'fresh intent');
      expect(audits, isEmpty);
    });
    for (final kind in ['auth', 'generic', 'firebase']) {
      test('$method owned $kind failure keeps safe feedback and audit',
          () async {
        final result = login(method);
        final Object failure = kind == 'auth'
            ? AuthException('fixture private provider detail')
            : kind == 'firebase'
                ? FirebaseAuthException(
                    code: 'invalid-credential',
                    message: 'fixture private provider detail')
                : StateError('fixture private provider detail');
        service.replies.single.completeError(failure);
        expect(await result, isFalse);
        expect(auth.error, isNot(contains('private provider')));
        expect(audits.single['error'], isNot(contains('private provider')));
        expect(auth.isLoading, isFalse);
      });
    }
    for (final scenario in ['dispose', 'paused']) {
      test('$method $scenario refuses initial dispatch', () async {
        invalidate(scenario);
        final error = auth.error;
        expect(await login(method), isFalse);
        expect(service.replies, isEmpty);
        expect(auth.error, error);
      });
    }
  }
  for (final first in ['email', 'google', 'phone', 'linked', 'register']) {
    for (final second in ['email', 'google', 'phone', 'linked', 'register']) {
      test('duplicate $first/$second dispatches only once', () async {
        final result = login(first);
        final duplicate = login(second);
        await drain();
        final count = service.replies.length;
        for (final reply in service.replies) {
          reply.complete(_profile('owner_a'));
        }
        service.emit('owner_a');
        final secondResult = await duplicate;
        await result;
        expect(count, 1);
        expect(secondResult, isFalse);
      });
    }
  }
  for (final stage in ['read', 'write']) {
    test('email $stage preference boundary cannot continue a renewed session',
        () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _Preferences();
      final hold = Completer<void>();
      if (stage == 'read') {
        SharedPreferences.setMockInitialValues({});
        store.readHold = hold;
      } else {
        store.writeHold = hold;
      }
      SharedPreferencesStorePlatform.instance = store;
      try {
        auth.setRememberMe(true);
        final result = login('email');
        service.emit('owner_a');
        service.replies.single.complete(_profile('owner_a'));
        await store.entered.future.timeout(const Duration(seconds: 2));
        service.emit('owner_a');
        await drain();
        hold.complete();
        expect(await result, isFalse);
        expect(store.writes,
            stage == 'read' ? isEmpty : ['flutter.remember_email']);
      } finally {
        if (!hold.isCompleted) {
          hold.complete();
        }
        SharedPreferencesStorePlatform.instance = previous;
      }
    });
  }
  test('current email remembers email only after confirmed buyer', () async {
    auth.setRememberMe(true);
    final result = login('email');
    service.emit('owner_a');
    service.replies.single.complete(_profile('owner_a'));
    expect(await result, isTrue);
    expect((await SharedPreferences.getInstance()).getString('remember_email'),
        'owner_a@example.invalid');
  });

  for (final method in ['email', 'google', 'phone', 'linked', 'register']) {
    for (final scenario in ['switch', 'renew', 'dispose', 'paused']) {
      test(
          '$method delayed token $scenario cannot write or complete old sign-in',
          () async {
        tokenHold = Completer<void>();
        final result = login(method);
        service.emit('owner_a');
        service.replies.single.complete(_profile('owner_a'));
        await tokenEntered.future.timeout(const Duration(seconds: 2));
        invalidate(scenario);
        await drain();
        final user = auth.currentUser;
        tokenHold!.complete();
        expect(await result, isFalse);
        expect(tokenWrites, isEmpty);
        expect(auth.currentUser, same(user));
      });
    }
  }
  test('phone TIMEOUT retains safe code and does not count lockout attempts',
      () async {
    for (var i = 0; i < 6; i++) {
      final result = login('phone');
      service.replies.last.completeError(
          AuthException('private transport detail', code: 'TIMEOUT'));
      expect(await result, isFalse);
      expect(auth.errorCode, 'TIMEOUT');
      expect(auth.error, isNot(contains('private')));
      expect(auth.isLocked, isFalse);
    }
  });
}
