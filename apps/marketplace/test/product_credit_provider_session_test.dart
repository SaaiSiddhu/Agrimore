import 'dart:async';

import 'package:agrimore_marketplace/providers/product_credit_provider.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

class _EnabledFlags extends BenefitFlagService {
  @override
  Future<BenefitFeatureFlagsModel> fetchFlags() async =>
      const BenefitFeatureFlagsModel(benefitProgramEnabled: true);
}

class _ControlledFlags extends BenefitFlagService {
  _ControlledFlags(this.fetch);
  final Future<BenefitFeatureFlagsModel> Function() fetch;
  @override
  Future<BenefitFeatureFlagsModel> fetchFlags() => fetch();
}

const _enabled = BenefitFeatureFlagsModel(benefitProgramEnabled: true);
const _disabled = BenefitFeatureFlagsModel();

ProductCreditBalanceModel _balance(String uid, double amount) =>
    ProductCreditBalanceModel(
        customerId: uid, available: amount, updatedAt: DateTime.utc(2026));
ProductCreditLedgerModel _entry(String uid, String id) =>
    ProductCreditLedgerModel(
        id: id,
        customerId: uid,
        enrollmentId: 'fixture',
        type: 'CREDIT',
        amount: 1,
        createdAt: DateTime.utc(2026));
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Fixture {
  _Fixture(
      {Future<BenefitFeatureFlagsModel> Function()? flags,
      Future<List<ProductCreditLedgerModel>> Function(String)? ledger}) {
    provider = ProductCreditProvider(
      currentUserId: () => owner,
      authChanges: () => auth.stream,
      flagService: _ControlledFlags(() {
        flagReads++;
        return flags?.call() ?? Future.value(_enabled);
      }),
      balanceSnapshots: (uid) {
        balanceReads++;
        return streams.putIfAbsent(uid, _LateBalanceStream.new);
      },
      loadLedger: (uid) {
        ledgerReads++;
        return ledger?.call(uid) ?? Future.value([_entry(uid, 'current_$uid')]);
      },
    );
    addTearDown(() async {
      dispose();
      await auth.close();
    });
  }
  String? owner = 'owner_a';
  final auth = StreamController<String?>.broadcast();
  final streams = <String, _LateBalanceStream>{};
  late final ProductCreditProvider provider;
  int flagReads = 0, balanceReads = 0, ledgerReads = 0;
  bool disposed = false;
  void dispose() {
    if (!disposed) {
      disposed = true;
      provider.dispose();
    }
  }

  Future<void> switchTo(String? uid) async {
    owner = uid;
    auth.add(uid);
    await _settle();
  }

  void emit(String uid, int subscription, double amount) => streams[uid]!
      .subscriptions[subscription]
      .dataCallback
      ?.call(_balance(uid, amount));
}

class _LateSubscription
    implements StreamSubscription<ProductCreditBalanceModel> {
  _LateSubscription(this.dataCallback, this.errorCallback, this.doneCallback);
  void Function(ProductCreditBalanceModel)? dataCallback;
  Function? errorCallback;
  void Function()? doneCallback;
  int cancelCount = 0;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  void onData(void Function(ProductCreditBalanceModel data)? handleData) =>
      dataCallback = handleData;
  @override
  void onError(Function? handleError) => errorCallback = handleError;
  @override
  void onDone(void Function()? handleDone) => doneCallback = handleDone;
  @override
  void pause([Future<void>? resumeSignal]) {}
  @override
  void resume() {}
  @override
  bool get isPaused => false;
  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);
}

class _LateBalanceStream extends Stream<ProductCreditBalanceModel> {
  final subscriptions = <_LateSubscription>[];

  @override
  StreamSubscription<ProductCreditBalanceModel> listen(
    void Function(ProductCreditBalanceModel)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _LateSubscription(onData, onError, onDone);
    subscriptions.add(subscription);
    return subscription;
  }

