// Phase DLV-4B — the rider's money as the server records it
// (lib/money/rider_money.dart) and the pay on an offer.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/offers/delivery_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an earning reads its lines the way riderMoney.ts writes them', () {
    final e = RiderEarning.fromMap('o1', {
      'orderId': 'o1',
      'orderNumber': 'ORD-9',
      'total': 55.46,
      'km': 3.91,
      'waitMinutes': 7,
      'codCollected': 480,
      'statementId': null,
      'lines': [
        {'type': 'trip_base', 'amount': 25},
        {'type': 'distance', 'amount': 23.46, 'km': 3.91},
        {'type': 'waiting', 'amount': 7, 'minutes': 7},
      ],
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 24, 6)),
    });
    expect(e.total, 55.46);
    expect(e.basePay, 25);
    expect(e.distancePay, 23.46);
    expect(e.waitingPay, 7);
    expect(e.codCollected, 480);
    expect(e.statementId, isNull);
  });

  test('today is the Indian calendar day', () {
    // 00:10 IST on 24 Sep = 18:40 UTC on 23 Sep.
    final start = istDayStart(DateTime.utc(2026, 9, 23, 18, 40));
    expect(start, DateTime.utc(2026, 9, 23, 18, 30));
    final list = [
      RiderEarning(orderId: 'a', total: 40, createdAt: DateTime.utc(2026, 9, 23, 18, 35)), // 00:05 IST today
      RiderEarning(orderId: 'b', total: 30, createdAt: DateTime.utc(2026, 9, 23, 18, 20)), // 23:50 IST yesterday
    ];
    expect(earnedSince(list, start), 40);
  });

  test('statement wording a rider can act on', () {
    RiderPayout p(String status, {String? hold, String? ref, double cashAfter = 0}) => RiderPayout(
        id: 'x', weekKey: '2026-W38', earned: 900, netted: 300, amount: 600, cashHeldAfter: cashAfter,
        orderCount: 12, status: status, holdReason: hold, paymentReference: ref,
        periodEnd: DateTime.utc(2026, 9, 20, 18, 30));
    expect(payoutStatusLabel(p('paid', ref: 'UTR123456')), 'Paid · Ref UTR123456');
    expect(payoutStatusLabel(p('pending')), 'Being paid');
    expect(payoutStatusLabel(p('on_hold', hold: 'bank_change_pending')), contains('being checked'));
    expect(payoutStatusLabel(p('on_hold', hold: 'no_bank_details')), contains('add your bank or UPI'));
    expect(payoutStatusLabel(p('nothing_to_pay', cashAfter: 1600)), contains('still with you'));
    // periodEnd is Monday 00:00 IST; the week ended on Sunday 20 Sep.
    expect(payoutWeekLabel(p('paid')), 'Week ending 20 Sep');
  });

  test('bank form: the same checks as the server', () {
    expect(bankFormError(), 'Enter bank details or a UPI ID');
    expect(bankFormError(name: 'Ravi', account: '12', ifsc: 'SBIN0001234'), contains('9–18 digits'));
    expect(bankFormError(name: 'Ravi', account: '1234 5678 9012', ifsc: 'sbin0001234'), isNull);
    expect(bankFormError(name: 'Ravi', account: '123456789012', ifsc: 'SBIN1001234'), contains('IFSC'));
    expect(bankFormError(upi: 'ravi@okaxis'), isNull);
    expect(bankFormError(upi: 'not-upi'), contains('UPI'));
    expect(maskAccount(null), isNull);
    expect(maskAccount('123456789012'), endsWith('9012'));
  });

  test('an offer carries its pay; older offers do not', () {
    final base = {'orderId': 'o1', 'orderNumber': 'ORD-1', 'expiresAt': DateTime.utc(2026, 9, 24, 6), 'itemCount': 2};
    final withPay = DeliveryOffer.fromMap({...base, 'estimatedPay': 49.3})!;
    expect(withPay.estimatedPay, 49.3);
    expect(withPay.summary, startsWith('Earn ~₹49 · '));
    expect(DeliveryOffer.fromMap(base)!.estimatedPay, isNull);
  });
}
