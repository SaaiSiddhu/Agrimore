// Phase DLVMAP3 (5.12) — assignment changes & recovery. ActiveOrderScreen
// used to take a static OrderModel snapshot and never re-check it; these
// tests drive the live DeliveryOrderProvider directly (via its injectable
// activeSource) to prove the reconciliation: a material change is reviewed,
// not silently swallowed; a genuine reassignment blocks the screen; a
// listener failure masks identity and disables actions; and — the
// safety-critical case — a rider's OWN successful completion is never
// misread as "reassigned away", even though both leave DeliveryOrderProvider
// the same way (the order drops out of riderActiveOrderStatuses).
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

OrderModel _order({
  String id = 'ord-42',
  String riderId = 'r-tour',
  String status = 'out_for_delivery',
  String name = 'Arun Kumar',
  int quantity = 2,
  double total = 468.0,
}) =>
    OrderModel.fromMap({
      'orderNumber': 'AGM-1042',
      'userId': 'cust-1',
      'sellerId': 'sel-1',
      'deliveryPartnerId': riderId,
      'orderStatus': status,
      'status': 'processing',
      'paymentMethod': 'cod',
      'paymentStatus': 'pending',
      'subtotal': 420.0,
      'deliveryFee': 48.0,
      'total': total,
      'deliveryEarning': 54.0,
      'deliveryAddress': {
        'name': name,
        'phone': '+91 98421 55120',
        'addressLine1': '44, West Masi Street',
        'city': 'Madurai',
        'state': 'Tamil Nadu',
        'pincode': '625001',
      },
      'items': [
        {
          'productId': 'p1',
          'productName': 'Organic Tomatoes',
          'price': 210.0,
          'quantity': quantity,
          'unit': 'kg',
        },
      ],
    }, id);

/// A controllable live source: tests push snapshots (or errors) directly,
/// and `retry()` re-subscribes correctly since the controller is broadcast.
class FakeActiveWork {
  final controller = StreamController<ActiveSnapshot>.broadcast();
  ActiveWorkSource get source => (_) => controller.stream;

  void emit(List<OrderModel> orders, {bool fromCache = false}) {
    controller.add((
      docs: orders.map((o) => (id: o.id, data: o.toMap())).toList(),
      fromCache: fromCache,
    ));
  }

  void emitError() => controller.addError(Exception('offline'));
}

