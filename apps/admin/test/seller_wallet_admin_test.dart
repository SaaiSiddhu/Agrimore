// SELLER-WALLET-1 — admin seller wallet helpers (seller_wallet_admin.dart).
import 'package:agrimore_admin/screens/admin/sellers/seller_wallet_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every server refusal reads as an admin sentence', () {
    for (final r in ['payout_change_pending', 'no_destination', 'not_requested', 'payout_mismatch', 'bad_reference',
      'bad_method', 'method_mismatch', 'reason_required', 'not_pending', 'not_found']) {
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

  // ADMR-78 — legacy (pre-destinationFull) withdrawal destination handling.
  final maskedBank = {'method': 'bank', 'accountLast4': '4821', 'ifsc': 'EXMP0001234', 'bankName': 'Example Bank', 'accountHolder': 'Kaveri'};
  final maskedUpi = {'method': 'upi', 'upiId': 'kaveri@okbank'};
  final liveBankMatch = {'payoutMethod': 'bank', 'accountNumber': '123456784821', 'ifsc': 'EXMP0001234', 'accountHolder': 'Kaveri', 'bankName': 'Example Bank'};
  final liveBankChanged = {'payoutMethod': 'bank', 'accountNumber': '999888777666', 'ifsc': 'SCND0001122', 'accountHolder': 'Kaveri', 'bankName': 'Second Bank'};
  final liveUpiMatch = {'payoutMethod': 'upi', 'upiId': 'Kaveri@OkBank'}; // case-insensitive match

  test('destinationMatchesMasked: same account matches regardless of full-vs-masked shape, a changed one does not', () {
    expect(destinationMatchesMasked(liveBankMatch, maskedBank), isTrue);
    expect(destinationMatchesMasked(liveBankChanged, maskedBank), isFalse);
    expect(destinationMatchesMasked(liveUpiMatch, maskedUpi), isTrue);
    expect(destinationMatchesMasked({'payoutMethod': 'upi', 'upiId': 'someoneelse@okbank'}, maskedUpi), isFalse);
    expect(destinationMatchesMasked(null, maskedBank), isFalse);
    expect(destinationMatchesMasked(liveBankMatch, null), isFalse);
    // A method switch alone (even with coincidentally-matching sub-fields) must never match.
    expect(destinationMatchesMasked({'payoutMethod': 'upi', 'upiId': 'kaveri@okbank'}, maskedBank), isFalse);
  });

  test('resolveSellerWithdrawalDestination: full (new-shape) request', () {
    final full = {'payoutMethod': 'bank', 'accountNumber': '123456784821', 'ifsc': 'EXMP0001234', 'accountHolder': 'Kaveri', 'bankName': null, 'upiId': null};
    final r = resolveSellerWithdrawalDestination({'destination': maskedBank, 'destinationFull': full});
    expect(r.kind, SellerPayoutDestinationKind.full);
    expect(r.payable, isTrue);
    expect(r.method, 'bank');
    expect(sellerPayoutDestinationText(r), contains('123456784821'));
  });

  test('resolveSellerWithdrawalDestination: legacy bank request, live details still match', () {
    final r = resolveSellerWithdrawalDestination({'destination': maskedBank}, liveDetails: liveBankMatch);
    expect(r.kind, SellerPayoutDestinationKind.legacyVerified);
    expect(r.payable, isTrue);
    expect(r.method, 'bank');
    expect(sellerPayoutDestinationText(r), contains('verified against'));
    expect(sellerPayoutDestinationText(r), contains('123456784821')); // the live full account number, safe to show once verified
  });

  test('resolveSellerWithdrawalDestination: legacy UPI request, live details still match', () {
    final r = resolveSellerWithdrawalDestination({'destination': maskedUpi}, liveDetails: liveUpiMatch);
    expect(r.kind, SellerPayoutDestinationKind.legacyVerified);
    expect(r.payable, isTrue);
    expect(r.method, 'upi');
  });

  test('resolveSellerWithdrawalDestination: legacy request, seller changed bank since — refused, not guessed', () {
    final r = resolveSellerWithdrawalDestination({'destination': maskedBank}, liveDetails: liveBankChanged);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnverified);
    expect(r.payable, isFalse);
    expect(r.method, 'bank'); // still the frozen record's own method, never live's
    final text = sellerPayoutDestinationText(r);
    expect(text, contains('4821')); // only the masked last-4, never the live full number
    expect(text, isNot(contains('999888777666')));
    expect(text, contains('Do not pay'));
  });

  test('resolveSellerWithdrawalDestination: legacy request, no live payout details at all — refused, not guessed', () {
    final r = resolveSellerWithdrawalDestination({'destination': maskedBank}, liveDetails: null);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnverified);
    expect(r.payable, isFalse);
  });

  test('resolveSellerWithdrawalDestination: malformed request with no destination at all — a safe dead end, not a crash', () {
    final r = resolveSellerWithdrawalDestination({});
    expect(r.kind, SellerPayoutDestinationKind.missing);
    expect(r.payable, isFalse);
    expect(r.method, isNull);
    expect(sellerPayoutDestinationText(r), contains('Contact the owner'));
  });
}
