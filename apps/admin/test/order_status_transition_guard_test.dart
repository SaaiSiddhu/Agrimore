// ADMR-8 — order status transition guard.
//
// PROBLEM: orders/{orderId}'s three cancellation-triggered reversals
// (restoreStockOnCancellation, reverseEmployeeCommissionOnCancellation,
// reverseProductCreditOnCancellation — functions/src/customer/*.ts) all fire
// on any transition into their reversal status set, regardless of what the
// PRIOR status was. firestore.rules gives admin an unrestricted update on
// orders (a deliberate trust decision, not a bug), and
// order_status_updater.dart let any status chip be tapped from any current
// status with no confirmation at all — so a single mis-tap on an
// already-DELIVERED order (goods handed over, stock consumed, commission or
// product credit likely already paid) silently restored phantom stock and
// clawed back money that was already rightfully paid out.
//
// FIX: isDangerousOrderStatusTransition (order_status_updater.dart) flags
// exactly the evidenced case — leaving 'delivered' for anything else — and
// _updateStatus shows a confirmation dialog before proceeding. This does not
// block the admin (a genuine return/refund legitimately needs exactly this
// transition), it only adds friction so it is a deliberate choice, not an
// accident.
//
// isDangerousOrderStatusTransition is plain Dart with no Firebase
// dependency, so it gets a real, direct unit test — unlike OrderProvider
// itself, whose FirebaseFirestore.instance field initializer means even
// constructing it crashes outside a real Firebase app (matching this
// project's other established Firebase-free guard tests).
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/orders/widgets/order_status_updater.dart';
import 'package:agrimore_admin/providers/order_provider.dart';

void main() {
  // ADMR-24 — OrderStatusUpdateResult.isSuccess, the pure logic every call
  // site now branches on instead of ignoring updateOrderStatus's return
  // value outright (the confirmed bug this phase fixes). Real Firestore/
  // callable behavior for adminUpdateOrderStatus itself is proven against
  // the emulator by functions/scripts/phase64_admin_order_status_command_test.js
  // — OrderProvider can't be constructed here at all outside a real
  // Firebase app (its FirebaseFirestore.instance field initializer),
  // matching this file's own established note above.
  group('OrderStatusUpdateResult.isSuccess', () {
    test('applied and already_applied both count as success', () {
      expect(const OrderStatusUpdateResult(OrderStatusUpdateOutcome.applied).isSuccess, isTrue);
      expect(const OrderStatusUpdateResult(OrderStatusUpdateOutcome.alreadyApplied).isSuccess, isTrue);
    });

    test('every failure outcome counts as NOT success — the exact branch '
        'order_status_updater.dart and order_management_screen.dart now use '
        'to decide whether to show a green or red result', () {
      for (final outcome in [
        OrderStatusUpdateOutcome.staleState,
        OrderStatusUpdateOutcome.notFound,
        OrderStatusUpdateOutcome.validationFailed,
        OrderStatusUpdateOutcome.permissionDenied,
        OrderStatusUpdateOutcome.networkError,
      ]) {
        expect(OrderStatusUpdateResult(outcome).isSuccess, isFalse,
            reason: '$outcome must not be reported as success');
      }
    });
  });

  group('isDangerousOrderStatusTransition', () {
    test('flags leaving delivered for cancelled — the exact case that '
        'fires stock restoration, commission reversal, and product-credit '
        'reversal on an order that was actually fulfilled', () {
      expect(isDangerousOrderStatusTransition('delivered', 'cancelled'), isTrue);
    });

    test('flags leaving delivered for any other status too, not just '
        'cancelled', () {
      for (final next in ['pending', 'confirmed', 'processing', 'shipped']) {
        expect(isDangerousOrderStatusTransition('delivered', next), isTrue,
            reason: 'delivered -> $next should require confirmation');
      }
    });

    test('is case-insensitive on both sides, matching how orderStatus is '
        'actually compared elsewhere in this widget', () {
      expect(isDangerousOrderStatusTransition('DELIVERED', 'Cancelled'), isTrue);
      expect(isDangerousOrderStatusTransition('Delivered', 'CANCELLED'), isTrue);
    });

    test('does not flag re-selecting delivered while already delivered — '
        'not an actual status change', () {
      expect(isDangerousOrderStatusTransition('delivered', 'delivered'), isFalse);
      expect(isDangerousOrderStatusTransition('DELIVERED', 'Delivered'), isFalse);
    });

    test('does not flag ordinary forward progress through the fulfilment '
        'states — only leaving delivered is in scope for this phase', () {
      expect(isDangerousOrderStatusTransition('pending', 'confirmed'), isFalse);
      expect(isDangerousOrderStatusTransition('confirmed', 'processing'), isFalse);
      expect(isDangerousOrderStatusTransition('processing', 'shipped'), isFalse);
      expect(isDangerousOrderStatusTransition('shipped', 'delivered'), isFalse);
    });

    test('does not flag leaving an already-cancelled order — the backend '
        "triggers' own wasCancelled guard already makes that a no-op, and "
        'this phase does not invent a wider transition policy', () {
      expect(isDangerousOrderStatusTransition('cancelled', 'confirmed'), isFalse);
      expect(isDangerousOrderStatusTransition('cancelled', 'pending'), isFalse);
    });
  });
}
