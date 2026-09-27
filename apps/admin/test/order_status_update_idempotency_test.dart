// ADMR-38 — updateOrderStatus's own requestId reuse/mismatch logic.
//
// PROBLEM: OrderProvider.updateOrderStatus generated a brand new UUID as
// requestId on EVERY call, including a retry of the exact same admin
// action after an ambiguous failure (a dropped connection, a timeout) —
// the one case adminUpdateOrderStatus's own requestId-keyed idempotency
// exists to protect, defeated by never actually reusing the id a retry
// would need to land on the SAME adminActions/{requestId} document.
//
// OrderProvider itself cannot be constructed here at all outside a real
// Firebase app (its own FirebaseFirestore.instance field initializer
// crashes outside one, the same limitation order_360_layout_test.dart's
// own header already documents for admin_order_details_screen.dart). The
// two pieces of decision logic ADMR-38 adds — PendingStatusUpdate.matches
// and isAmbiguousFunctionsErrorCode — are plain, Firebase-free classes/
// functions specifically so they are directly testable without that
// dependency, mirroring this session's own established pattern
// (codLiabilityLabel, orderNeedsReturnConfirmation).
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/providers/order_provider.dart';

void main() {
  group('PendingStatusUpdate.matches', () {
    test('matches an identical retry of the same action', () {
      const pending = PendingStatusUpdate(
        orderId: 'order1',
        newStatus: 'cancelled',
        description: 'Customer requested a return',
        requestId: 'req-1',
      );
      expect(pending.matches('order1', 'cancelled', 'Customer requested a return'), isTrue);
    });

    test('does not match a different order', () {
      const pending = PendingStatusUpdate(
        orderId: 'order1',
        newStatus: 'cancelled',
        description: 'reason',
        requestId: 'req-1',
      );
      expect(pending.matches('order2', 'cancelled', 'reason'), isFalse);
    });

    test('does not match a different target status', () {
      const pending = PendingStatusUpdate(
        orderId: 'order1',
        newStatus: 'cancelled',
        description: 'reason',
        requestId: 'req-1',
      );
      expect(pending.matches('order1', 'delivered', 'reason'), isFalse);
    });

    test('does not match a different reason — the payload changed, so '
        'this is a different action even against the same order/status', () {
      const pending = PendingStatusUpdate(
        orderId: 'order1',
        newStatus: 'cancelled',
        description: 'Customer requested a return',
        requestId: 'req-1',
      );
      expect(pending.matches('order1', 'cancelled', 'Changed my mind about why'), isFalse);
    });

    test('a null description only matches another null description', () {
      const pending = PendingStatusUpdate(
        orderId: 'order1',
        newStatus: 'confirmed',
        description: null,
        requestId: 'req-1',
      );
      expect(pending.matches('order1', 'confirmed', null), isTrue);
      expect(pending.matches('order1', 'confirmed', ''), isFalse);
    });
  });

  group('isAmbiguousFunctionsErrorCode', () {
    test('transport/availability codes are ambiguous — the server may '
        'have committed before the client learned the outcome, so a '
        'retry must reuse the same requestId', () {
      expect(isAmbiguousFunctionsErrorCode('unavailable'), isTrue);
      expect(isAmbiguousFunctionsErrorCode('deadline-exceeded'), isTrue);
      expect(isAmbiguousFunctionsErrorCode('internal'), isTrue);
      expect(isAmbiguousFunctionsErrorCode('cancelled'), isTrue);
      expect(isAmbiguousFunctionsErrorCode('unknown'), isTrue);
    });

    test('definite rejections are NOT ambiguous — the server demonstrably '
        'applied nothing, so the next attempt is safe to treat as fresh', () {
      expect(isAmbiguousFunctionsErrorCode('permission-denied'), isFalse);
      expect(isAmbiguousFunctionsErrorCode('invalid-argument'), isFalse);
      expect(isAmbiguousFunctionsErrorCode('failed-precondition'), isFalse);
      expect(isAmbiguousFunctionsErrorCode('not-found'), isFalse);
      expect(isAmbiguousFunctionsErrorCode('unauthenticated'), isFalse);
    });
  });
}
