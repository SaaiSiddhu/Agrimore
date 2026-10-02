@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show User, FirebaseAuth, AuthCredential;
import 'package:firebase_core/firebase_core.dart';
// Official cached platform harness; all transports use local fixtures.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

final _pendingGoogle = PendingGoogleIdentity(
    credential:
        const AuthCredential(providerId: 'fixture', signInMethod: 'fixture'),
    idToken: 'fixture');
UserModel _profile(String uid) => UserModel(
    uid: uid,
    email: '$uid@example.invalid',
    name: 'Server',
    role: 'seller',
    createdAt: DateTime(2026));

class _Service implements AuthService {
  _Service(this.firebase);
  final _Firebase firebase;
  final calls = <String>[];
  Future<void> Function(String)? hold;
  bool publishSDK = true, linked = false, linkResult = true;
  Object? failure;
  bool rawSdkWithoutEvent = false;
  String? email, password;
  String resultUid = 'signed_in';
  Future<void> request(String stage) async {
    calls.add(stage);
    await hold?.call(stage);
    if (failure != null) throw failure!;
  }

  @override
  Future<PhoneOtpSendResult> sendPhoneOTP(String phone,
      {String channel = 'sms'}) async {
    await request('send');
    return PhoneOtpSendResult(
        userExists: true, channel: 'voice', testOtp: '123456');
  }

  @override
  Future<PhoneAuthResult> verifyPhoneOTP(
      {required String phone, required String otp, String? name}) async {
    await request('verify');
    if (rawSdkWithoutEvent) firebase.uid = 'signed_in';
    if (publishSDK) firebase.emit('signed_in');
    return PhoneAuthResult(user: _profile(resultUid), isNewUser: true);
  }

  @override
  Future<PendingGoogleIdentity?> acquireGoogleCredential() async {
    await request('acquire');
    return _pendingGoogle;
  }

  @override
  Future<GoogleIdentityResolution> resolveGoogleIdentity(
      PendingGoogleIdentity pending) async {
    await request('resolve');
    return GoogleIdentityResolution(linked: linked, expectedUid: 'signed_in');
  }

  @override
  Future<UserModel> signInWithLinkedGoogleCredential(
      PendingGoogleIdentity pending,
      {String? expectedUid}) async {
    await request('linked');
    if (rawSdkWithoutEvent) firebase.uid = 'signed_in';
    if (publishSDK) firebase.emit('signed_in');
    return _profile(resultUid);
  }

  @override
  Future<bool> linkPendingGoogleCredential(
      PendingGoogleIdentity pending) async {
    await request('link');
    return linkResult;
  }

