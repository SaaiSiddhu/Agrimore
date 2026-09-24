// Phase DLV-C1 — the order provider belongs to one rider at a time: late
// answers for a previous rider are dropped, a failed read keeps what was
// known and can be retried, today's count is since local midnight, and
// history pages continue from a cursor.
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:delivery/data/rider_history.dart';
import 'package:delivery/data/rider_work.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

OrderDoc active(String id, String rider, [String status = 'picked_up']) =>
    (id: id, data: {'deliveryPartnerId': rider, 'orderStatus': status, 'orderNumber': id});

void main() {
  late Map<String, StreamController<ActiveSnapshot>> streams;
  late List<String> subscribed;
  late List<(String, DateTime)> counts;
  late Map<String, Completer<int>> countAnswers;

  DeliveryOrderProvider make({HistoryFetch? history, DateTime? now}) => DeliveryOrderProvider(
        activeSource: (rider) {
          subscribed.add(rider);
          return (streams[rider] = StreamController<ActiveSnapshot>()).stream;
        },
        deliveredCount: (rider, since) {
          counts.add((rider, since));
          return (countAnswers[rider] = Completer<int>()).future;
        },
        historyFetch: history,
        clock: () => now ?? DateTime(2026, 9, 24, 15, 30),
      );

  setUp(() {
    streams = {};
    subscribed = [];
    counts = [];
    countAnswers = {};
  });

  test('zero, one and several active orders', () async {
    final p = make()..bind('r1');
    expect(p.work.loaded, isFalse);
    streams['r1']!.add((docs: [], fromCache: false));
    await pumpEventQueue();
    expect(p.work.isEmpty, isTrue);
    expect(p.activeOrder, isNull);

    streams['r1']!.add((docs: [active('o1', 'r1')], fromCache: false));
    await pumpEventQueue();
    expect(p.activeOrder?.id, 'o1');

    streams['r1']!.add((docs: [active('o1', 'r1'), active('o2', 'r1', 'delivery_accepted')], fromCache: false));
    await pumpEventQueue();
    expect(p.work.hasMultiple, isTrue);
    expect(p.activeOrder, isNull, reason: 'never an arbitrary first');
    expect(p.activeOrders.map((o) => o.id).toSet(), {'o1', 'o2'});
  });

  test('account switch: rider A\'s late snapshot and count never reach rider B', () async {
    final p = make()..bind('rA');
    final aStream = streams['rA']!;
    final aCount = countAnswers['rA']!;
    p.bind('rB');
    aStream.add((docs: [active('secretA', 'rA')], fromCache: false));
    aCount.complete(7);
    await pumpEventQueue();
    expect(p.riderId, 'rB');
    expect(p.work.loaded, isFalse);
    expect(p.activeOrders, isEmpty);
    expect(p.todayDelivered, isNull);
    expect(aStream.hasListener, isFalse, reason: 'A\'s listener was cancelled');
  });

  test('sign-out clears everything; binding the same rider twice subscribes once', () async {
    final p = make()..bind('r1');
    p.bind('r1');
    expect(subscribed, ['r1']);
    streams['r1']!.add((docs: [active('o1', 'r1')], fromCache: false));
    await pumpEventQueue();
    p.bind(null);
    expect(p.activeOrders, isEmpty);
    expect(streams['r1']!.hasListener, isFalse);
    p.bind('r1');
    p.bind(null);
    p.bind('r1');
    expect(subscribed, ['r1', 'r1', 'r1']);
    expect(streams.values.where((s) => s.hasListener).length, 1, reason: 'one live listener after repeated sign-ins');
  });

  test('a failed read keeps the last known orders and can be retried', () async {
    final p = make()..bind('r1');
    streams['r1']!.add((docs: [active('o1', 'r1')], fromCache: false));
    await pumpEventQueue();
    streams['r1']!.addError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    await pumpEventQueue();
    expect(p.work.error, RiderDataError.offline);
    expect(p.activeOrders.single.id, 'o1');
    p.retry();
    expect(p.work.loaded, isFalse);
    streams['r1']!.add((docs: [], fromCache: false));
    await pumpEventQueue();
    expect(p.work.isEmpty, isTrue);
    expect(p.work.error, isNull);
  });

  test('cache answers are marked', () async {
    final p = make()..bind('r1');
    streams['r1']!.add((docs: [active('o1', 'r1')], fromCache: true));
    await pumpEventQueue();
    expect(p.work.fromCache, isTrue);
  });

  test('today counts from local midnight and refreshes when an order leaves active work', () async {
    final p = make(now: DateTime(2026, 9, 24, 15, 30))..bind('r1');
    expect(counts.single, ('r1', DateTime(2026, 9, 24)));
    countAnswers['r1']!.complete(3);
    await pumpEventQueue();
    expect(p.todayDelivered, 3);
    streams['r1']!.add((docs: [active('o1', 'r1')], fromCache: false));
    await pumpEventQueue();
    streams['r1']!.add((docs: [], fromCache: false));
    await pumpEventQueue();
    expect(counts, hasLength(2), reason: 'o1 left active work — maybe delivered');
  });

  group('history', () {
    test('pages continue after the cursor; a second tap while loading does nothing', () async {
      final calls = <Object?>[];
      final answers = <Completer<HistoryPage>>[];
      final p = make(history: (rider, cursor, size) {
        calls.add(cursor);
        final c = Completer<HistoryPage>();
        answers.add(c);
        return c.future;
      })..bind('r1');
      final h = p.history;
      h.loadMore();
      h.loadMore();
      expect(calls, [null]);
      answers[0].complete((items: [OrderModel.fromMap({'orderNumber': 'A'}, 'a')], cursor: 'c1', hasMore: true));
      await pumpEventQueue();
      h.loadMore();
      expect(calls, [null, 'c1']);
      answers[1].complete((
        items: [OrderModel.fromMap({'orderNumber': 'A'}, 'a'), OrderModel.fromMap({'orderNumber': 'B'}, 'b')],
        cursor: 'c2',
        hasMore: false,
      ));
      await pumpEventQueue();
      expect(h.items.map((o) => o.id), ['a', 'b'], reason: 'no duplicate rows');
      expect(h.hasMore, isFalse);
      h.loadMore();
      expect(calls, hasLength(2));
    });

    test('a page for the previous rider is dropped', () async {
      final answers = <Completer<HistoryPage>>[];
      final p = make(history: (rider, cursor, size) {
        final c = Completer<HistoryPage>();
        answers.add(c);
        return c.future;
      })..bind('rA');
      p.history.loadMore();
      p.bind('rB');
      answers[0].complete((items: [OrderModel.fromMap({'orderNumber': 'A'}, 'secretA')], cursor: 'x', hasMore: false));
      await pumpEventQueue();
      expect(p.history.items, isEmpty);
      expect(p.history.loading, isFalse);
    });

    test('a failed page reports the error and can be retried', () async {
      var fail = true;
      final p = make(history: (rider, cursor, size) async {
        if (fail) throw FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })..bind('r1');
      await p.history.loadMore();
      expect(p.history.error, RiderDataError.permission);
      fail = false;
      await p.history.loadMore();
      expect(p.history.error, isNull);
      expect(p.history.hasMore, isFalse);
    });
  });
}
