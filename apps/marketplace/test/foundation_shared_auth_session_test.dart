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

class _WriteCodec extends StandardMessageCodec {
  const _WriteCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) => switch (type) {
        130 => fs.DocumentReferenceRequest.decode(readValue(buffer)!),
        131 => fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!),
        135 => fs.PigeonFirebaseSettings.decode(readValue(buffer)!),
        187 => 'fixture_server_timestamp',
        190 => readValue(buffer),
        192 =>
          List.generate(readSize(buffer), (_) => readValue(buffer)).join('.'),
        _ => super.readValueOfType(type, buffer),
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const documents = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  const updates =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate';
  late _Auth auth;
  late _Store store;
  late AuthService service;
  late List<String> reads;
  late List<fs.DocumentReferenceRequest> writes;
  late Future<List<Object?>> Function(String) read;
  late Future<void> Function() write;
  late List<Object?> updateReply;
  Completer<void>? googlePending;
  var googleSignouts = 0;
  var listenBase = 0, cancelBase = 0;
  List<Object?> document(String path, Map<String, Object?>? data) => [
        fs.PigeonDocumentSnapshot(
            path: path,
            data: data,
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
  List<Object?> profile(String path,
          {String name = 'Current', String role = 'user', String? email}) =>
      document(
          path,
          path == 'settings/access'
              ? {'adminEmails': <String>[]}
              : {
                  'name': name,
                  'email': email ?? '${path.split('/').last}@example.invalid',
                  'role': role
                });
  Future<void> drain() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> seed(String uid,
          {String name = 'Seed', bool Function()? current}) =>
      SharedPreferencesService.saveUserSession(
          userId: uid,
          email: '$uid@example.invalid',
          name: name,
          role: 'user',
          isSessionCurrent: current);
  Future<Map<String, Object>> disk() async => store.getAll();
  void saved(String uid, {String name = 'Current'}) {
    expect(SharedPreferencesService.getUserId(), uid);
    expect(SharedPreferencesService.getUserEmail(), '$uid@example.invalid');
    expect(SharedPreferencesService.getUserName(), name);
    expect(SharedPreferencesService.getUserRole(), 'user');
    expect(SharedPreferencesService.isLoggedIn(), isTrue);
  }

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
    auth.reloads.clear();
    auth.signouts.clear();
    auth.signoutPending = null;
    auth.reloading = (_) async {};
    store = _Store();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = store;
    await SharedPreferencesService.init();
    await seed('owner_a');
    store.sets.clear();
    reads = [];
    writes = [];
    read = (path) async => profile(path);
    write = () async {};
    updateReply = [null];
    googlePending = null;
    googleSignouts = 0;
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      reads.add(r.path);
      return read(r.path);
    });
    messenger.setMockMessageHandler(updates, (message) async {
      writes.add((const _WriteCodec().decodeMessage(message)! as List)[1]
          as fs.DocumentReferenceRequest);
      await write();
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage(updateReply);
    });
    messenger.setMockMethodCallHandler(google, (call) async {
      if (call.method == 'signOut') {
        googleSignouts++;
        await googlePending?.future;
      }
      return null;
    });
  });
  tearDown(() async {
    await drain();
    expect(auth.cancelled - cancelBase, auth.listening - listenBase,
        reason: 'Every operation must release its SDK listener');
    messenger.setMockDecodedMessageHandler<Object?>(documents, null);
    messenger.setMockMessageHandler(updates, null);
    messenger.setMockMethodCallHandler(google, null);
  });
  test('current SDK restore reloads reads and stores its own profile',
      () async {
    final user = await service.restoreSession();
    expect(user?.uid, 'owner_a');
    expect(user?.role, 'user');
    saved('owner_a');
    expect(auth.reloads, ['owner_a']);
    expect(reads.toSet(), {'users/owner_a'});
  });
  test('signed-out restore returns null without reads or persistence',
      () async {
    auth.uid = null;
    expect(await service.restoreSession(), isNull);
    expect(reads, isEmpty);
    expect(store.sets, isEmpty);
  });
  test('current reload failure uses captured SDK user fallback only', () async {
    auth.reloading = (_) async => throw StateError('PRIVATE_RELOAD');
    final user = await service.restoreSession();
    expect(user?.uid, 'owner_a');
    expect(user?.role, 'user');
    expect(user?.name, 'sdk-owner_a');
    expect(store.sets, isEmpty);
  });
  test('SDK switch during reload refuses before any profile read', () async {
    final pending = Completer<void>();
    auth.reloading = (_) => pending.future;
    final old = service.restoreSession();
    await drain();
    auth.emit('owner_b');
    await seed('owner_b');
    pending.complete();
    expect(await old, isNull);
    expect(reads, isEmpty);
    saved('owner_b', name: 'Seed');
  });
  test('late old restore profile cannot persist over new owner', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path == 'users/owner_a' ? await pending.future : profile(path);
    final old = service.restoreSession();
    await drain();
    auth.emit('owner_b');
    await seed('owner_b');
    pending.complete(profile('users/owner_a'));
    expect(await old, isNull);
    saved('owner_b', name: 'Seed');
  });
  test('old restore failure cannot return the new SDK user as fallback',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path == 'users/owner_a' ? await pending.future : profile(path);
    final old = service.restoreSession();
    await drain();
    auth.emit('owner_b');
    await seed('owner_b');
    pending.complete(['unavailable', 'PRIVATE_FIXTURE', null]);
    expect(await old, isNull);
    saved('owner_b', name: 'Seed');
  });
  test('latest same-owner restore wins over older profile result', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    final old = service.restoreSession();
    await drain();
    read = (path) async => profile(path, name: 'Latest');
    expect((await service.restoreSession())?.name, 'Latest');
    pending.complete(profile('users/owner_a', name: 'Old'));
    expect(await old, isNull);
    saved('owner_a', name: 'Latest');
  });
  test('same UID renewal fences older restore', () async {
    final pending = Completer<void>();
    auth.reloading = (_) => pending.future;
    final old = service.restoreSession();
    await drain();
    auth.emit('owner_a');
    await drain();
    pending.complete();
    expect(await old, isNull);
    expect(reads, isEmpty);
    saved('owner_a', name: 'Seed');
  });
  test('current profile read preserves server role with one native read',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    final result = service.getUserData('owner_a');
    await drain();
    expect(reads.toSet(), {'users/owner_a'});
    pending.complete(profile('users/owner_a', role: 'employee'));
    expect((await result).role, 'employee');
    expect(writes, isEmpty);
  });
  test('foreign profile request refuses before native IO', () async {
    await expectLater(
        service.getUserData('owner_b'), throwsA(isA<AuthException>()));
    expect(reads, isEmpty);
    expect(writes, isEmpty);
  });
  test('late profile read refuses after account switch', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    final result = service.getUserData('owner_a');
    await drain();
    auth.emit('owner_b');
    pending.complete(profile('users/owner_a'));
    await expectLater(result, throwsA(isA<AuthException>()));
    expect(writes, isEmpty);
  });
  test('admin allowlist hints cannot grant or write a profile role', () async {
    read = (path) async => path == 'settings/access'
        ? document(path, {
            'adminEmails': ['owner_a@example.invalid']
          })
        : profile(path);
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(reads, ['users/owner_a']);
    expect(writes, isEmpty);
  });
  test('native Google logout await cannot sign out a newer Firebase owner',
      () async {
    googlePending = Completer<void>();
    final old = service.signOut();
    await drain();
    expect(googleSignouts, 1);
    auth.emit('owner_b');
    await seed('owner_b');
    googlePending!.complete();
    await old;
    expect(auth.signouts, isEmpty);
    saved('owner_b', name: 'Seed');
  });
  test('same UID renewal during Google logout prevents Firebase dispatch',
      () async {
    googlePending = Completer<void>();
    final old = service.signOut();
    await drain();
    auth.emit('owner_a');
    await drain();
    googlePending!.complete();
    await old;
    expect(auth.signouts, isEmpty);
    saved('owner_a', name: 'Seed');
  });
  test('current sign-out clears only session keys after own SDK null',
      () async {
    await SharedPreferencesService.setString('theme_fixture', 'dark');
    await service.signOut();
    expect(auth.signouts, ['owner_a']);
    expect(auth.uid, isNull);
    expect(SharedPreferencesService.getUserId(), isNull);
    expect(SharedPreferencesService.getString('theme_fixture'), 'dark');
    expect(store.removals, hasLength(8));
  });
  test('already dispatched logout completion cannot erase newer stored owner',
      () async {
    auth.signoutPending = Completer<void>();
    final old = service.signOut();
    await drain();
    expect(auth.signouts, ['owner_a']);
    auth.emit('owner_b');
    await seed('owner_b');
    auth.signoutPending!.complete();
    await old;
    saved('owner_b', name: 'Seed');
    expect(store.removals, isEmpty);
  });
  test('foreign stored identity survives sign-out of active owner', () async {
    await seed('owner_b');
    await service.signOut();
    saved('owner_b', name: 'Seed');
    expect(store.removals, isEmpty);
  });
  test('false save predicate prevents all stored mutations', () async {
    await seed('owner_b', current: () => false);
    saved('owner_a', name: 'Seed');
    expect(store.sets, isEmpty);
  });
  test('held old native save completes before newer save commits', () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_name') && value == 'Held') await pending.future;
    };
    final old =
        seed('owner_a', name: 'Held', current: () => auth.uid == 'owner_a');
    await drain();
    auth.emit('owner_b');
    var completed = false;
    final next =
        seed('owner_b', name: 'Latest', current: () => auth.uid == 'owner_b')
            .then((_) {
      completed = true;
    });
    await drain();
    final early = completed;
    pending.complete();
    await Future.wait([old, next]);
    expect(early, isFalse);
    saved('owner_b', name: 'Latest');
    expect((await disk())['flutter.user_name'], 'Latest');
    expect((await disk())['flutter.user_id'], 'owner_b');
  });
  test('held old clear cannot delete a completed newer session', () async {
    final pending = Completer<void>();
    store.beforeRemove = (key) async {
      if (key.endsWith('is_logged_in')) await pending.future;
    };
    final old = SharedPreferencesService.clearUserSession(
        expectedUserId: 'owner_a',
        isSessionCurrent: () => auth.uid == 'owner_a');
    await drain();
    auth.emit('owner_b');
    var completed = false;
    final next =
        seed('owner_b', name: 'Latest', current: () => auth.uid == 'owner_b')
            .then((_) {
      completed = true;
    });
    await drain();
    final early = completed;
    pending.complete();
    await Future.wait([old, next]);
    expect(early, isFalse);
    saved('owner_b', name: 'Latest');
    expect((await disk())['flutter.is_logged_in'], true);
  });

  test('signed-out logout cannot erase a stored foreign owner', () async {
    await seed('owner_b');
    store.sets.clear();
    auth.uid = null;
    await service.signOut();
    saved('owner_b', name: 'Seed');
    expect(auth.signouts, isEmpty);
    expect(googleSignouts, 0);
    expect(store.removals, isEmpty);
  });
  test('missing current user retains established database failure type',
      () async {
    read = (path) async => document(
        path, path.startsWith('users/') ? null : {'adminEmails': <String>[]});
    await expectLater(
        service.getUserData('owner_a'), throwsA(isA<DatabaseException>()));
    expect(writes, isEmpty);
  });
  test('current profile read failure retains role-user SDK fallback', () async {
    read = (path) async => path.startsWith('users/')
        ? ['unavailable', 'PRIVATE_FIXTURE', null]
        : profile(path);
    final result = await service.restoreSession();
    expect(result?.uid, 'owner_a');
    expect(result?.name, 'sdk-owner_a');
    expect(result?.role, 'user');
    expect(store.sets, isEmpty);
  });
  test('current server user remains user even when hint lists that email',
      () async {
    read = (path) async => path == 'settings/access'
        ? document(path, {
            'adminEmails': ['owner_a@example.invalid']
          })
        : profile(path);
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
  });
  test('server admin cannot be demoted by a mismatched email hint', () async {
    read = (path) async => path == 'settings/access'
        ? document(path, {
            'adminEmails': ['other@example.invalid']
          })
        : profile(path, role: 'admin');
    expect((await service.getUserData('owner_a')).role, 'admin');
    expect(writes, isEmpty);
  });
  test('owned profile read cannot dispatch any role mutation', () async {
    read = (path) async => path == 'settings/access'
        ? document(path, {
            'adminEmails': ['owner_a@example.invalid']
          })
        : profile(path);
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
    expect(store.sets, isEmpty);
  });
  test('same UID renewal refuses a held profile result', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    final result = service.getUserData('owner_a');
    await drain();
    auth.emit('owner_a');
    await drain();
    pending.complete(profile('users/owner_a'));
    await expectLater(result, throwsA(isA<AuthException>()));
    expect(writes, isEmpty);
  });
  test('owner changes away and back cannot revive held profile result',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    final result = service.getUserData('owner_a');
    await drain();
    auth.emit('owner_b');
    auth.emit('owner_a');
    await drain();
    pending.complete(profile('users/owner_a'));
    await expectLater(result, throwsA(isA<AuthException>()));
  });
  test('SDK stream error revokes held profile and a new read can recover',
      () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    final result = service.getUserData('owner_a');
    await drain();
    auth.events.addError(StateError('PRIVATE_AUTH_STREAM'));
    await drain();
    pending.complete(profile('users/owner_a'));
    await expectLater(result, throwsA(isA<AuthException>()));
    read = (path) async => profile(path);
    expect((await service.getUserData('owner_a')).uid, 'owner_a');
  });
  test('SDK stream closes on listen and held work loses authority', () async {
    final pending = Completer<List<Object?>>();
    read = (path) async =>
        path.startsWith('users/') ? await pending.future : profile(path);
    auth.closeOnListen = true;
    final result = service.getUserData('owner_a');
    await drain();
    pending.complete(profile('users/owner_a'));
    await expectLater(result, throwsA(isA<AuthException>()));
    expect(writes, isEmpty);
    auth.closeOnListen = false;
    read = (path) async => profile(path);
    expect((await service.getUserData('owner_a')).uid, 'owner_a');
  });
  test('SDK stream error during restore cannot produce fallback', () async {
    final pending = Completer<void>();
    auth.reloading = (_) => pending.future;
    final result = service.restoreSession();
    await drain();
    auth.events.addError(StateError('PRIVATE_AUTH_STREAM'));
    await drain();
    pending.completeError(StateError('PRIVATE_RELOAD'));
    expect(await result, isNull);
    expect(reads, isEmpty);
    expect(store.sets, isEmpty);
  });
  test('SDK stream error during Google logout prevents Firebase dispatch',
      () async {
    googlePending = Completer<void>();
    final result = service.signOut();
    await drain();
    auth.events.addError(StateError('PRIVATE_AUTH_STREAM'));
    await drain();
    googlePending!.complete();
    await result;
    expect(auth.signouts, isEmpty);
    expect(store.removals, isEmpty);
  });
  test('renewal after issued logout cannot authorize later stored cleanup',
      () async {
    auth.signoutPending = Completer<void>();
    final result = service.signOut();
    await drain();
    auth.emit('owner_a');
    await drain();
    auth.signoutPending!.complete();
    await result;
    expect(auth.uid, isNull); // Already-issued SDK logout is not cancellable.
    expect(store.removals, isEmpty);
    saved('owner_a', name: 'Seed');
  });
  test('renewal while native restore persistence is held prevents completion',
      () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_name')) await pending.future;
    };
    final result = service.restoreSession();
    await drain();
    auth.emit('owner_a');
    await drain();
    pending.complete();
    expect(await result, isNull);
    expect(SharedPreferencesService.isLoggedIn(), isFalse);
    expect(store.sets.where((key) => key.endsWith('user_role')), isEmpty);
  });
  test('save predicate is rechecked after each held native key', () async {
    final pending = Completer<void>();
    var current = true;
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_email')) await pending.future;
    };
    final result = seed('owner_a', name: 'New', current: () => current);
    await drain();
    current = false;
    pending.complete();
    await result;
    expect(SharedPreferencesService.isLoggedIn(), isFalse);
    expect(store.sets.where((key) => key.endsWith('user_name')), isEmpty);
    expect(store.sets.where((key) => key.endsWith('user_role')), isEmpty);
  });
  test('latest queued same-owner save supersedes an older queued save',
      () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_name') && value == 'Held') await pending.future;
    };
    final first = seed('owner_a', name: 'Held');
    await drain();
    final obsolete = seed('owner_a', name: 'Obsolete');
    final latest = seed('owner_a', name: 'Latest');
    pending.complete();
    await Future.wait([first, obsolete, latest]);
    saved('owner_a', name: 'Latest');
    expect((await disk())['flutter.user_name'], 'Latest');
    expect(store.sets.where((key) => key.endsWith('user_name')), hasLength(2));
  });
  test('foreign cleanup cannot supersede a valid in-flight session save',
      () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_id') && value == 'owner_b') await pending.future;
    };
    final next = seed('owner_b', name: 'Latest');
    await drain();
    await SharedPreferencesService.clearUserSession(expectedUserId: 'owner_a');
    expect(store.removals, isEmpty);
    pending.complete();
    await next;
    saved('owner_b', name: 'Latest');
    expect((await disk())['flutter.user_name'], 'Latest');
  });
  test('failed native key never publishes logged-in and next save recovers',
      () async {
    store.failSetKey = 'flutter.user_email';
    await seed('owner_a', name: 'Failed');
    expect(SharedPreferencesService.isLoggedIn(), isFalse);
    expect((await disk())['flutter.is_logged_in'], false);
    expect(store.sets.where((key) => key.endsWith('user_name')), isEmpty);
    store.failSetKey = null;
    await seed('owner_b', name: 'Recovered');
    saved('owner_b', name: 'Recovered');
    expect((await disk())['flutter.is_logged_in'], true);
  });
  test('unrelated preference can complete while session write is held',
      () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_name')) await pending.future;
    };
    final result = seed('owner_a', name: 'Held');
    await drain();
    await SharedPreferencesService.setString('theme_fixture', 'dark');
    expect((await disk())['flutter.theme_fixture'], 'dark');
    pending.complete();
    await result;
    saved('owner_a', name: 'Held');
  });

  test('foreign clear refuses before new owner first native key completes',
      () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('is_logged_in') && value == false) await pending.future;
    };
    final next = seed('owner_b', name: 'Latest');
    await drain();
    expect(SharedPreferencesService.getUserId(), 'owner_a');
    final old =
        SharedPreferencesService.clearUserSession(expectedUserId: 'owner_a');
    await drain();
    pending.complete();
    await Future.wait([next, old]);
    saved('owner_b', name: 'Latest');
    expect(store.removals, isEmpty);
    expect((await disk())['flutter.user_id'], 'owner_b');
  });
  test('foreign clear cannot replace queued new owner before any native field',
      () async {
    final pending = Completer<void>();
    store.beforeSet = (key, value) async {
      if (key.endsWith('user_name') && value == 'Held') await pending.future;
    };
    final first = seed('owner_a', name: 'Held');
    await drain();
    final next = seed('owner_b', name: 'Latest');
    final old =
        SharedPreferencesService.clearUserSession(expectedUserId: 'owner_a');
    await drain();
    pending.complete();
    await Future.wait([first, next, old]);
    saved('owner_b', name: 'Latest');
    expect(store.removals, isEmpty);
    expect((await disk())['flutter.user_name'], 'Latest');
  });

  test('unverified default admin email never grants client role', () async {
    auth.verified = false;
    auth.emailOverride = 'admin@agrimore.in';
    read = (path) async => profile(path, email: 'admin@agrimore.in');
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
    expect(reads, ['users/owner_a']);
  });
  test('verified default admin email alone never grants client role', () async {
    auth.verified = true;
    auth.emailOverride = 'admin@agrimore.in';
    read = (path) async => profile(path, email: 'admin@agrimore.in');
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
  });
  test('different SDK email cannot elevate from profile email hint', () async {
    read = (path) async => profile(path, email: 'admin@agrimore.in');
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
  });
  test('rejected native role update cannot fabricate admin profile', () async {
    updateReply = ['permission-denied', 'PRIVATE_ROLE_REFUSAL', null];
    read = (path) async => path == 'settings/access'
        ? document(path, {
            'adminEmails': ['owner_a@example.invalid']
          })
        : profile(path);
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
  });
  test('restored role cannot persist admin derived from hints', () async {
    read = (path) async => path == 'settings/access'
        ? document(path, {
            'adminEmails': ['owner_a@example.invalid']
          })
        : profile(path);
    expect((await service.restoreSession())?.role, 'user');
    saved('owner_a');
    expect((await disk())['flutter.user_role'], 'user');
    expect(writes, isEmpty);
  });
  test('server admin retained even if obsolete hint endpoint rejects',
      () async {
    read = (path) async => path == 'settings/access'
        ? ['permission-denied', 'PRIVATE_HINT_REFUSAL', null]
        : profile(path, role: 'admin');
    expect((await service.getUserData('owner_a')).role, 'admin');
    expect(reads, ['users/owner_a']);
    expect(writes, isEmpty);
  });
  test('server-recorded admin restore keeps its established role', () async {
    read = (path) async => profile(path, role: 'admin');
    expect((await service.restoreSession())?.role, 'admin');
    expect(SharedPreferencesService.getUserRole(), 'admin');
    expect(writes, isEmpty);
  });
  test('missing profile cannot become admin through fallback email', () async {
    auth.emailOverride = 'admin@agrimore.in';
    read = (path) async => document(path, null);
    final restored = await service.restoreSession();
    expect(restored?.uid, 'owner_a');
    expect(restored?.email, 'admin@agrimore.in');
    expect(restored?.role, 'user');
    expect(store.sets, isEmpty);
    expect(writes, isEmpty);
  });
  test('build-time hint cannot grant role without server record', () async {
    if (const String.fromEnvironment('AGRIMORE_BOOTSTRAP_ADMIN_EMAILS') ==
        'owner_a@example.invalid') {
      expect(
          AdminAccessConfig.shouldBootstrapAdminRole('owner_a@example.invalid'),
          isTrue,
          reason: 'The test build must actually recognize the hint');
    }
    expect((await service.getUserData('owner_a')).role, 'user');
    expect(writes, isEmpty);
    expect(reads, ['users/owner_a']);
  });
  for (final role in [
    'user',
    'seller',
    'delivery_partner',
    'employee',
    'admin'
  ]) {
    test('server-recorded $role survives conflicting client hint', () async {
      read = (path) async => path == 'settings/access'
          ? document(path, {
              'adminEmails': ['owner_a@example.invalid']
            })
          : profile(path, role: role);
      expect((await service.getUserData('owner_a')).role, role);
      expect(writes, isEmpty);
      expect(reads, ['users/owner_a']);
    });
  }
}
