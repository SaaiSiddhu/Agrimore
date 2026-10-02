@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart' as app;
import 'package:firebase_auth/firebase_auth.dart' show User, AuthCredential;
import 'package:firebase_core/firebase_core.dart';
// Official cached platform fixtures; every operation stays in local callbacks.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordFactor extends MultiFactorPlatform {
  PasswordFactor(super.auth);
}

class PasswordReceipt extends UserCredentialPlatform {
  PasswordReceipt({required super.auth, required super.user});
}

class PasswordTransport extends FirebaseAuthPlatform {
  String? uid = 'owner_a';
  late StreamController<UserPlatform?> events;
  final calls = <String>[];
  Future<void> Function()? beforeReauthReply;
  Future<void> Function()? beforeUpdateReply;
  void reset() {
    uid = 'owner_a';
    calls.clear();
    beforeReauthReply = null;
    beforeUpdateReply = null;
    events = StreamController<UserPlatform?>.broadcast(onListen: () {
      final initial = currentUser;
      scheduleMicrotask(() => events.add(initial));
    });
  }

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser =>
      uid == null ? null : PasswordUser(this, uid!);
  @override
  Stream<UserPlatform?> authStateChanges() => events.stream;
  void change(String? owner) {
    uid = owner;
    events.add(currentUser);
  }
}

class PasswordUser extends UserPlatform {
  PasswordUser(this.transport, String owner)
      : super(
            transport,
            PasswordFactor(transport),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: owner,
                    email: 'fixture@example.test',
                    isAnonymous: false,
                    isEmailVerified: true),
                providerData: []));
  final PasswordTransport transport;
  @override
  Future<UserCredentialPlatform> reauthenticateWithCredential(
      AuthCredential credential) async {
    transport.calls.add('reauth:$uid');
    await transport.beforeReauthReply?.call();
    return PasswordReceipt(auth: transport, user: this);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    transport.calls.add('update:$uid');
    await transport.beforeUpdateReply?.call();
  }
}

class PasswordEventUser implements User {
  PasswordEventUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PasswordProviderService implements AuthService {
  String? uid = 'owner_a';
  final events = StreamController<User?>.broadcast();
  final calls = <String?>[];
  Future<void> Function()? reply;
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => events.stream;
  @override
  Future<UserModel> getUserData(String uid) async => UserModel(
      uid: uid,
      email: '$uid@example.test',
      name: 'Fixture',
      role: 'user',
      createdAt: DateTime(2026));
  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    calls.add(uid);
    await reply?.call();
  }

