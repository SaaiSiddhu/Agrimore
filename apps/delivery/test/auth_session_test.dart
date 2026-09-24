// Phase DLV-C1 — one rider session at a time: the profile is loaded once,
// a slow answer for the previous rider is dropped, refusals are typed, and
// this device's push token follows the session (added while the rider may
// work, moved on refresh, removed and invalidated before sign-out).
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements RiderAuthGateway {
  final _uids = StreamController<String?>.broadcast();
  String? uid;
  final log = <String>[];
  Map<String, String> passwords = {'a@x.in': 'pw A ', 'b@x.in': 'pwB', 'cust@x.in': 'pwC'};
  Map<String, String> uidOf = {'a@x.in': 'rA', 'b@x.in': 'rB', 'cust@x.in': 'cust'};
  int claimRefreshes = 0;

  @override
  Stream<String?> get uidChanges async* {
    yield uid;
    yield* _uids.stream;
  }

  @override
  String? get currentUid => uid;

  void emit(String? next) {
    uid = next;
    _uids.add(next);
  }

  @override
  Future<void> signIn(String email, String password) async {
    log.add('signIn $email');
    if (passwords[email] != password) throw const RiderAuthFailure('invalid-credential');
    emit(uidOf[email]);
  }

  @override
  Future<void> signOut() async {
    log.add('signOut');
    emit(null);
  }

  @override
  Future<void> refreshClaims() async => claimRefreshes++;

  final resets = <String>[];
  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@')) throw const RiderAuthFailure('invalid-email');
    if (email.startsWith('broken')) throw const RiderAuthFailure('api-key-not-valid');
    resets.add(email); // known or unknown: the same outcome
  }
}

class FakeStore implements RiderAccountStore {
  final users = <String, ProfileRead>{};
  final partners = <String, ProfileRead>{};
  final Map<String, Completer<ProfileRead>> slowUser = {};
  final partnerStreams = <String, StreamController<ProfileRead>>{};
  final userReads = <String>[];
  final tokens = <String, Set<String>>{};
  final log = <String>[];

  @override
  Future<ProfileRead> user(String uid) {
    userReads.add(uid);
    final slow = slowUser[uid];
    if (slow != null) return slow.future;
    return Future.value(users[uid] ?? const ProfileRead(exists: false, fromCache: false));
  }

  @override
  Future<ProfileRead> partner(String uid) async =>
      partners[uid] ?? const ProfileRead(exists: false, fromCache: false);

  @override
  Stream<ProfileRead> watchPartner(String uid) =>
      (partnerStreams[uid] = StreamController<ProfileRead>.broadcast()).stream;

  int get liveWatchers => partnerStreams.values.where((c) => c.hasListener).length;

  @override
  Future<void> addToken(String uid, String token) async {
    log.add('add $uid $token');
    (tokens[uid] ??= {}).add(token);
  }

  @override
  Future<void> removeToken(String uid, String token) async {
    log.add('remove $uid $token');
    tokens[uid]?.remove(token);
  }
}

class FakePush implements RiderPushTokens {
  String? token = 'T1';
  final refresh = StreamController<String>.broadcast();
  int forgotten = 0;

  @override
  Future<String?> current() async => token;

  @override
  Stream<String> get refreshed => refresh.stream;

  @override
  Future<void> forget() async {
    forgotten++;
    token = 'T-after-delete';
  }
}

ProfileRead doc(Map<String, dynamic> data) => ProfileRead(exists: true, fromCache: false, data: data);

