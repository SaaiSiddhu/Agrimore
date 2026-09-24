import 'dart:io';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/rfq_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/screens/rfq/quote_rules.dart';
import 'package:seller/screens/rfq/seller_rfq_detail_screen.dart';
import 'package:seller/screens/rfq/seller_rfq_inbox_screen.dart';
import 'package:seller/screens/rfq/widgets/quote_counter_sheet.dart';
import 'package:seller/screens/rfq/widgets/quote_decline_sheet.dart';

/// SELLER-RFQ-2: quotes are bucketed the way the seller acts on them, the
/// thread offers exactly the actions the server allows, and the counter
/// sheet shows the live total against the listed B2B price.
final DateTime _now = DateTime(2026, 9, 23, 12);

RfqModel _q(
  String id, {
  RfqStatus status = RfqStatus.negotiating,
  RfqRole? awaiting = RfqRole.seller,
  double? price = 1700,
  int qty = 20,
  RfqRole by = RfqRole.buyer,
  int expiresInDays = 5,
  String? orderId,
}) =>
    RfqModel(
      id: id,
      buyerId: 'b',
      sellerId: 's',
      productId: 'p',
      status: status,
      awaitingResponseFrom: awaiting,
      lastOffer: price == null
          ? null
          : RfqOffer(price: price, quantity: qty, by: by, expiresAt: _now.add(Duration(days: expiresInDays))),
      finalPrice: status == RfqStatus.accepted ? price : null,
      finalQuantity: status == RfqStatus.accepted ? qty : null,
      createdAt: _now.subtract(const Duration(days: 2)),
      updatedAt: _now,
      history: [
        RfqHistoryEntry(actor: RfqRole.buyer, action: 'create', price: price, quantity: qty, at: _now),
      ],
      productName: 'Basmati Rice 25kg',
      listedB2bPrice: 1800,
      listedB2bMoq: 10,
      buyerBusinessName: 'Priya Traders',
      consumedByOrderId: orderId,
    );

