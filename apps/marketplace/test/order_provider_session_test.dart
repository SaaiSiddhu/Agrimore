import 'dart:async';
import 'package:agrimore_marketplace/providers/order_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel row(String uid, String id, [int day = 1]) => OrderModel(
    id: id,
    userId: uid,
    orderNumber: id,
    items: [],
    deliveryAddress: AddressModel.fromMap({'id': 'address', 'userId': uid}),
    subtotal: 100,
    total: 100,
    paymentMethod: 'cod',
    createdAt: DateTime.utc(2026, 1, day));
OrderTimelineModel event(String title) => OrderTimelineModel(
    status: OrderStatus.pending,
    title: title,
    description: 'Fixture',
    timestamp: DateTime.utc(2026));
Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class Fixture {
  Fixture(
      {Future<OrderModel?> Function(String)? read,
      Future<List<OrderTimelineModel>> Function(String)? timeline,
      Future<void> Function(String, Map<String, dynamic>)? update,
      Future<void> Function(String, Map<String, dynamic>)? addTimeline}) {
    provider = OrderProvider(
        currentUserId: () => owner,
        authChanges: () => auth.stream,
        snapshots: (uid) => streams.putIfAbsent(uid, _LateOrderStream.new),
        readOrder: (id) {
          reads.add((owner, id));
          return read?.call(id) ?? Future.value(row(owner ?? 'missing', id));
        },
        readTimeline: (id) {
          timelines.add(id);
          return timeline?.call(id) ?? Future.value([event(id)]);
        },
        update: (id, data) {
          writes.add((id, Map.of(data)));
          return update?.call(id, data) ?? Future.value();
        },
        addTimeline: (id, data) {
          events.add((id, Map.of(data)));
          return addTimeline?.call(id, data) ?? Future.value();
        });
    addTearDown(() async {
      dispose();
      await auth.close();
    });
  }
  String? owner = 'a';
  final auth = StreamController<String?>.broadcast();
  final streams = <String, _LateOrderStream>{};
  final reads = <(String?, String)>[], timelines = <String>[];
  final writes = <(String, Map<String, dynamic>)>[],
      events = <(String, Map<String, dynamic>)>[];
  late OrderProvider provider;
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
    await settle();
  }

  void emit(String uid, int index, String id) =>
      streams[uid]!.subscriptions[index].dataCallback!([row(uid, id)]);
}

class _LateSubscription implements StreamSubscription<List<OrderModel>> {
  _LateSubscription(this.dataCallback, this.errorCallback, this.doneCallback);
  void Function(List<OrderModel>)? dataCallback;
  Function? errorCallback;
  void Function()? doneCallback;
  int cancelCount = 0;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  void onData(void Function(List<OrderModel> data)? handleData) =>
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

class _LateOrderStream extends Stream<List<OrderModel>> {
  final subscriptions = <_LateSubscription>[];