  @override
  Future<UserModel> signInWithEmail(
      {required String email, required String password}) async {
    this.email = email;
    this.password = password;
    await request('email');
    if (rawSdkWithoutEvent) firebase.uid = 'signed_in';
    if (publishSDK) firebase.emit('signed_in');
    return _profile(resultUid);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => request('reset');
  @override
  Future<void> signOut() async {
    final owner = firebase.uid;
    await request('signout');
    if (publishSDK && firebase.uid == owner) firebase.emit(null);
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
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Firebase firebase;
  late _Service service;
  late SellerAuthProvider auth;
  var disposed = false;
  Future<void> drain() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Object?> act(String method) async {
    try {
      return switch (method) {
        'send' => await auth.sendOtp('+919999999999', channel: 'sms'),
        'verify' => await auth.verifyOtp('123456'),
        'google' => await auth.continueWithGoogle(),
        'email' =>
          await auth.signInWithEmail(' mixed@example.invalid ', ' password '),
        'reset' => await auth.sendPasswordReset('mixed@example.invalid'),
        _ => await (() async {
            await auth.signOut();
            return null;
          })(),
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
    firebase = _Firebase();
    service = _Service(firebase);
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      return [
        fs.PigeonDocumentSnapshot(
            path: r.path,
            data: r.path.startsWith('users/')
                ? {
                    'name': 'Server',
                    'role': 'seller',
                    'email': 'fixture@example.invalid'
                  }
                : r.path.startsWith('sellers/')
                    ? {'status': 'approved'}
                    : null,
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
    });
    auth = SellerAuthProvider(
        authService: service,
        firebaseAuth: firebase,
        readPushToken: () async => null,
        savePendingPushToken: (_) async {});
    firebase.emit('owner_a');
    await drain();
    expect(await auth.sendOtp('+919999999999'), isTrue);
    service.calls.clear();
  });
  tearDown(() async {
    if (!disposed) auth.dispose();
    await drain();
    expect(
        firebase.stream.subscriptions.every((s) => s.cancelled == 1), isTrue);
    messenger.setMockDecodedMessageHandler<Object?>(documents, null);
  });
  const methods = ['send', 'verify', 'google', 'email', 'reset', 'signout'];
  for (final method in methods) {
    test('$method valid current command preserves expected result', () async {
      final result = await act(method);
      await drain();
      expect(
          result,
          method == 'signout'
              ? isNull
              : method == 'google'
                  ? isFalse
                  : isTrue);
      expect(auth.isBusy, isFalse);
      if (method == 'send') {
        expect(auth.otpChannel, 'voice');
        expect(auth.testOtp, '123456');
      }
      if (method == 'email') {
        expect(service.password, ' password ');
      }
    });
    for (final change in [
      'switch',
      'renew',
      'return',
      'error',
      'done',
      'dispose',
      'reset'
    ]) {
      for (final fail in [false, true]) {
        test(
            '$method late ${fail ? 'failure' : 'success'} after $change cannot publish old state',
            () async {
          final entered = Completer<void>(), release = Completer<void>();
          var held = false;
          service.publishSDK = false;
          service.hold = (_) async {
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
            } else if (change == 'reset') {
              auth.resetOtp();
              auth.cancelGoogleLink();
            } else if (change == 'renew') {
              firebase.emit('owner_a');
            } else {
              firebase.emit('new_owner');
              if (change == 'return') firebase.emit('owner_a');
            }
            await drain();
            final count = service.calls.length;
            if (fail) service.failure = AuthException('PRIVATE_DIAGNOSTIC');
            release.complete();
            final result = await pending;
            await drain();
            if (method != 'signout') expect(result, isFalse);
            expect(service.calls.length, count);
            expect(auth.pendingGoogle, isNull);
            expect(auth.pendingPhone, isNull);
            expect(auth.testOtp, isNull);
            expect(auth.lastErrorMessage, isNull);
            expect(auth.isBusy, isFalse);
          } finally {
            if (!release.isCompleted) release.complete();
            await pending;
          }
        });
      }
    }
    for (final second in methods) {
      test('$method excludes concurrent $second command', () async {
        final entered = Completer<void>(), release = Completer<void>();
        var held = false;
        service.hold = (_) async {
          if (!held) {
            held = true;
            entered.complete();
            await release.future;
          }
        };
        final pending = act(method);
        try {
          await entered.future.timeout(const Duration(seconds: 3));
          final count = service.calls.length;
          await act(second);
          expect(service.calls.length, count);
          expect(auth.isBusy, isTrue);
        } finally {
          release.complete();
          await pending;
        }
        expect(auth.isBusy, isFalse);
      });
    }
  }
  test('linked Google resolves and signs in without retaining credentials',
      () async {
    service.linked = true;
    expect(await act('google'), isTrue);
    expect(service.calls, ['acquire', 'resolve', 'linked']);
    expect(auth.pendingGoogle, isNull);
  });
  for (final conflict in [false, true]) {
    test('phone verified with pending Google preserves link outcome $conflict',
        () async {
      expect(await act('google'), isFalse);
      service.linkResult = !conflict;
      expect(await act('verify'), isTrue);
      expect(service.calls.contains('link'), isTrue);
      expect(auth.googleLinkConflict, conflict);
      expect(auth.pendingGoogle, isNull);
    });
  }
  test('raw SDK owner mismatch hides pending phone and Google before callback',
      () async {
    await act('google');
    firebase.uid = 'new_owner';
    expect(auth.pendingPhone, isNull);
    expect(auth.pendingGoogle, isNull);
    expect(auth.testOtp, isNull);
  });
  test('retired completion cannot release a replacement command spinner',
      () async {
    final oldEntered = Completer<void>(), oldRelease = Completer<void>();
    final newEntered = Completer<void>(), newRelease = Completer<void>();
    var count = 0;
    service.hold = (_) async {
      count++;
      if (count == 1) {
        oldEntered.complete();
        await oldRelease.future;
      } else if (count == 2) {
        newEntered.complete();
        await newRelease.future;
      }
    };
    final old = act('send');
    await oldEntered.future;
    auth.resetOtp();
    final fresh = act('send');
    await newEntered.future;
    try {
      oldRelease.complete();
      expect(await old, isFalse);
      expect(auth.isBusy, isTrue);
      newRelease.complete();
      expect(await fresh, isTrue);
      expect(auth.isBusy, isFalse);
    } finally {
      if (!oldRelease.isCompleted) oldRelease.complete();
      if (!newRelease.isCompleted) newRelease.complete();
      await old;
      await fresh;
    }
  });
  for (final stage in ['resolve', 'linked', 'link']) {
    for (final change in [
      'switch',
      'renew',
      'return',
      'error',
      'done',
      'dispose'
    ]) {
      test('$stage later-stage $change cannot continue old command', () async {
        if (stage == 'link') {
          expect(await act('google'), isFalse);
        }
        service.linked = stage == 'linked';
        final entered = Completer<void>(), release = Completer<void>();
        service.hold = (where) async {
          if (where == stage) {
            entered.complete();
            await release.future;
          }
        };
        final pending = act(stage == 'link' ? 'verify' : 'google');
        try {
          await entered.future.timeout(const Duration(seconds: 3));
          final owner = firebase.uid;
          if (change == 'dispose') {
            auth.dispose();
            disposed = true;
          } else if (change == 'error') {
            firebase.stream.subscriptions.last.error
                ?.call(StateError('fixture'));
          } else if (change == 'done') {
            firebase.stream.subscriptions.last.done?.call();
          } else if (change == 'renew') {
            firebase.emit(owner);
          } else {
            firebase.emit('new_owner');
            if (change == 'return') firebase.emit(owner);
          }
          final calls = service.calls.length;
          release.complete();
          expect(await pending, isFalse);
          expect(service.calls.length, calls);
          expect(auth.pendingGoogle, isNull);
          expect(auth.lastErrorMessage, isNull);
        } finally {
          if (!release.isCompleted) release.complete();
          await pending;
        }
      });
    }
  }
  test(
      'queued foreign callback before first intended event revokes confirmed phone link',
      () async {
    await act('google');
    service.publishSDK = false;
    service.rawSdkWithoutEvent = true;
    final entered = Completer<void>(), release = Completer<void>();
    service.hold = (where) async {
      if (where == 'link') {
        entered.complete();
        await release.future;
      }
    };
    final pending = act('verify');
    try {
      await entered.future.timeout(const Duration(seconds: 3));
      firebase.stream.subscriptions.last.data?.call(_User('foreign'));
      firebase.stream.subscriptions.last.data?.call(firebase.currentUser);
      release.complete();
      expect(await pending, isFalse);
      expect(auth.lastErrorMessage, isNull);
    } finally {
      if (!release.isCompleted) release.complete();
      await pending;
    }
  });
  test('failed Google attachment preserves confirmed current phone sign-in',
      () async {
    await act('google');
    service.hold = (stage) async {
      if (stage == 'link') throw StateError('fixture');
    };
    expect(await act('verify'), isTrue);
    expect(auth.googleLinkConflict, isTrue);
    expect(firebase.uid, 'signed_in');
  });
  for (final method in ['verify', 'email', 'google']) {
    test('$method mismatched result UID cannot claim the current SDK account',
        () async {
      service.linked = true;
      service.resultUid = 'different';
      expect(await act(method), isFalse);
      await drain();
      expect(auth.currentUser?.uid, 'signed_in');
      expect(firebase.uid, 'signed_in');
    });
  }
  for (final method in methods) {
    test('$method refuses requests after observer failure', () async {
      firebase.stream.subscriptions.last.error?.call(StateError('fixture'));
      service.calls.clear();
      await act(method);
      expect(service.calls, isEmpty);
    });
  }
  test('rate limit retains safe typed feedback and retry duration', () async {
    service.failure =
        PhoneOtpRateLimitException('PRIVATE_DIAGNOSTIC', retryAfterMs: 4321);
    expect(await act('send'), isFalse);
    expect(auth.lastError, SellerAuthError.rateLimited);
    expect(auth.retryAfterMs, 4321);
    expect(auth.lastErrorMessage, isNot(contains('PRIVATE_DIAGNOSTIC')));
  });
  test('unavailable OTP retains safe typed feedback', () async {
    service.failure = PhoneOtpUnavailableException('PRIVATE_DIAGNOSTIC');
    expect(await act('send'), isFalse);
    expect(auth.lastError, SellerAuthError.unavailable);
    expect(auth.lastErrorMessage, isNot(contains('PRIVATE_DIAGNOSTIC')));
  });
  test('reset known and unknown address are indistinguishable', () async {
    service.failure = UserNotFoundException('PRIVATE_DIAGNOSTIC');
    expect(await act('reset'), isTrue);
    expect(auth.lastError, SellerAuthError.none);
  });
  test('current reset maps raw failure to safe seller feedback', () async {
    service.failure = AuthException('PRIVATE_DIAGNOSTIC');
    expect(await act('reset'), isFalse);
    expect(auth.lastErrorMessage, isNot(contains('PRIVATE_DIAGNOSTIC')));
  });
}
