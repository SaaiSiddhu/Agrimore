// DLV-N1 — the rider inbox (lib/inbox, screens/inbox) and the history filter
// and detail (data/rider_history.dart, screens/history).
import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/account/support_card.dart';
import 'package:delivery/data/order_timeline.dart';
import 'package:delivery/design_system/design_system.dart'
    show DeliveryCard, DeliveryCardVariant, DeliveryIcons;
import 'package:delivery/data/rider_history.dart';
import 'package:delivery/inbox/rider_inbox.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/data/rider_work.dart' show OrderDoc, RiderDataError;
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/screens/history/rider_history_screen.dart';
import 'package:delivery/screens/inbox/inbox_screen.dart';
import 'package:delivery/screens/money/bank_change_request_screen.dart';
import 'package:delivery/screens/money/money_screen.dart' show EarningTile, MoneyScreen;
import 'package:delivery/screens/money/statement_screen.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:delivery/screens/profile/identity_change_screen.dart';
import 'package:delivery/screens/support/support_request_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

// RiderRouteCard (DLVMAP1) reads LocationProvider for the stale-location
// banner's Refresh-location/native-service branching, and ActiveOrderScreen
// (DLVMAP3) unconditionally reads DeliveryOrderProvider to reconcile
// assignment/recovery state -- both needed here since some cases navigate to
// the real ActiveOrderScreen, which renders it. An always-empty active-work
// source is safe for every case in this file: DLVMAP3's own grace period
// keeps that silent (RecoveryPhase.normal) unless a test waits out
// kAssignmentConfirmGrace, which none here do.
Widget host(
  Widget child, {
  HistoryFetch? historyFetch,
  CountsFetch? historyCounts,
  SearchFetch? historySearch,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
        ChangeNotifierProvider<DeliveryOrderProvider>(
          create: (_) => DeliveryOrderProvider(
            activeSource: (_) => Stream.value((docs: const <OrderDoc>[], fromCache: false)),
            deliveredCount: (_, __) async => 0,
            historyFetch: historyFetch,
            historyCounts: historyCounts ?? (_, __, ___) async => (all: 0, delivered: 0, cancelled: 0, returned: 0),
            historySearch: historySearch ?? (_, __) async => null,
          )..bind('r1'),
        ),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

/// DLVH7: `RiderHistory.loadMore()` deliberately does not await its own
/// fire-and-forget counts refresh (a slow count query must never hold up the
/// main list) -- so a plain `test()` (no widget pump to ride along on) needs
/// an explicit microtask turn before asserting on `counts`.
Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

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

  group('identity change notice routing (DLVID3)', () {
    testWidgets('a vehicle-change notice opens the screen pinned to THAT request, as a vehicle change', (t) async {
      final src = FakeInbox()
        ..current = [
          RiderNotice.fromMap('n6', {
            'type': 'identity_change_rejected',
            'title': 'Vehicle change not approved',
            'unread': true,
            'data': {'type': 'identity_change_rejected', 'requestId': 'req-9', 'changeType': 'vehicle'},
          }),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Vehicle change not approved'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final screen = t.widget<IdentityChangeScreen>(find.byType(IdentityChangeScreen));
      expect(screen.requestId, 'req-9');
      expect(screen.changeType, 'vehicle');
    });

    testWidgets('a legacy notice with no changeType defaults to name, not a crash', (t) async {
      final src = FakeInbox()
        ..current = [
          RiderNotice.fromMap('n7', {
            'type': 'identity_change_approved',
            'title': 'Your name was updated',
            'unread': true,
            'data': {'type': 'identity_change_approved', 'requestId': 'req-old'},
          }),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Your name was updated'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final screen = t.widget<IdentityChangeScreen>(find.byType(IdentityChangeScreen));
      expect(screen.requestId, 'req-old');
      expect(screen.changeType, 'name');
    });

    testWidgets('an identity notice with no requestId (malformed) does nothing, not crash', (t) async {
      final src = FakeInbox()
        ..current = [
          RiderNotice.fromMap('n8', {
            'type': 'identity_change_approved',
            'title': 'Your name was updated',
            'unread': true,
            'data': {'type': 'identity_change_approved'},
          }),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Your name was updated'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(IdentityChangeScreen), findsNothing);
    });
  });

  group('bank change notice routing (DLVBANK1)', () {
    RiderNotice bankNotice(String id, String type, {String? requestId}) => RiderNotice.fromMap(id, {
          'type': type,
          'title': type == 'bank_change_approved' ? 'Payout details updated' : 'Payout details not changed',
          'unread': true,
          'data': {
            'type': type,
            if (requestId != null) 'requestId': requestId,
          },
        });

    testWidgets('a rejection notice with a requestId opens the screen pinned to THAT exact request', (t) async {
      final src = FakeInbox()..current = [bankNotice('n9', 'bank_change_rejected', requestId: 'req-77')];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Payout details not changed'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final screen = t.widget<BankChangeRequestScreen>(find.byType(BankChangeRequestScreen));
      expect(screen.requestId, 'req-77');
      expect(screen.riderId, 'r1');
    });

    testWidgets('an approval notice with a requestId opens the same pinned screen', (t) async {
      final src = FakeInbox()..current = [bankNotice('n10', 'bank_change_approved', requestId: 'req-88')];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Payout details updated'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final screen = t.widget<BankChangeRequestScreen>(find.byType(BankChangeRequestScreen));
      expect(screen.requestId, 'req-88');
    });

    testWidgets('a legacy notice with no requestId keeps the pre-existing generic Earnings destination', (t) async {
      final src = FakeInbox()..current = [bankNotice('n11', 'bank_change_rejected')];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Payout details not changed'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(MoneyScreen), findsOneWidget);
      expect(find.byType(BankChangeRequestScreen), findsNothing);
    });
  });

  group('support ticket notices (DLVSUP2)', () {
    RiderNotice supportNotice(String type, String ticketId) => RiderNotice.fromMap('n4', {
          'type': type,
          'title': 'Your support request was seen',
          'unread': true,
          'data': {'type': type, 'ticketId': ticketId},
        });

    testWidgets('a support-request-seen notice opens the exact ticket', (t) async {
      final src = FakeInbox()..current = [supportNotice('support_request_seen', 'tk-42')];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Your support request was seen'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final screen = t.widget<SupportRequestStatusScreen>(find.byType(SupportRequestStatusScreen));
      expect(screen.ticketId, 'tk-42');
    });

    testWidgets('a support-request-closed notice opens the exact ticket', (t) async {
      final src = FakeInbox()..current = [supportNotice('support_request_closed', 'tk-7')];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Your support request was seen'));
      await t.pumpAndSettle();
      final screen = t.widget<SupportRequestStatusScreen>(find.byType(SupportRequestStatusScreen));
      expect(screen.ticketId, 'tk-7');
    });

    testWidgets('a support notice with no ticketId (malformed/legacy) does nothing, not crash', (t) async {
      final src = FakeInbox()
        ..current = [
          RiderNotice.fromMap('n5', {
            'type': 'support_request_seen',
            'title': 'Your support request was seen',
            'unread': true,
            'data': {'type': 'support_request_seen'},
          }),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      await t.tap(find.text('Your support request was seen'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(SupportRequestStatusScreen), findsNothing);
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

    group('DLVH11: mondayIstMidnightAtOrBefore (pure)', () {
      test('a Monday-IST-midnight instant maps to itself -- the boundary is inclusive', () {
        final mondayIst = DateTime.utc(2026, 9, 27, 18, 30); // 2026-09-28 00:00 IST, a real Monday
        expect(mondayIstMidnightAtOrBefore(mondayIst), mondayIst);
      });

      test('a Sunday just before the boundary maps to the PRIOR Monday, not the upcoming one', () {
        final mondayIst = DateTime.utc(2026, 9, 27, 18, 30);
        final oneMinuteBefore = mondayIst.subtract(const Duration(minutes: 1)); // still Sunday IST
        expect(mondayIstMidnightAtOrBefore(oneMinuteBefore), mondayIst.subtract(const Duration(days: 7)));
      });

      test('resolves by IST, not by UTC -- a UTC-Sunday instant that is already IST-Monday counts as the new week', () {
        // 2026-09-27 20:00 UTC is still Sunday in UTC, but +5:30 makes it
        // 2026-09-28 01:30 IST -- already the new week by the SAME clock the
        // rider's own weekly statement is cut by.
        final utcSundayButIstMonday = DateTime.utc(2026, 9, 27, 20, 0);
        final mondayIst = DateTime.utc(2026, 9, 27, 18, 30);
        expect(mondayIstMidnightAtOrBefore(utcSundayButIstMonday), mondayIst,
            reason: 'a naive UTC-only check would wrongly say "not yet Monday"');
      });

      test('crosses a year boundary correctly: an early-January instant can belong to a December Monday', () {
        // 2026-01-01 is a Thursday; its own week's Monday is 2025-12-29.
        final earlyJan = DateTime.utc(2026, 1, 1, 12, 0);
        final decMondayIst = DateTime.utc(2025, 12, 28, 18, 30); // 2025-12-29 00:00 IST
        expect(mondayIstMidnightAtOrBefore(earlyJan), decMondayIst);
      });
    });

    test('changing the date range reloads from the first page with that window', () async {
      final askedSince = <DateTime?>[];
      final askedUntil = <DateTime?>[];
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        askedSince.add(query.since);
        askedUntil.add(query.until);
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      await h.setDateRange(HistoryDateRange.thisWeek);
      expect(askedSince, hasLength(2));
      expect(askedSince[0], isNull, reason: 'all time: no cutoff');
      expect(askedUntil[0], isNull);
      expect(askedSince[1], mondayIstMidnightAtOrBefore(DateTime.now()), reason: 'the same Monday-IST cutoff the rider\'s own statement uses');
      expect(askedUntil[1], isNull, reason: 'this week is open-ended -- it runs up to now');
      expect(h.dateRange, HistoryDateRange.thisWeek);
      expect(h.hasActiveFilter, isTrue);
      await h.setDateRange(HistoryDateRange.lastWeek);
      expect(askedSince[2], mondayIstMidnightAtOrBefore(DateTime.now()).subtract(const Duration(days: 7)));
      expect(askedUntil[2], mondayIstMidnightAtOrBefore(DateTime.now()), reason: 'last week is bounded -- it excludes the current week');
    });

    test('DLVC1: setCustomDateRange -- same-day range, inclusive last day via a correct exclusive upper bound', () async {
      final askedSince = <DateTime?>[];
      final askedUntil = <DateTime?>[];
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        askedSince.add(query.since);
        askedUntil.add(query.until);
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      final day = DateTime(2026, 9, 15);
      await h.setCustomDateRange(day, day);
      expect(h.dateRange, HistoryDateRange.custom);
      expect(askedSince[1], DateTime(2026, 9, 15), reason: 'midnight of the chosen day');
      expect(askedUntil[1], DateTime(2026, 9, 16), reason: 'exclusive upper bound is the NEXT day, not the same day');
      expect(h.since, askedSince[1]);
      expect(h.until, askedUntil[1]);
    });

    test('DLVC1: setCustomDateRange -- month and year boundaries normalize correctly', () async {
      final askedUntil = <DateTime?>[];
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        askedUntil.add(query.until);
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      await h.setCustomDateRange(DateTime(2026, 1, 20), DateTime(2026, 1, 31));
      expect(askedUntil[1], DateTime(2026, 2, 1), reason: 'day 31 + 1 rolls into the next month');
      await h.setCustomDateRange(DateTime(2026, 12, 20), DateTime(2026, 12, 31));
      expect(askedUntil[2], DateTime(2027, 1, 1), reason: 'and across a year boundary too');
    });

    test('DLVC1: setCustomDateRange is a no-op when the same range is already applied', () async {
      var calls = 0;
      final h = RiderHistory(fetch: (rider, query, cursor, size) async {
        calls++;
        return (items: <OrderModel>[], cursor: null, hasMore: false);
      })
        ..bind('r1');
      await h.loadMore();
      final first = DateTime(2026, 9, 1);
      final last = DateTime(2026, 9, 7);
      await h.setCustomDateRange(first, last);
      final before = calls;
      await h.setCustomDateRange(first, last);
      expect(calls, before, reason: 'an identical custom range must not trigger a redundant reload');
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
      await h.setDateRange(HistoryDateRange.lastWeek);
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

    group('DLVH7: per-status counts scoped to the active date range', () {
      test('counts load once on the first page, not again on later pages of the same scope', () async {
        var calls = 0;
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async =>
              (items: <OrderModel>[historyOrder('o1', {'orderNumber': 'A'})], cursor: 'c1', hasMore: true),
          counts: (rider, since, until) async {
            calls++;
            return (all: 5, delivered: 3, cancelled: 1, returned: 1);
          },
        )..bind('r1');
        await h.loadMore();
        await flushMicrotasks(); // counts are deliberately not awaited by loadMore itself
        expect(calls, 1);
        expect(h.counts, (all: 5, delivered: 3, cancelled: 1, returned: 1));
        await h.loadMore(); // a second page, same rider/date scope
        await flushMicrotasks();
        expect(calls, 1, reason: 'paging further must not recompute date-scoped counts');
      });

      test('counts reload when the date range changes, but not when only the status chip does', () async {
        var calls = 0;
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          counts: (rider, since, until) async {
            calls++;
            return (all: 0, delivered: 0, cancelled: 0, returned: 0);
          },
        )..bind('r1');
        await h.loadMore();
        await flushMicrotasks();
        expect(calls, 1);
        await h.setFilter(HistoryFilter.delivered);
        await flushMicrotasks();
        expect(calls, 1, reason: 'a status-chip tap must not recompute date-scoped counts');
        await h.setDateRange(HistoryDateRange.thisWeek);
        await flushMicrotasks();
        expect(calls, 2);
      });

      test('a counts failure clears them to unavailable rather than showing a stale number', () async {
        var fail = false;
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          counts: (rider, since, until) async {
            if (fail) throw Exception('offline');
            return (all: 9, delivered: 9, cancelled: 0, returned: 0);
          },
        )..bind('r1');
        await h.loadMore();
        await flushMicrotasks();
        expect(h.counts, isNotNull);
        fail = true;
        await h.setDateRange(HistoryDateRange.lastWeek);
        await flushMicrotasks();
        expect(h.counts, isNull);
      });

      test('DLVH11: counts and the list receive the identical since/until window for the same preset', () async {
        DateTime? listSince, listUntil, countsSince, countsUntil;
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async {
            listSince = query.since;
            listUntil = query.until;
            return (items: <OrderModel>[], cursor: null, hasMore: false);
          },
          counts: (rider, since, until) async {
            countsSince = since;
            countsUntil = until;
            return (all: 0, delivered: 0, cancelled: 0, returned: 0);
          },
        )..bind('r1');
        await h.setDateRange(HistoryDateRange.lastWeek);
        await flushMicrotasks();
        expect(listSince, isNotNull);
        expect(listSince, countsSince, reason: 'the list and its counts must never see different windows');
        expect(listUntil, isNotNull, reason: 'last week is genuinely bounded');
        expect(listUntil, countsUntil);
      });
    });

    group('DLVH7: exact Order ID search', () {
      test('finds an order by its exact Order ID, independent of the currently-active filter', () async {
        final order = historyOrder('o9', {'orderNumber': 'AGM-9', 'orderStatus': 'cancelled'});
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async {
            expect(rider, 'r1');
            expect(orderNumber, 'AGM-9');
            return order;
          },
        )..bind('r1');
        await h.setFilter(HistoryFilter.delivered); // deliberately not the found order's own status
        await h.search('AGM-9');
        expect(h.searchResult, order);
        expect(h.searchNotFound, isFalse);
        expect(h.isSearchActive, isTrue);
        expect(h.filter, HistoryFilter.delivered, reason: 'search must not silently change the status filter underneath');
      });

      test('a search with no match reports not-found, not a silent empty state', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => null,
        )..bind('r1');
        await h.search('DOES-NOT-EXIST');
        expect(h.searchResult, isNull);
        expect(h.searchNotFound, isTrue);
      });

      test('clearing search, including by submitting an empty string, returns to the un-searched state', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => historyOrder('o1', {'orderNumber': orderNumber}),
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.isSearchActive, isTrue);
        h.clearSearch();
        expect(h.isSearchActive, isFalse);
        expect(h.searchResult, isNull);
        await h.search('AGM-2');
        expect(h.isSearchActive, isTrue);
        await h.search(''); // an empty submission clears exactly like the X button
        expect(h.isSearchActive, isFalse);
      });

      test('a newer search supersedes a slower, still-in-flight older one', () async {
        final gates = <String, Completer<OrderModel?>>{};
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) {
            final c = Completer<OrderModel?>();
            gates[orderNumber] = c;
            return c.future;
          },
        )..bind('r1');
        final first = h.search('AAA');
        await Future<void>.delayed(Duration.zero);
        final second = h.search('BBB');
        await Future<void>.delayed(Duration.zero);
        gates['BBB']!.complete(historyOrder('o2', {'orderNumber': 'BBB'}));
        await second;
        gates['AAA']!.complete(historyOrder('o1', {'orderNumber': 'AAA'})); // resolves late, after BBB already won
        await first;
        expect(h.searchText, 'BBB');
        expect(h.searchResult?.orderNumber, 'BBB', reason: 'the late AAA response must not overwrite the newer BBB result');
      });

      test('binding to a different rider clears both counts and search', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          counts: (rider, since, until) async => (all: 1, delivered: 1, cancelled: 0, returned: 0),
          search: (rider, orderNumber) async => historyOrder('o1', {'orderNumber': orderNumber}),
        )..bind('r1');
        await h.loadMore();
        await flushMicrotasks();
        await h.search('AGM-1');
        expect(h.counts, isNotNull);
        expect(h.isSearchActive, isTrue);
        h.bind('r2');
        expect(h.counts, isNull);
        expect(h.isSearchActive, isFalse);
        expect(h.searchResult, isNull);
      });

      test('DLVC1: switching rider accounts while a list page fetch is in flight discards the stale page', () async {
        final gate = Completer<HistoryPage>();
        final h = RiderHistory(fetch: (rider, query, cursor, size) => gate.future)..bind('r1');
        final pending = h.loadMore(); // in flight, not yet resolved
        h.bind('r2'); // account switch WHILE the above page fetch is still pending
        gate.complete((items: [historyOrder('secretA', {'orderNumber': 'A'})], cursor: 'c1', hasMore: true));
        await pending;
        expect(h.items, isEmpty, reason: 'rider A\'s late page must never land under rider B\'s session');
        expect(h.loading, isFalse, reason: 'the stale response must not leave the NEW session stuck loading forever');
      });

      test('DLVC1: switching rider accounts while counts are in flight discards the stale counts', () async {
        final gate = Completer<HistoryCounts>();
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          counts: (rider, since, until) => gate.future,
        )..bind('r1');
        await h.loadMore(); // starts the counts fetch (fire-and-forget) but does not await it
        h.bind('r2');
        gate.complete((all: 99, delivered: 99, cancelled: 0, returned: 0)); // rider A's stale counts arrive late
        await flushMicrotasks();
        expect(h.counts, isNull, reason: 'rider A\'s late counts must never land under rider B\'s session');
      });
    });

    group('DLVH9: search errors are distinct from a genuine not-found result', () {
      test('a FirebaseException failure sets searchError, not searchNotFound', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => throw FirebaseException(plugin: 'firestore', code: 'unavailable'),
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.searchError, RiderDataError.offline);
        expect(h.searchNotFound, isFalse, reason: 'a query failure is not the same fact as a genuine no-match');
        expect(h.searchResult, isNull);
      });

      test('a permission-denied failure maps to RiderDataError.permission, not unknown', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => throw FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.searchError, RiderDataError.permission);
      });

      test('a missing-index failure (failed-precondition) is a search error, never a false not-found', () async {
        // The exact scenario this phase exists to fix: an unresolved index dependency
        // must fail honestly, not read to the rider as "no delivery with that Order ID".
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => throw FirebaseException(plugin: 'firestore', code: 'failed-precondition'),
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.searchError, isNotNull);
        expect(h.searchNotFound, isFalse);
      });

      test('a non-Firebase exception maps to RiderDataError.unknown', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => throw Exception('boom'),
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.searchError, RiderDataError.unknown);
      });

      test('a fresh search clears a stale error from a previous failed attempt', () async {
        var fail = true;
        final order = historyOrder('o1', {'orderNumber': 'AGM-1'});
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async {
            if (fail) throw FirebaseException(plugin: 'firestore', code: 'unavailable');
            return order;
          },
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.searchError, isNotNull);
        fail = false;
        await h.search('AGM-1');
        expect(h.searchError, isNull, reason: 'a successful retry must not leave the old error lingering');
        expect(h.searchResult, order);
      });

      test('clearSearch resets a lingering error, not only the result', () async {
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) async => throw FirebaseException(plugin: 'firestore', code: 'unavailable'),
        )..bind('r1');
        await h.search('AGM-1');
        expect(h.searchError, isNotNull);
        h.clearSearch();
        expect(h.searchError, isNull);
      });

      test('switching rider accounts while a search is in flight discards the stale response', () async {
        final gate = Completer<OrderModel?>();
        final h = RiderHistory(
          fetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          search: (rider, orderNumber) => gate.future,
        )..bind('r1');
        final pending = h.search('AGM-1'); // in flight, not yet resolved
        h.bind('r2'); // account switch WHILE the above search is still pending
        gate.complete(historyOrder('o1', {'orderNumber': 'AGM-1'})); // the stale r1 response arrives late
        await pending;
        expect(h.isSearchActive, isFalse, reason: 'the stale r1 search result must not resurrect after switching to r2');
        expect(h.searchResult, isNull);
        expect(h.searchError, isNull);
      });
    });

    testWidgets('DLVH9: a search failure shows a distinct, retryable error, not the not-found message', (t) async {
      var fail = true;
      final order = historyOrder('o1', {'orderNumber': 'AGM-1'});
      await t.pumpWidget(host(
        const RiderHistoryScreen(),
        historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
        historySearch: (rider, orderNumber) async {
          if (fail) throw FirebaseException(plugin: 'firestore', code: 'unavailable');
          return order;
        },
      ));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('history-search-field')), 'AGM-1');
      await t.pumpAndSettle();
      expect(find.text("Couldn't reach Agrimore. Check your connection."), findsOneWidget);
      expect(find.text('No delivery found with that Order ID'), findsNothing);

      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Order AGM-1'), findsOneWidget);
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

    testWidgets('DLVH5: payment method shows for every status, not just when an earning resolves', (t) async {
      final cod = historyOrder('o6', {'orderStatus': 'cancelled', 'orderNumber': 'ORD-6', 'total': 150});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: cod,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(find.text('COD (cash)'), findsOneWidget);
      expect(find.text('Online Payment'), findsNothing);
    });

    testWidgets('DLVH5: a non-cod order shows Online Payment, not COD', (t) async {
      final online = historyOrder('o7', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-7',
        'total': 300,
        'paymentMethod': 'razorpay',
      });
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: online,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null))));
      await t.pumpAndSettle();
      expect(find.text('Online Payment'), findsOneWidget);
      expect(find.text('COD (cash)'), findsNothing);
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

    testWidgets('DLVH6: the merchant section shows the resolved seller name', (t) async {
      final order = historyOrder('o8', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-8',
        'total': 90,
        'sellerId': 'seller-1',
      });
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null,
              fetchStoreName: (id) async {
                expect(id, 'seller-1');
                return 'Fresh Fields';
              }))));
      await t.pumpAndSettle();
      expect(find.text('Merchant'), findsOneWidget);
      expect(find.text('Fresh Fields'), findsOneWidget);
    });

    testWidgets('DLVH6: no sellerId shows no merchant section at all', (t) async {
      final order = historyOrder('o9', {'orderStatus': 'delivered', 'orderNumber': 'ORD-9', 'total': 90});
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null,
              fetchStoreName: (id) async => fail('must not be called without a sellerId')))));
      await t.pumpAndSettle();
      expect(find.text('Merchant'), findsNothing);
    });

    testWidgets('DLVH6: an unresolvable seller shows no merchant section, not an error state', (t) async {
      final order = historyOrder('o10', {
        'orderStatus': 'delivered',
        'orderNumber': 'ORD-10',
        'total': 90,
        'sellerId': 'deleted-seller',
      });
      await t.pumpWidget(host(Scaffold(
          body: HistoryDetail(
              order: order,
              loadEarning: (id) async => null,
              loadTimeline: (id) async => const [],
              loadPayout: (id) async => null,
              fetchStoreName: (id) async => null))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Merchant'), findsNothing);
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

      // DLVH4: reached from history, so a "Back to delivery" affordance is
      // offered, and tapping it returns to the same HistoryDetail instance.
      final backButton = find.byKey(const ValueKey('back-to-delivery'));
      expect(backButton, findsOneWidget);
      await t.ensureVisible(backButton);
      await t.pumpAndSettle();
      await t.tap(backButton);
      await t.pumpAndSettle();
      expect(find.byType(StatementScreen), findsNothing);
      expect(find.byType(HistoryDetail), findsOneWidget);
    });

    testWidgets('a statement opened NOT from history has no "Back to delivery" affordance', (t) async {
      // The inbox-notice and payouts-list call sites have no originating
      // order to return to -- confirmed by constructing StatementScreen
      // directly the way those two callers do, neither setting the new
      // DLVH4 parameters.
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-2', weekKey: '2026-W38', earned: 500, netted: 0, amount: 500,
          cashHeldAfter: 0, orderCount: 3, status: 'paid',
        ),
        load: (after) async => const StatementPage([], null, false),
      )));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('back-to-delivery')), findsNothing);
    });

    testWidgets('the statement line matching highlightOrderId renders with the brand-highlighted card variant', (t) async {
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-3', weekKey: '2026-W38', earned: 900, netted: 0, amount: 900,
          cashHeldAfter: 0, orderCount: 2, status: 'paid',
        ),
        load: (after) async => const StatementPage(
          [
            RiderEarning(orderId: 'o-highlighted', total: 400, statementId: 'stmt-3'),
            RiderEarning(orderId: 'o-other', total: 500, statementId: 'stmt-3'),
          ],
          null,
          false,
        ),
        highlightOrderId: 'o-highlighted',
      )));
      await t.pumpAndSettle();

      final tiles = find.byType(EarningTile);
      expect(tiles, findsNWidgets(2));
      DeliveryCardVariant variantOf(int index) => t
          .widget<DeliveryCard>(find.descendant(
              of: tiles.at(index), matching: find.byType(DeliveryCard)))
          .variant;

      expect(variantOf(0), DeliveryCardVariant.brand);
      expect(variantOf(1), DeliveryCardVariant.standard);
    });

    testWidgets('DLVH8: a highlighted order beyond the first page is found by auto-loading further pages', (t) async {
      var calls = 0;
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-4', weekKey: '2026-W38', earned: 900, netted: 0, amount: 900,
          cashHeldAfter: 0, orderCount: 2, status: 'paid',
        ),
        load: (after) async {
          calls++;
          if (calls == 1) {
            return const StatementPage(
              [RiderEarning(orderId: 'o-page1', total: 100, statementId: 'stmt-4')],
              null, // this fake tracks pages via `calls`, not the cursor's identity
              true,
            );
          }
          return const StatementPage(
            [RiderEarning(orderId: 'o-page2-target', total: 200, statementId: 'stmt-4')],
            null,
            false,
          );
        },
        highlightOrderId: 'o-page2-target',
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(calls, 2, reason: 'must auto-continue to the second page without a manual Load More tap');

      final tiles = find.byType(EarningTile);
      expect(tiles, findsNWidgets(2));
      DeliveryCardVariant variantOf(int index) => t
          .widget<DeliveryCard>(find.descendant(of: tiles.at(index), matching: find.byType(DeliveryCard)))
          .variant;
      expect(variantOf(0), DeliveryCardVariant.standard, reason: 'o-page1 is not the target');
      expect(variantOf(1), DeliveryCardVariant.brand, reason: 'o-page2-target, found on the second page');
      // Fully settled, not stuck loading forever once the target is found.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('DLVH8: a highlighted order that never appears exhausts all pages honestly, unhighlighted', (t) async {
      var calls = 0;
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-5', weekKey: '2026-W38', earned: 300, netted: 0, amount: 300,
          cashHeldAfter: 0, orderCount: 1, status: 'paid',
        ),
        load: (after) async {
          calls++;
          if (calls == 1) {
            return const StatementPage(
              [RiderEarning(orderId: 'o-only', total: 300, statementId: 'stmt-5')],
              null,
              true,
            );
          }
          return const StatementPage([], null, false); // exhausted, target never found
        },
        highlightOrderId: 'this-id-does-not-exist-in-this-statement',
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(calls, 2, reason: 'must exhaust every page looking for the target, not stop after the first');
      final tile = t.widget<DeliveryCard>(
          find.descendant(of: find.byType(EarningTile), matching: find.byType(DeliveryCard)));
      expect(tile.variant, DeliveryCardVariant.standard, reason: 'honestly unhighlighted -- the id is not in this statement');
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'settled, not stuck loading forever');
    });

    testWidgets('DLVH8: a null highlightOrderId never triggers an extra page load beyond what the rider asks for', (t) async {
      var calls = 0;
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-6', weekKey: '2026-W38', earned: 100, netted: 0, amount: 100,
          cashHeldAfter: 0, orderCount: 1, status: 'paid',
        ),
        load: (after) async {
          calls++;
          return const StatementPage(
            [RiderEarning(orderId: 'o-1', total: 100, statementId: 'stmt-6')],
            null,
            true, // more pages exist, but nothing should ask for them automatically
          );
        },
        // highlightOrderId deliberately omitted -- the plain, pre-existing case.
      )));
      await t.pumpAndSettle();
      expect(calls, 1, reason: 'no highlight target: exactly the one page the rider is shown, no silent extra fetch');
      expect(find.text('Load more'), findsOneWidget, reason: 'further pages remain available on manual request, as before');
    });

    group('DLVH10: statementCursorAdvanced (pure)', () {
      test('a repeated non-null cursor id is no progress; anything else is', () {
        expect(statementCursorAdvanced('doc-1', 'doc-1'), isFalse, reason: 'the exact anomaly this guards against');
        expect(statementCursorAdvanced('doc-1', 'doc-2'), isTrue);
        expect(statementCursorAdvanced(null, 'doc-1'), isTrue);
        expect(statementCursorAdvanced('doc-1', null), isTrue, reason: 'a null cursor is not itself suspicious');
        expect(statementCursorAdvanced(null, null), isTrue, reason: 'matches this file\'s own null-cursor test fixtures');
      });
    });

    testWidgets('DLVH10: a duplicate row across two pages is not double-counted', (t) async {
      var calls = 0;
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-7', weekKey: '2026-W38', earned: 300, netted: 0, amount: 300,
          cashHeldAfter: 0, orderCount: 2, status: 'paid',
        ),
        load: (after) async {
          calls++;
          if (calls == 1) {
            return const StatementPage(
              [RiderEarning(orderId: 'o-a', total: 100, statementId: 'stmt-7'), RiderEarning(orderId: 'o-b', total: 100, statementId: 'stmt-7')],
              null,
              true,
            );
          }
          // o-b reappears (a race shifted the pagination window) alongside a genuinely new o-c.
          return const StatementPage(
            [RiderEarning(orderId: 'o-b', total: 100, statementId: 'stmt-7'), RiderEarning(orderId: 'o-c', total: 100, statementId: 'stmt-7')],
            null,
            false,
          );
        },
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('Load more'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(EarningTile), findsNWidgets(3), reason: 'o-a, o-b (once, not twice), o-c');
    });

    testWidgets('DLVH10: a target that never appears stops auto-continuing at a hard cap, not forever', (t) async {
      // A generous viewport: this test is about the auto-continue COUNT and
      // the footer's own reachability, not about scroll-to-target behaviour
      // (covered separately below) -- tall enough that ListView's own lazy
      // Sliver children (it stays lazy even with the plain children:
      // constructor) build far enough to reach the footer without a manual
      // scroll standing in for what this test is actually checking.
      t.view.physicalSize = const Size(1080, 3200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var calls = 0;
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-8', weekKey: '2026-W38', earned: 1000, netted: 0, amount: 1000,
          cashHeldAfter: 0, orderCount: 50, status: 'paid',
        ),
        load: (after) async {
          calls++;
          return StatementPage(
            [RiderEarning(orderId: 'o-page-$calls', total: 10, statementId: 'stmt-8')],
            null,
            true, // always claims more -- a deliberately adversarial fixture
          );
        },
        highlightOrderId: 'never-appears-anywhere',
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(calls, 20, reason: 'the hard cap, not an unbounded chain');
      expect(find.text('Load more'), findsOneWidget,
          reason: 'hasMore is genuinely still true -- manual continuation remains available past the auto-cap');
    });

    testWidgets('DLVH10: the found target scrolls into the visible viewport, not just the widget tree', (t) async {
      // Deliberately the tester's own DEFAULT (small) viewport: entry #25 of
      // 30 starts well beyond ListView's initial Sliver cache extent, so its
      // own element -- and hence a GlobalKey context to ensureVisible -- does
      // not exist until something actually scrolls near it first. This is
      // exactly the gap the review named: correct highlight colour is not
      // itself proof of visibility.
      final manyEntries = List.generate(30, (i) => RiderEarning(orderId: 'o-$i', total: 10, statementId: 'stmt-9'));
      await t.pumpWidget(host(StatementScreen(
        payout: const RiderPayout(
          id: 'stmt-9', weekKey: '2026-W38', earned: 300, netted: 0, amount: 300,
          cashHeldAfter: 0, orderCount: 30, status: 'paid',
        ),
        load: (after) async => StatementPage(manyEntries, null, false),
        highlightOrderId: 'o-25',
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final targetFinder = find.byWidgetPredicate((w) => w is EarningTile && w.earning.orderId == 'o-25' && w.highlighted);
      expect(targetFinder, findsOneWidget, reason: 'the estimated-offset jump must make the Sliver build it at all');
      final dy = t.getTopLeft(targetFinder).dy;
      final viewportHeight = t.view.physicalSize.height / t.view.devicePixelRatio;
      expect(dy, greaterThanOrEqualTo(0), reason: 'scrolled into view, not sitting above the visible area');
      expect(dy, lessThan(viewportHeight), reason: 'scrolled into view, not sitting below the visible area');
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

    group('DLVH7: history screen -- count-annotated chips and Order ID search', () {
      testWidgets('status chips show counts once loaded, plain labels before that', (t) async {
        final gate = Completer<HistoryCounts>();
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          historyCounts: (rider, since, until) => gate.future,
        ));
        await t.pump();
        expect(find.text('All'), findsOneWidget, reason: 'no count yet: the plain label');
        expect(find.text('All (4)'), findsNothing);
        gate.complete((all: 4, delivered: 3, cancelled: 1, returned: 0));
        await t.pumpAndSettle();
        expect(find.text('All (4)'), findsOneWidget);
        expect(find.text('Delivered (3)'), findsOneWidget);
        expect(find.text('Cancelled (1)'), findsOneWidget);
        expect(find.text('Returned (0)'), findsOneWidget);
      });

      testWidgets('entering a matching Order ID shows exactly that order, regardless of the active filter', (t) async {
        final found = historyOrder('o1', {'orderNumber': 'AGM-42', 'orderStatus': 'cancelled', 'total': 250});
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async =>
              (items: <OrderModel>[historyOrder('o2', {'orderNumber': 'AGM-1', 'orderStatus': 'delivered'})], cursor: null, hasMore: false),
          historySearch: (rider, orderNumber) async {
            expect(orderNumber, 'AGM-42');
            return found;
          },
        ));
        await t.pumpAndSettle();
        expect(find.text('Order AGM-1'), findsOneWidget);
        await t.enterText(find.byKey(const ValueKey('history-search-field')), 'AGM-42');
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Order AGM-42'), findsOneWidget);
        expect(find.text('Order AGM-1'), findsNothing, reason: 'search replaces the filtered list, not merges with it');
      });

      testWidgets('a non-matching Order ID says so, not a blank or generic empty state', (t) async {
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
          historySearch: (rider, orderNumber) async => null,
        ));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const ValueKey('history-search-field')), 'NO-SUCH-ORDER');
        await t.pumpAndSettle();
        expect(find.text('No delivery found with that Order ID'), findsOneWidget);
      });

      testWidgets('clearing the search field restores the normal filtered list', (t) async {
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async =>
              (items: <OrderModel>[historyOrder('o3', {'orderNumber': 'AGM-3', 'orderStatus': 'delivered'})], cursor: null, hasMore: false),
          historySearch: (rider, orderNumber) async => null,
        ));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const ValueKey('history-search-field')), 'NO-SUCH-ORDER');
        await t.pumpAndSettle();
        expect(find.text('No delivery found with that Order ID'), findsOneWidget);
        await t.tap(find.byIcon(DeliveryIcons.close).last);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Order AGM-3'), findsOneWidget);
        expect(find.text('No delivery found with that Order ID'), findsNothing);
      });
    });

    group('DLVC1: history filter bottom sheet', () {
      testWidgets('the funnel action opens the sheet; This week + Apply commits the range', (t) async {
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
        ));
        await t.pumpAndSettle();
        expect(find.text('All time'), findsOneWidget, reason: 'the summary bar\'s own default label');

        await t.tap(find.byKey(const ValueKey('history-open-filter-sheet')));
        await t.pumpAndSettle();
        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('Date range'), findsOneWidget);
        expect(find.text('Delivery status'), findsOneWidget);

        await t.tap(find.byKey(const ValueKey('history-sheet-range-thisWeek')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-apply')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Filters'), findsNothing, reason: 'the sheet closed after Apply');
        expect(find.text('All time'), findsNothing, reason: 'the summary bar reflects the newly-applied range');
      });

      testWidgets('closing the sheet without Apply discards the staged selection', (t) async {
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
        ));
        await t.pumpAndSettle();

        await t.tap(find.byKey(const ValueKey('history-open-filter-sheet')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-range-lastWeek')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-close')));
        await t.pumpAndSettle();

        expect(t.takeException(), isNull);
        expect(find.text('All time'), findsOneWidget, reason: 'the staged Last week tap was never applied');
      });

      testWidgets('Reset filters clears an already-applied filter from inside the sheet', (t) async {
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
        ));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-open-filter-sheet')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-range-thisWeek')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-apply')));
        await t.pumpAndSettle();
        expect(find.text('All time'), findsNothing);

        await t.tap(find.byKey(const ValueKey('history-open-filter-sheet')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-reset')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('All time'), findsOneWidget, reason: 'Reset applies immediately, unlike a plain close');
      });

      testWidgets('a status radio selection combines with a date-range pill in one Apply', (t) async {
        await t.pumpWidget(host(
          const RiderHistoryScreen(),
          historyFetch: (rider, query, cursor, size) async => (items: <OrderModel>[], cursor: null, hasMore: false),
        ));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-open-filter-sheet')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-status-delivered')));
        await t.tap(find.byKey(const ValueKey('history-sheet-range-lastWeek')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('history-sheet-apply')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // The inline status chip reflects the same underlying filter the
        // sheet just staged -- both controls share one RiderHistory.
        final chip = t.widget<ChoiceChip>(find.byKey(const ValueKey('history-filter-delivered')));
        expect(chip.selected, isTrue);
      });
    });
  });

  group('DLVI3: noticeIcon distinguishes notification TYPE, not just read/unread', () {
    test('every real, currently-written RiderNoticeType maps to a distinct-from-generic icon', () {
      const typed = {
        'delivery_assigned': DeliveryIcons.package,
        'delivery_unassigned': DeliveryIcons.packageX,
        'delivery_problem_resolved': DeliveryIcons.documentWarning,
        'statement_ready': DeliveryIcons.statement,
        'payout_sent': DeliveryIcons.rupee,
        'bank_change_approved': DeliveryIcons.bank,
        'bank_change_rejected': DeliveryIcons.bank,
        'identity_change_approved': DeliveryIcons.idCard,
        'identity_change_rejected': DeliveryIcons.idCard,
        'document_review_approved': DeliveryIcons.document,
        'document_review_rejected': DeliveryIcons.document,
        'incident_acknowledged': DeliveryIcons.shieldCheck,
        'incident_resolved': DeliveryIcons.shieldCheck,
        'support_request_seen': DeliveryIcons.support,
        'support_request_closed': DeliveryIcons.support,
        'rider_offline': DeliveryIcons.offline,
      };
      for (final entry in typed.entries) {
        expect(noticeIcon(entry.key, unread: true), entry.value, reason: '${entry.key} (unread)');
        expect(noticeIcon(entry.key, unread: false), entry.value, reason: '${entry.key} (read)');
      }
    });

    test('two different types never collapse to the same icon as the generic read/unread pair', () {
      // Guards against a mapping that accidentally reuses bell/checkCircle
      // for a real type, which would silently regress to the old behaviour.
      const typed = [
        'delivery_assigned', 'delivery_unassigned', 'delivery_problem_resolved', 'statement_ready',
        'payout_sent', 'bank_change_approved', 'identity_change_approved', 'document_review_approved',
        'incident_acknowledged', 'support_request_seen', 'rider_offline',
      ];
      for (final type in typed) {
        expect(noticeIcon(type, unread: true), isNot(DeliveryIcons.bell), reason: type);
        expect(noticeIcon(type, unread: false), isNot(DeliveryIcons.checkCircle), reason: type);
      }
    });

    test('an unrecognised or empty type falls back to the pre-existing read/unread pair', () {
      expect(noticeIcon('', unread: true), DeliveryIcons.bell);
      expect(noticeIcon('', unread: false), DeliveryIcons.checkCircle);
      expect(noticeIcon('some_future_type_this_client_does_not_know_yet', unread: true), DeliveryIcons.bell);
      expect(noticeIcon('some_future_type_this_client_does_not_know_yet', unread: false), DeliveryIcons.checkCircle);
    });
  });

  group('DLVI4: Today/Earlier inbox time-grouping', () {
    final now = DateTime(2026, 9, 27, 15, 0);

    test('inboxSectionFor: calendar-day comparison, not a fixed 24h window', () {
      expect(inboxSectionFor(DateTime(2026, 9, 27, 0, 1), now: now), InboxSection.today);
      expect(inboxSectionFor(DateTime(2026, 9, 27, 23, 59), now: now), InboxSection.today);
      // 23:59 yesterday is less than a minute before "today, 00:01" above, but a DIFFERENT calendar day.
      expect(inboxSectionFor(DateTime(2026, 9, 26, 23, 59), now: now), InboxSection.earlier);
      expect(inboxSectionFor(DateTime(2026, 9, 20), now: now), InboxSection.earlier);
      expect(inboxSectionFor(null, now: now), InboxSection.earlier, reason: 'missing createdAt must not crash or default to today');
    });

    test('groupedInboxItems: one header per group, right before its own first item, never repeated', () {
      final notices = [
        RiderNotice(id: 't1', type: 'payout_sent', title: 'T1', body: 'B1', unread: true, createdAt: DateTime(2026, 9, 27, 9)),
        RiderNotice(id: 't2', type: 'rider_offline', title: 'T2', body: 'B2', unread: true, createdAt: DateTime(2026, 9, 27, 8)),
        RiderNotice(id: 'e1', type: 'statement_ready', title: 'E1', body: 'B3', unread: false, createdAt: DateTime(2026, 9, 20)),
      ];
      final items = groupedInboxItems(notices, now: now);
      expect(items, [InboxSection.today, notices[0], notices[1], InboxSection.earlier, notices[2]]);
    });

    test('groupedInboxItems: an all-earlier list gets exactly one header, not one per notice', () {
      final notices = [
        RiderNotice(id: 'e1', type: 'statement_ready', title: 'E1', body: 'B', unread: false, createdAt: DateTime(2026, 9, 1)),
        RiderNotice(id: 'e2', type: 'payout_sent', title: 'E2', body: 'B', unread: false, createdAt: DateTime(2026, 9, 2)),
      ];
      final items = groupedInboxItems(notices, now: now);
      expect(items, [InboxSection.earlier, notices[0], notices[1]]);
    });

    testWidgets('the real screen renders both section headers when both groups are present', (t) async {
      final src = FakeInbox()
        ..current = [
          RiderNotice(id: 'today1', type: 'rider_offline', title: 'Today one', body: 'B', unread: true, createdAt: DateTime.now()),
          RiderNotice(id: 'old1', type: 'statement_ready', title: 'Old one', body: 'B', unread: false, createdAt: DateTime(2020, 1, 1)),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
    });
  });

  group('DLVI5: inbox All/Unread filter tabs', () {
    test('filteredInboxNotices: all is the list unchanged, unread keeps only unread', () {
      final notices = [
        RiderNotice(id: 'r1', type: 'payout_sent', title: 'R1', body: 'B', unread: true, createdAt: DateTime(2026, 9, 27)),
        RiderNotice(id: 'r2', type: 'statement_ready', title: 'R2', body: 'B', unread: false, createdAt: DateTime(2026, 9, 26)),
        RiderNotice(id: 'r3', type: 'rider_offline', title: 'R3', body: 'B', unread: true, createdAt: DateTime(2026, 9, 25)),
      ];
      expect(filteredInboxNotices(notices, InboxFilter.all), same(notices));
      expect(filteredInboxNotices(notices, InboxFilter.unread), [notices[0], notices[2]]);
    });

    testWidgets('defaults to All: both read and unread notices are visible', (t) async {
      final src = FakeInbox()
        ..current = [n('u1', 'payout_sent'), n('r1', 'statement_ready', unread: false)];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      expect(find.text('T u1'), findsOneWidget);
      expect(find.text('T r1'), findsOneWidget);
    });

    testWidgets('selecting Unread hides read notices; selecting All restores them', (t) async {
      final src = FakeInbox()
        ..current = [n('u1', 'payout_sent'), n('r1', 'statement_ready', unread: false)];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inbox-filter-unread')));
      await t.pumpAndSettle();
      expect(find.text('T u1'), findsOneWidget);
      expect(find.text('T r1'), findsNothing);

      await t.tap(find.byKey(const ValueKey('inbox-filter-all')));
      await t.pumpAndSettle();
      expect(find.text('T u1'), findsOneWidget);
      expect(find.text('T r1'), findsOneWidget);
    });

    testWidgets('Unread with nothing unread shows a distinct empty state, not the generic one', (t) async {
      final src = FakeInbox()..current = [n('r1', 'statement_ready', unread: false)];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inbox-filter-unread')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('No unread notifications.'), findsOneWidget);
      expect(find.text('Nothing here yet. Orders, statements and payments you should know about show here.'), findsNothing);
    });

    testWidgets('filtering happens before grouping: a read Today notice never shows under either header', (t) async {
      final now = DateTime.now();
      final src = FakeInbox()
        ..current = [
          RiderNotice(id: 'ut', type: 'rider_offline', title: 'Unread today', body: 'B', unread: true, createdAt: now),
          RiderNotice(id: 'rt', type: 'statement_ready', title: 'Read today', body: 'B', unread: false, createdAt: now),
          RiderNotice(id: 'ue', type: 'payout_sent', title: 'Unread earlier', body: 'B', unread: true, createdAt: DateTime(2020, 1, 1)),
        ];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inbox-filter-unread')));
      await t.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('Unread today'), findsOneWidget);
      expect(find.text('Unread earlier'), findsOneWidget);
      expect(find.text('Read today'), findsNothing);
    });
  });

  group('DLVI6: unread notice row shows a dot, accessibly labeled', () {
    testWidgets('an unread notice carries an accessibly-labeled dot; a read one does not', (t) async {
      final handle = t.ensureSemantics();
      final src = FakeInbox()
        ..current = [n('u1', 'payout_sent'), n('r1', 'statement_ready', unread: false)];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Unread'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the dot reflects live notice data as it arrives, not a one-time snapshot', (t) async {
      final handle = t.ensureSemantics();
      final src = FakeInbox()..current = [n('u1', 'payout_sent')];
      await t.pumpWidget(host(InboxScreen(riderId: 'r1', source: src)));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Unread'), findsOneWidget);

      src.notices.add([n('u1', 'payout_sent', unread: false)]);
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Unread'), findsNothing);
      handle.dispose();
    });
  });
}
