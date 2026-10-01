@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends FirebaseAuthPlatform {
  String? uid = 'owner_a';
  bool closeOnListen = false;
  bool verified = true;
  String? emailOverride;
  final events = StreamController<UserPlatform?>.broadcast();
  late Future<void> Function(String) reloading;
  Completer<void>? signoutPending;
  final reloads = <String>[], signouts = <String?>[];
  int listening = 0, cancelled = 0;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);
  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.multi((sink) {
        listening++;
        var released = false;
        void release() {
          if (released) return;
          released = true;
          cancelled++;
        }

        sink.add(currentUser);
        if (closeOnListen) {
          sink.onCancel = release;
          sink.close();
          return;
        }
        final subscription = events.stream
            .listen(sink.add, onError: sink.addError, onDone: sink.close);
        sink.onCancel = () async {
          release();
          await subscription.cancel();
        };
      });
  void emit(String? owner) {
    uid = owner;
    events.add(currentUser);
  }

  @override
  Future<void> signOut() async {
    final owner = uid;
    signouts.add(owner);
    await signoutPending?.future;
    if (uid == owner) emit(null);
  }
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(this.owner, String uid)
      : super(
            owner,
            _Factor(owner),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid,
                    isAnonymous: false,
                    isEmailVerified: owner.verified,
                    email: owner.emailOverride ?? '$uid@example.invalid',
                    displayName: 'sdk-$uid'),
                providerData: []));
  final _Auth owner;
  @override
  Future<void> reload() async {
    owner.reloads.add(uid);
    await owner.reloading(uid);
  }
}

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  Future<void> Function(String, Object)? beforeSet;
  Future<void> Function(String)? beforeRemove;
  String? failSetKey;
  final sets = <String>[], removals = <String>[];
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    sets.add(key);
    await beforeSet?.call(key, value);
    if (key == failSetKey) return false;
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    removals.add(key);
    await beforeRemove?.call(key);
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const callable = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  const document = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  late _Auth auth;
  late _Store store;
  late AuthService service;
  late List<Map> calls;
  late List<String> reads;
  late Future<List<Object?>> Function(Map) reply;
  late Future<List<Object?>> Function(String) read;
  var listenBase = 0, cancelBase = 0;
  const commands = [
    'verifyEmailForProfile',
    'completeUserProfile',
    'changePhoneNumber',
    'changeEmailAddress',
    'changeDateOfBirth'
  ];
  Future<Object?> run(String command) => switch (command) {
        'verifyEmailForProfile' => service
            .verifyEmailOtpForProfile(
                email: 'owner_a@example.invalid', otp: 'local-code')
            .then<Object?>((_) => 'confirmed'),
        'completeUserProfile' => service.completeUserProfile(
            name: 'Current',
            email: 'owner_a@example.invalid',
            dateOfBirth: DateTime(1990, 1, 1),
            gender: 'male'),
        'changePhoneNumber' =>
          service.changePhoneNumber(phone: '9876500011', otp: 'local-code'),
        'changeEmailAddress' =>
          service.changeEmailAddress(email: 'owner_a@example.invalid'),
        'changeDateOfBirth' =>
          service.changeDateOfBirth(dateOfBirth: DateTime(1990, 1, 1)),
        _ => throw ArgumentError(command),
      };
  List<Object?> profile(String path) => [
        fs.PigeonDocumentSnapshot(
            path: path,
            data: {
              'name': 'Current',
              'email': 'owner_a@example.invalid',
              'role': 'user'
            },
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
  Future<void> drain() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> seed(String uid) => SharedPreferencesService.saveUserSession(
      userId: uid, email: '$uid@example.invalid', name: 'Seed', role: 'user');
  Matcher refusal(String code) =>
      isA<AuthException>().having((e) => e.code, 'code', code);
  setUpAll(() async {
    await Firebase.initializeApp();
    auth = _Auth();
    FirebaseAuthPlatform.instance = auth;
    service = AuthService();
  });
  setUp(() async {
    auth.uid = 'owner_a';
    auth.closeOnListen = false;
    auth.verified = true;
    auth.emailOverride = null;
    listenBase = auth.listening;
    cancelBase = auth.cancelled;
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    await SharedPreferencesService.init();
    await seed('owner_a');
    store.sets.clear();
    calls = [];
    reads = [];
    reply = (_) async => [
          {'success': true}
        ];
    read = (path) async => profile(path);
    messenger.setMockDecodedMessageHandler(callable, (message) async {
      final data = (message! as List).single as Map;
      calls.add(data);
      return reply(data);
    });
    messenger.setMockDecodedMessageHandler(document, (message) async {
      final request = (message! as List)[1] as fs.DocumentReferenceRequest;
      reads.add(request.path);
      return read(request.path);
    });
  });
  tearDown(() async {
    await drain();
    expect(auth.cancelled - cancelBase, auth.listening - listenBase,
        reason: 'Each profile operation must release its native SDK listener');
    messenger.setMockDecodedMessageHandler(callable, null);
    messenger.setMockDecodedMessageHandler(document, null);
  });
  tearDownAll(() => auth.events.close());
  for (final command in commands) {
    test('$command confirmed current command sends captured owner', () async {
      final result = await run(command);
      expect(calls.single['functionName'], command);
      expect((calls.single['parameters'] as Map)['expectedOwnerId'], 'owner_a');
      if (command == 'verifyEmailForProfile') {
        expect(result, 'confirmed');
        expect(reads, isEmpty);
        expect(store.sets, isEmpty);
      } else {
        expect((result as UserModel).uid, 'owner_a');
        expect(result.role, 'user');
        expect(reads, ['users/owner_a']);
        expect(SharedPreferencesService.getUserId(), 'owner_a');
        expect(SharedPreferencesService.getUserName(), 'Current');
      }
    });
    test('$command signed-out refusal before callable IO', () async {
      auth.uid = null;
      await expectLater(run(command), throwsA(isA<UnauthorizedException>()));
      expect(calls, isEmpty);
      expect(reads, isEmpty);
      expect(store.sets, isEmpty);
    });
    test('$command switched account cannot accept old callable reply',
        () async {
      final pending = Completer<List<Object?>>();
      reply = (_) => pending.future;
      final result = run(command);
      final rejected = expectLater(result, throwsA(refusal('session-changed')));
      await drain();
      auth.emit('owner_b');
      await seed('owner_b');
      pending.complete([
        {'success': true}
      ]);
      await rejected;
      expect(reads, isEmpty);
      expect(SharedPreferencesService.getUserId(), 'owner_b');
      expect(SharedPreferencesService.getUserName(), 'Seed');
    });
    test('$command same UID renewal cannot continue old command', () async {
      final pending = Completer<List<Object?>>();
      reply = (_) => pending.future;
      final result = run(command);
      final rejected = expectLater(result, throwsA(refusal('session-changed')));
      await drain();
      auth.emit('owner_a');
      await drain();
      pending.complete([
        {'success': true}
      ]);
      await rejected;
      expect(reads, isEmpty);
      expect(store.sets, isEmpty);
    });
    test('$command SDK stream error revokes pending command', () async {
      final pending = Completer<List<Object?>>();
      reply = (_) => pending.future;
      final result = run(command);
      final rejected = expectLater(result, throwsA(refusal('session-changed')));
      await drain();
      auth.events.addError(StateError('PRIVATE_AUTH_STREAM'));
      await drain();
      pending.complete([
        {'success': true}
      ]);
      await rejected;
      expect(reads, isEmpty);
      expect(store.sets, isEmpty);
    });
    test('$command SDK stream closure revokes pending command', () async {
      final pending = Completer<List<Object?>>();
      reply = (_) => pending.future;
      auth.closeOnListen = true;
      final result = run(command);
      final rejected = expectLater(result, throwsA(refusal('session-changed')));
      await drain();
      pending.complete([
        {'success': true}
      ]);
      await rejected;
      expect(reads, isEmpty);
      expect(store.sets, isEmpty);
    });
    for (final response in [
      {'success': false},
      <String, Object?>{},
      {'success': 'true'}
    ]) {
      test('$command refuses unconfirmed $response without read or save',
          () async {
        reply = (_) async => [response];
        await expectLater(run(command), throwsA(refusal('unconfirmed')));
        expect(reads, isEmpty);
        expect(store.sets, isEmpty);
      });
    }
    test('$command preserves original server refusal code', () async {
      reply = (_) async => [
            'functions-error',
            'Please verify this email first.',
            {
              'code': 'failed-precondition',
              'message': 'Please verify this email first.'
            }
          ];
      await expectLater(run(command), throwsA(refusal('failed-precondition')));
      expect(reads, isEmpty);
      expect(store.sets, isEmpty);
    });
    if (command != 'verifyEmailForProfile') {
      test('$command account switch during profile read cannot publish or save',
          () async {
        final pending = Completer<List<Object?>>();
        read = (_) => pending.future;
        final result = run(command);
        final rejected =
            expectLater(result, throwsA(refusal('session-changed')));
        await drain();
        auth.emit('owner_b');
        await seed('owner_b');
        pending.complete(profile('users/owner_a'));
        await rejected;
        expect(SharedPreferencesService.getUserId(), 'owner_b');
        expect(SharedPreferencesService.getUserName(), 'Seed');
      });
      test(
          '$command renewal during native preference reply cannot return success',
          () async {
        final pending = Completer<void>();
        store.beforeSet = (key, value) async {
          if (key.endsWith('user_name')) await pending.future;
        };
        final result = run(command);
        final rejected =
            expectLater(result, throwsA(refusal('session-changed')));
        await drain();
        auth.emit('owner_a');
        await drain();
        pending.complete();
        await rejected;
        expect(SharedPreferencesService.isLoggedIn(), isFalse);
        expect(store.sets.where((key) => key.endsWith('user_role')), isEmpty);
      });
    }
  }
}
