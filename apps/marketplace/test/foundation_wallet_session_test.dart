@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/wallet_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// Cached official platform transports; all operations are isolated fixtures.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends FirebaseAuthPlatform {
  String? uid = 'owner_a';
  int cancelled = 0;
  late StreamController<UserPlatform?> changes;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  Stream<UserPlatform?> authStateChanges() => changes.stream;
  void switchTo(String? owner) {
    uid = owner;
    changes.add(currentUser);
  }

  @override
  UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth, String uid)
      : super(
            auth,
            _Factor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid,
                    isAnonymous: false,
                    isEmailVerified: true,
                    email: 'fixture@example.invalid'),
                providerData: []));
}

// The production Firestore codec intentionally decodes replies only; native
// query requests contain FieldPath tags. This fixture reads those native tags
// without changing the production client or its query representation.
class _QueryRequestCodec extends StandardMessageCodec {
  const _QueryRequestCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 131:
        return fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!);
      case 135:
        return fs.PigeonFirebaseSettings.decode(readValue(buffer)!);
      case 136:
        return fs.PigeonGetOptions.decode(readValue(buffer)!);
      case 137:
        return fs.PigeonQueryParameters.decode(readValue(buffer)!);
      case 192:
        final length = readSize(buffer);
        return fs.FieldPath(
            List<String>.generate(length, (_) => readValue(buffer)! as String));
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

