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

  // ADMR-78/81 — legacy (pre-destinationFull) withdrawal destination handling.
  final maskedBank = {'method': 'bank', 'accountLast4': '4821', 'ifsc': 'EXMP0001234', 'bankName': 'Example Bank', 'accountHolder': 'Kaveri'};
  final maskedUpi = {'method': 'upi', 'upiId': 'kaveri@okbank'};
  final historicalAccountA = {'payoutMethod': 'bank', 'accountNumber': '123456784821', 'ifsc': 'EXMP0001234', 'accountHolder': 'Kaveri', 'bankName': 'Example Bank'};
  // ADMR-81's own regression fixture: a DIFFERENT real account (different middle digits) that happens
  // to share the same last-4 AND the same IFSC as historicalAccountA — the exact collision the owner's
  // prompt describes (same branch, coincidentally shared last-4).
  final differentAccountSameLast4AndIfsc = {'payoutMethod': 'bank', 'accountNumber': '999999994821', 'ifsc': 'EXMP0001234', 'accountHolder': 'Someone Else', 'bankName': 'Example Bank'};
  final liveBankChanged = {'payoutMethod': 'bank', 'accountNumber': '999888777666', 'ifsc': 'SCND0001122', 'accountHolder': 'Kaveri', 'bankName': 'Second Bank'};
  final liveUpiMatch = {'payoutMethod': 'upi', 'upiId': 'Kaveri@OkBank'}; // case-insensitive match
  final t1000 = Timestamp.fromMillisecondsSinceEpoch(1000);
  final t2000 = Timestamp.fromMillisecondsSinceEpoch(2000);
  final t3000 = Timestamp.fromMillisecondsSinceEpoch(3000);

  test('destinationMatchesMasked: a consistency check only — proves the collision fixture would still "match" alone', () {
    expect(destinationMatchesMasked(historicalAccountA, maskedBank), isTrue);
    // THE REGRESSION THIS PHASE FIXES: a completely different real account with the same last-4+IFSC
    // still passes this check alone — proving it is display evidence, never identity proof by itself.
    expect(destinationMatchesMasked(differentAccountSameLast4AndIfsc, maskedBank), isTrue);
    expect(destinationMatchesMasked(liveBankChanged, maskedBank), isFalse);
    expect(destinationMatchesMasked(liveUpiMatch, maskedUpi), isTrue);
    expect(destinationMatchesMasked({'payoutMethod': 'upi', 'upiId': 'someoneelse@okbank'}, maskedUpi), isFalse);
    expect(destinationMatchesMasked(null, maskedBank), isFalse);
    expect(destinationMatchesMasked(historicalAccountA, null), isFalse);
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

  test('resolveLegacyDestination: THE COLLISION REGRESSION — same last-4+IFSC on a DIFFERENT current '
      'account, no change-request history at all, must NOT resolve even though destinationMatchesMasked alone would', () {
    final withdrawal = {'destination': maskedBank, 'createdAt': t2000};
    // No approved change history at all for this seller. Per this phase's own fix, an empty history
    // is NEVER treated as proof current data is unchanged (seller_payout_details allows a direct
    // admin write outside the change-request flow) — so this must resolve unresolved regardless of
    // whether some live account happens to collide on last-4+IFSC.
    final r = resolveLegacyDestination(withdrawal, const []);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnresolved, reason: 'an empty history must never resolve');
    expect(r.payable, isFalse);
    final text = sellerPayoutDestinationText(r);
    expect(text, isNot(contains('999999994821')), reason: 'no live account number is ever shown as if correct');
    expect(text, contains('4821')); // only the masked last-4
    expect(text, contains('Do not pay'));
  });

  test('resolveLegacyDestination: resolved from a real approved change before the withdrawal — genuine provenance', () {
    final withdrawal = {'destination': maskedBank, 'createdAt': t2000};
    final changes = [SellerPayoutChangeRecord(reviewedAtMillis: 1000, fields: historicalAccountA)];
    final r = resolveLegacyDestination(withdrawal, changes);
    expect(r.kind, SellerPayoutDestinationKind.legacyResolvedFromHistory);
    expect(r.payable, isTrue);
    expect(r.method, 'bank');
    expect(sellerPayoutDestinationText(r), contains('123456784821'));
    expect(sellerPayoutDestinationText(r), contains('approved bank/UPI change history'));
  });

  test('resolveLegacyDestination: a change was approved, but only AFTER the withdrawal — nothing earlier to anchor to', () {
    final withdrawal = {'destination': maskedBank, 'createdAt': t1000};
    final changes = [SellerPayoutChangeRecord(reviewedAtMillis: 3000, fields: liveBankChanged)];
    final r = resolveLegacyDestination(withdrawal, changes);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnresolved,
        reason: 'the ONLY known account state is what it became AFTER this request, not what it was when requested');
    expect(r.payable, isFalse);
  });

  test('resolveLegacyDestination: the most recent approved change at-or-before createdAt wins over an older one', () {
    final withdrawal = {'destination': maskedBank, 'createdAt': t3000};
    final changes = [
      SellerPayoutChangeRecord(reviewedAtMillis: 500, fields: liveBankChanged), // older, wrong account
      SellerPayoutChangeRecord(reviewedAtMillis: 1000, fields: historicalAccountA), // most recent <= createdAt
    ];
    final r = resolveLegacyDestination(withdrawal, changes);
    expect(r.kind, SellerPayoutDestinationKind.legacyResolvedFromHistory);
    expect(r.display?['accountNumber'], '123456784821');
  });

  test('resolveLegacyDestination: a found historical record inconsistent with the frozen masked destination is not trusted', () {
    final withdrawal = {'destination': maskedBank, 'createdAt': t2000};
    final changes = [SellerPayoutChangeRecord(reviewedAtMillis: 1000, fields: liveBankChanged)]; // wrong account entirely
    final r = resolveLegacyDestination(withdrawal, changes);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnresolved);
  });

  test('resolveLegacyDestination: no createdAt on the withdrawal — cannot order history, refused not guessed', () {
    final withdrawal = {'destination': maskedBank};
    final changes = [SellerPayoutChangeRecord(reviewedAtMillis: 1000, fields: historicalAccountA)];
    final r = resolveLegacyDestination(withdrawal, changes);
    expect(r.kind, SellerPayoutDestinationKind.legacyUnresolved);
  });

  test('resolveSellerWithdrawalDestination: malformed request with no destination at all — a safe dead end, not a crash', () {
    final r = resolveSellerWithdrawalDestination({});
    expect(r.kind, SellerPayoutDestinationKind.missing);
    expect(r.payable, isFalse);
    expect(r.method, isNull);
    expect(sellerPayoutDestinationText(r), contains('Contact the owner'));
  });
}