  void change(String? owner) {
    uid = owner;
    events.add(owner == null ? null : PasswordEventUser(owner));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PasswordWriteCodec extends StandardMessageCodec {
  const PasswordWriteCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) => switch (type) {
        130 => fs.DocumentReferenceRequest.decode(readValue(buffer)!),
        131 => fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!),
        135 => fs.PigeonFirebaseSettings.decode(readValue(buffer)!),
        187 => 'fixture_timestamp',
        _ => super.readValueOfType(type, buffer),
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final transport = PasswordTransport();
  final writes = <fs.DocumentReferenceRequest>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet';
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = transport;
  });
  setUp(() {
    transport.reset();
    writes.clear();
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMessageHandler(channel, (message) async {
      writes.add((const PasswordWriteCodec().decodeMessage(message) as List)[1]
          as fs.DocumentReferenceRequest);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]);
    });
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
        (_) async => fs.FirebaseFirestoreHostApi.codec.encodeMessage([null]));
  });
  tearDown(() async {
    await transport.events.close();
    messenger.setMockMessageHandler(channel, null);
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
        null);
  });
  Future<void> action() => AuthService().changePassword(
      currentPassword: 'fixture_old', newPassword: 'fixture_new');
  group('shared existing password action', () {
    test('normal current owner executes local update once', () async {
      await action();
      expect(transport.calls, ['reauth:owner_a', 'update:owner_a']);
    });
    for (final owner in <String?>['owner_b', null, 'owner_a']) {
      test('changed session $owner during reauth cannot update', () async {
        final held = Completer<void>();
        transport.beforeReauthReply = () => held.future;
        final pending = action();
        await drain();
        transport.change(owner);
        await drain();
        held.complete();
        await expectLater(pending, throwsA(isA<AuthException>()));
        expect(transport.calls, ['reauth:owner_a']);
      });
      test('changed session $owner during update cannot report success',
          () async {
        final held = Completer<void>();
        transport.beforeUpdateReply = () => held.future;
        final pending = action();
        await drain();
        transport.change(owner);
        await drain();
        held.complete();
        await expectLater(pending, throwsA(isA<AuthException>()));
        expect(transport.calls, ['reauth:owner_a', 'update:owner_a']);
      });
    }

    test('signed-out caller cannot dispatch local reauth', () async {
      transport.uid = null;
      await expectLater(action(), throwsA(isA<AuthException>()));
      expect(transport.calls, isEmpty);
    });
    for (final closed in [false, true]) {
      test('lost shared observer closed $closed prevents update', () async {
        final held = Completer<void>();
        transport.beforeReauthReply = () => held.future;
        final pending = action();
        await drain();
        if (closed) {
          await transport.events.close();
        } else {
          transport.events
              .addError(StateError('local fixture observer failure'));
          await drain();
        }
        held.complete();
        await expectLater(pending, throwsA(isA<AuthException>()));
        expect(transport.calls, ['reauth:owner_a']);
        expect(transport.events.hasListener, isFalse);
      });
    }
    test('normal shared action cancels owned observer', () async {
      await action();
      expect(transport.events.hasListener, isFalse);
    });
    test('reauth unexpected error is safely mapped', () async {
      transport.beforeReauthReply =
          () async => throw StateError('unsafe fixture detail');
      await expectLater(
          action(),
          throwsA(isA<AuthException>().having((e) => e.message, 'safe message',
              'Could not change your password. Please try again.')));
      expect(transport.calls, ['reauth:owner_a']);
    });
  });
  group('actual marketplace password provider', () {
    late PasswordProviderService service;
    late app.AuthProvider auth;
    setUp(() async {
      service = PasswordProviderService();
      auth = app.AuthProvider(authService: service);
      service.change('owner_a');
      await drain();
      writes.clear();
    });
    tearDown(() async {
      auth.dispose();
      await service.events.close();
    });
    Future<bool> change() => auth.changePassword(
        currentPassword: 'fixture_old', newPassword: 'fixture_new');
    test('normal owned result succeeds once', () async {
      expect(await change(), isTrue);
      expect(service.calls, ['owner_a']);
    });
    for (final owner in <String?>['owner_b', null, 'owner_a']) {
      test('stale password result $owner cannot affect next profile', () async {
        final held = Completer<void>();
        service.reply = () => held.future;
        final pending = change();
        service.change(owner);
        await drain();
        held.complete();
        expect(await pending, isFalse);
        expect(auth.error, isNull);
      });
    }
    test('disposed provider cannot dispatch password action', () async {
      auth.dispose();
      expect(await change(), isFalse);
      expect(service.calls, isEmpty);
    });
    test('provider disposed in flight absorbs completion', () async {
      final held = Completer<void>();
      service.reply = () => held.future;
      final pending = change();
      auth.dispose();
      held.complete();
      expect(await pending, isFalse);
      expect(writes, isEmpty);
    });

    test('busy listener switching SDK owner prevents password dispatch',
        () async {
      auth.addListener(() {
        if (auth.isLoading) service.uid = 'owner_b';
      });
      expect(await change(), isFalse);
      expect(service.calls, isEmpty);
    });
    test('stale password failure cannot log or replace new error', () async {
      final held = Completer<void>();
      service.reply = () => held.future;
      final pending = change();
      service.change('owner_b');
      await drain();
      held.completeError(AuthException('unsafe fixture detail'));
      expect(await pending, isFalse);
      expect(auth.error, isNull);
      expect(writes, isEmpty);
    });
  });
}
