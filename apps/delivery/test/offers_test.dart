// Phase DLV-2B — the rider app's offer rules and the incoming-offer screen.
import 'package:delivery/offers/delivery_offer.dart';
import 'package:delivery/offers/offer_launch.dart';
import 'package:delivery/providers/offer_provider.dart';
import 'package:delivery/screens/offers/incoming_offer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// OfferProvider with no Firebase: a fixed offer list and scripted results.
class FakeOfferProvider extends OfferProvider {
  FakeOfferProvider(this._list, {this.acceptResult, this.declineResult});
  List<DeliveryOffer> _list;
  final OfferActionResult? acceptResult;
  final OfferActionResult? declineResult;
  final List<String> calls = [];

  @override
  List<DeliveryOffer> get offers => _list;
  @override
  DeliveryOffer? get current => _list.isEmpty ? null : _list.first;
  @override
  DeliveryOffer? byOrderId(String orderId) {
    for (final o in _list) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  void withdraw(String orderId) {
    _list = _list.where((o) => o.orderId != orderId).toList();
    notifyListeners();
  }

  @override
  Future<OfferActionResult> accept(String orderId) async {
    calls.add('accept:$orderId');
    return acceptResult ?? const OfferActionResult.success();
  }

  @override
  Future<OfferActionResult> decline(String orderId, {String? reason}) async {
    calls.add('decline:$orderId');
    withdraw(orderId);
    return declineResult ?? const OfferActionResult.success();
  }
}

DeliveryOffer offer({int secondsLeft = 25, double cod = 450}) => DeliveryOffer(
      orderId: 'o1',
      orderNumber: 'ORD-1',
      expiresAt: DateTime.now().add(Duration(seconds: secondsLeft)),
      pickupDistanceKm: 1.24,
      pickupArea: 'Madurai · 625001',
      dropPincode: '625002',
      dropDistanceKm: 3.4,
      itemCount: 3,
      codAmount: cod,
    );

void main() {
  group('DeliveryOffer', () {
    test('parses the dispatch.ts offer document', () {
      final o = DeliveryOffer.fromMap({
        'orderId': 'o9',
        'orderNumber': 'ORD-9',
        'expiresAt': DateTime(2026, 9, 23, 12, 0, 30),
        'pickupDistanceKm': 1.5,
        'pickupArea': 'Madurai · 625001',
        'dropPincode': '625002',
        'dropDistanceKm': 2,
        'itemCount': 2,
        'codAmount': 0,
        'wave': 4,
      })!;
      expect(o.orderNumber, 'ORD-9');
      expect(o.dropDistanceKm, 2.0);
      expect(o.isCod, isFalse);
      expect(o.wave, 4);
    });

    test('expiry as FCM sends it (milliseconds string) parses too', () {
      final o = DeliveryOffer.fromMap(
          {'orderId': 'o1', 'expiresAt': '${DateTime(2026, 1, 1).millisecondsSinceEpoch}'});
      expect(o!.expiresAt, DateTime(2026, 1, 1));
    });

    test('an offer without an order id or expiry is ignored', () {
      expect(DeliveryOffer.fromMap({'expiresAt': DateTime.now()}), isNull);
      expect(DeliveryOffer.fromMap({'orderId': 'o1'}), isNull);
    });

    test('countdown, liveness and ring fraction', () {
      final start = DateTime(2026, 9, 23, 12);
      final o = DeliveryOffer(
          orderId: 'o', orderNumber: 'n', expiresAt: start.add(const Duration(seconds: 30)));
      expect(o.fractionLeft(start), 1.0);
      expect(o.remaining(start.add(const Duration(seconds: 12))).inSeconds, 18);
      expect(o.fractionLeft(start.add(const Duration(seconds: 15))), closeTo(0.5, 1e-9));
      expect(o.isLive(start.add(const Duration(seconds: 29))), isTrue);
      expect(o.isLive(start.add(const Duration(seconds: 30))), isFalse);
      expect(o.remaining(start.add(const Duration(minutes: 5))), Duration.zero);
      expect(o.fractionLeft(start.add(const Duration(minutes: 5))), 0.0);
    });

    test('summary mirrors the server push body', () {
      expect(offer().summary, 'Pickup 1.2 km away · 3 items · Collect ₹450');
      expect(offer(cod: 0).summary, 'Pickup 1.2 km away · 3 items');
    });
  });

  group('refusal wording (never raw server text)', () {
    test('each dispatch reason has its own sentence', () {
      for (final r in ['taken', 'expired', 'busy', 'not_eligible', 'no_offer']) {
        final m = offerRefusalMessage(code: 'failed-precondition', reason: r);
        // A sentence for a person, not a code or the server's own message.
        expect(m, isNot(contains('_')));
        expect(m, isNot(contains('failed-precondition')));
        expect(m, isNot(offerRefusalMessage(code: 'internal')));
        expect(m.endsWith('.'), isTrue);
      }
      expect(offerRefusalMessage(code: 'failed-precondition', reason: 'taken'),
          'Another delivery partner took this order.');
    });
    test('anything else is generic', () {
      expect(offerRefusalMessage(code: 'internal'),
          'Could not update this offer. Please try again.');
      expect(offerRefusalMessage(code: 'unavailable'),
          startsWith('No connection'));
    });
  });

  group('notification identity', () {
    test('payload round-trips and ignores other payloads', () {
      expect(orderIdFromPayload(offerPayload('abc')), 'abc');
      expect(orderIdFromPayload('{"actionUrl":"order/abc"}'), isNull);
      expect(orderIdFromPayload('delivery_offer:'), isNull);
      expect(orderIdFromPayload(null), isNull);
    });
    test('the tag matches what dispatch.ts sets', () {
      expect(offerNotificationTag('o1'), 'delivery_offer_o1');
    });
    test('ids are stable, positive, non-zero and distinct', () {
      expect(offerNotificationId('order-123'), offerNotificationId('order-123'));
      // FNV-1a 32 of "order-123" masked to 31 bits (computed independently) —
      // pinned so a change that would break cancel-from-another-isolate
      // (the background handler posts, the main isolate cancels) is caught.
      expect(offerNotificationId('order-123'), 621334298);
      final ids = List.generate(500, (i) => offerNotificationId('order-$i')).toSet();
      expect(ids.length, 500);
      expect(ids.every((i) => i > 0), isTrue);
    });
  });

  group('IncomingOfferScreen', () {
    Future<FakeOfferProvider> pump(WidgetTester tester, FakeOfferProvider p) async {
      await tester.pumpWidget(ChangeNotifierProvider<OfferProvider>.value(
        value: p,
        child: MaterialApp(
          navigatorKey: deliveryNavigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const IncomingOfferScreen(orderId: 'o1'))),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return p;
    }

    testWidgets('shows what the offer carries and nothing about the customer',
        (tester) async {
      await pump(tester, FakeOfferProvider([offer()]));
      expect(find.text('New delivery request'), findsOneWidget);
      expect(find.text('Order #ORD-1'), findsOneWidget);
      expect(find.textContaining('1.2 km away'), findsOneWidget);
      expect(find.textContaining('Madurai · 625001'), findsOneWidget);
      expect(find.textContaining('PIN 625002'), findsOneWidget);
      expect(find.text('Collect ₹450 in cash'), findsOneWidget);
      expect(find.text('Accept order'), findsOneWidget);
      // Countdown shows whole seconds left.
      expect(find.text('seconds'), findsOneWidget);
      // No phone/call affordance before accepting.
      expect(find.byIcon(Icons.call), findsNothing);
      expect(find.byIcon(Icons.call_rounded), findsNothing);
      // Leave the screen so its ticker stops.
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
    });

    testWidgets('a refused accept closes the screen and says why',
        (tester) async {
      final p = await pump(
          tester,
          FakeOfferProvider([offer()],
              acceptResult: const OfferActionResult.failure(
                  'Another delivery partner took this order.')));
      await tester.tap(find.text('Accept order'));
      await tester.pumpAndSettle();
      expect(p.calls, ['accept:o1']);
      expect(find.text('New delivery request'), findsNothing);
      expect(find.text('Another delivery partner took this order.'), findsOneWidget);
    });

    testWidgets('decline goes through the provider and closes', (tester) async {
      final p = await pump(tester, FakeOfferProvider([offer()]));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(p.calls, ['decline:o1']);
      expect(find.text('New delivery request'), findsNothing);
    });

    testWidgets('an offer withdrawn by the server closes the screen with a reason',
        (tester) async {
      final p = await pump(tester, FakeOfferProvider([offer()]));
      p.withdraw('o1');
      await tester.pumpAndSettle();
      expect(find.text('New delivery request'), findsNothing);
      expect(find.text('This order is no longer available.'), findsOneWidget);
    });
  });


  // DLV-D1: the accept's new refusals are worded, not the generic fallback.
  test('offline and cash-limit refusals are worded', () {
    expect(offerRefusalMessage(code: 'failed-precondition', reason: 'offline'), 'Go online to accept orders.');
    expect(offerRefusalMessage(code: 'failed-precondition', reason: 'cash_limit'), contains('Deposit the cash'));
  });
}
