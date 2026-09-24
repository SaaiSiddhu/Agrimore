// DLV-N1 — the rider inbox (lib/inbox, screens/inbox) and the history filter
// and detail (data/rider_history.dart, screens/history).
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/data/rider_history.dart';
import 'package:delivery/inbox/rider_inbox.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/screens/history/rider_history_screen.dart';
import 'package:delivery/screens/inbox/inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInbox implements RiderInboxSource {
  final notices = StreamController<List<RiderNotice>>.broadcast();
  final unread = StreamController<int>.broadcast();
  final marked = <String>[];
  List<RiderNotice> current = const [];
  @override
  Stream<List<RiderNotice>> latest(String riderId) async* {
    yield current;
    yield* notices.stream;
  }

  @override
  Stream<int> unreadCount(String riderId) async* {
    yield current.where((n) => n.unread).length;
    yield* unread.stream;
  }

  @override
  Future<void> markRead(String riderId, Iterable<String> ids) async => marked.addAll(ids);
}

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  RiderNotice n(String id, String type, {bool unread = true}) =>
      RiderNotice(id: id, type: type, title: 'T $id', body: 'B $id', unread: unread, createdAt: DateTime(2026, 9, 24, 9));

  test('notices read the server shape; money notices lead to Earnings', () {
    final a = RiderNotice.fromMap('x', {
      'type': 'payout_sent', 'title': 'Money sent', 'body': '₹10.00 sent', 'unread': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 24)),
    });
    expect(a.unread, isTrue);
    expect(a.target, NoticeTarget.money);
    // An admin broadcast written before N1 (message, read:false) still shows.
    final b = RiderNotice.fromMap('y', {'title': 'Hi', 'message': 'Welcome', 'read': false});
    expect(b.body, 'Welcome');
    expect(b.unread, isTrue);
    expect(b.target, NoticeTarget.none);
    expect(unreadBadgeText(3), '3');
    expect(unreadBadgeText(kInboxSize), '$kInboxSize+');
  });

  testWidgets('inbox lists notices, a tap marks read, mark-all marks the rest', (t) async {
    final src = FakeInbox()..current = [n('a', 'rider_offline'), n('b', 'delivery_assigned'), n('c', 'statement_ready', unread: false)];
    await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('T a'), findsOneWidget);
    await t.tap(find.text('T a'));
    await t.pumpAndSettle();
    expect(src.marked, ['a']);
    await t.tap(find.text('Mark all read'));
    await t.pumpAndSettle();
    expect(src.marked, ['a', 'a', 'b']); // the stream has not yet confirmed a as read
  });

  testWidgets('empty inbox explains itself', (t) async {
    await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: FakeInbox())));
    await t.pumpAndSettle();
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('the dashboard button shows the unread count', (t) async {
    final src = FakeInbox()..current = [n('a', 'rider_offline'), n('b', 'payout_sent')];
    await t.pumpWidget(host(Scaffold(appBar: AppBar(actions: [InboxButton(riderId: 'r1', source: src)]))));
    await t.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('Inbox, 2 unread'), findsOneWidget);
  });

  group('history', () {
    test('an order an admin finished through status alone reads as finished', () {
      expect(historyOrder('o1', {'orderStatus': 'out_for_delivery', 'status': 'delivered', 'orderNumber': 'A'}).orderStatus, 'delivered');
      expect(historyOrder('o2', {'orderStatus': 'returned', 'status': 'delivered', 'orderNumber': 'B'}).orderStatus, 'returned');
      expect(historyOrder('o3', {'orderStatus': 'out_for_delivery', 'status': 'cancelled', 'orderNumber': 'C'}).orderStatus, 'cancelled');
      expect(historyOrder('o4', {'orderStatus': 'picked_up', 'orderNumber': 'D'}).orderStatus, 'picked_up');
    });

    test('filters keep only canonical matches', () {
      final delivered = historyOrder('a', {'orderStatus': 'delivered'});
      final returned = historyOrder('b', {'orderStatus': 'returned', 'status': 'delivered'});
      final active = historyOrder('c', {'orderStatus': 'picked_up'});
      expect([delivered, returned, active].where((o) => historyMatches(o, HistoryFilter.delivered)).map((o) => o.id), ['a']);
      expect([delivered, returned, active].where((o) => historyMatches(o, HistoryFilter.notDelivered)).map((o) => o.id), ['b']);
      expect([delivered, returned, active].where((o) => historyMatches(o, HistoryFilter.all)).length, 3);
    });

    test('changing the filter reloads from the first page with that filter', () async {
      final asked = <HistoryFilter>[];
      final h = RiderHistory(fetch: (rider, filter, cursor, size) async {
        asked.add(filter);
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      await h.setFilter(HistoryFilter.delivered);
      expect(asked, [HistoryFilter.all, HistoryFilter.delivered]);
      expect(h.filter, HistoryFilter.delivered);
    });

    testWidgets('detail shows this order\'s pay and whether it is in a statement', (t) async {
      final order = historyOrder('o9', {'orderStatus': 'delivered', 'orderNumber': 'ORD-9', 'total': 480});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => RiderEarning(
                  orderId: id, total: 55.46, basePay: 25, distancePay: 23.46, km: 3.91, codCollected: 480)))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('₹55.46'), findsOneWidget);
      expect(find.text('Cash collected'), findsOneWidget);
      expect(find.text("Goes into next Monday's statement"), findsOneWidget);
    });

    testWidgets('detail of an order not delivered says pay comes later, without a read', (t) async {
      var reads = 0;
      final order = historyOrder('o8', {'orderStatus': 'cancelled', 'orderNumber': 'ORD-8', 'total': 100});
      await t.pumpWidget(host(Scaffold(body: HistoryDetail(order: order, loadEarning: (id) async { reads++; return null; }))));
      await t.pumpAndSettle();
      expect(reads, 0);
      expect(find.text('Pay shows here once the order is delivered.'), findsOneWidget);
    });
  });
}