  void emit(ProductCreditBalanceModel value) {
    for (final subscription in List.of(subscriptions)) {
      // Deliberately permits a queued callback after cancellation.
      subscription.dataCallback?.call(value);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('account switch clears credit and rejects late old-owner snapshots',
      () async {
    final auth = StreamController<String?>.broadcast();
    var owner = 'owner_a';
    final streams = <String, _LateBalanceStream>{};
    final provider = ProductCreditProvider(
      flagService: _EnabledFlags(),
      currentUserId: () => owner,
      authChanges: () => auth.stream,
      balanceSnapshots: (uid) =>
          streams.putIfAbsent(uid, _LateBalanceStream.new),
      loadLedger: (_) async => [],
    );
    ProductCreditBalanceModel balance(String uid, double amount) =>
        ProductCreditBalanceModel(
          customerId: uid,
          available: amount,
          updatedAt: DateTime.utc(2026),
        );

    await provider.init();
    streams['owner_a']!.emit(balance('owner_a', 75));
    expect(provider.available, 75);

    owner = 'owner_b';
    auth.add(owner);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(provider.available, 0);
    expect(streams['owner_a']!.subscriptions.single.cancelCount, 1);

    streams['owner_b']!.emit(balance('owner_b', 8));
    streams['owner_a']!.emit(balance('owner_a', 999));
    expect(provider.available, 8);
    expect(provider.balanceModel?.customerId, 'owner_b');

    provider.dispose();
    await auth.close();
  });
  test('disabled flags perform no credit reads', () async {
    final f = _Fixture(flags: () async => _disabled);
    await f.provider.init();
    expect(f.provider.isEnabled, false);
    expect(f.balanceReads, 0);
    expect(f.ledgerReads, 0);
  });

  test('signed out init performs no flag or credit reads', () async {
    final f = _Fixture()..owner = null;
    await f.provider.init();
    expect(f.provider.isEnabled, false);
    expect(f.provider.isLoading, false);
    expect(f.flagReads, 0);
    expect(f.balanceReads, 0);
    expect(f.ledgerReads, 0);
  });

  test('getters hide old data before auth event arrives', () async {
    final f = _Fixture();
    await f.provider.init();
    f.emit('owner_a', 0, 75);
    expect(f.provider.available, 75);
    expect(f.provider.ledger, isNotEmpty);
    f.owner = 'owner_b';
    expect(f.provider.available, 0);
    expect(f.provider.balanceModel, isNull);
    expect(f.provider.ledger, isEmpty);
    expect(f.provider.isEnabled, false);
    await f.switchTo(null);
    expect(f.provider.isLoading, false);
  });

  test('explicit new owner init clears data while flags wait', () async {
    final pending = Completer<BenefitFeatureFlagsModel>();
    var reads = 0;
    final f = _Fixture(
        flags: () => ++reads == 1 ? Future.value(_enabled) : pending.future);
    await f.provider.init();
    f.emit('owner_a', 0, 75);
    f.owner = 'owner_b';
    final next = f.provider.init();
    expect(f.provider.available, 0);
    expect(f.provider.ledger, isEmpty);
    expect(f.provider.isEnabled, false);
    pending.complete(_enabled);
    await next;
    expect(f.provider.ledger.single.customerId, 'owner_b');
  });

  test('late same owner flags cannot reenable disabled refresh', () async {
    final pending = Completer<BenefitFeatureFlagsModel>();
    var reads = 0;
    final f = _Fixture(
        flags: () => ++reads == 1 ? pending.future : Future.value(_disabled));
    final first = f.provider.init();
    await _settle();
    await f.provider.refresh();
    pending.complete(_enabled);
    await first;
    expect(f.provider.isEnabled, false);
    expect(f.balanceReads, 0);
    expect(f.ledgerReads, 0);
  });

  test('late flag failure cannot disable newer enabled refresh', () async {
    final pending = Completer<BenefitFeatureFlagsModel>();
    var reads = 0;
    final f = _Fixture(
        flags: () => ++reads == 1 ? pending.future : Future.value(_enabled));
    final first = f.provider.init();
    await _settle();
    await f.provider.refresh();
    pending.completeError(StateError('fixture old flags'));
    await first;
    expect(f.provider.isEnabled, true);
  });

  test('same owner refresh rejects canceled balance callbacks', () async {
    final f = _Fixture();
    await f.provider.init();
    f.emit('owner_a', 0, 75);
    await f.provider.refresh();
    f.emit('owner_a', 1, 8);
    f.emit('owner_a', 0, 999);
    expect(f.provider.available, 8);
  });

  test('disabled and reenabled refresh cannot revive old snapshot', () async {
    var enabled = true;
    final f = _Fixture(flags: () async => enabled ? _enabled : _disabled);
    await f.provider.init();
    f.emit('owner_a', 0, 75);
    enabled = false;
    await f.provider.refresh();
    f.emit('owner_a', 0, 999);
    expect(f.provider.available, 0);
    enabled = true;
    await f.provider.refresh();
    f.emit('owner_a', 0, 888);
    expect(f.provider.available, 0);
    f.emit('owner_a', 1, 8);
    expect(f.provider.available, 8);
  });

  test('newer same owner ledger survives old success', () async {
    final old = Completer<List<ProductCreditLedgerModel>>();
    var reads = 0;
    final f = _Fixture(
        ledger: (uid) =>
            ++reads == 1 ? old.future : Future.value([_entry(uid, 'latest')]));
    final first = f.provider.init();
    await _settle();
    await f.provider.refresh();
    old.complete([_entry('owner_a', 'old')]);
    await first;
    expect(f.provider.ledger.single.id, 'latest');
    expect(f.provider.hasLedgerError, false);
  });

  test('newer same owner ledger survives old failure', () async {
    final old = Completer<List<ProductCreditLedgerModel>>();
    var reads = 0;
    final f = _Fixture(
        ledger: (uid) =>
            ++reads == 1 ? old.future : Future.value([_entry(uid, 'latest')]));
    final first = f.provider.init();
    await _settle();
    await f.provider.refresh();
    old.completeError(StateError('fixture old ledger'));
    await first;
    expect(f.provider.ledger.single.id, 'latest');
    expect(f.provider.hasLedgerError, false);
  });

  test('A B A session cannot accept first A balance or ledger', () async {
    final old = Completer<List<ProductCreditLedgerModel>>();
    var reads = 0;
    final f = _Fixture(
        ledger: (uid) => ++reads == 1
            ? old.future
            : Future.value([_entry(uid, 'latest_$uid')]));
    final first = f.provider.init();
    await _settle();
    await f.switchTo('owner_b');
    await f.switchTo('owner_a');
    f.emit('owner_a', 1, 8);
    f.emit('owner_a', 0, 999);
    old.complete([_entry('owner_a', 'old_a')]);
    await first;
    expect(f.provider.available, 8);
    expect(f.provider.ledger.single.id, 'latest_owner_a');
  });

  test('late A flags cannot enable disabled B session', () async {
    final old = Completer<BenefitFeatureFlagsModel>();
    var reads = 0;
    final f = _Fixture(
        flags: () => ++reads == 1 ? old.future : Future.value(_disabled));
    final first = f.provider.init();
    await _settle();
    await f.switchTo('owner_b');
    old.complete(_enabled);
    await first;
    expect(f.provider.isEnabled, false);
    expect(f.balanceReads, 0);
    expect(f.ledgerReads, 0);
  });

  test('dispose during flag load prevents state or notification', () async {
    final old = Completer<BenefitFeatureFlagsModel>();
    final f = _Fixture(flags: () => old.future);
    var notifications = 0;
    f.provider.addListener(() => notifications++);
    final first = f.provider.init();
    final before = notifications;
    f.dispose();
    old.complete(_enabled);
    await first;
    expect(f.provider.isEnabled, false);
    expect(f.provider.isLoading, false);
    expect(notifications, before);
    expect(f.balanceReads, 0);
    expect(f.ledgerReads, 0);
  });

  test('dispose during ledger load rejects late data and hides cache',
      () async {
    final old = Completer<List<ProductCreditLedgerModel>>();
    final f = _Fixture(ledger: (_) => old.future);
    var notifications = 0;
    f.provider.addListener(() => notifications++);
    final first = f.provider.init();
    await _settle();
    f.emit('owner_a', 0, 75);
    final before = notifications;
    f.dispose();
    f.emit('owner_a', 0, 999);
    old.complete([_entry('owner_a', 'old')]);
    await first;
    expect(f.provider.available, 0);
    expect(f.provider.ledger, isEmpty);
    expect(f.provider.balanceModel, isNull);
    expect(notifications, before);
  });

  test('obsolete auth event cannot clear the current owner session', () async {
    final f = _Fixture();
    await f.provider.init();
    await f.switchTo('owner_b');
    f.emit('owner_b', 0, 8);
    final reads = f.flagReads;
    f.auth.add('owner_a');
    f.auth.add(null);
    await _settle();
    expect(f.provider.isEnabled, true);
    expect(f.provider.available, 8);
    expect(f.provider.ledger.single.customerId, 'owner_b');
    expect(f.flagReads, reads);
  });

  test('signed out provider binds a later sign in and clears on sign out',
      () async {
    final f = _Fixture();
    f.owner = null;
    await f.provider.init();
    expect(f.flagReads, 0);
    await f.switchTo('owner_b');
    f.emit('owner_b', 0, 8);
    expect(f.provider.available, 8);
    expect(f.provider.ledger.single.customerId, 'owner_b');
    await f.switchTo(null);
    f.emit('owner_b', 0, 999);
    expect(f.provider.isEnabled, false);
    expect(f.provider.isLoading, false);
    expect(f.provider.balanceModel, isNull);
    expect(f.provider.ledger, isEmpty);
    expect(f.provider.available, 0);
    expect(f.flagReads, 1);
    expect(f.balanceReads, 1);
    expect(f.ledgerReads, 1);
  });

  test('latest ledger error remains visible and valid retry clears it',
      () async {
    var reads = 0;
    final f = _Fixture(
        ledger: (uid) => ++reads == 1
            ? Future.error(StateError('fixture current ledger'))
            : Future.value([_entry(uid, 'recovered')]));
    await f.provider.init();
    expect(f.provider.hasLedgerError, true);
    expect(f.provider.isLoading, false);
    await f.provider.refresh();
    expect(f.provider.hasLedgerError, false);
    expect(f.provider.ledger.single.id, 'recovered');
  });
}
