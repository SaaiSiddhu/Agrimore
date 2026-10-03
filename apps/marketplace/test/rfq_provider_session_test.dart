import 'dart:async';
import 'package:agrimore_marketplace/providers/rfq_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

RfqModel row(String uid, String id, [int day = 1]) => RfqModel(
    id: id,
    buyerId: uid,
    sellerId: 'seller',
    productId: 'product',
    status: RfqStatus.pending,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026, 1, day));
Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class Fixture {
  Fixture(
      {Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
          call}) {
    provider = RfqProvider(
        currentUserId: () => owner,
        authChanges: () => auth.stream,
        rfqSnapshots: (uid) {
          reads++;
          return streams.putIfAbsent(uid, _LateRfqStream.new);
        },
        call: (name, data) {
          calls.add((name, data));
          return call?.call(name, data) ??
              Future.value({'rfqId': 'created', 'orderId': 'order'});
        });
    addTearDown(() async {
      dispose();
      await auth.close();
    });
  }
  String? owner = 'a';
  final auth = StreamController<String?>.broadcast();
  final streams = <String, _LateRfqStream>{};
  final calls = <(String, Map<String, dynamic>)>[];
  late RfqProvider provider;
  bool disposed = false;
  int reads = 0;
  void dispose() {
    if (!disposed) {
      disposed = true;
      provider.dispose();
    }
  }

  Future<void> switchTo(String? uid) async {
    owner = uid;
    auth.add(uid);
    await settle();
  }

  void emit(String uid, int subscription, String id) =>
      streams[uid]!.subscriptions[subscription].dataCallback!([row(uid, id)]);
}

class _LateSubscription implements StreamSubscription<List<RfqModel>> {
  _LateSubscription(this.dataCallback, this.errorCallback, this.doneCallback);
  void Function(List<RfqModel>)? dataCallback;
  Function? errorCallback;
  void Function()? doneCallback;
  int cancelCount = 0;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  void onData(void Function(List<RfqModel> data)? handleData) =>
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

class _LateRfqStream extends Stream<List<RfqModel>> {
  final subscriptions = <_LateSubscription>[];