void main() {
  late FakeGateway gw;
  late FakeStore store;
  late FakePush push;

  setUp(() {
    gw = FakeGateway();
    store = FakeStore()
      ..users['rA'] = doc({'email': 'a@x.in', 'name': 'Asha', 'role': 'delivery_partner'})
      ..partners['rA'] = doc({'status': 'approved'})
      ..users['rB'] = doc({'email': 'b@x.in', 'name': 'Bala', 'role': 'delivery_partner'})
      ..partners['rB'] = doc({'status': 'approved'})
      ..users['cust'] = doc({'email': 'cust@x.in', 'name': 'C', 'role': 'user'});
    push = FakePush();
  });

  DeliveryAuthProvider make() => DeliveryAuthProvider(gateway: gw, store: store, pushTokens: push);

  test('sign-in loads the profile once and registers the token', () async {
    final p = make();
    await pumpEventQueue();
    expect(await p.signIn(' a@x.in ', 'pw A '), isTrue, reason: 'password used exactly as typed (trailing space)');
    await pumpEventQueue();
    expect(store.userReads.where((u) => u == 'rA'), hasLength(1));
    expect(p.isAuthenticated, isTrue);
    expect(store.tokens['rA'], {'T1'});
  });

  test('a failed sign-in never shows the gate\'s loading screen (it wiped the form)', () async {
    final p = make();
    await pumpEventQueue();
    final seen = <bool>[];
    p.addListener(() => seen.add(p.isLoading));
    final f = p.signIn('a@x.in', 'nope');
    expect(p.signingIn, isTrue);
    await f;
    expect(seen, everyElement(isFalse));
    expect(p.signingIn, isFalse);
  });

  test('password reset: same answer for known and unknown emails; malformed email is a problem', () async {
    final p = make();
    await pumpEventQueue();
    expect(await p.sendPasswordReset(' a@x.in '), isNull);
    expect(await p.sendPasswordReset('nobody@x.in'), isNull);
    expect(gw.resets, ['a@x.in', 'nobody@x.in']);
    expect(await p.sendPasswordReset('not-an-email'), RiderAuthProblem.invalidEmail);
    // A real failure is never reported as "sent" (the DLV-A1 browser run
    // hit a misconfigured key and the old code said the link was on its way).
    expect(await p.sendPasswordReset('broken@x.in'), RiderAuthProblem.unknown);
  });

  test('wrong password is a typed problem, not a raw message', () async {
    final p = make();
    await pumpEventQueue();
    expect(await p.signIn('a@x.in', 'nope'), isFalse);
    expect(p.problem, RiderAuthProblem.wrongCredentials);
    expect(authProblemOf('too-many-requests'), RiderAuthProblem.tooManyAttempts);
    expect(authProblemOf('whatever'), RiderAuthProblem.unknown);
  });

  test('a customer account is refused, signed out, and told why', () async {
    final p = make();
    await pumpEventQueue();
    expect(await p.signIn('cust@x.in', 'pwC'), isFalse);
    await pumpEventQueue();
    expect(gw.uid, isNull);
    expect(p.problem, RiderAuthProblem.notDeliveryPartner);
    expect(store.tokens['cust'], isNull, reason: 'no push token for a refused account');
  });

  // DLV-A1: an account without a rider record resumes registration — it is
  // never signed out (that would break an in-progress registration).
  test('no rider record on the server = needs registration, still signed in; a cache miss is only "unavailable"', () async {
    store.partners.remove('rA');
    final p = make();
    await pumpEventQueue();
    await p.signIn('a@x.in', 'pw A ');
    await pumpEventQueue();
    expect(p.needsRegistration, isTrue);
    expect(p.problem, isNull);
    expect(gw.uid, 'rA');
    expect(store.tokens['rA'], isNull, reason: 'no push token before approval');

    store.partners['rA'] = const ProfileRead(exists: false, fromCache: true);
    await p.signIn('a@x.in', 'pw A ');
    await pumpEventQueue();
    expect(p.profileUnavailable, isTrue);
    expect(gw.uid, 'rA', reason: 'not signed out for a cache miss');
    store.partners['rA'] = doc({'status': 'approved'});
    await p.retryProfile();
    expect(p.isAuthenticated, isTrue);
  });

  test('account switch: rider A\'s slow profile never lands in rider B\'s session', () async {
    final p = make();
    await pumpEventQueue();
    final slowA = store.slowUser['rA'] = Completer<ProfileRead>();
    gw.emit('rA');
    await pumpEventQueue();
    gw.emit('rB');
    await pumpEventQueue();
    slowA.complete(doc({'email': 'a@x.in', 'name': 'Asha', 'role': 'delivery_partner'}));
    await pumpEventQueue();
    expect(p.user?.uid, 'rB');
    expect(store.tokens['rA'], isNull, reason: 'A\'s late load registered nothing');
  });

  test('a brand-new account (no profile at all) needs registration; a profile without a role may register', () async {
    final p = make();
    await pumpEventQueue();
    gw.emit('fresh');
    await pumpEventQueue();
    expect(p.needsRegistration, isTrue);
    expect(gw.uid, 'fresh');
    store.users['half'] = doc({'email': 'h@x.in', 'name': 'H'});
    store.partners['half'] = doc({'status': 'pending'});
    gw.emit('half');
    await pumpEventQueue();
    expect(p.needsRegistration, isTrue, reason: 'role not set yet: registration was never submitted');
    store.users['half'] = doc({'email': 'h@x.in', 'name': 'H', 'role': 'delivery_partner'});
    await p.registrationSubmitted();
    expect(p.needsRegistration, isFalse);
    expect(p.isBlocked, isTrue, reason: 'pending');
  });

  test('sign-out removes then invalidates the token, before signing out', () async {
    final p = make();
    await pumpEventQueue();
    await p.signIn('a@x.in', 'pw A ');
    await pumpEventQueue();
    await p.signOut();
    await pumpEventQueue();
    expect(store.tokens['rA'], isEmpty);
    expect(push.forgotten, 1);
    expect(store.log.last, 'remove rA T1');
    expect(gw.log.last, 'signOut');
    expect(p.user, isNull);
    // B signs in on the same phone: only B holds this device's (new) token.
    await p.signIn('b@x.in', 'pwB');
    await pumpEventQueue();
    expect(store.tokens['rB'], {'T-after-delete'});
    expect(store.tokens['rA'], isEmpty);
  });

  test('token refresh moves the token', () async {
    final p = make();
    await pumpEventQueue();
    await p.signIn('a@x.in', 'pw A ');
    await pumpEventQueue();
    push.refresh.add('T2');
    await pumpEventQueue();
    expect(store.tokens['rA'], {'T2'});
    expect(p.registeredToken, 'T2');
  });

  test('suspension during the session: blocked, token removed, claims refreshed', () async {
    final p = make();
    await pumpEventQueue();
    await p.signIn('a@x.in', 'pw A ');
    await pumpEventQueue();
    store.partnerStreams['rA']!.add(doc({'status': 'suspended', 'suspensionReason': 'Cash not deposited'}));
    await pumpEventQueue();
    expect(p.isBlocked, isTrue);
    expect(p.kycStatus, RiderKycStatus.suspended);
    expect(p.statusReason, 'Cash not deposited');
    expect(store.tokens['rA'], isEmpty);
    expect(gw.claimRefreshes, 1);
    // A cache-only "missing" partner doc is ignored.
    store.partnerStreams['rA']!.add(const ProfileRead(exists: false, fromCache: true));
    await pumpEventQueue();
    expect(p.kycStatus, RiderKycStatus.suspended);
  });

  test('repeated sign-ins keep exactly one partner listener', () async {
    final p = make();
    await pumpEventQueue();
    for (var i = 0; i < 3; i++) {
      await p.signIn('a@x.in', 'pw A ');
      await pumpEventQueue();
      await p.signOut();
      await pumpEventQueue();
    }
    await p.signIn('a@x.in', 'pw A ');
    await pumpEventQueue();
    expect(store.liveWatchers, 1);
  });
}
