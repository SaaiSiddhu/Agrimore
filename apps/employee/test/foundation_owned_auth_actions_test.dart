@TestOn('vm')
library;

import 'dart:async';
import 'package:employee/providers/auth_provider.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show User, FirebaseAuth, UserCredential, FirebaseAuthException;
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

class _Credential implements UserCredential {
  _Credential(String uid) : user = _User(uid);
  @override
  final User? user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firebase implements FirebaseAuth {
  String? uid = 'owner_a';
  String resultUid = 'signed_in';
  bool publishSDK = true, rawWithoutEvent = false;
  String? password;
  Object? failure;
  Future<void> Function(String)? hold;
  final stream = _Stream();
  final calls = <String>[], signouts = <String?>[];
  Future<void> request(String stage) async {
    calls.add(stage);
    await hold?.call(stage);
    if (failure != null) throw failure!;
  }

  Future<void> establish() async {
    if (rawWithoutEvent) uid = 'signed_in';
    if (publishSDK) emit('signed_in');
    await request('credential');
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    this.password = password;
    await request('email');
    await establish();
    return _Credential(resultUid);
  }

  @override
  Future<void> signOut() async {
    final owner = uid;
    signouts.add(owner);
    await request('signout');
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
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Service implements AuthService {
  _Service(this.firebase);
  final _Firebase firebase;
  Future<void> request(String stage) => firebase.request(stage);
  @override
  Future<PhoneOtpSendResult> sendPhoneOTP(String phone,
      {String channel = 'sms'}) async {
    await request('send');
    return PhoneOtpSendResult(
        userExists: true, channel: 'voice', testOtp: '123456');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => request('reset');
  @override
  Future<PhoneAuthResult> verifyPhoneOTP(
      {required String phone, required String otp, String? name}) async {
    await request('phone');
    await firebase.establish();
    return PhoneAuthResult(
        user: UserModel(
            uid: firebase.resultUid,
            email: 'fixture@example.invalid',
            name: 'Server',
            role: 'employee',
            createdAt: DateTime(2026)),
        isNewUser: true);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const documents = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const updates =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate';
  const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Firebase firebase;
  late EmployeeAuthProvider auth;
  late List<String> reads, writes;
  String role = 'employee', status = 'approved';
  bool missingUser = false, missingEmployee = false, disposed = false;
  Future<void> Function(String)? hold;
  Future<void> drain() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Object?> act(String method) async {
    try {
      return switch (method) {
        'email' => await auth.signIn('fixture@example.invalid', ' password '),
        'phone' => await auth.verifyPhoneOtpAndSignIn(
            phone: '+919999999999', otp: '123456'),
        'send' => await auth.sendPhoneOtp('+919999999999', channel: 'sms'),
        _ => await auth.sendPasswordReset('fixture@example.invalid'),
      };
    } catch (e) {
      return e;
    }
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    disposed = false;
    role = 'employee';
    status = 'approved';
    missingUser = false;
    missingEmployee = false;
    hold = null;
    reads = [];
    writes = [];
    firebase = _Firebase();
    firebase.hold = (stage) async => hold?.call(stage);
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      reads.add(r.path);
      await hold?.call(r.path.startsWith('users/') ? 'user' : 'approval');
      final isUser = r.path.startsWith('users/');
      return [
        fs.PigeonDocumentSnapshot(
            path: r.path,
            data: (isUser ? missingUser : missingEmployee)
                ? null
                : isUser
                    ? {
                        'name': 'Server',
                        'role': role,
                        'email': 'fixture@example.invalid'
                      }
                    : {'status': status},
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
    });
    messenger.setMockMessageHandler(updates, (message) async {
      final r = (const _WriteRequestCodec().decodeMessage(message)! as List)[1]
          as fs.DocumentReferenceRequest;
      writes.add(r.path);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMethodCallHandler(messaging, (call) async {
      if (call.method == 'Messaging#getToken') {
        await hold?.call('token');
        return {'token': null};
      }
      return null;
    });
    auth = EmployeeAuthProvider(
        firebaseAuth: firebase, authService: _Service(firebase));
    firebase.emit('owner_a');
    await drain();
    firebase.calls.clear();
    reads.clear();
    writes.clear();
  });
  tearDown(() async {
    hold = null;
    if (!disposed) auth.dispose();
    await drain();
    expect(
        firebase.stream.subscriptions.every((s) => s.cancelled == 1), isTrue);
    messenger.setMockDecodedMessageHandler<Object?>(documents, null);
    messenger.setMockMessageHandler(updates, null);
    messenger.setMockMethodCallHandler(messaging, null);
  });
  const methods = ['email', 'phone', 'send', 'reset'];
  for (final method in methods) {
    test('$method valid current command preserves result', () async {
      final result = await act(method);
      await drain();
      if (method == 'send') {
        expect((result as PhoneOtpSendResult).channel, 'voice');
        expect(result.testOtp, '123456');
      } else {
        expect(result, isTrue);
      }
      expect(auth.isLoading, isFalse);
      if (method == 'email') {
        expect(firebase.password, ' password ');
      }
    });
    for (final change in [
      'switch',
      'renew',
      'return',
      'error',
      'done',
      'dispose'
    ]) {
      for (final fail in [false, true]) {
        test(
            '$method held ${fail ? 'failure' : 'success'} after $change cannot publish old result',
            () async {
          final entered = Completer<void>(), release = Completer<void>();
          var held = false;
          firebase.publishSDK = false;
          hold = (stage) async {
            if (!held) {
              held = true;
              entered.complete();
              await release.future;
            }
          };
          final pending = act(method);
          try {
            await entered.future.timeout(const Duration(seconds: 3));
            if (change == 'dispose') {
              auth.dispose();
              disposed = true;
            } else if (change == 'error') {
              firebase.stream.subscriptions.last.error
                  ?.call(StateError('fixture'));
            } else if (change == 'done') {
              firebase.stream.subscriptions.last.done?.call();
            } else if (change == 'renew') {
              firebase.emit('owner_a');
            } else {
              firebase.emit('new_owner');
              if (change == 'return') firebase.emit('owner_a');
            }
            await drain();
            // The SDK fixture completes its already-dispatched credential
            // operation after release; that is not a second provider command.
            final count =
                firebase.calls.where((stage) => stage != 'credential').length;
            if (fail) {
              firebase.failure = method == 'email'
                  ? FirebaseAuthException(
                      code: 'wrong-password', message: 'PRIVATE_DIAGNOSTIC')
                  : AuthException('PRIVATE_DIAGNOSTIC');
            }
            release.complete();
            expect(await pending, method == 'send' ? isNull : isFalse);
            expect(
                firebase.calls.where((stage) => stage != 'credential').length,
                count);
            expect(auth.error, isNot(contains('PRIVATE_DIAGNOSTIC')));
            if (change == 'switch' || change == 'renew' || change == 'return') {
              expect(auth.isAuthenticated, isTrue);
            }
          } finally {
            if (!release.isCompleted) release.complete();
            await pending;
          }
        });
      }
    }
    for (final second in methods) {
      test('$method excludes concurrent $second', () async {
        final entered = Completer<void>(), release = Completer<void>();
        var held = false;
        hold = (_) async {
          if (!held) {
            held = true;
            entered.complete();
            await release.future;
          }
        };
        final pending = act(method);
        try {
          await entered.future.timeout(const Duration(seconds: 3));
          final count = firebase.calls.length;
          await act(second);
          expect(firebase.calls.length, count);
          expect(auth.isLoading, isTrue);
        } finally {
          release.complete();
          await pending;
        }
      });
    }
    test('$method excludes explicit logout while command is pending', () async {
      final entered = Completer<void>(), release = Completer<void>();
      var held = false;
      hold = (_) async {
        if (!held) {
          held = true;
          entered.complete();
          await release.future;
        }
      };
      final pending = act(method);
      try {
        await entered.future.timeout(const Duration(seconds: 3));
        await auth.signOut();
        expect(firebase.signouts, isEmpty);
      } finally {
        release.complete();
        await pending;
      }
    });
  }
  for (final method in ['email', 'phone']) {
    for (final outcome in [
      'approved',
      'pending',
      'suspended',
      'nonassociate',
      'missingUser',
      'missingEmployee'
    ]) {
      test('$method preserves owned $outcome gate', () async {
        status = outcome;
        role = outcome == 'nonassociate' ? 'user' : 'employee';
        missingUser = outcome == 'missingUser';
        missingEmployee = outcome == 'missingEmployee';
        final result = await act(method);
        await drain();
        final refusal = ['nonassociate', 'missingUser', 'missingEmployee']
            .contains(outcome);
        expect(result, method == 'phone' || !refusal ? isTrue : isFalse);
        expect(auth.isAuthenticated, outcome == 'approved');
        if (refusal) {
          expect(firebase.uid, isNull);
          expect(auth.error, isNotNull);
          expect(firebase.signouts, ['signed_in']);
        } else {
          expect(auth.user?.uid, 'signed_in');
        }
      });
    }
    test(
        '$method refusal waits for the matching signin result before SDK logout',
        () async {
      role = 'user';
      final entered = Completer<void>(), release = Completer<void>();
      hold = (stage) async {
        if (stage == 'credential') {
          entered.complete();
          await release.future;
        }
      };
      final pending = act(method);
      try {
        await entered.future.timeout(const Duration(seconds: 3));
        await drain();
        expect(firebase.signouts, isEmpty);
        release.complete();
        expect(await pending, method == 'phone' ? isTrue : isFalse);
        await drain();
        expect(firebase.signouts, ['signed_in']);
        expect(auth.isAuthenticated, isFalse);
      } finally {
        if (!release.isCompleted) release.complete();
        await pending;
      }
    });
    test('$method mismatched result cannot claim the current account',
        () async {
      firebase.resultUid = 'different';
      expect(await act(method), isFalse);
      await drain();
      expect(auth.user?.uid, 'signed_in');
      expect(firebase.uid, 'signed_in');
      expect(firebase.signouts, isEmpty);
    });
    for (final stage in ['user', 'approval', 'token']) {
      for (final change in ['switch', 'renew', 'return']) {
        test('$method held $stage rejects $change after SDK authentication',
            () async {
          final entered = Completer<void>(), release = Completer<void>();
          var held = false;
          hold = (where) async {
            if (where == stage && !held) {
              held = true;
              entered.complete();
              await release.future;
            }
          };
          final pending = act(method);
          try {
            await entered.future.timeout(const Duration(seconds: 3));
            final owner = firebase.uid;
            firebase.emit(change == 'renew' ? owner : 'new_owner');
            if (change == 'return') firebase.emit(owner);
            await drain();
            final count = writes.length;
            release.complete();
            expect(await pending, isFalse);
            expect(writes.length, count);
            expect(firebase.signouts, isEmpty);
          } finally {
            if (!release.isCompleted) release.complete();
            await pending;
          }
        });
      }
    }
  }
  test('current SDK error and reset errors use safe feedback', () async {
    firebase.failure = FirebaseAuthException(
        code: 'unknown-fixture', message: 'PRIVATE_DIAGNOSTIC');
    expect(await act('email'), isFalse);
    expect(auth.error, isNot(contains('PRIVATE_DIAGNOSTIC')));
  });
  test('known and unknown reset addresses are indistinguishable', () async {
    firebase.failure = UserNotFoundException('PRIVATE_DIAGNOSTIC');
    expect(await act('reset'), isTrue);
    expect(auth.error, isNull);
  });
  test('OTP throttling keeps retry metadata and unavailable copy is safe',
      () async {
    firebase.failure =
        PhoneOtpRateLimitException('PRIVATE_DIAGNOSTIC', retryAfterMs: 45000);
    expect(await act('send'), isNull);
    expect(
        auth.error, 'Too many verification requests. Please try again later.');
    expect(auth.error, isNot(contains('PRIVATE_DIAGNOSTIC')));
    expect(auth.retryAfterMs, 45000);
    firebase.failure = PhoneOtpUnavailableException('PRIVATE_DIAGNOSTIC');
    expect(await act('send'), isNull);
    expect(auth.error,
        'Phone verification is currently unavailable. Please try again later.');
    expect(auth.error, isNot(contains('PRIVATE_DIAGNOSTIC')));
  });
}
