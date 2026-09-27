// ADMR-27 — the first real Order 360 slice on top of ADMR-24/25/26's
// canonical command: actor-attributed timeline, cancellation/refund
// visibility, and a responsive compact/wide split.
//
// admin_order_details_screen.dart's own StatefulWidget cannot be
// constructed here at all outside a real Firebase app (it drives
// OrderProvider, whose FirebaseFirestore.instance field initializer
// crashes outside one — the same limitation order_status_transition_guard_
// test.dart's own header already documents for OrderProvider directly).
// The three pieces of DECISION LOGIC this phase actually adds are pure,
// top-level functions specifically so they can be tested directly without
// that dependency — this file proves those, not the widget tree.
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/orders/admin_order_details_screen.dart';

AddressModel _address() => AddressModel(
      id: 'addr1',
      userId: 'user1',
      name: 'Test Customer',
      phone: '9999999999',
      addressLine1: '1 Test Street',
      addressLine2: '',
      city: 'Chennai',
      state: 'Tamil Nadu',
      zipcode: '600001',
    );

OrderModel _order({String? cancelledBy}) => OrderModel(
      id: 'order1',
      userId: 'user1',
      orderNumber: 'ORD1',
      items: const [],
      deliveryAddress: _address(),
      subtotal: 100,
      total: 100,
      paymentMethod: 'razorpay',
      cancelledBy: cancelledBy,
    );

void main() {
  group('isOrder360Wide', () {
    test('below the breakpoint is compact', () {
      expect(isOrder360Wide(320), isFalse);
      expect(isOrder360Wide(768), isFalse);
      expect(isOrder360Wide(kOrder360WideBreakpoint - 1), isFalse);
    });

    test('at or above the breakpoint is wide', () {
      expect(isOrder360Wide(kOrder360WideBreakpoint), isTrue);
      expect(isOrder360Wide(1200), isTrue);
      expect(isOrder360Wide(1920), isTrue);
    });
  });

  group('orderNeedsCancellationCard', () {
    test('an ordinary, never-cancelled order does not show the card', () {
      expect(orderNeedsCancellationCard(_order()), isFalse);
    });

    test('an order with real ADMR-25 cancellation data shows the card', () {
      expect(orderNeedsCancellationCard(_order(cancelledBy: 'admin')), isTrue);
    });
  });

  group('friendlyActorLabel', () {
    test('maps every known role to a human-readable label', () {
      expect(friendlyActorLabel('admin'), 'Admin');
      expect(friendlyActorLabel('seller'), 'Seller');
      expect(friendlyActorLabel('rider'), 'Delivery Partner');
      expect(friendlyActorLabel('delivery_partner'), 'Delivery Partner');
      expect(friendlyActorLabel('system'), 'System');
    });

    test('is case-insensitive, matching how updatedBy is actually written', () {
      expect(friendlyActorLabel('ADMIN'), 'Admin');
      expect(friendlyActorLabel('Seller'), 'Seller');
    });

    test('an unrecognized role falls back to the raw string rather than '
        'hiding it or crashing', () {
      expect(friendlyActorLabel('some_future_role'), 'some_future_role');
    });
  });

  group('OrderModel cancellation/refund fields (ADMR-25/27)', () {
    test('round-trip through toMap/fromMap preserves all four fields', () {
      final cancelledAt = DateTime(2026, 9, 27, 10, 30);
      final original = _order(cancelledBy: 'admin').copyWith(
        cancelledAt: cancelledAt,
        cancellationReason: 'Customer requested return',
        refundStatus: 'pending',
      );

      final map = original.toMap();
      final restored = OrderModel.fromMap(map, original.id);

      expect(restored.cancelledBy, 'admin');
      expect(restored.cancellationReason, 'Customer requested return');
      expect(restored.refundStatus, 'pending');
      expect(restored.cancelledAt, isNotNull);
      expect(restored.cancelledAt!.difference(cancelledAt).inSeconds.abs(), lessThan(2));
    });

    test('an order that was never cancelled leaves all four fields null', () {
      final map = _order().toMap();
      final restored = OrderModel.fromMap(map, 'order1');
      expect(restored.cancelledBy, isNull);
      expect(restored.cancelledAt, isNull);
      expect(restored.cancellationReason, isNull);
      expect(restored.refundStatus, isNull);
    });
  });
}
