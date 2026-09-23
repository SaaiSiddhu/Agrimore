import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/screens/notifications/inbox_rules.dart';
import 'package:seller/screens/notifications/notifications_screen.dart';
import 'package:seller/screens/search/search_rules.dart';

/// SELLER-HOME-1b: inbox entries are categorised and linked from what the
/// server writes; the screen groups by Indian day and filters; search finds
/// orders, products and quotes and recognises an exact order number.
final DateTime _now = DateTime.utc(2026, 9, 23, 6);

InboxEntry _n(String id, String type, {bool unread = true, int hoursAgo = 1, String? url}) => InboxEntry(
      id: id,
      title: 'Title $id',
      body: 'Body $id',
      type: type,
      unread: unread,
      createdAt: _now.subtract(Duration(hours: hoursAgo)),
      link: InboxLink.parse(url),
    );

void main() {
  group('inbox rules', () {
    test('categories follow the server types', () {
      expect(inboxCategoryOf('seller_new_order'), InboxCategory.orders);
      expect(inboxCategoryOf('order_update'), InboxCategory.orders);
      expect(inboxCategoryOf('rfq_offer'), InboxCategory.quotes);
      expect(inboxCategoryOf('payout_paid'), InboxCategory.payments);
      expect(inboxCategoryOf('admin_broadcast'), InboxCategory.account);
    });

    test('links parse to a target and id', () {
      expect(InboxLink.parse('order/o1').target, InboxTarget.order);
      expect(InboxLink.parse('rfq/r1').id, 'r1');
      expect(InboxLink.parse('payout/p1').target, InboxTarget.payments);
      expect(InboxLink.parse('https://evil').target, InboxTarget.none);
      expect(InboxLink.parse(null).target, InboxTarget.none);
    });

    test('both unread conventions are honoured', () {
      final at = Timestamp.fromDate(_now);
      expect(InboxEntry.fromMap('a', {'unread': true, 'createdAt': at}).unread, isTrue);
      expect(InboxEntry.fromMap('b', {'unread': false}).unread, isFalse);
      expect(InboxEntry.fromMap('c', {'read': true}).unread, isFalse);
      expect(InboxEntry.fromMap('d', {'isRead': true}).unread, isFalse);
      expect(InboxEntry.fromMap('e', const {}).unread, isTrue);
      expect(InboxEntry.fromMap('f', {'data': {'actionUrl': 'rfq/r9'}}).link.id, 'r9');
    });

    test('mark-read update only touches the fields the rules allow', () {
      expect(markReadUpdate().keys.toSet(), {'unread', 'read', 'readAt'});
    });
  });

  group('search', () {
    OrderModel order(String id, String number, String customer) => OrderModel.fromMap({
          'userId': 'u',
          'orderNumber': number,
          'items': const [],
          'deliveryAddress': {'name': customer},
          'total': 100,
          'orderStatus': 'pending',
        }, id);
    final orders = [order('o1', 'AGM-1001', 'Priya'), order('o2', 'AGM-1002', 'Ravi')];
    final quotes = [
      RfqModel(
        id: 'r1',
        buyerId: 'b',
        sellerId: 's',
        productId: 'p',
        status: RfqStatus.pending,
        createdAt: _now,
        updatedAt: _now,
        productName: 'Basmati Rice',
        buyerBusinessName: 'Priya Traders',
      ),
    ];

    test('under two characters finds nothing', () {
      expect(searchSeller('a', orders: orders, products: const [], quotes: quotes).isEmpty, isTrue);
    });

    test('exact order number (with or without #) is recognised', () {
      final r = searchSeller('#agm-1002', orders: orders, products: const [], quotes: quotes);
      expect(r.exactOrder?.id, 'o2');
      expect(r.orders.length, 1);
    });

    test('a name matches orders and quotes', () {
      final r = searchSeller('priya', orders: orders, products: const [], quotes: quotes);
      expect(r.orders.map((o) => o.id), ['o1']);
      expect(r.quotes.map((q) => q.id), ['r1']);
      expect(r.exactOrder, isNull);
    });
  });

  Future<AppLocalizations> pump(WidgetTester tester, Widget child) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
        ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider.preview(const [])),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return child;
        }),
      ),
    ));
    await tester.pump();
    return l10n;
  }

  testWidgets('inbox groups today/earlier, filters by category, shows unread', (tester) async {
    final l10n = await pump(
      tester,
      NotificationsScreen(now: _now, entries: [
        _n('1', 'seller_new_order', url: 'order/o1'),
        _n('2', 'rfq_offer', url: 'rfq/r1'),
        _n('3', 'payout_paid', unread: false, hoursAgo: 48),
      ]),
    );
    expect(find.text(l10n.notificationsToday), findsOneWidget);
    expect(find.text(l10n.notificationsEarlier), findsOneWidget);
    expect(find.text(l10n.notificationsMarkAllRead), findsOneWidget);
    // The dot's label merges into its tile's node for screen readers.
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == l10n.notificationsUnreadLabel),
        findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, l10n.notificationsQuotes));
    await tester.pump();
    expect(find.text('Title 2'), findsOneWidget);
    expect(find.text('Title 1'), findsNothing);
    expect(find.text(l10n.notificationsEarlier), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty inbox explains itself; bell shows the unread count', (tester) async {
    final l10n = await pump(tester, NotificationsScreen(now: _now, entries: const []));
    expect(find.text(l10n.notificationsEmpty), findsOneWidget);
    expect(find.text(l10n.notificationsMarkAllRead), findsNothing);
    await pump(tester, const Scaffold(body: NotificationBell(unreadOverride: 3)));
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip(l10n.notificationsUnread(3)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