  @override
  StreamSubscription<List<RfqModel>> listen(
    void Function(List<RfqModel>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _LateSubscription(onData, onError, onDone);
    subscriptions.add(subscription);
    return subscription;
  }

  void emit(List<RfqModel> value) {
    for (final subscription in List.of(subscriptions)) {
      // Deliberately permits a queued callback after cancellation.
      subscription.dataCallback?.call(value);
    }
  }
}

void main() {
  test('current owner rows sort newest first', () async {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.streams['a']!.subscriptions.single
        .dataCallback!([row('a', 'old'), row('a', 'new', 2)]);
    expect(f.provider.myRfqs.map((r) => r.id), ['new', 'old']);
    expect(f.provider.isLoading, false);
  });
  test('identity change hides rows before auth delivery', () {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.emit('a', 0, 'private');
    f.owner = 'b';
    expect(f.provider.myRfqs, isEmpty);
    expect(f.provider.isLoading, false);
  });
  test('switch binds new owner and old callbacks cannot overwrite', () async {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.emit('a', 0, 'private');
    await f.switchTo('b');
    expect(f.provider.myRfqs, isEmpty);
    f.emit('b', 0, 'new');
    f.emit('a', 0, 'late');
    expect(f.provider.myRfqs.single.id, 'new');
  });
  test('same owner reload rejects canceled snapshot and error', () {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.provider.loadMyRfqs();
    f.emit('a', 1, 'fresh');
    f.emit('a', 0, 'late');
    f.streams['a']!.subscriptions[0].errorCallback!(StateError('late'));
    expect(f.provider.myRfqs.single.id, 'fresh');
    expect(f.provider.error, isNull);
  });
  test('A B A rejects first A subscription', () async {
    final f = Fixture();
    f.provider.loadMyRfqs();
    await f.switchTo('b');
    await f.switchTo('a');
    f.emit('a', 1, 'fresh');
    f.emit('a', 0, 'late');
    expect(f.provider.myRfqs.single.id, 'fresh');
  });
  test('sign out clears and later sign in resumes listener', () async {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.emit('a', 0, 'private');
    await f.switchTo(null);
    f.emit('a', 0, 'late');
    expect(f.provider.myRfqs, isEmpty);
    expect(f.provider.isLoading, false);
    await f.switchTo('b');
    f.emit('b', 0, 'new');
    expect(f.provider.myRfqs.single.buyerId, 'b');
    expect(f.reads, 2);
  });
  test('signed out load reads nothing', () {
    final f = Fixture();
    f.owner = null;
    f.provider.loadMyRfqs();
    expect(f.reads, 0);
    expect(f.provider.myRfqs, isEmpty);
  });
  test('disposed provider hides cache and ignores late callbacks', () {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.emit('a', 0, 'private');
    f.dispose();
    expect(() => f.emit('a', 0, 'late'), returnsNormally);
    expect(f.provider.myRfqs, isEmpty);
    f.provider.loadMyRfqs();
    expect(f.reads, 1);
  });
  test('current stream error clears after reload', () {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.streams['a']!.subscriptions[0].errorCallback!(StateError('fixture'));
    expect(f.provider.error, 'Failed to load your quote requests');
    f.provider.loadMyRfqs();
    f.emit('a', 1, 'new');
    expect(f.provider.error, isNull);
  });
  test('obsolete auth event cannot clear new session', () async {
    final f = Fixture();
    f.provider.loadMyRfqs();
    await f.switchTo('b');
    f.emit('b', 0, 'new');
    f.auth.add('a');
    f.auth.add(null);
    await settle();
    expect(f.provider.myRfqs.single.id, 'new');
    expect(f.reads, 2);
  });
  final commands = <String, Future<dynamic> Function(RfqProvider)>{
    'createRfq': (p) =>
        p.createRfq(productId: 'product', quantity: 2, notes: ' note '),
    'submitRfqOffer': (p) => p.submitOffer(rfqId: 'rfq', price: 1, quantity: 2),
    'respondToRfqOffer': (p) => p.respond(rfqId: 'rfq', action: 'accept'),
    'createOrderFromRfq': (p) => p.placeOrder(
        rfqId: 'rfq',
        productId: 'product',
        quantity: 2,
        deliveryAddress: {'id': 'address'},
        deliveryQuoteId: 'quote'),
  };
  for (final entry in commands.entries) {
    test('${entry.key} refuses late successful result after account switch',
        () async {
      final pending = Completer<Map<String, dynamic>>();
      final f = Fixture(call: (_, __) => pending.future);
      f.provider.loadMyRfqs();
      final work = entry.value(f.provider);
      final refused = expectLater(work, throwsStateError);
      await f.switchTo('b');
      pending.complete({'rfqId': 'old', 'orderId': 'old'});
      await refused;
      expect(f.provider.isSubmitting, false);
      expect(f.provider.error, isNull);
    });
    test('${entry.key} keeps current success and exact callable contract',
        () async {
      final f = Fixture();
      await entry.value(f.provider);
      expect(f.calls.single.$1, entry.key);
      expect(f.provider.isSubmitting, false);
      if (entry.key == 'createRfq') expect(f.calls.single.$2['notes'], 'note');
      if (entry.key == 'createOrderFromRfq') {
        expect(f.calls.single.$2['paymentMethod'], 'cod');
        expect(f.calls.single.$2['legacyDeliveryCharge'], 0);
        expect(f.calls.single.$2['deliveryQuoteId'], 'quote');
      }
    });
  }
  test('old command error and finally cannot change new pending submission',
      () async {
    final first = Completer<Map<String, dynamic>>(),
        second = Completer<Map<String, dynamic>>();
    var count = 0;
    final f =
        Fixture(call: (_, __) => ++count == 1 ? first.future : second.future);
    f.provider.loadMyRfqs();
    final old = f.provider.respond(rfqId: 'a', action: 'accept');
    final refused = expectLater(old, throwsStateError);
    await f.switchTo('b');
    final current = f.provider.respond(rfqId: 'b', action: 'accept');
    first.completeError(FirebaseFunctionsException(
        code: 'permission-denied', message: 'old account'));
    await refused;
    expect(f.provider.isSubmitting, true);
    expect(f.provider.error, isNull);
    second.complete({});
    await current;
    expect(f.provider.isSubmitting, false);
  });
  test('disposed pending command refuses result without notification',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    final f = Fixture(call: (_, __) => pending.future);
    final work = f.provider.createRfq(productId: 'product', quantity: 1);
    final refused = expectLater(work, throwsStateError);
    f.dispose();
    pending.complete({'rfqId': 'old'});
    await refused;
    expect(f.provider.isSubmitting, false);
  });
  test('signed out command does not dispatch', () async {
    final f = Fixture();
    f.owner = null;
    await expectLater(
        f.provider.respond(rfqId: 'rfq', action: 'accept'), throwsStateError);
    expect(f.calls, isEmpty);
  });
  test('command from first A session is rejected after A B A', () async {
    final pending = Completer<Map<String, dynamic>>();
    final f = Fixture(call: (_, __) => pending.future);
    f.provider.loadMyRfqs();
    final work = f.provider.createRfq(productId: 'product', quantity: 1);
    final refused = expectLater(work, throwsStateError);
    await f.switchTo('b');
    await f.switchTo('a');
    pending.complete({'rfqId': 'old'});
    await refused;
    expect(f.provider.error, isNull);
    expect(f.provider.isSubmitting, false);
  });

  test('same owner list refresh does not invalidate an active command',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    final f = Fixture(call: (_, __) => pending.future);
    final work = f.provider.createRfq(productId: 'product', quantity: 1);
    f.provider.loadMyRfqs();
    f.provider.loadMyRfqs();
    pending.complete({'rfqId': 'created'});
    expect(await work, 'created');
    expect(f.provider.isSubmitting, false);
  });

  test('same session submitting stays true until both commands finish',
      () async {
    final first = Completer<Map<String, dynamic>>();
    final second = Completer<Map<String, dynamic>>();
    var count = 0;
    final f =
        Fixture(call: (_, __) => ++count == 1 ? first.future : second.future);
    final a = f.provider.respond(rfqId: 'a', action: 'accept');
    final b = f.provider.respond(rfqId: 'b', action: 'accept');
    first.complete({});
    await a;
    expect(f.provider.isSubmitting, true);
    second.complete({});
    await b;
    expect(f.provider.isSubmitting, false);
  });

  test('command before delayed auth event rebinds a previously opened list',
      () async {
    final f = Fixture();
    f.provider.loadMyRfqs();
    f.emit('a', 0, 'private');
    f.owner = 'b';
    await f.provider.respond(rfqId: 'b', action: 'accept');
    f.auth.add('b');
    await settle();
    expect(f.streams.containsKey('b'), true);
    f.emit('b', 0, 'new');
    expect(f.provider.myRfqs.single.buyerId, 'b');
    expect(f.reads, 2);
  });

  test('current callable failure remains observable', () async {
    final f = Fixture(
        call: (_, __) => Future.error(FirebaseFunctionsException(
            code: 'unavailable', message: 'Try again')));
    await expectLater(f.provider.respond(rfqId: 'rfq', action: 'accept'),
        throwsA(isA<FirebaseFunctionsException>()));
    expect(f.provider.error, 'Try again');
    expect(f.provider.isSubmitting, false);
  });
}