  @override
  StreamSubscription<List<OrderModel>> listen(
    void Function(List<OrderModel>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _LateSubscription(onData, onError, onDone);
    subscriptions.add(subscription);
    return subscription;
  }

  void emit(List<OrderModel> value) {
    for (final subscription in List.of(subscriptions)) {
      // Deliberately permits a queued callback after cancellation.
      subscription.dataCallback?.call(value);
    }
  }
}

void main() {
  test('current-owner list sorts newest first', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.streams['a']!.emit([row('a', 'old'), row('a', 'new', 2)]);
    expect(f.provider.orders.map((r) => r.id), ['new', 'old']);
  });
  test('public list is immutable', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.emit('a', 0, 'one');
    expect(() => f.provider.orders.clear(), throwsUnsupportedError);
  });
  test('public timeline is immutable', () async {
    final f = Fixture();
    await f.provider.loadOrderById('one');
    expect(
        () => f.provider.selectedOrderTimeline.clear(), throwsUnsupportedError);
  });
  test('getters hide old owner before auth callback', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.emit('a', 0, 'one');
    await f.provider.loadOrderById('one');
    f.owner = 'b';
    expect(f.provider.orders, isEmpty);
    expect(f.provider.selectedOrder, isNull);
    expect(f.provider.selectedOrderTimeline, isEmpty);
    expect(f.provider.searchOrders('one'), isEmpty);
    expect(f.provider.pendingOrders, isEmpty);
    expect(f.provider.getOrderStatistics()['total'], 0);
  });
  test('auth switch clears and rebinds opened list', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.emit('a', 0, 'one');
    await f.switchTo('b');
    expect(f.streams.containsKey('b'), true);
    expect(f.provider.orders, isEmpty);
    f.emit('b', 0, 'two');
    expect(f.provider.orders.single.userId, 'b');
  });
  test('late cancelled callback is refused', () async {
    final f = Fixture();
    f.provider.loadOrders();
    await f.switchTo('b');
    f.provider.loadOrders();
    f.emit('b', f.streams['b']!.subscriptions.length - 1, 'new');
    f.emit('a', 0, 'old');
    expect(f.provider.orders.single.id, 'new');
  });
  test('same-owner reload fences callbacks', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.provider.loadOrders();
    f.emit('a', 1, 'new');
    f.emit('a', 0, 'old');
    expect(f.provider.orders.single.id, 'new');
  });
  test('late cancelled error cannot poison new owner', () async {
    final f = Fixture();
    f.provider.loadOrders();
    await f.switchTo('b');
    f.provider.loadOrders();
    f.streams['a']!.subscriptions.first
        .errorCallback!(StateError('private fixture'));
    expect(f.provider.error, isNull);
  });
  test('ABA cannot revive old subscription', () async {
    final f = Fixture();
    f.provider.loadOrders();
    await f.switchTo('b');
    await f.switchTo('a');
    f.provider.loadOrders();
    final i = f.streams['a']!.subscriptions.length - 1;
    f.emit('a', i, 'new');
    f.emit('a', 0, 'old');
    expect(f.provider.orders.single.id, 'new');
  });
  test('foreign list row fails closed', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.streams['a']!.emit([row('b', 'foreign')]);
    expect(f.provider.orders, isEmpty);
    expect(f.provider.error, isNotNull);
  });
  test('signed-out detail performs no reads', () async {
    final f = Fixture();
    f.owner = null;
    await f.provider.loadOrderById('one');
    expect(f.reads, isEmpty);
    expect(f.timelines, isEmpty);
    expect(f.provider.selectedOrder, isNull);
  });
  test('disposed list callback cannot notify', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.dispose();
    expect(() => f.emit('a', 0, 'late'), returnsNormally);
    expect(f.provider.orders, isEmpty);
  });
  test('previous-owner detail cannot load timeline', () async {
    final c = Completer<OrderModel?>();
    final f = Fixture(read: (_) => c.future);
    final work = f.provider.loadOrderById('one');
    await f.switchTo('b');
    c.complete(row('a', 'one'));
    await work;
    expect(f.provider.selectedOrder, isNull);
    expect(f.timelines, isEmpty);
  });
  test('foreign detail row refused', () async {
    final f = Fixture(read: (id) async => row('b', id));
    await f.provider.loadOrderById('one');
    expect(f.provider.selectedOrder, isNull);
    expect(f.timelines, isEmpty);
  });
  test('mismatched detail ID refused', () async {
    final f = Fixture(read: (_) async => row('a', 'wrong'));
    await f.provider.loadOrderById('one');
    expect(f.provider.selectedOrder, isNull);
    expect(f.timelines, isEmpty);
  });
  test('not found clears previous selection', () async {
    var missing = false;
    final f = Fixture(read: (id) async => missing ? null : row('a', id));
    await f.provider.loadOrderById('one');
    missing = true;
    await f.provider.loadOrderById('two');
    expect(f.provider.selectedOrder, isNull);
    expect(f.provider.selectedOrderTimeline, isEmpty);
  });
  test('new detail immediately clears old selection', () async {
    final c = Completer<OrderModel?>();
    final f = Fixture(
        read: (id) => id == 'one' ? Future.value(row('a', id)) : c.future);
    await f.provider.loadOrderById('one');
    final work = f.provider.loadOrderById('two');
    expect(f.provider.selectedOrder, isNull);
    expect(f.provider.selectedOrderTimeline, isEmpty);
    c.complete(row('a', 'two'));
    await work;
  });
  test('older detail cannot replace newer', () async {
    final c = Completer<OrderModel?>();
    final f = Fixture(
        read: (id) => id == 'old' ? c.future : Future.value(row('a', id)));
    final old = f.provider.loadOrderById('old');
    await f.provider.loadOrderById('new');
    c.complete(row('a', 'old'));
    await old;
    expect(f.provider.selectedOrder!.id, 'new');
    expect(f.provider.selectedOrderTimeline.single.title, 'new');
  });
  test('older timeline cannot replace newer', () async {
    final c = Completer<List<OrderTimelineModel>>();
    final f = Fixture(
        timeline: (id) => id == 'old' ? c.future : Future.value([event(id)]));
    final old = f.provider.loadOrderById('old');
    await settle();
    await f.provider.loadOrderById('new');
    c.complete([event('old')]);
    await old;
    expect(f.provider.selectedOrder!.id, 'new');
    expect(f.provider.selectedOrderTimeline.single.title, 'new');
  });
  test('clear selection invalidates pending detail', () async {
    final c = Completer<OrderModel?>();
    final f = Fixture(read: (_) => c.future);
    final work = f.provider.loadOrderById('one');
    f.provider.clearSelectedOrder();
    c.complete(row('a', 'one'));
    await work;
    expect(f.provider.selectedOrder, isNull);
    expect(f.timelines, isEmpty);
  });
  test('disposed detail cannot notify or load timeline', () async {
    final c = Completer<OrderModel?>();
    final f = Fixture(read: (_) => c.future);
    final work = f.provider.loadOrderById('one');
    f.dispose();
    c.complete(row('a', 'one'));
    await expectLater(work, completes);
    expect(f.timelines, isEmpty);
    expect(f.provider.selectedOrder, isNull);
  });
  test('stale read error leaves newer loading', () async {
    final a = Completer<OrderModel?>(), b = Completer<OrderModel?>();
    final f = Fixture(read: (id) => id == 'a' ? a.future : b.future);
    final old = f.provider.loadOrderById('a'),
        latest = f.provider.loadOrderById('b');
    a.completeError(StateError('private fixture'));
    await old;
    expect(f.provider.isLoading, true);
    expect(f.provider.error, isNull);
    b.complete(row('a', 'b'));
    await latest;
  });
  for (final action in ['cancel', 'return', 'status']) {
    Future<bool> invoke(Fixture f) => switch (action) {
          'cancel' => f.provider.cancelOrder('one', 'Fixture'),
          'return' => f.provider.returnOrder('one', 'Fixture'),
          _ => f.provider.updateOrderStatus('one', 'confirmed')
        };
    test('$action refuses foreign target', () async {
      final f = Fixture(read: (id) async => row('b', id));
      expect(await invoke(f), false);
      expect(f.writes, isEmpty);
      expect(f.events, isEmpty);
    });
    test('$action signed-out has no writes', () async {
      final f = Fixture();
      f.owner = null;
      expect(await invoke(f), false);
      expect(f.writes, isEmpty);
      expect(f.events, isEmpty);
    });
    test('$action late write cannot dispatch next timeline', () async {
      final c = Completer<void>();
      final f = Fixture(update: (_, __) => c.future);
      final work = invoke(f);
      await settle();
      await f.switchTo('b');
      c.complete();
      expect(await work, false);
      expect(f.events, isEmpty);
      expect(f.provider.error, isNull);
    });
  }
  test('current-owner cancel keeps payload', () async {
    final f = Fixture();
    expect(await f.provider.cancelOrder('one', 'Fixture reason'), true);
    expect(f.writes.single.$1, 'one');
    expect(f.writes.single.$2['orderStatus'], 'cancelled');
    expect(f.writes.single.$2['cancellationReason'], 'Fixture reason');
    expect(f.events.single.$2['status'], 'cancelled');
    expect(f.provider.isLoading, false);
  });
  test('owner switch during fresh mutation read dispatches nothing', () async {
    final c = Completer<OrderModel?>();
    final f = Fixture(read: (_) => c.future);
    final work = f.provider.cancelOrder('one', 'Fixture');
    await settle();
    await f.switchTo('b');
    c.complete(row('a', 'one'));
    expect(await work, false);
    expect(f.writes, isEmpty);
  });
  test('owner switch during timeline refuses reload and success', () async {
    final c = Completer<void>();
    final f = Fixture(addTimeline: (_, __) => c.future);
    final work = f.provider.cancelOrder('one', 'Fixture');
    await settle();
    await f.switchTo('b');
    c.complete();
    expect(await work, false);
    expect(f.reads.where((r) => r.$1 == 'b'), isEmpty);
  });
  test('detail command rebinds list before delayed auth callback', () async {
    final f = Fixture();
    f.provider.loadOrders();
    f.owner = 'b';
    await f.provider.loadOrderById('two');
    expect(f.streams.containsKey('b'), true);
    f.emit('b', 0, 'two');
    f.auth.add('b');
    await settle();
    expect(f.provider.orders.single.userId, 'b');
  });
  test('clear selection invalidates pending timeline', () async {
    final c = Completer<List<OrderTimelineModel>>();
    final f = Fixture(timeline: (_) => c.future);
    final work = f.provider.loadOrderById('one');
    await settle();
    f.provider.clearSelectedOrder();
    c.complete([event('old')]);
    await work;
    expect(f.provider.selectedOrder, isNull);
    expect(f.provider.selectedOrderTimeline, isEmpty);
  });
  test('switch while timeline pending cannot expose old timeline', () async {
    final c = Completer<List<OrderTimelineModel>>();
    final f = Fixture(timeline: (_) => c.future);
    final work = f.provider.loadOrderById('one');
    await settle();
    await f.switchTo('b');
    c.complete([event('old')]);
    await work;
    expect(f.provider.selectedOrderTimeline, isEmpty);
    expect(f.provider.selectedOrder, isNull);
  });
  test('current timeline failure has safe feedback and stops loading',
      () async {
    final f =
        Fixture(timeline: (_) async => throw StateError('private fixture'));
    await f.provider.loadOrderById('one');
    expect(f.provider.selectedOrder!.id, 'one');
    expect(f.provider.error, contains('timeline'));
    expect(f.provider.error, isNot(contains('private')));
    expect(f.provider.isLoadingTimeline, false);
  });
  test('disposed provider dispatches no new command', () async {
    final f = Fixture();
    f.dispose();
    expect(await f.provider.cancelOrder('one', 'Fixture'), false);
    expect(f.reads, isEmpty);
    expect(f.writes, isEmpty);
  });
  test('dispose during write cannot continue timeline or notify', () async {
    final c = Completer<void>();
    final f = Fixture(update: (_, __) => c.future);
    final work = f.provider.cancelOrder('one', 'Fixture');
    await settle();
    f.dispose();
    c.complete();
    expect(await work, false);
    expect(f.events, isEmpty);
  });
  test('ABA during dispatched write cannot continue old session', () async {
    final c = Completer<void>();
    final f = Fixture(update: (_, __) => c.future);
    final work = f.provider.cancelOrder('one', 'Fixture');
    await settle();
    await f.switchTo('b');
    await f.switchTo('a');
    c.complete();
    expect(await work, false);
    expect(f.events, isEmpty);
  });
  test('completed old action does not steal new selected request', () async {
    final c = Completer<void>();
    final f = Fixture(update: (_, __) => c.future);
    final work = f.provider.cancelOrder('one', 'Fixture');
    await settle();
    await f.provider.loadOrderById('two');
    c.complete();
    expect(await work, true);
    expect(f.provider.selectedOrder!.id, 'two');
    expect(f.provider.selectedOrderTimeline.single.title, 'two');
  });
  test('same-owner command failure is generic and clears loading', () async {
    final f =
        Fixture(update: (_, __) async => throw StateError('private fixture'));
    expect(await f.provider.cancelOrder('one', 'Fixture'), false);
    expect(f.provider.error, isNotNull);
    expect(f.provider.error, isNot(contains('private')));
    expect(f.provider.isLoading, false);
    expect(f.events, isEmpty);
  });
  test('stale command error leaves new owner loading untouched', () async {
    final old = Completer<void>(), latest = Completer<OrderModel?>();
    final f = Fixture(
        read: (id) => id == 'two' ? latest.future : Future.value(row('a', id)),
        update: (_, __) => old.future);
    final work = f.provider.cancelOrder('one', 'Fixture');
    await settle();
    await f.switchTo('b');
    final detail = f.provider.loadOrderById('two');
    old.completeError(StateError('private fixture'));
    expect(await work, false);
    expect(f.provider.isLoading, true);
    expect(f.provider.error, isNull);
    latest.complete(row('b', 'two'));
    await detail;
  });
}
