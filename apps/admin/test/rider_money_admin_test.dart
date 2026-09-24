// Phase DLV-4B — admin Rider Payouts helpers (rider_money_admin.dart).
import 'package:agrimore_admin/screens/admin/delivery/rider_money_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, String> form([Map<String, String> over = const {}]) => {
        'basePay': '25', 'perKm': '6', 'waitingPerMin': '1', 'waitingFreeMin': '10', 'codCashLimit': '2000', 'maxKm': '25',
        ...over,
      };

  test('rate bounds match riderPay.ts', () {
    expect(validateRates(form()).values!['basePay'], 25);
    expect(validateRates(form({'basePay': '501'})).error, contains('between 0 and 500'));
    expect(validateRates(form({'maxKm': '0'})).error, contains('between 1 and 100'));
    expect(validateRates(form({'perKm': 'six'})).error, contains('enter a number'));
    expect(validateRates(form({'codCashLimit': '100000'})).error, isNull);
  });

  test('what the server will use for a stored value', () {
    expect(effectiveRate('perKm', 7), 7);
    expect(effectiveRate('perKm', 700), 6); // out of range → default
    expect(effectiveRate('basePay', null), 25);
    expect(ratesSummary(const {}), '₹25 + ₹6/km + ₹1/min after 10 min · COD cash limit ₹2000');
  });

  test('references and refusals', () {
    expect(paymentReferenceError('UTR'), isNotNull);
    expect(paymentReferenceError('UTR123456'), isNull);
    expect(riderMoneyRefusal('failed-precondition', 'more_than_held'), contains('more cash'));
    expect(riderMoneyRefusal('permission-denied', null), 'Only admins can do this.');
    expect(holdReasonLabel('no_bank_details'), contains('no bank'));
  });
}
