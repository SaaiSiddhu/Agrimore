import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/rfq/seller_rfq_detail_screen.dart';
import 'package:seller/screens/rfq/seller_rfq_inbox_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

final DateTime _now = DateTime(2026, 9, 24, 10);

RfqModel _q(String id, {RfqStatus status = RfqStatus.negotiating, RfqRole? awaiting = RfqRole.seller, int days = 3, String product = 'Fresh tomatoes'}) => RfqModel(
      id: id,
      buyerId: 'b',
      sellerId: 's',
      productId: 'p',
      status: status,
      awaitingResponseFrom: awaiting,
      lastOffer: RfqOffer(price: 52, quantity: 20, by: RfqRole.buyer, expiresAt: _now.add(Duration(days: days)), notes: 'For our weekly kitchen supply.'),
      createdAt: _now.subtract(const Duration(days: 1)),
      updatedAt: _now,
      history: [
        RfqHistoryEntry(actor: RfqRole.buyer, action: 'create', at: _now.subtract(const Duration(days: 1))),
        RfqHistoryEntry(actor: RfqRole.buyer, action: 'offer', price: 52, quantity: 20, at: _now.subtract(const Duration(hours: 20)), notes: 'For our weekly kitchen supply.'),
      ],
      productName: product,
      listedB2bPrice: 56,
      listedB2bMoq: 10,
      buyerBusinessName: 'Green Valley Foods',
    );

void main() {
  setUpAll(loadSellerFonts);
  final quotes = [_q('q1'), _q('q2', product: 'Green chillies', days: 1), _q('q3', awaiting: RfqRole.buyer)];
  testWidgets('quotes_inbox', (tester) async {
    await pumpSellerApp(tester, SellerRfqInboxScreen(now: _now), quotes: quotes);
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'quotes_inbox');
  });
  for (final (name, b) in [('quote_detail_light', Brightness.light), ('quote_detail_dark', Brightness.dark)]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, SellerRfqDetailScreen(rfqId: 'q1', now: _now), quotes: quotes, brightness: b, size: const Size(390, 1500));
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
}
