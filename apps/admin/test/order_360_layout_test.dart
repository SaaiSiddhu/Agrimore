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

OrderModel _order({
  String? cancelledBy,
  DateTime? deliveredAt,
  String paymentMethod = 'razorpay',
  String? employeeUid,
}) =>
    OrderModel(
      id: 'order1',
      userId: 'user1',
      orderNumber: 'ORD1',
      items: const [],
      deliveryAddress: _address(),
      subtotal: 100,
      total: 100,
      paymentMethod: paymentMethod,
      cancelledBy: cancelledBy,
      deliveredAt: deliveredAt,
      employeeUid: employeeUid,
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

  // ADMR-28 additions below.
  group('orderHasDeliveryVerification', () {
    test('an order never delivered shows nothing', () {
      expect(orderHasDeliveryVerification(_order()), isFalse);
    });

    test('an order with a real deliveredAt shows the section', () {
      expect(orderHasDeliveryVerification(_order(deliveredAt: DateTime(2026, 9, 27))), isTrue);
    });

    test('stays visible even after a later cancellation — keyed on '
        'deliveredAt, not the current orderStatus, so real delivery '
        'history is never silently hidden by a subsequent return', () {
      final order = _order(deliveredAt: DateTime(2026, 9, 27), cancelledBy: 'admin');
      expect(orderHasDeliveryVerification(order), isTrue);
    });
  });

  group('OrderModel delivery/COD-settlement fields (ADMR-28)', () {
    test('round-trip through toMap/fromMap preserves all six fields', () {
      final deliveredAt = DateTime(2026, 9, 27, 14, 0);
      final codCollectedAt = DateTime(2026, 9, 27, 18, 0);
      final original = _order(deliveredAt: deliveredAt, paymentMethod: 'cod').copyWith(
        deliveryConfirmedBy: 'customer-uid-1',
        deliveryConfirmedVia: 'confirmDelivery',
        codSettlementStatus: 'collected',
        codCollectedBy: 'rider-uid-1',
        codCollectedAt: codCollectedAt,
      );

      final restored = OrderModel.fromMap(original.toMap(), original.id);

      expect(restored.deliveryConfirmedBy, 'customer-uid-1');
      expect(restored.deliveryConfirmedVia, 'confirmDelivery');
      expect(restored.codSettlementStatus, 'collected');
      expect(restored.codCollectedBy, 'rider-uid-1');
      expect(restored.deliveredAt, isNotNull);
      expect(restored.codCollectedAt, isNotNull);
      expect(restored.deliveredAt!.difference(deliveredAt).inSeconds.abs(), lessThan(2));
      expect(restored.codCollectedAt!.difference(codCollectedAt).inSeconds.abs(), lessThan(2));
    });

    test('an order never delivered leaves all six fields null', () {
      final restored = OrderModel.fromMap(_order().toMap(), 'order1');
      expect(restored.deliveredAt, isNull);
      expect(restored.deliveryConfirmedBy, isNull);
      expect(restored.deliveryConfirmedVia, isNull);
      expect(restored.codSettlementStatus, isNull);
      expect(restored.codCollectedBy, isNull);
      expect(restored.codCollectedAt, isNull);
    });
  });

  group('DispatchOfferRecord.fromMap', () {
    test('parses a real delivery_requests-shaped document', () {
      final offer = DispatchOfferRecord.fromMap({
        'riderId': 'rider-1',
        'status': 'accepted',
        'wave': 2,
        'pickupDistanceKm': 3.456,
        'dropDistanceKm': 5.1,
        'estimatedPay': 62.5,
        'codAmount': 450.0,
      });
      expect(offer.riderId, 'rider-1');
      expect(offer.status, 'accepted');
      expect(offer.statusDisplayName, 'Accepted');
      expect(offer.wave, 2);
      expect(offer.pickupDistanceKm, 3.456);
      expect(offer.estimatedPay, 62.5);
    });

    test('falls back to the legacy partnerId field when riderId is absent '
        '— dispatch.ts itself writes both, but an older record may not', () {
      final offer = DispatchOfferRecord.fromMap({
        'partnerId': 'legacy-rider-2',
        'status': 'expired',
        'wave': 1,
      });
      expect(offer.riderId, 'legacy-rider-2');
      expect(offer.statusDisplayName, 'Expired');
    });

    test('an unrecognized status falls back to the raw string rather than '
        'hiding it', () {
      final offer = DispatchOfferRecord.fromMap({'riderId': 'r1', 'status': 'some_future_status', 'wave': 1});
      expect(offer.statusDisplayName, 'some_future_status');
    });
  });

  // ADMR-29 additions below.
  group('orderHasCommissionAttribution', () {
    test('an order with no employeeUid is not attributed', () {
      expect(orderHasCommissionAttribution(_order()), isFalse);
    });

    test('an order with a blank employeeUid is not attributed', () {
      expect(orderHasCommissionAttribution(_order(employeeUid: '  ')), isFalse);
    });

    test('an order with a real employeeUid is attributed', () {
      expect(orderHasCommissionAttribution(_order(employeeUid: 'assoc-1')), isTrue);
    });
  });

  group('OrderModel commission fields (ADMR-29)', () {
    test('round-trip through toMap/fromMap preserves all five fields', () {
      final paidAt = DateTime(2026, 9, 27, 9, 0);
      final reversedAt = DateTime(2026, 9, 28, 9, 0);
      final original = _order(employeeUid: 'assoc-1').copyWith(
        commissionPaid: true,
        commissionAmount: 42.5,
        commissionPaidAt: paidAt,
        commissionReversed: true,
        commissionReversedAt: reversedAt,
      );

      final restored = OrderModel.fromMap(original.toMap(), original.id);

      expect(restored.commissionPaid, isTrue);
      expect(restored.commissionAmount, 42.5);
      expect(restored.commissionReversed, isTrue);
      expect(restored.commissionPaidAt, isNotNull);
      expect(restored.commissionReversedAt, isNotNull);
      expect(restored.commissionPaidAt!.difference(paidAt).inSeconds.abs(), lessThan(2));
      expect(restored.commissionReversedAt!.difference(reversedAt).inSeconds.abs(), lessThan(2));
    });

    test('an unattributed order leaves all five fields null', () {
      final restored = OrderModel.fromMap(_order().toMap(), 'order1');
      expect(restored.commissionPaid, isNull);
      expect(restored.commissionAmount, isNull);
      expect(restored.commissionPaidAt, isNull);
      expect(restored.commissionReversed, isNull);
      expect(restored.commissionReversedAt, isNull);
    });
  });

  group('RiderEarningRecord.fromMap', () {
    test('parses a real rider_earnings-shaped document', () {
      final earning = RiderEarningRecord.fromMap({
        'riderId': 'rider-1',
        'orderNumber': 'ORD1',
        'lines': [
          {'type': 'trip_base', 'amount': 20.0},
          {'type': 'distance', 'amount': 15.0, 'km': 3.2},
          {'type': 'waiting', 'amount': 5.0, 'minutes': 4},
        ],
        'total': 40.0,
        'km': 3.2,
        'kmSource': 'route',
        'waitMinutes': 4,
        'codCollected': 250.0,
        'statementId': null,
      }, 'order1');

      expect(earning.orderId, 'order1');
      expect(earning.riderId, 'rider-1');
      expect(earning.lines, hasLength(3));
      expect(earning.lines[0].label, 'Trip base');
      expect(earning.lines[1].label, 'Distance');
      expect(earning.lines[2].label, 'Waiting');
      expect(earning.total, 40.0);
      expect(earning.codCollected, 250.0);
      expect(earning.isSettled, isFalse);
    });

    test('a statementId marks the earning as settled', () {
      final earning = RiderEarningRecord.fromMap({
        'riderId': 'rider-1',
        'lines': [],
        'total': 40.0,
        'km': 0.0,
        'kmSource': 'none',
        'waitMinutes': 0,
        'codCollected': 0.0,
        'statementId': 'rider-1_2026-W39',
      }, 'order1');
      expect(earning.isSettled, isTrue);
    });

    test('an unrecognized pay-line type falls back to the raw string '
        'rather than hiding it', () {
      final line = PayLineRecord.fromMap({'type': 'future_line', 'amount': 1.0});
      expect(line.label, 'future_line');
    });
  });

  group('RiderSupportTicketRecord.fromMap', () {
    test('parses a real rider_support_tickets-shaped document, including '
        'a relatedTo order link', () {
      final ticket = RiderSupportTicketRecord.fromMap({
        'riderId': 'rider-1',
        'category': 'delivery_issue',
        'relatedTo': {'type': 'order', 'id': 'order1'},
        'message': 'Customer address was wrong',
        'status': 'submitted',
      }, 'ticket1');

      expect(ticket.ticketId, 'ticket1');
      expect(ticket.categoryLabel, 'Delivery issue');
      expect(ticket.relatedToType, 'order');
      expect(ticket.relatedToId, 'order1');
      expect(ticket.statusLabel, 'Submitted');
    });

    test('a ticket with no relatedTo leaves both fields null — the '
        'per-order query filters these out before display', () {
      final ticket = RiderSupportTicketRecord.fromMap({
        'riderId': 'rider-1',
        'category': 'earnings_payouts',
        'message': 'Where is my payout?',
        'status': 'closed',
      }, 'ticket2');
      expect(ticket.relatedToType, isNull);
      expect(ticket.relatedToId, isNull);
      expect(ticket.statusLabel, 'Closed');
    });

    test('an unrecognized category falls back to the raw string rather '
        'than hiding it', () {
      final ticket = RiderSupportTicketRecord.fromMap({
        'riderId': 'rider-1',
        'category': 'some_future_category',
        'message': 'm',
        'status': 'submitted',
      }, 'ticket3');
      expect(ticket.categoryLabel, 'some_future_category');
    });
  });

  group('CommissionExceptionRecord.fromMap', () {
    test('parses a real commission_exceptions-shaped document', () {
      final exception = CommissionExceptionRecord.fromMap({
        'orderId': 'order1',
        'orderNumber': 'ORD1',
        'employeeUid': 'assoc-1',
        'orderMode': 'B2C',
        'total': 500.0,
        'reason': 'no_configured_rate',
        'status': 'unresolved',
      }, 'exc1');

      expect(exception.id, 'exc1');
      expect(exception.orderId, 'order1');
      expect(exception.employeeUid, 'assoc-1');
      expect(exception.reason, 'no_configured_rate');
      expect(exception.status, 'unresolved');
    });
  });

  // ADMR-30 additions below.
  group('SellerPayoutRecord.fromMap', () {
    test('parses a real seller_payouts-shaped pending document', () {
      final payout = SellerPayoutRecord.fromMap({
        'sellerId': 'seller-1',
        'orderId': 'order1',
        'orderNumber': 'ORD1',
        'grossAmount': 500.0,
        'commissionRate': 10.0,
        'commissionAmount': 50.0,
        'netAmount': 450.0,
        'status': 'pending',
        'itemCount': 3,
      }, 'order1_seller-1');

      expect(payout.id, 'order1_seller-1');
      expect(payout.sellerId, 'seller-1');
      expect(payout.statusLabel, 'Pending');
      expect(payout.grossAmount, 500.0);
      expect(payout.netAmount, 450.0);
      expect(payout.paidAt, isNull);
    });

    test('a paid document carries its real payment reference and method', () {
      final payout = SellerPayoutRecord.fromMap({
        'sellerId': 'seller-1',
        'orderId': 'order1',
        'grossAmount': 500.0,
        'commissionRate': 10.0,
        'commissionAmount': 50.0,
        'netAmount': 450.0,
        'status': 'paid',
        'paidBy': 'admin-uid-1',
        'paymentReference': 'UTR123456',
        'payoutMethod': 'upi',
        'withdrawalId': 'wd-1',
      }, 'order1_seller-1');

      expect(payout.statusLabel, 'Paid');
      expect(payout.paymentReference, 'UTR123456');
      expect(payout.payoutMethod, 'upi');
      expect(payout.withdrawalId, 'wd-1');
    });

    test('falls back to the legacy amount field when netAmount is absent', () {
      final payout = SellerPayoutRecord.fromMap({
        'sellerId': 'seller-1',
        'orderId': 'order1',
        'grossAmount': 100.0,
        'commissionRate': 0.0,
        'commissionAmount': 0.0,
        'amount': 100.0,
        'status': 'pending',
      }, 'order1_seller-1');
      expect(payout.netAmount, 100.0);
    });

    test('an unrecognized status falls back to the raw string rather than '
        'hiding it', () {
      final payout = SellerPayoutRecord.fromMap({
        'sellerId': 'seller-1',
        'orderId': 'order1',
        'grossAmount': 0.0,
        'commissionRate': 0.0,
        'commissionAmount': 0.0,
        'netAmount': 0.0,
        'status': 'some_future_status',
      }, 'id1');
      expect(payout.statusLabel, 'some_future_status');
    });
  });

  // ADMR-36 additions below: `order.codSettlementStatus == 'collected'`
  // (functions/src/delivery/riderMoney.ts's recordDeliveryEarningCore) means
  // only that the rider now personally holds this order's cash as their own
  // liability — never that AgriMore has received or reconciled it. The old
  // label here ("Cash collected & settled") could not be justified by that
  // field; codLiabilityLabel is the pure decision this phase adds so the
  // wording is directly testable without constructing the screen.
  group('codLiabilityLabel', () {
    test('a non-COD order carries no cash liability at all', () {
      expect(
        codLiabilityLabel(isCod: false, collected: false),
        'Not applicable — paid online, no cash liability',
      );
      // Even if some future bug set codSettlementStatus on a non-COD order,
      // isCod alone gates this branch — never claim a liability that
      // paymentMethod says cannot exist.
      expect(
        codLiabilityLabel(isCod: false, collected: true),
        'Not applicable — paid online, no cash liability',
      );
    });

    test('a COD order not yet collected never says "settlement pending" — '
        'settlement is a rider-account concept this state knows nothing '
        'about', () {
      final label = codLiabilityLabel(isCod: true, collected: false);
      expect(label, 'Cash on delivery — not yet collected by rider');
      expect(label.toLowerCase(), isNot(contains('settl')));
    });

    test('a COD order the rider has collected never says "settled" — that '
        'would claim AgriMore has received/reconciled cash this field '
        'cannot prove', () {
      final label = codLiabilityLabel(isCod: true, collected: true);
      expect(label, contains('rider'));
      expect(label, contains('liability'));
      expect(label.toLowerCase(), isNot(contains('settled')));
    });
  });

  // ADMR-37 additions below: a delivered order cancelled afterward must
  // never have its stock auto-restored (restoreStockOnCancellation.ts
  // defers to an explicit admin confirmation instead) — these two
  // predicates are the pure decision of which honest message (if any) the
  // cancellation card shows, mirroring codLiabilityLabel's own reasoning
  // for being pulled out of the widget and made directly testable.
  group('orderNeedsReturnConfirmation', () {
    test('an order never delivered never needs return confirmation, '
        'regardless of any stray stockRestorePending flag', () {
      expect(orderNeedsReturnConfirmation(_order()), isFalse);
      expect(
        orderNeedsReturnConfirmation(_order().copyWith(stockRestorePending: true)),
        isFalse,
      );
    });

    test('a delivered order with no pending flag does not need confirmation '
        '(the ordinary, unaffected majority of cancellations)', () {
      final order = _order(deliveredAt: DateTime(2026, 9, 27));
      expect(orderNeedsReturnConfirmation(order), isFalse);
    });

    test('a delivered order flagged stockRestorePending needs confirmation', () {
      final order = _order(deliveredAt: DateTime(2026, 9, 27))
          .copyWith(stockRestorePending: true);
      expect(orderNeedsReturnConfirmation(order), isTrue);
    });
  });

  group('orderShowsStockRestoredNote', () {
    test('an order never delivered never shows the note', () {
      final order = _order().copyWith(stockRestored: true);
      expect(orderShowsStockRestoredNote(order), isFalse);
    });

    test('a delivered order not yet marked restored shows nothing', () {
      final order = _order(deliveredAt: DateTime(2026, 9, 27));
      expect(orderShowsStockRestoredNote(order), isFalse);
    });

    test('a delivered order marked restored shows the note', () {
      final order = _order(deliveredAt: DateTime(2026, 9, 27))
          .copyWith(stockRestored: true);
      expect(orderShowsStockRestoredNote(order), isTrue);
    });

    test('never true at the same time as orderNeedsReturnConfirmation — '
        'a still-pending order must show the prompt, not the note, even if '
        'stockRestored was somehow also set on old data', () {
      final order = _order(deliveredAt: DateTime(2026, 9, 27))
          .copyWith(stockRestorePending: true, stockRestored: true);
      expect(orderNeedsReturnConfirmation(order), isTrue);
      expect(orderShowsStockRestoredNote(order), isFalse);
    });
  });

  group('OrderModel stock-restoration fields (ADMR-37)', () {
    test('round-trip through toMap/fromMap preserves both fields', () {
      final original = _order(deliveredAt: DateTime(2026, 9, 27)).copyWith(
        stockRestored: true,
        stockRestorePending: false,
      );
      final restored = OrderModel.fromMap(original.toMap(), original.id);
      expect(restored.stockRestored, isTrue);
      expect(restored.stockRestorePending, isFalse);
    });

    test('an order never delivered leaves both fields null', () {
      final restored = OrderModel.fromMap(_order().toMap(), 'order1');
      expect(restored.stockRestored, isNull);
      expect(restored.stockRestorePending, isNull);
    });
  });

  // ADMR-39 additions below: riderExceptions.ts's attachProofCore already
  // writes these three fields (already covered server-side by
  // phaseDLVE1_exceptions_test.js) — this only proves the client's own
  // round-trip of them, since nothing read them before this phase.
  group('OrderModel delivery-proof fields (ADMR-39)', () {
    test('round-trip through toMap/fromMap preserves all three fields', () {
      final attachedAt = DateTime(2026, 9, 27, 19, 30);
      final original = _order(deliveredAt: DateTime(2026, 9, 27)).copyWith(
        deliveryProofPath: 'delivery_proofs/order1_proof',
        deliveryProofAttachedAt: attachedAt,
        deliveryProofAttachedBy: 'rider-uid-1',
      );
      final restored = OrderModel.fromMap(original.toMap(), original.id);
      expect(restored.deliveryProofPath, 'delivery_proofs/order1_proof');
      expect(restored.deliveryProofAttachedBy, 'rider-uid-1');
      expect(restored.deliveryProofAttachedAt, isNotNull);
      expect(restored.deliveryProofAttachedAt!.difference(attachedAt).inSeconds.abs(), lessThan(2));
    });

    test('an order with no proof attached leaves all three fields null', () {
      final restored = OrderModel.fromMap(_order().toMap(), 'order1');
      expect(restored.deliveryProofPath, isNull);
      expect(restored.deliveryProofAttachedAt, isNull);
      expect(restored.deliveryProofAttachedBy, isNull);
    });
  });

  group('RiderCashAccountRecord.fromMap', () {
    test('reads the authoritative paise field when present (DLV-M1: whole '
        'paise, no float drift)', () {
      final acc = RiderCashAccountRecord.fromMap({
        'cashHeld': 999.99, // stale/derived rupee field — paise must win
        'cashHeldPaise': 43050,
      }, 'rider-1');
      expect(acc.riderId, 'rider-1');
      expect(acc.cashHeld, 430.5);
    });

    test('falls back to the legacy rupee field for an account written '
        'before the DLV-M1 migration', () {
      final acc = RiderCashAccountRecord.fromMap({'cashHeld': 120.5}, 'rider-2');
      expect(acc.cashHeld, 120.5);
    });

    test('an account that has never held cash reads as a real zero, not '
        'an error', () {
      final acc = RiderCashAccountRecord.fromMap(const {}, 'rider-3');
      expect(acc.cashHeld, 0.0);
    });
  });
}
