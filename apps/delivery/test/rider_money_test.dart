// Phase DLV-4B — the rider's money as the server records it
// (lib/money/rider_money.dart) and the pay on an offer.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/money_text.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/offers/delivery_offer.dart';
import 'package:flutter/widgets.dart';
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
    final l = lookupAppLocalizations(const Locale('en'));
    // DLV-M1: "pending" is a statement made, not money sent.
    expect(payoutStageText(l, p('paid', ref: 'UTR123456')), 'Money sent · Ref UTR123456');
    expect(payoutStageText(l, p('pending')), contains('will send the money'));
    expect(payoutStageText(l, p('on_hold', hold: 'bank_change_pending')), contains('being checked'));
    expect(payoutStageText(l, p('on_hold', hold: 'no_bank_details')), contains('add your bank or UPI'));
    expect(payoutStageText(l, p('nothing_to_pay', cashAfter: 1600)), contains('still with you'));
    // periodEnd is Monday 00:00 IST; the week ended on Sunday 20 Sep.
    expect(payoutTitle(l, p('paid')), 'Week ending 20 Sep');
  });

  test('bank form: the same checks as the server', () {
    expect(bankFormProblem(), BankFormProblem.empty);
    expect(bankFormProblem(name: 'Ravi', account: '12', ifsc: 'SBIN0001234'), BankFormProblem.accountDigits);
    expect(bankFormProblem(name: 'Ravi', account: '1234 5678 9012', ifsc: 'sbin0001234'), isNull);
    expect(bankFormProblem(name: 'Ravi', account: '123456789012', ifsc: 'SBIN1001234'), BankFormProblem.ifsc);
    expect(bankFormProblem(upi: 'ravi@okaxis'), isNull);
    expect(bankFormProblem(upi: 'not-upi'), BankFormProblem.upi);
    final l = lookupAppLocalizations(const Locale('en'));
    for (final pr in BankFormProblem.values) {
      expect(bankProblemText(l, pr), isNotEmpty);
    }
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

  // DLV-M1
  test('money reads exact paise and falls back to rounded rupees', () {
    expect(moneyField({'cashHeldPaise': 43070, 'cashHeld': 1}, 'cashHeld'), 430.7);
    expect(moneyField({'cashHeld': 430.70000000000005}, 'cashHeld'), 430.7);
    expect(moneyField(null, 'cashHeld'), 0);
    expect(RiderAccount.fromMap({'cashHeld': 0.30000000000000004}).cashHeld, 0.3);
    expect(sumRupees(List.filled(10, 0.1)), 1.0); // a fold of doubles gives 0.9999999999999999
    final e = RiderEarning.fromMap('o', {'total': 55.460000001, 'totalPaise': 5546, 'codCollectedPaise': 48000});
    expect(e.total, 55.46);
    expect(e.codCollected, 480);
  });

  test('a paid statement says where the money went', () {
    final l = lookupAppLocalizations(const Locale('en'));
    RiderPayout paid(Map<String, dynamic> extra) => RiderPayout.fromMap('rS_2026-W39_p2', {
          'weekKey': '2026-W39', 'status': 'paid', 'paymentReference': 'UTR777777', 'amountPaise': 125550,
          'amount': 1255.5, 'part': 2, 'periodEnd': Timestamp.fromDate(DateTime.utc(2026, 9, 27, 18, 30)), ...extra,
        });
    final bank = paid({'paidTo': {'method': 'bank', 'accountLast4': '7777', 'ifscCode': 'HDFC0001234'}});
    expect(payoutDestinationText(l, bank), 'Sent to bank account ending 7777');
    expect(payoutTitle(l, bank), 'Week ending 27 Sep · part 2');
    expect(bank.amount, 1255.5);
    expect(payoutDestinationText(l, paid({'paidTo': {'method': 'upi', 'upiId': 'ravi@upi'}})), 'Sent to UPI ravi@upi');
    expect(payoutDestinationText(l, paid({'payoutMethod': 'bank'})), isNull); // paid before DLV-M1
  });
}
