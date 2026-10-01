import 'dart:async';

import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_session_test.dart' as fixture;

class HeldStore extends fixture.FakeStore {
  Completer<void>? removal;
  Completer<void>? addition;
  Completer<ProfileRead>? partnerRead;
  @override
  Future<ProfileRead> partner(String uid) =>
      partnerRead?.future ?? super.partner(uid);
  @override
  Future<void> addToken(String uid, String token) async {
    await super.addToken(uid, token);
    if (uid == 'rA') await addition?.future;
  }

  @override
  Future<void> removeToken(String uid, String token) async {
    await super.removeToken(uid, token);
    await removal?.future;
  }
}

class HeldPush extends fixture.FakePush {
  Completer<String?>? read;
  Completer<void>? invalidation;
  int reads = 0;
  @override
  Future<String?> current() {
    reads++;
    return read?.future ?? super.current();
  }

  @override
  Future<void> forget() async {
    await super.forget();
    await invalidation?.future;
  }
}

class ControlledGateway extends fixture.FakeGateway {
  final events = StreamController<String?>.broadcast();
  @override
  Stream<String?> get uidChanges => events.stream;
  @override
  void emit(String? next) {
    uid = next;
    events.add(next);
  }
}

void main() {
  late fixture.FakeGateway gateway;
  late HeldStore store;
  late HeldPush push;
  late DeliveryAuthProvider auth;
  void make() {
    auth =
        DeliveryAuthProvider(gateway: gateway, store: store, pushTokens: push);
  }

  var disposed = false;
  setUp(() {
    disposed = false;
    gateway = fixture.FakeGateway()..uid = 'rA';
    store = HeldStore();
    for (final uid in ['rA', 'rB']) {
      store.users[uid] = fixture.doc({
        'name': uid,
        'email': '$uid@example.invalid',
        'role': 'delivery_partner'
      });
      store.partners[uid] =
          fixture.doc({'status': 'approved', 'isOnline': true});
    }
    push = HeldPush();
  });
  tearDown(() async {
    if (!disposed) auth.dispose();
    await pumpEventQueue();
    for (final stream in store.partnerStreams.values) {
      await stream.close();
    }
    await push.refresh.close();
  });

  test(
      'profile and authority hide immediately when SDK owner changes before its event',
      () async {
    make();
    await pumpEventQueue();
    expect(auth.user?.uid, 'rA');
    gateway.uid = 'rB';
    expect(auth.user, isNull);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.isDeliveryPartner, isFalse);
    expect(auth.kycStatus, isNull);
    expect(auth.partnerOnline, isNull);
    expect(auth.registeredToken, isNull);
    expect(auth.isLoading, isTrue);
  });
  test('signed-out SDK hides blocked rider status and registration immediately',
      () async {
    store.partners['rA'] = fixture.doc({
      'status': 'suspended',
      'suspensionReason': 'review',
      'offlineReason': 'suspended'
    });
    make();
    await pumpEventQueue();
    expect(auth.isBlocked, isTrue);
    gateway.uid = null;
    expect(auth.isBlocked, isFalse);
    expect(auth.statusReason, isNull);
    expect(auth.offlineReason, isNull);
    expect(auth.user, isNull);
    expect(auth.isLoading, isFalse);
  });
  test('late old profile cannot register token or subscribe before auth event',
      () async {
    final read = Completer<ProfileRead>();
    store.slowUser['rA'] = read;
    make();
    await pumpEventQueue();
    gateway.uid = 'rB';
    read.complete(store.users['rA']);
    await pumpEventQueue();
    expect(store.tokens['rA'], isNull);
    expect(store.liveWatchers, 0);
  });
  test('late non-rider refusal cannot sign out current SDK owner', () async {
    final read = Completer<ProfileRead>();
    store.slowUser['rA'] = read;
    make();
    await pumpEventQueue();
    gateway.uid = 'rB';
    read.complete(fixture.doc({'role': 'user'}));
    await pumpEventQueue();
    expect(gateway.uid, 'rB');
    expect(gateway.log, isEmpty);
  });
  test('late partner read cannot register old-owner token', () async {
    store.partnerRead = Completer<ProfileRead>();
    make();
    await pumpEventQueue();
    gateway.uid = 'rB';
    store.partnerRead!.complete(store.partners['rA']);
    await pumpEventQueue();
    expect(store.tokens['rA'], isNull);
  });
  test('late token read cannot write old-owner token before auth event',
      () async {
    push.read = Completer<String?>();
    make();
    await pumpEventQueue();
    gateway.uid = 'rB';
    push.read!.complete('late');
    await pumpEventQueue();
    expect(store.tokens['rA'], isNull);
    expect(auth.registeredToken, isNull);
  });
  test('logout cannot invalidate or sign out B after awaited A token removal',
      () async {
    make();
    await pumpEventQueue();
    store.removal = Completer<void>();
    final logout = auth.signOut();
    await pumpEventQueue();
    gateway.emit('rB');
    await pumpEventQueue();
    store.removal!.complete();
    await logout;
    await pumpEventQueue();
    expect(gateway.uid, 'rB');
    expect(push.forgotten, 0);
    expect(auth.user?.uid, 'rB');
  });
  test('logout cannot sign out B after awaited device token invalidation',
      () async {
    make();
    await pumpEventQueue();
    push.invalidation = Completer<void>();
    final logout = auth.signOut();
    await pumpEventQueue();
    gateway.emit('rB');
    await pumpEventQueue();
    push.invalidation!.complete();
    await logout;
    await pumpEventQueue();
    expect(gateway.uid, 'rB');
    expect(auth.user?.uid, 'rB');
  });
  test(
      'refresh cannot add new token after awaited old token removal changes owner',
      () async {
    make();
    await pumpEventQueue();
    store.removal = Completer<void>();
    push.refresh.add('fresh');
    await pumpEventQueue();
    gateway.uid = 'rB';
    store.removal!.complete();
    await pumpEventQueue();
    expect(store.log, isNot(contains('add rA fresh')));
  });
  test(
      'disposed provider hides authority and ignores late reads without notifying',
      () async {
    final read = Completer<ProfileRead>();
    store.slowUser['rA'] = read;
    make();
    await pumpEventQueue();
    auth.dispose();
    disposed = true;
    read.complete(store.users['rA']);
    await pumpEventQueue();
    expect(auth.user, isNull);
    expect(auth.isAuthenticated, isFalse);
    expect(store.tokens, isEmpty);
    expect(store.liveWatchers, 0);
  });
  test('owned logout still removes token, invalidates device and signs out',
      () async {
    make();
    await pumpEventQueue();
    await auth.signOut();
    await pumpEventQueue();
    expect(gateway.uid, isNull);
    expect(store.tokens['rA'], isEmpty);
    expect(push.forgotten, 1);
    expect(gateway.log, ['signOut']);
  });
  test('captured ticket expires on same UID renewal and disposal', () async {
    make();
    await pumpEventQueue();
    final version = auth.sessionVersion;
    expect(auth.isCurrentSession('rA', version), isTrue);
    gateway.emit('rA');
    await pumpEventQueue();
    expect(auth.isCurrentSession('rA', version), isFalse);
    expect(auth.isCurrentSession('rA', version, allowSignedOut: true), isFalse);
    final current = auth.sessionVersion;
    auth.dispose();
    disposed = true;
    expect(auth.isCurrentSession('rA', current), isFalse);
    expect(store.liveWatchers, 0);
    expect(push.refresh.hasListener, isFalse);
  });
  test('old partner event before SDK event cannot refresh new owner claims',
      () async {
    make();
    await pumpEventQueue();
    final before = gateway.claimRefreshes;
    gateway.uid = 'rB';
    store.partnerStreams['rA']!.add(fixture.doc({'status': 'suspended'}));
    await pumpEventQueue();
    expect(gateway.claimRefreshes, before);
    expect(store.log, ['add rA T1']);
  });
  test('late issued token write cannot replace B refresh subscription',
      () async {
    store.addition = Completer<void>();
    make();
    await pumpEventQueue();
    gateway.emit('rB');
    await pumpEventQueue();
    expect(auth.registeredToken, 'T1');
    store.addition!.complete();
    await pumpEventQueue();
    push.refresh.add('T2');
    await pumpEventQueue();
    expect(store.tokens['rB'], {'T2'});
    expect(store.log, isNot(contains('add rA T2')));
    expect(auth.registeredToken, 'T2');
  });
  test('revoked approval fences an outstanding token read', () async {
    push.read = Completer<String?>();
    make();
    await pumpEventQueue();
    store.partnerStreams['rA']!.add(fixture.doc({'status': 'suspended'}));
    await pumpEventQueue();
    push.read!.complete('late');
    await pumpEventQueue();
    expect(store.tokens, isEmpty);
    expect(auth.isBlocked, isTrue);
  });
  test('logout token fallback read cannot remove or invalidate newer SDK token',
      () async {
    push.token = null;
    make();
    await pumpEventQueue();
    push.read = Completer<String?>();
    final logout = auth.signOut();
    await pumpEventQueue();
    gateway.uid = 'rB';
    push.read!.complete('B-token');
    await logout;
    expect(store.log, isEmpty);
    expect(push.forgotten, 0);
    expect(gateway.uid, 'rB');
  });
  test('same UID renewal fences an outstanding logout', () async {
    make();
    await pumpEventQueue();
    store.removal = Completer<void>();
    final logout = auth.signOut();
    await pumpEventQueue();
    gateway.emit('rA');
    await pumpEventQueue();
    store.removal!.complete();
    await logout;
    expect(gateway.uid, 'rA');
    expect(push.forgotten, 0);
    expect(auth.isAuthenticated, isTrue);
  });
  test('reentrant listener SDK switch prevents any old profile read', () async {
    make();
    auth.addListener(() {
      if (auth.isLoading) gateway.uid = 'rB';
    });
    await pumpEventQueue();
    expect(store.userReads, isEmpty);
    expect(auth.user, isNull);
  });
  test('queued superseded auth event never reads its old UID', () async {
    make();
    await pumpEventQueue();
    store.userReads.clear();
    gateway.emit('rA');
    gateway.emit('rB');
    await pumpEventQueue();
    expect(store.userReads, ['rB']);
    expect(auth.user?.uid, 'rB');
  });
  test(
      'auth stream failure clears authority, cancels owned listeners and permits retry',
      () async {
    final controlled = ControlledGateway()..uid = 'rA';
    gateway = controlled;
    make();
    controlled.emit('rA');
    await pumpEventQueue();
    expect(auth.isAuthenticated, isTrue);
    controlled.events.addError(StateError('fixture unavailable'));
    await pumpEventQueue();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.profileUnavailable, isTrue);
    expect(store.liveWatchers, 0);
    expect(push.refresh.hasListener, isFalse);
    await auth.retryProfile();
    await pumpEventQueue();
    expect(auth.isAuthenticated, isTrue);
    await controlled.events.close();
  });
  test('disposed provider cannot begin a new signin or logout', () async {
    make();
    await pumpEventQueue();
    auth.dispose();
    disposed = true;
    expect(await auth.signIn('b@x.in', 'pwB'), isFalse);
    await auth.signOut();
    expect(gateway.uid, 'rA');
    expect(gateway.log, isEmpty);
    expect(push.forgotten, 0);
  });
}