// Deliberate transport double for cancelled/late callbacks; real get/query
// snapshots are still exercised through the official native codec above.
// ignore: subtype_of_sealed_class
class _Doc implements DocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Subscription
    implements StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> {
  _Subscription(this.data, this.error, this.done);
  final void Function(DocumentSnapshot<Map<String, dynamic>>)? data;
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

class _Stream extends Stream<DocumentSnapshot<Map<String, dynamic>>> {
  final subscriptions = <_Subscription>[];
  @override
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> listen(
      void Function(DocumentSnapshot<Map<String, dynamic>>)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    final s = _Subscription(onData, onError, onDone);
    subscriptions.add(s);
    return s;
  }

  void emit(_Doc doc) {
    for (final s in List.of(subscriptions)) {
      s.data?.call(doc);
    }
  }

  void fail() {
    for (final s in List.of(subscriptions)) {
      Function.apply(s.error!, [StateError('PRIVATE_WALLET_FIXTURE')]);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const documents = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const writes = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet',
      fs.FirebaseFirestoreHostApi.codec);
  const queries = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.queryGet',
      fs.FirebaseFirestoreHostApi.codec);
  const functions = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  late _Auth auth;
  late WalletProvider wallet;
  late Map<String, List<_Stream>> streams;
  late List<fs.DocumentReferenceRequest> readCalls, writeCalls;
  late List<Map> callableCalls;
  late List<List> queryCalls;
  late Future<List<Object?>> Function(fs.DocumentReferenceRequest) read;
  late Future<List<Object?>> Function(fs.DocumentReferenceRequest) write;
  late Future<List<Object?>> Function(List) query;
  late Future<List<Object?>> Function(Map) callable;
  fs.PigeonDocumentSnapshot document(String path, Map<String, Object?>? data) =>
      fs.PigeonDocumentSnapshot(
          path: path,
          data: data,
          metadata: fs.PigeonSnapshotMetadata(
              hasPendingWrites: false, isFromCache: false));
  Map<String, dynamic> data(String owner, {double balance = 10}) => {
        'userId': owner,
        'balance': balance,
        'coins': 3,
        'lifetimeEarnings': 10.0,
        'referralCode': 'OWNED_$owner'
      };
  List<Object?> history(String owner,
          {String id = 'history', int created = 1}) =>
      [
        fs.PigeonQuerySnapshot(
            documents: [
              document('wallet_transactions/$id', {
                'userId': owner,
                'walletId': owner,
                'amount': 10.0,
                'createdAt': Timestamp.fromMillisecondsSinceEpoch(created)
              })
            ],
            documentChanges: [],
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
  _Stream latest(String owner) => streams[owner]!.last;
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  WalletProvider make() => WalletProvider(walletSnapshots: (owner) {
        final stream = _Stream();
        streams.putIfAbsent(owner, () => []).add(stream);
        return stream;
      });
  setUpAll(() async {
    await Firebase.initializeApp();
    auth = _Auth();
    FirebaseAuthPlatform.instance = auth;
  });
  setUp(() async {
    auth.uid = 'owner_a';
    auth.cancelled = 0;
    auth.changes = StreamController<UserPlatform?>.broadcast(onCancel: () {
      auth.cancelled++;
    });
    streams = {};
    readCalls = [];
    writeCalls = [];
    callableCalls = [];
    queryCalls = [];
    read = (r) async => [
          document(
              r.path,
              r.path.startsWith('wallets/')
                  ? data(r.path.split('/').last)
                  : null)
        ];
    write = (_) async => [null];
    query = (args) async {
      final p = args[3] as fs.PigeonQueryParameters;
      return history(p.where!.single![2] as String);
    };
    callable = (_) async => [
          {'success': true}
        ];
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      readCalls.add(r);
      return read(r);
    });
    messenger.setMockDecodedMessageHandler<Object?>(writes, (message) async {
      final r = (message! as List)[1] as fs.DocumentReferenceRequest;
      writeCalls.add(r);
      return write(r);
    });
    messenger.setMockMessageHandler(queries.name, (message) async {
      final args = const _QueryRequestCodec().decodeMessage(message)! as List;
      queryCalls.add(args);
      return fs.FirebaseFirestoreHostApi.codec.encodeMessage(await query(args));
    });
    messenger.setMockDecodedMessageHandler<Object?>(functions, (message) async {
      final call = (message! as List).single as Map;
      callableCalls.add(call);
      return callable(call);
    });
    wallet = make();
    await drain();
    readCalls.clear();
  });
  tearDown(() async {
    wallet.dispose();
    await auth.changes.close();
    for (final c in [documents, writes, queries, functions]) {
      messenger.setMockDecodedMessageHandler<Object?>(c, null);
    }
  });
  void own() => latest('owner_a').emit(_Doc('owner_a', data('owner_a')));
  test('owned snapshot and history exposed; repeated loads keep one listener',
      () async {
    own();
    await wallet.loadTransactions();
    await wallet.loadWallet();
    expect(wallet.balance, 10);
    expect(wallet.coins, 3);
    expect(wallet.transactions.single.userId, 'owner_a');
    expect(streams['owner_a']!.length, 1);
    expect(wallet.referralCode, 'OWNED_owner_a');
  });
  test('account change hides balance, history and referral before auth event',
      () async {
    own();
    await wallet.loadTransactions();
    auth.uid = 'owner_b';
    expect(wallet.balance, 0);
    expect(wallet.coins, 0);
    expect(wallet.wallet, isNull);
    expect(wallet.transactions, isEmpty);
    expect(wallet.referralCode, isNot('OWNED_owner_a'));
    expect(wallet.canUseWallet, false);
  });
  test('auth change cancels old listener and clears pending state', () async {
    own();
    await wallet.loadTransactions();
    final old = latest('owner_a');
    auth.switchTo('owner_b');
    await drain();
    expect(old.subscriptions.single.cancelled, 1);
    expect(wallet.transactions, isEmpty);
    expect(wallet.balance, 0);
    latest('owner_b').emit(_Doc('owner_b', data('owner_b', balance: 20)));
    expect(wallet.balance, 20);
  });
  test('late cancelled wallet snapshot and error never overwrite new owner',
      () async {
    own();
    final old = latest('owner_a');
    auth.switchTo('owner_b');
    await drain();
    latest('owner_b').emit(_Doc('owner_b', data('owner_b', balance: 20)));
    old.emit(_Doc('owner_a', data('owner_a', balance: 999)));
    old.fail();
    expect(wallet.balance, 20);
    expect(wallet.error, isNull);
    expect(latest('owner_b').subscriptions.single.cancelled, 0);
  });
  test('same account return fences old session reply by epoch', () async {
    own();
    final old = latest('owner_a');
    auth.switchTo('owner_b');
    await drain();
    auth.switchTo('owner_a');
    await drain();
    latest('owner_a').emit(_Doc('owner_a', data('owner_a', balance: 20)));
    old.emit(_Doc('owner_a', data('owner_a', balance: 999)));
    expect(wallet.balance, 20);
  });
  test('signout cancels private listener and hides all account projections',
      () async {
    own();
    await wallet.loadTransactions();
    final old = latest('owner_a');
    auth.switchTo(null);
    await drain();
    expect(old.subscriptions.single.cancelled, 1);
    expect(wallet.balance, 0);
    expect(wallet.transactions, isEmpty);
    expect(wallet.referralCode, '');
  });
  test('dispose cancels auth/wallet and ignores late notification callbacks',
      () async {
    own();
    final old = latest('owner_a');
    var count = 0;
    wallet.addListener(() => count++);
    wallet.dispose();
    old.emit(_Doc('owner_a', data('owner_a')));
    old.fail();
    await drain();
    expect(old.subscriptions.single.cancelled, 1);
    expect(auth.cancelled, 1);
    expect(count, 0);
    expect(wallet.balance, 0);
    expect(wallet.referralCode, '');
    wallet = make();
  });
  for (final invalid in [
    null,
    {'userId': 'other_owner', 'balance': 100.0},
    {'userId': 'owner_a', 'balance': double.nan}
  ]) {
    test('deleted or invalid wallet snapshot clears stale balance $invalid',
        () {
      own();
      latest('owner_a').emit(_Doc('owner_a', invalid));
      expect(wallet.wallet, isNull);
      expect(wallet.balance, 0);
    });
  }
  test('negative owned reversal balance remains supported', () {
    latest('owner_a').emit(_Doc('owner_a', data('owner_a', balance: -10)));
    expect(wallet.balance, -10);
  });
  test('listener error is safe, cancels subscription and can retry', () async {
    own();
    final old = latest('owner_a');
    old.fail();
    expect(old.subscriptions.single.cancelled, 1);
    expect(wallet.error, contains('Please refresh'));
    expect(wallet.error, isNot(contains('PRIVATE')));
    await wallet.loadWallet();
    expect(streams['owner_a']!.length, 2);
    expect(wallet.balance, 10);
  });
  test('old wallet read cannot publish new owner balance or loading state',
      () async {
    own();
    final reply = Completer<void>();
    read = (r) async {
      await reply.future;
      return [document(r.path, data('owner_a', balance: 999))];
    };
    final pending = wallet.loadWallet();
    await drain();
    auth.switchTo('owner_b');
    await drain();
    latest('owner_b').emit(_Doc('owner_b', data('owner_b', balance: 20)));
    reply.complete();
    await pending;
    expect(wallet.balance, 20);
    expect(wallet.isLoading, false);
    expect(wallet.error, isNull);
  });
  test('missing wallet reply after switch cannot create or grant bonus',
      () async {
    final reply = Completer<void>();
    read = (r) async {
      await reply.future;
      return [document(r.path, null)];
    };
    final pending = wallet.loadWallet();
    await drain();
    auth.switchTo('owner_b');
    await drain();
    reply.complete();
    await pending;
    expect(writeCalls, isEmpty);
    expect(callableCalls, isEmpty);
  });
  test('account switch after zero-wallet write prevents signup call', () async {
    read = (r) async => [document(r.path, null)];
    write = (r) async {
      auth.switchTo('owner_b');
      await drain();
      return [null];
    };
    await wallet.loadWallet();
    expect(writeCalls.single.path, 'wallets/owner_a');
    expect(writeCalls.single.data!['balance'], 0);
    expect(callableCalls, isEmpty);
    expect(wallet.wallet, isNull);
  });
  test('zero-only create preserves server signup bonus command', () async {
    read = (r) async => [document(r.path, null)];
    await wallet.loadWallet();
    expect(writeCalls.single.data!['userId'], 'owner_a');
    expect(writeCalls.single.data!['balance'], 0);
    expect(writeCalls.single.data!['coins'], 0);
    expect(callableCalls.single['functionName'], 'creditSignupBonus');
    expect(callableCalls.single['parameters']['checkoutOwnerId'], 'owner_a');
  });
  test(
      'new server snapshot credit during wallet create is never overwritten by empty local wallet',
      () async {
    read = (r) async => [document(r.path, null)];
    write = (r) async {
      latest('owner_a').emit(_Doc('owner_a', data('owner_a', balance: 100)));
      return [null];
    };
    await wallet.loadWallet();
    expect(wallet.balance, 100);
  });
  test('later wallet read wins over earlier reply', () async {
    final old = Completer<void>();
    var n = 0;
    read = (r) async {
      if (++n == 1) {
        await old.future;
        return [document(r.path, data('owner_a', balance: 999))];
      }
      return [document(r.path, data('owner_a', balance: 20))];
    };
    final first = wallet.loadWallet();
    await drain();
    await wallet.loadWallet();
    old.complete();
    await first;
    expect(wallet.balance, 20);
    expect(wallet.isLoading, false);
  });
  test('server confirmation supersedes older wallet load without stuck loading',
      () async {
    final old = Completer<void>();
    var n = 0;
    read = (r) async {
      if (++n == 1) {
        await old.future;
        return [document(r.path, data('owner_a', balance: 999))];
      }
      return [document(r.path, data('owner_a', balance: 20))];
    };
    final first = wallet.loadWallet();
    await drain();
    await wallet.refreshWalletForOwner('owner_a');
    old.complete();
    await first;
    expect(wallet.balance, 20);
    expect(wallet.isLoading, false);
  });
  test(
      'dispose while wallet read pending prevents create/listener resurrection',
      () async {
    final reply = Completer<void>();
    read = (r) async {
      await reply.future;
      return [document(r.path, null)];
    };
    final pending = wallet.loadWallet();
    await drain();
    wallet.dispose();
    reply.complete();
    await pending;
    expect(writeCalls, isEmpty);
    expect(callableCalls, isEmpty);
    expect(streams['owner_a']!.length, 1);
    wallet = make();
  });
  test('late history reply cannot expose old owner transactions', () async {
    final old = Completer<void>();
    query = (args) async {
      await old.future;
      return history('owner_a');
    };
    final pending = wallet.loadTransactions();
    await drain();
    auth.switchTo('owner_b');
    await drain();
    old.complete();
    await pending;
    expect(wallet.transactions, isEmpty);
    expect(wallet.isLoadingTransactions, false);
    expect(wallet.error, isNull);
  });
  test('newer history request wins and old finally does not clear pending flag',
      () async {
    final old = Completer<void>();
    var n = 0;
    query = (args) async {
      if (++n == 1) {
        await old.future;
        return history('owner_a', id: 'old');
      }
      return history('owner_a', id: 'new');
    };
    final first = wallet.loadTransactions();
    await drain();
    await wallet.loadTransactions();
    old.complete();
    await first;
    expect(wallet.transactions.single.id, 'new');
    expect(wallet.isLoadingTransactions, false);
  });
  test('wrong-owner history row rejected despite matching requested filter',
      () async {
    query = (_) async => history('other_owner');
    await wallet.loadTransactions();
    expect(wallet.transactions, isEmpty);
    expect(wallet.error, contains('history could not be loaded'));
  });
  test('history list cannot be mutated by caller', () async {
    await wallet.loadTransactions();
    expect(() => wallet.transactions.clear(), throwsUnsupportedError);
  });
  test('history sorted and existing requested local limit retained', () async {
    query = (_) async => [
          fs.PigeonQuerySnapshot(
              documents: [
                document('wallet_transactions/old', {
                  'userId': 'owner_a',
                  'createdAt': Timestamp.fromMillisecondsSinceEpoch(1)
                }),
                document('wallet_transactions/new', {
                  'userId': 'owner_a',
                  'createdAt': Timestamp.fromMillisecondsSinceEpoch(2)
                })
              ],
              documentChanges: [],
              metadata: fs.PigeonSnapshotMetadata(
                  hasPendingWrites: false, isFromCache: false))
        ];
    await wallet.loadTransactions(limit: 1);
    expect(wallet.transactions.single.id, 'new');
  });
  test('old history failure cannot publish new owner error', () async {
    final old = Completer<void>();
    query = (_) async {
      await old.future;
      return ['unavailable', 'PRIVATE_WALLET_FIXTURE', null];
    };
    final pending = wallet.loadTransactions();
    await drain();
    auth.switchTo('owner_b');
    await drain();
    old.complete();
    await pending;
    expect(wallet.error, isNull);
  });
  test('disposed global configuration reply cannot notify or start listener',
      () async {
    final old = Completer<void>();
    read = (r) async {
      await old.future;
      return [
        document(r.path, {'maxCoinsPercentage': 30})
      ];
    };
    var count = 0;
    wallet.addListener(() => count++);
    final pending = wallet.loadConfig();
    await drain();
    wallet.dispose();
    old.complete();
    await pending;
    expect(count, 0);
    expect(streams['owner_a']!.length, 1);
    wallet = make();
  });
  test('later global configuration read wins', () async {
    final old = Completer<void>();
    var n = 0;
    read = (r) async {
      if (++n == 1) {
        await old.future;
        return [
          document(r.path, {'maxCoinsPercentage': 10})
        ];
      }
      return [
        document(r.path, {'maxCoinsPercentage': 30})
      ];
    };
    final first = wallet.loadConfig();
    await drain();
    await wallet.loadConfig();
    old.complete();
    await first;
    expect(wallet.config.maxCoinsPercentage, 30);
  });
  test('topup forwards captured owner and does not load next account history',
      () async {
    own();
    callable = (call) async {
      auth.switchTo('owner_b');
      await drain();
      return [
        {'success': true}
      ];
    };
    await expectLater(
        wallet.addMoney(100, 'pay_fixture',
            orderId: 'order_fixture', signature: 'fixture'),
        throwsStateError);
    expect(callableCalls.single['parameters']['checkoutOwnerId'], 'owner_a');
    expect(queryCalls, isEmpty);
    expect(wallet.balance, 0);
  });
  test('referral call reply cannot refresh next account wallet', () async {
    own();
    callable = (call) async {
      auth.switchTo('owner_b');
      await drain();
      return [
        {'success': true}
      ];
    };
    await expectLater(
        wallet.applyReferralCode('PUBLIC_FIXTURE'), throwsStateError);
    expect(callableCalls.single['functionName'], 'redeemReferralCode');
    expect(readCalls, isEmpty);
  });
  test(
      'same-user session renewal prevents pending server receipt acknowledgement',
      () async {
    final old = Completer<void>();
    read = (r) async {
      await old.future;
      return [document(r.path, data('owner_a'))];
    };
    final pending = wallet.refreshWalletForOwner('owner_a');
    await drain();
    auth.switchTo('owner_b');
    await drain();
    auth.switchTo('owner_a');
    await drain();
    old.complete();
    await expectLater(pending, throwsStateError);
  });
  test('disposed refresh refuses any new reads or commands', () async {
    wallet.dispose();
    await wallet.refresh();
    await wallet.loadWallet();
    await wallet.loadTransactions();
    expect(readCalls, isEmpty);
    expect(queryCalls, isEmpty);
    expect(callableCalls, isEmpty);
    wallet = make();
  });
  test('older history completion cannot clear newer pending loading flag',
      () async {
    final older = Completer<void>(), newer = Completer<void>();
    var n = 0;
    query = (_) async {
      final first = ++n == 1;
      await (first ? older.future : newer.future);
      return history('owner_a', id: first ? 'old' : 'new');
    };
    final first = wallet.loadTransactions();
    await drain();
    final second = wallet.loadTransactions();
    await drain();
    older.complete();
    await first;
    expect(wallet.isLoadingTransactions, true);
    expect(wallet.transactions, isEmpty);
    newer.complete();
    await second;
    expect(wallet.isLoadingTransactions, false);
    expect(wallet.transactions.single.id, 'new');
  });
  test(
      'legacy wallet without redundant userId remains bound to owned document path',
      () async {
    read = (r) async => [
          document(r.path, {'balance': 10.0, 'coins': 3})
        ];
    await wallet.refreshWalletForOwner('owner_a');
    expect(wallet.wallet!.userId, 'owner_a');
    expect(wallet.balance, 10);
  });
  test(
      'closed wallet stream invalidates pending read and clears its loading flag',
      () async {
    own();
    final old = latest('owner_a');
    final reply = Completer<void>();
    read = (r) async {
      await reply.future;
      return [document(r.path, data('owner_a', balance: 999))];
    };
    final pending = wallet.loadWallet();
    await drain();
    expect(wallet.isLoading, true);
    old.subscriptions.single.done!();
    expect(wallet.isLoading, false);
    expect(old.subscriptions.single.cancelled, 1);
    reply.complete();
    await pending;
    expect(wallet.balance, 10);
    expect(wallet.error, contains('updates paused'));
  });
}
