// SELLER-WALLET-1 — admin seller wallet helpers (seller_wallet_admin.dart).
import 'package:agrimore_admin/screens/admin/sellers/seller_wallet_admin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // ADMR-78/81/83 — legacy (pre-destinationFull) withdrawal destination handling.
  final maskedBank = {'method': 'bank', 'accountLast4': '4821', 'ifsc': 'EXMP0001234', 'bankName': 'Example Bank', 'accountHolder': 'Kaveri'};

  test('resolveSellerWithdrawalDestination: full (new-shape) request', () {
    final full = {'payoutMethod': 'bank', 'accountNumber': '123456784821', 'ifsc': 'EXMP0001234', 'accountHolder': 'Kaveri', 'bankName': null, 'upiId': null};
    final r = resolveSellerWithdrawalDestination({'destination': maskedBank, 'destinationFull': full});
    expect(r.kind, SellerPayoutDestinationKind.full);
    expect(r.payable, isTrue);
    expect(r.method, 'bank');
    expect(sellerPayoutDestinationText(r), contains('123456784821'));
  });

  test('resolveLegacyDestination: THE ADMR-83 COUNTEREXAMPLE — account A approved via the change-request '
      'flow, then a direct (untracked) write silently changes the live account to a DIFFERENT B sharing '
      'A\'s own masked shape; a withdrawal requested after must NOT resolve to A', () {
    // Before this phase, resolveLegacyDestination would find the approved-change record for A (the
    // only one on file, timestamped before this withdrawal) and — since A's own masked shape matches
    // the withdrawal's frozen `destination` (itself computed from the LIVE, now-B, details at request
    // time, per the owner's own stated premise that A and B collide on last-4+IFSC) — would have
    // reported legacyResolvedFromHistory with A's full account. A was never the real destination; B
    // was, silently, the whole time. No masked-field consistency check can detect this, because the
    // withdrawal's own frozen snapshot was itself derived from the same live data the untracked write
    // already replaced. This is exactly why legacyResolvedFromHistory no longer exists at all.
    final withdrawal = {'destination': maskedBank, 'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000)};
    final r = resolveLegacyDestination(withdrawal);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnresolved);
    expect(r.payable, isFalse);
    final text = sellerPayoutDestinationText(r);
    expect(text, contains('4821')); // only ever the masked last-4
    expect(text, isNot(contains('123456784821')), reason: 'no full account number, correct or not, is ever shown as if resolved');
    expect(text, contains('Do not pay'));
  });

  test('resolveLegacyDestination: unconditionally unresolved whenever a masked destination exists, no exceptions', () {
    final maskedUpi = {'method': 'upi', 'upiId': 'kaveri@okbank'};
    for (final withdrawal in [
      {'destination': maskedBank, 'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000)},
      {'destination': maskedUpi}, // no createdAt at all
      {'destination': maskedBank}, // no createdAt, bank method
    ]) {
      final r = resolveLegacyDestination(withdrawal);
      expect(r.kind, SellerPayoutDestinationKind.legacyUnresolved, reason: withdrawal.toString());
      expect(r.payable, isFalse, reason: withdrawal.toString());
      expect(r.method, withdrawal['destination'] is Map ? (withdrawal['destination'] as Map)['method'] : null, reason: withdrawal.toString());
    }
  });

  test('resolveSellerWithdrawalDestination: malformed request with no destination at all — a safe dead end, not a crash', () {
    final r = resolveSellerWithdrawalDestination({});
    expect(r.kind, SellerPayoutDestinationKind.missing);
    expect(r.payable, isFalse);
    expect(r.method, isNull);
    expect(sellerPayoutDestinationText(r), contains('Contact the owner'));
  });
}
