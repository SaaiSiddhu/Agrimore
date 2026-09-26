// ADMR-20 — employee_payouts_screen.dart's "Mark Paid" button always failed.
//
// PROBLEM, confirmed by reading both the screen and firestore.rules directly:
// this LIST screen's own `_markPaid` wrote directly to Firestore
// (`employee_payouts` doc `.update({status:'paid', paidAt:..., updatedAt:...})`)
// — but firestore.rules' employee_payouts collection has had
// `allow update: if false` since Phase ADMR-3 (Admin SDK only, via the
// markEmployeePayoutPaid/rejectEmployeePayout callables). The sibling detail
// screen (employee_payout_detail_screen.dart) was fixed in ADMR-3; this list
// screen's own separate copy of the same "Mark Paid" action was missed, so
// every click of its button has always failed with permission-denied.
//
// FIX: the button now opens a confirmation dialog collecting a UTR / payment
// reference (mirroring the detail screen's own dialog, which the correct
// callable requires — a bare status flip with no reference is not a valid
// call), then calls the real markEmployeePayoutPaid callable.
//
// This project has no Firebase-mocking test setup for this screen (its own
// direct FirebaseFirestore.instance calls would need a real Firebase app),
// so — matching this repo's other Firebase-free guards — this test asserts
// the committed source directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-20 employee payouts list "Mark Paid" truthfulness guard', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/admin/employees/employee_payouts_screen.dart',
      ).readAsString();
    });

    test('no longer writes directly to the employee_payouts collection', () {
      expect(
        source.contains("collection('employee_payouts').doc(payoutId).update"),
        isFalse,
        reason:
            "the direct Firestore write is back — firestore.rules' employee_payouts "
            "collection has 'allow update: if false' (Admin SDK only, via the "
            'markEmployeePayoutPaid callable), so this write always fails with '
            'permission-denied. If a client-writable path is being reintroduced '
            'deliberately, this guard should be removed on purpose, not silently '
            'defeated by reverting to a direct write.',
      );
    });

    test('calls the real markEmployeePayoutPaid callable with a payment reference', () {
      expect(source.contains("httpsCallable('markEmployeePayoutPaid')"), isTrue,
          reason: 'the "Mark Paid" button must call the real callable, the only '
              'path firestore.rules actually permits for this transition.');
      expect(source.contains('paymentReference'), isTrue,
          reason: 'markEmployeePayoutPaid requires a paymentReference (4-64 chars) — '
              'a bare status flip with no reference is not a valid call and would '
              'be refused as bad_reference.');
    });

    test('collects the UTR via a confirmation dialog before submitting', () {
      expect(source.contains('UTR'), isTrue,
          reason: 'the admin must be prompted to enter a UTR / transaction '
              'reference before the payout is marked paid — matching the '
              "sibling detail screen's own, already-correct dialog.");
    });

    test('maps callable refusals to plain admin-facing text, not a raw exception', () {
      expect(source.contains('_employeePayoutPaidRefusal'), isTrue,
          reason: 'a FirebaseFunctionsException must be translated into a plain '
              'message (e.g. "Enter the UTR / payment reference"), not shown raw.');
    });
  });
}
