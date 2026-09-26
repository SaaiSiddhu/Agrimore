// DLV-N1 — the rider inbox (lib/inbox, screens/inbox) and the history filter
// and detail (data/rider_history.dart, screens/history).
import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/account/support_card.dart';
import 'package:delivery/data/order_timeline.dart';
import 'package:delivery/data/rider_history.dart';
import 'package:delivery/inbox/rider_inbox.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/screens/history/rider_history_screen.dart';
import 'package:delivery/screens/inbox/inbox_screen.dart';
import 'package:delivery/screens/money/statement_screen.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:delivery/screens/profile/identity_change_screen.dart';
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

  var markAllCalls = 0;
  Object? markAllError;
  Completer<void>? markAllGate;
  @override
  Future<void> markAllRead(String riderId) async {
    markAllCalls++;
    if (markAllGate != null) await markAllGate!.future;
    if (markAllError != null) throw markAllError!;
    marked.addAll(current.where((n) => n.unread).map((n) => n.id));
  }
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

  test('notices read the server shape and resolve their real, typed target', () {
    // riderNotices.ts's own data map (payoutId), not just type/title/body.
    final a = RiderNotice.fromMap('x', {
      'type': 'payout_sent', 'title': 'Money sent', 'body': '₹10.00 sent', 'unread': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 24)),
      'data': {'type': 'payout_sent', 'payoutId': 'stmt-1'},
    });
    expect(a.unread, isTrue);
    expect(a.payoutId, 'stmt-1');
    expect(a.target, NoticeTarget.statement);

    final assigned = RiderNotice.fromMap('z', {
      'type': 'delivery_assigned', 'title': 'New order assigned to you', 'unread': true,
      'data': {'type': 'delivery_assigned', 'orderId': 'ord-9', 'orderNumber': 'AGM-9'},
    });
    expect(assigned.orderId, 'ord-9');
    expect(assigned.target, NoticeTarget.delivery);

    // No identifier in data (an older write, or a type that doesn't carry
    // one) is a real gap, not silently routed anywhere.
    final assignedNoData = RiderNotice.fromMap('z2', {'type': 'delivery_assigned', 'title': 'T'});
    expect(assignedNoData.target, NoticeTarget.none);

    final bankChange = RiderNotice.fromMap('w', {
      'type': 'bank_change_approved', 'title': 'Payout details updated', 'unread': true,
      'data': {'type': 'bank_change_approved'},
    });
    expect(bankChange.target, NoticeTarget.payoutDetails, reason: 'no per-notice id needed: goes to Earnings');

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

  group('typed notification destinations (DLVI1)', () {
    RiderNotice deliveryNotice(String orderId) => RiderNotice.fromMap('n1', {
          'type': 'delivery_assigned',
          'title': 'New order assigned to you',
          'unread': true,
          'data': {'type': 'delivery_assigned', 'orderId': orderId},
        });

    RiderNotice statementNotice(String payoutId) => RiderNotice.fromMap('n2', {
          'type': 'statement_ready',
          'title': 'Your weekly statement is ready',
          'unread': true,
          'data': {'type': 'statement_ready', 'payoutId': payoutId},
        });

    OrderModel order({required String status}) => historyOrder('ord-9', {
          'orderNumber': 'AGM-9',
          'orderStatus': status,
          'total': 200,
          'deliveryPartnerId': 'r1',
        });

    testWidgets('a delivery notice for an ACTIVE order opens ActiveOrderScreen', (t) async {
      final src = FakeInbox()..current = [deliveryNotice('ord-9')];
      await t.pumpWidget(host(InboxScreen(
        riderId: 'r1',
        source: src,
        loadOrder: (id) async {
          expect(id, 'ord-9');
          return order(status: 'out_for_delivery');
        },
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('New order assigned to you'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ActiveOrderScreen), findsOneWidget);
    });

    testWidgets('a delivery notice for a COMPLETED order opens the read-only historical detail', (t) async {
      final src = FakeInbox()..current = [deliveryNotice('ord-9')];
      await t.pumpWidget(host(InboxScreen(
        riderId: 'r1',
        source: src,
        loadOrder: (id) async => order(status: 'delivered'),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('New order assigned to you'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(HistoryDetail), findsOneWidget);
      expect(find.byType(ActiveOrderScreen), findsNothing);
      expect(find.text('Order details'), findsOneWidget);
    });

    testWidgets('a delivery notice for a reassigned/deleted order says so, not silently nothing', (t) async {
      final src = FakeInbox()..current = [deliveryNotice('ord-9')];
      await t.pumpWidget(host(InboxScreen(
        riderId: 'r1',
        source: src,
        loadOrder: (id) async => null,
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('New order assigned to you'));
      await t.pumpAndSettle();
      expect(find.text('This delivery is no longer available to you.'), findsOneWidget);
    });

    testWidgets('a failed delivery lookup says so distinctly, not as if it were missing', (t) async {
      final src = FakeInbox()..current = [deliveryNotice('ord-9')];
      await t.pumpWidget(host(InboxScreen(
        riderId: 'r1',
        source: src,
        loadOrder: (id) async => throw Exception('offline'),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('New order assigned to you'));
      await t.pumpAndSettle();
      expect(find.text('Could not open this delivery. Try again.'), findsOneWidget);
      expect(find.text('This delivery is no longer available to you.'), findsNothing);
    });

    testWidgets('a statement notice opens the real statement it names', (t) async {
      final src = FakeInbox()..current = [statementNotice('stmt-1')];
      final payout = RiderPayout(
        id: 'stmt-1',
        weekKey: '2026-W38',
        earned: 1000,
        netted: 0,
        amount: 1000,
        cashHeldAfter: 0,
        orderCount: 10,
        status: 'paid',
      );
      await t.pumpWidget(host(InboxScreen(
        riderId: 'r1',
        source: src,
        loadPayout: (id) async {
          expect(id, 'stmt-1');
          return payout;
        },
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('Your weekly statement is ready'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(StatementScreen), findsOneWidget);
    });
  });

  group('identity change notices (DLVID1)', () {
    testWidgets('an identity-change notice opens the request status screen', (t) async {
      final src = FakeInbox()
        ..current = [
          RiderNotice.fromMap('n3', {
            'type': 'identity_change_approved',
            'title': 'Your name was updated',
            'unread': true,
            'data': {'type': 'identity_change_approved', 'requestId': 'req-1'},
          }),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Your name was updated'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(IdentityChangeScreen), findsOneWidget);
    });
  });

  group('mark all read (DLVI2)', () {
    testWidgets('marks every unread notice, not only a read one, in a single call', (t) async {
      final src = FakeInbox()
        ..current = [
          n('a', 'rider_offline'),
          n('b', 'payout_sent', unread: false),
          n('c', 'cod_settled'),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark all read'));
      await t.pumpAndSettle();
      expect(src.markAllCalls, 1);
      expect(src.marked, containsAll(['a', 'c']));
      expect(src.marked, isNot(contains('b')));
    });

    testWidgets('shows a disabled loading state in flight and ignores a second tap', (t) async {
      final gate = Completer<void>();
      final src = FakeInbox()
        ..current = [n('a', 'rider_offline')]
        ..markAllGate = gate;
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark all read'));
      await t.pump();
      expect(find.text('Marking all read…'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
      await t.tap(find.text('Marking all read…'));
      await t.pump();
      expect(src.markAllCalls, 1);
      gate.complete();
      await t.pumpAndSettle();
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('Marking all read…'), findsNothing);
    });

    testWidgets('shows a success toast only after the server confirms, never before', (t) async {
      final gate = Completer<void>();
      final src = FakeInbox()
        ..current = [n('a', 'rider_offline')]
        ..markAllGate = gate;
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark all read'));
      await t.pump();
      expect(find.text('All notifications marked as read.'), findsNothing);
      gate.complete();
      await t.pumpAndSettle();
      expect(find.text('All notifications marked as read.'), findsOneWidget);
    });

    testWidgets('a failed mark-all-read shows the existing failure toast, not a false success', (t) async {
      final src = FakeInbox()
        ..current = [n('a', 'rider_offline')]
        ..markAllError = Exception('offline');
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark all read'));
      await t.pumpAndSettle();
      expect(find.text('Could not update your inbox. Try again.'), findsOneWidget);
      expect(find.text('All notifications marked as read.'), findsNothing);
      expect(find.text('Mark all read'), findsOneWidget);
    });
  });

  group('history', () {
    test('an order an admin finished through status alone reads as finished', () {
      expect(historyOrder('o1', {'orderStatus': 'out_for_delivery', 'status': 'delivered', 'orderNumber': 'A'}).orderStatus, 'delivered');
      expect(historyOrder('o2', {'orderStatus': 'returned', 'status': 'delivered', 'orderNumber': 'B'}).orderStatus, 'returned');
      expect(historyOrder('o3', {'orderStatus': 'out_for_delivery', 'status': 'cancelled', 'orderNumber': 'C'}).orderStatus, 'cancelled');
      expect(historyOrder('o4', {'orderStatus': 'picked_up', 'orderNumber': 'D'}).orderStatus, 'picked_up');
    });

    test('filters keep only canonical matches, cancelled and returned separately', () {
      final delivered = historyOrder('a', {'orderStatus': 'delivered'});
      final returned = historyOrder('b', {'orderStatus': 'returned', 'status': 'delivered'});
      final cancelled = historyOrder('c', {'orderStatus': 'cancelled'});
      final active = historyOrder('d', {'orderStatus': 'picked_up'});
      final all = [delivered, returned, cancelled, active];
      expect(all.where((o) => historyMatches(o, HistoryFilter.delivered)).map((o) => o.id), ['a']);
      expect(all.where((o) => historyMatches(o, HistoryFilter.returned)).map((o) => o.id), ['b']);
      expect(all.where((o) => historyMatches(o, HistoryFilter.cancelled)).map((o) => o.id), ['c']);
      expect(all.where((o) => historyMatches(o, HistoryFilter.all)).length, 4);
    });

    test('changing the filter reloads from the first page with that filter', () async {
      final asked = <HistoryFilter>[];
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        asked.add(query.filter);
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      await h.setFilter(HistoryFilter.delivered);
      expect(asked, [HistoryFilter.all, HistoryFilter.delivered]);
      expect(h.filter, HistoryFilter.delivered);
    });

    test('changing the date range reloads from the first page with that cutoff', () async {
      final asked = <DateTime?>[];
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        asked.add(query.since);
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      await h.setDateRange(HistoryDateRange.last7Days);
      expect(asked, hasLength(2));
      expect(asked[0], isNull, reason: 'all time: no cutoff');
      expect(asked[1], isNotNull);
      expect(DateTime.now().difference(asked[1]!).inDays, 7);
      expect(h.dateRange, HistoryDateRange.last7Days);
      expect(h.hasActiveFilter, isTrue);
    });

    test('clearFilters resets status and date range together, in one reload', () async {
      var calls = 0;
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        calls++;
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      await h.setFilter(HistoryFilter.cancelled);
      await h.setDateRange(HistoryDateRange.last30Days);
      expect(h.hasActiveFilter, isTrue);
      final before = calls;
      await h.clearFilters();
      expect(calls, before + 1, reason: 'exactly one reload, not one per field');
      expect(h.filter, HistoryFilter.all);
      expect(h.dateRange, HistoryDateRange.allTime);
      expect(h.hasActiveFilter, isFalse);
      // A second clear with nothing active does not reload again.
      await h.clearFilters();
      expect(calls, before + 1);
    });

    testWidgets('detail shows this order\'s pay and whether it is in a statement', (t) async {
      final order = historyOrder('o9', {'orderStatus': 'delivered', 'orderNumber': 'ORD-9', 'total': 480});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => RiderEarning(
                  orderId: id, total: 55.46, basePay: 25, distancePay: 23.46, km: 3.91, codCollected: 480),
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('₹55.46'), findsOneWidget);
      expect(find.text('Cash collected'), findsOneWidget);
      expect(find.text("Goes into next Monday's statement"), findsOneWidget);
    });

    testWidgets('a cancelled order shows a static no-earnings line, without a read', (t) async {
      var reads = 0;
      final order = historyOrder('o8', {'orderStatus': 'cancelled', 'orderNumber': 'ORD-8', 'total': 100});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async { reads++; return null; },
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(reads, 0, reason: 'cancelled never has a rider_earnings record; no point reading');
      expect(find.text('No earnings — this order was cancelled.'), findsOneWidget);
    });

    testWidgets('a returned order still attempts a read, showing a distinct no-earnings line when none exists', (t) async {
      var reads = 0;
      final order = historyOrder('o7', {'orderStatus': 'returned', 'status': 'delivered', 'orderNumber': 'ORD-7', 'total': 200});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async { reads++; return null; },
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(reads, 1, reason: 'unlike cancelled, a returned order DOES attempt a read (forward-compatible with future return-handling pay)');
      expect(find.text('No earnings recorded for this returned order.'), findsOneWidget);
    });

    testWidgets('the delivery timeline shows recorded events in order, oldest first', (t) async {
      final order = historyOrder('o6', {'orderStatus': 'delivered', 'orderNumber': 'ORD-6', 'total': 300});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => [
                    OrderTimelineEvent(
                      id: 'e1',
                      status: 'delivery_accepted',
                      title: 'Delivery Accepted',
                      timestamp: DateTime(2026, 9, 18, 13, 5),
                    ),
                    OrderTimelineEvent(
                      id: 'e2',
                      status: 'delivery_problem',
                      title: 'Delivery problem reported',
                      detail: 'The delivery partner reported a problem (customer unreachable).',
                      timestamp: DateTime(2026, 9, 18, 13, 40),
                    ),
                  ],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Delivery Accepted'), findsOneWidget);
      expect(find.text('Delivery problem reported'), findsOneWidget);
      expect(find.textContaining('customer unreachable'), findsOneWidget);
      // Oldest first: Accepted's node paints above Problem's.
      final acceptedY = t.getTopLeft(find.text('Delivery Accepted')).dy;
      final problemY = t.getTopLeft(find.text('Delivery problem reported')).dy;
      expect(acceptedY, lessThan(problemY));
    });

    testWidgets('an empty timeline says so instead of showing nothing', (t) async {
      final order = historyOrder('o5', {'orderStatus': 'delivered', 'orderNumber': 'ORD-5', 'total': 50});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(find.text('No recorded timeline for this order.'), findsOneWidget);
    });

    testWidgets('the customer section reads from the order\'s own delivery address, and Get help is present', (t) async {
      final order = historyOrder('o4', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-4',
        'total': 90,
        'deliveryAddress': {
          'name': 'Meenakshi Sundaram',
          'phone': '+91 98765 43210',
          'addressLine1': '44, West Masi Street',
          'city': 'Madurai',
          'zipcode': '625001',
        },
      });
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Meenakshi Sundaram'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.textContaining('West Masi Street'), findsOneWidget);
      expect(find.text('Need help with this order?'), findsOneWidget);
      expect(find.byType(SupportContactButtons), findsOneWidget);
      // Read-only: no Call/Navigate actions for a completed record.
      expect(find.text('Call'), findsNothing);
      expect(find.text('Navigate'), findsNothing);
    });

    testWidgets('tapping "In a weekly statement" opens the real statement it names', (t) async {
      final order = historyOrder('o3', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-3',
        'total': 200,
        'deliveryPartnerId': 'r1',
      });
      final payout = RiderPayout(
        id: 'stmt-1',
        weekKey: '2026-W38',
        earned: 1000,
        netted: 0,
        amount: 1000,
        cashHeldAfter: 0,
        orderCount: 10,
        status: 'paid',
      );
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => RiderEarning(orderId: id, total: 55, statementId: 'stmt-1'),
              loadTimeline: (id) async => const [],
              loadPayout: (id) async {
                expect(id, 'stmt-1');
                return payout;
              }))));
      await t.pumpAndSettle();
      expect(find.byType(StatementScreen), findsNothing);
      await t.tap(find.text('In a weekly statement'));
      await t.pump(); // loading frame
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(StatementScreen), findsOneWidget);
    });

    testWidgets('a deleted or inaccessible statement says so instead of doing nothing', (t) async {
      final order = historyOrder('o2', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-2',
        'total': 200,
        'deliveryPartnerId': 'r1',
      });
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => RiderEarning(orderId: id, total: 55, statementId: 'stmt-gone'),
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      await t.tap(find.text('In a weekly statement'));
      await t.pumpAndSettle();
      expect(find.text('This statement is no longer available.'), findsOneWidget);
      expect(find.byType(StatementScreen), findsNothing);
      // The row is tappable again, not stuck showing a spinner forever.
      expect(find.text('In a weekly statement'), findsOneWidget);
    });

    testWidgets('a failed statement lookup says so distinctly, not as if it were missing', (t) async {
      final order = historyOrder('o1', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-1',
        'total': 200,
        'deliveryPartnerId': 'r1',
      });
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => RiderEarning(orderId: id, total: 55, statementId: 'stmt-1'),
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => throw Exception('network unavailable')))));
      await t.pumpAndSettle();
      await t.tap(find.text('In a weekly statement'));
      await t.pumpAndSettle();
      expect(find.text('Could not open this statement. Try again.'), findsOneWidget);
      expect(find.text('This statement is no longer available.'), findsNothing);
    });
  });
}
