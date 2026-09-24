// SELLER-WALLET-1 — admin seller wallet helpers (seller_wallet_admin.dart).
import 'package:agrimore_admin/screens/admin/sellers/seller_wallet_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every server refusal reads as an admin sentence', () {
    for (final r in ['payout_change_pending', 'no_destination', 'not_requested', 'payout_mismatch', 'bad_reference',
      'bad_method', 'reason_required', 'not_pending', 'not_found']) {
      final text = sellerWalletRefusal('failed-precondition', r);
      expect(text, isNot(contains('_')), reason: r);
      expect(text, isNot('Could not complete that. Please try again.'), reason: r);
    }
    expect(sellerWalletRefusal('permission-denied', null), 'Only admins can do this.');
    expect(sellerWalletRefusal('unavailable', null), 'No connection. Try again.');
  });

  test('the admin sees the full destination to pay', () {
    expect(sellerDestinationFull(null), 'No payout account on file');
    expect(sellerDestinationFull({'payoutMethod': 'upi', 'upiId': 'kaveri@okbank', 'accountHolder': 'Kaveri'}), 'UPI kaveri@okbank · Kaveri');
    final bank = sellerDestinationFull({
      'payoutMethod': 'bank', 'accountHolder': 'Kaveri', 'bankName': 'Example Bank', 'accountNumber': '123456784821', 'ifsc': 'EXMP0001234',
    });
    expect(bank, contains('A/c 123456784821'));
    expect(bank, contains('IFSC EXMP0001234'));
  });
}