Widget wrap(Widget home, DeliveryOrderProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
        ChangeNotifierProvider<DeliveryOrderProvider>.value(value: provider),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  group('hasMaterialOrderChange (DLVMAP3)', () {
    test('identical orders: no change', () {
      expect(hasMaterialOrderChange(_order(), _order()), isFalse);
    });

    test('only orderStatus differs: not material (handled via _currentStep)', () {
      expect(
        hasMaterialOrderChange(_order(status: 'delivery_accepted'), _order(status: 'picked_up')),
        isFalse,
      );
    });

    test('customer name differs: material', () {
      expect(hasMaterialOrderChange(_order(), _order(name: 'Someone Else')), isTrue);
    });

    test('item quantity differs: material', () {
      expect(hasMaterialOrderChange(_order(quantity: 2), _order(quantity: 5)), isTrue);
    });

    test('total differs: material', () {
      expect(hasMaterialOrderChange(_order(total: 468), _order(total: 900)), isTrue);
    });
  });

  group('maskCustomerInitials (DLVMAP3)', () {
    test('two-word name: first name initial + last name initial', () {
      expect(maskCustomerInitials('Arun Kumar'), 'A K.');
    });

    test('single-word name: its own initial only', () {
      expect(maskCustomerInitials('Arun'), 'A.');
    });

    test('extra whitespace is ignored', () {
      expect(maskCustomerInitials('  Meenakshi   Sundaram  '), 'M S.');
    });
  });

  group('ActiveOrderScreen live recovery (DLVMAP3)', () {
    testWidgets('present and unchanged: normal screen, no banner', (tester) async {
      final work = FakeActiveWork();
      final provider = DeliveryOrderProvider(
        activeSource: work.source,
        deliveredCount: (_, __) async => 0,
      )..bind('r-tour');
      final order = _order();
      work.emit([order]);
      await tester.pumpWidget(wrap(ActiveOrderScreen(order: order), provider));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l.offerOrderNumber('AGM-1042')), findsOneWidget);
      expect(find.text(l.assignmentChangedTitle), findsNothing);
      expect(find.text(l.assignmentRemovedTitle), findsNothing);
    });

    testWidgets('genuine reassignment: removed screen blocks all detail', (tester) async {
      final work = FakeActiveWork();
      final provider = DeliveryOrderProvider(
        activeSource: work.source,
        deliveredCount: (_, __) async => 0,
      )..bind('r-tour');
      final order = _order();
      work.emit([order]); // confirmed present first
      await tester.pumpWidget(wrap(ActiveOrderScreen(order: order), provider));
      await tester.pump(const Duration(milliseconds: 50));

      work.emit(const []); // then genuinely gone -- no grace period needed
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l.assignmentRemovedTitle), findsOneWidget);
      expect(find.text(l.assignmentBackToDashboard), findsOneWidget);
      expect(find.text(l.assignmentContactSupport), findsOneWidget);
      // Privacy: no customer/address/item detail rendered underneath.
      expect(find.textContaining('Arun Kumar'), findsNothing);
    });

    testWidgets('never-yet-confirmed absence is silent within the grace window', (tester) async {
      final work = FakeActiveWork();
      final provider = DeliveryOrderProvider(
        activeSource: work.source,
        deliveredCount: (_, __) async => 0,
      )..bind('r-tour');
      final order = _order();
      // The order is never emitted at all (simulating the live query not yet
      // having caught up with a freshly accepted offer).
      await tester.pumpWidget(wrap(ActiveOrderScreen(order: order), provider));
      work.emit(const []); // loaded, but this order isn't in it -- yet
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l.assignmentRemovedTitle), findsNothing,
          reason: 'must not flash removed before the grace period elapses');
      expect(find.text(l.offerOrderNumber('AGM-1042')), findsOneWidget);

      await tester.pump(kAssignmentConfirmGrace + const Duration(seconds: 1));
      expect(find.text(l.assignmentRemovedTitle), findsOneWidget,
          reason: 'a genuinely-never-found order must still resolve to removed eventually');
    });

    testWidgets('live listener failure: connectionLost masks identity, disables actions', (tester) async {
      final work = FakeActiveWork();
      final provider = DeliveryOrderProvider(
        activeSource: work.source,
        deliveredCount: (_, __) async => 0,
      )..bind('r-tour');
      final order = _order();
      work.emit([order]);
      await tester.pumpWidget(wrap(ActiveOrderScreen(order: order), provider));
      await tester.pump(const Duration(milliseconds: 50));

      work.emitError();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l.assignmentConnectionLostTitle), findsOneWidget);
      expect(find.text('A K.'), findsOneWidget); // masked, not "Arun Kumar"
      expect(find.text('Arun Kumar'), findsNothing);
      expect(find.text(l.actionRetry), findsOneWidget);
    });

    testWidgets('material change: banner shown, dismissed by Review changes', (tester) async {
      final work = FakeActiveWork();
      final provider = DeliveryOrderProvider(
        activeSource: work.source,
        deliveredCount: (_, __) async => 0,
      )..bind('r-tour');
      final order = _order();
      work.emit([order]);
      await tester.pumpWidget(wrap(ActiveOrderScreen(order: order), provider));
      await tester.pump(const Duration(milliseconds: 50));

      work.emit([_order(name: 'Someone Else')]);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l.assignmentChangedTitle), findsOneWidget);
      expect(find.text('Someone Else'), findsOneWidget); // display already updated

      await tester.tap(find.text(l.assignmentReviewChanges));
      await tester.pump();
      expect(find.text(l.assignmentChangedTitle), findsNothing);
    });

    // NOTE: the own-completion-vs-reassignment disambiguation (_leavingByOwnAction,
    // set at the top of _showDelivered() and before releaseOrder() in
    // _confirmSellerNotReady()) is NOT exercised end-to-end here: both real
    // paths that set it go through a real Cloud Functions callable
    // (confirmDelivery / releaseDeliveryOrder) with no injectable seam in
    // this codebase today, so driving them requires a Firebase-emulator-backed
    // test, a materially heavier tier than this file's plain widget tests.
    // Verified instead by direct code inspection: _showDelivered()'s very
    // first statement sets the flag, before the non-dismissible sheet is even
    // built, so by the time DeliveryOrderProvider's next snapshot can
    // possibly drop the (now-delivered) order out of activeOrders,
    // _onProviderChanged's own first line (`if (... _leavingByOwnAction)
    // return;`) has already made the recovery machine inert for this screen
    // instance. Recorded here rather than silently assumed.
  });
}