Future<AppLocalizations> _pump(WidgetTester tester, Widget child, RfqProvider rfqs,
    {Brightness b = Brightness.light}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<RfqProvider>.value(value: rfqs),
      ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider()),
    ],
    child: MaterialApp(
      theme: (b == Brightness.dark ? SellerTheme.dark : SellerTheme.light),
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

void main() {
  group('quote rules', () {
    test('buckets follow whose turn it is and what happened', () {
      expect(quoteBucketOf(_q('1'), _now), QuoteBucket.needsResponse);
      expect(quoteBucketOf(_q('2', awaiting: RfqRole.buyer, by: RfqRole.seller), _now), QuoteBucket.negotiating);
      expect(quoteBucketOf(_q('3', status: RfqStatus.accepted, awaiting: null), _now), QuoteBucket.accepted);
      expect(quoteBucketOf(_q('4', status: RfqStatus.rejected, awaiting: null), _now), QuoteBucket.closed);
      // The seller's own lapsed offer, waiting on the buyer → closed.
      expect(quoteBucketOf(_q('5', awaiting: RfqRole.buyer, by: RfqRole.seller, expiresInDays: -1), _now),
          QuoteBucket.closed);
      // A lapsed buyer offer still needs the seller (they can counter).
      expect(quoteBucketOf(_q('6', expiresInDays: -1), _now), QuoteBucket.needsResponse);
      // A new request with no price yet.
      expect(quoteBucketOf(_q('7', status: RfqStatus.pending, price: null), _now), QuoteBucket.needsResponse);
    });

    test('price vs listed, days left', () {
      expect(priceVsListed(1700, 1800), closeTo(-0.0556, 0.001));
      expect(priceVsListed(1700, null), isNull);
      expect(priceVsListed(1700, 0), isNull);
      expect(daysLeft(_now.add(const Duration(hours: 30)), _now), 2);
      expect(daysLeft(_now.subtract(const Duration(minutes: 1)), _now), 0);
    });

    test('validity choices sit inside the server bounds (rfq.ts)', () {
      final src = File('../../functions/src/customer/rfq.ts').readAsStringSync();
      final max = int.parse(RegExp(r'MAX_VALID_DAYS = (\d+)').firstMatch(src)!.group(1)!);
      final def = int.parse(RegExp(r'DEFAULT_VALID_DAYS = (\d+)').firstMatch(src)!.group(1)!);
      expect(kQuoteValidityDays.every((d) => d >= 1 && d <= max), isTrue);
      expect(kDefaultQuoteValidityDays, def);
      expect(kQuoteValidityDays.contains(kDefaultQuoteValidityDays), isTrue);
    });

    test('callable failures map to specific copy', () {
      expect(RfqProvider.errorFor('failed-precondition', 'This offer has expired — send a new offer instead'),
          QuoteActionError.expired);
      expect(RfqProvider.errorFor('failed-precondition', 'Waiting for the other party to respond'),
          QuoteActionError.notYourTurn);
      expect(RfqProvider.errorFor('failed-precondition', 'This RFQ is no longer open'), QuoteActionError.closed);
      expect(RfqProvider.errorFor('internal', null), QuoteActionError.generic);
    });

    test('RfqModel reads the RFQ-2 snapshots and expiry', () {
      final m = RfqModel.fromMap({
        'buyerId': 'b',
        'sellerId': 's',
        'status': 'negotiating',
        'lastOffer': {'price': 10, 'quantity': 2, 'by': 'buyer', 'expiresAt': _now},
        'product': {'name': 'Rice', 'b2bPrice': 9, 'b2bMoq': 5},
        'buyer': {'name': 'Priya', 'businessName': ''},
        'consumedByOrderId': 'o1',
      }, 'r1');
      expect(m.productName, 'Rice');
      expect(m.listedB2bPrice, 9);
      expect(m.listedB2bMoq, 5);
      expect(m.buyerName, 'Priya');
      expect(m.buyerBusinessName, isNull);
      expect(m.lastOffer!.expiresAt, _now);
      expect(m.lastOffer!.total, 20);
      expect(m.consumedByOrderId, 'o1');
    });
  });

  testWidgets('inbox counts each tab and lists needs-response quotes first', (tester) async {
    final provider = RfqProvider.preview([
      _q('1'),
      _q('2', awaiting: RfqRole.buyer, by: RfqRole.seller),
      _q('3', status: RfqStatus.accepted, awaiting: null),
    ]);
    final l10n = await _pump(tester, SellerRfqInboxScreen(now: _now), provider);
    expect(tester.widget<SellerChip>(find.widgetWithText(SellerChip, l10n.quotesTabNeedsResponse)).count, 1);
    expect(tester.widget<SellerChip>(find.widgetWithText(SellerChip, l10n.quotesTabNegotiating)).count, 1);
    expect(tester.widget<SellerChip>(find.widgetWithText(SellerChip, l10n.quotesTabClosed)).count, 0);
    expect(find.text('Basmati Rice 25kg'), findsOneWidget);
    expect(find.text(l10n.quoteYourTurn), findsOneWidget);
    expect(find.text(l10n.quoteExpiresIn(5)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty needs-response tab explains itself (dark)', (tester) async {
    final l10n = await _pump(tester, SellerRfqInboxScreen(now: _now), RfqProvider.preview([]), b: Brightness.dark);
    expect(find.text(l10n.quotesEmptyNeedsResponse), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('my turn: counter, accept and decline are offered with the price comparison', (tester) async {
    final l10n = await _pump(tester, SellerRfqDetailScreen(rfqId: '1', now: _now), RfqProvider.preview([_q('1')]));
    expect(find.text(l10n.quoteCounter), findsOneWidget);
    expect(find.text(l10n.quoteDecline), findsOneWidget);
    final accept = tester.widget<FilledButton>(find.widgetWithText(FilledButton, l10n.quoteAccept));
    expect(accept.onPressed, isNotNull);
    expect(find.text(l10n.quoteVsListedBelow('6%')), findsOneWidget);
    expect(find.text(SellerFormat.money(34000)), findsOneWidget);
    expect(find.text(l10n.quoteListedB2b(SellerFormat.money(1800))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expired offer cannot be accepted and says why', (tester) async {
    final l10n = await _pump(
        tester, SellerRfqDetailScreen(rfqId: '1', now: _now), RfqProvider.preview([_q('1', expiresInDays: -1)]));
    final accept = tester.widget<FilledButton>(find.widgetWithText(FilledButton, l10n.quoteAccept));
    expect(accept.onPressed, isNull);
    expect(find.text(l10n.quoteAcceptExpiredHint), findsOneWidget);
    expect(find.text(l10n.quoteExpired), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waiting on the buyer: no actions', (tester) async {
    final l10n = await _pump(tester, SellerRfqDetailScreen(rfqId: '2', now: _now),
        RfqProvider.preview([_q('2', awaiting: RfqRole.buyer, by: RfqRole.seller)]));
    expect(find.text(l10n.quoteCounter), findsNothing);
    expect(find.text(l10n.quoteWaitingBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted and ordered quote links to the order', (tester) async {
    final l10n = await _pump(tester, SellerRfqDetailScreen(rfqId: '3', now: _now),
        RfqProvider.preview([_q('3', status: RfqStatus.accepted, awaiting: null, orderId: 'o1')]));
    expect(find.text(l10n.quoteOrderedBanner), findsOneWidget);
    expect(find.text(l10n.quoteViewOrder), findsOneWidget);
    expect(find.text(l10n.quoteStatusOrdered), findsOneWidget);
    expect(find.text(l10n.quoteAccept), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counter sheet: live total, comparison, MOQ hint and validation', (tester) async {
    CounterOffer? result;
    final l10n = await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showQuoteCounterSheet(context, _q('1')),
            child: const Text('open'),
          ),
        ),
      ),
      RfqProvider.preview([]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(SellerFormat.money(34000)), findsOneWidget); // pre-filled 1700 × 20
    await tester.enterText(find.byKey(const ValueKey('counterPrice')), '1800');
    await tester.enterText(find.byKey(const ValueKey('counterQty')), '5');
    await tester.pump();
    expect(find.text(SellerFormat.money(9000)), findsOneWidget);
    expect(find.text(l10n.quoteVsListedSame), findsOneWidget);
    expect(find.text(l10n.counterBelowMoq(SellerFormat.count(10))), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('counterQty')), '');
    await tester.tap(find.text(l10n.counterSend));
    await tester.pump();
    expect(find.text(l10n.counterQtyInvalid), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('counterQty')), '25');
    await tester.tap(find.text(l10n.counterValidityDays(15)));
    await tester.pump();
    await tester.ensureVisible(find.text(l10n.counterSend));
    await tester.tap(find.text(l10n.counterSend));
    await tester.pumpAndSettle();
    expect(result?.price, 1800);
    expect(result?.quantity, 25);
    expect(result?.validForDays, 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decline sheet needs a reason and returns reason + note', (tester) async {
    String? result;
    final l10n = await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showQuoteDeclineSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
      RfqProvider.preview([]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final cta = find.widgetWithText(FilledButton, l10n.declineCta);
    expect(tester.widget<FilledButton>(cta).onPressed, isNull);
    await tester.tap(find.text(l10n.declineReasonPriceTooLow));
    await tester.enterText(find.byType(TextField), 'Can do 1750');
    await tester.pump();
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(result, '${l10n.declineReasonPriceTooLow} — Can do 1750');
    expect(tester.takeException(), isNull);
  });
}
