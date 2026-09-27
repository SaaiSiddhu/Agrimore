// ADMR-53 — a support lookup for verified_payments, already collected,
// never shown.
//
// PROBLEM: verified_payments is written by three different flows
// (functions/src/customer/payment.ts, functions/src/employee/
// razorpayOnboardingWebhook.ts) and read as proof-of-payment by two more
// (seller/aiConnection.ts, employee/activationCore.ts) — firestore.rules
// already grants admin read — but no admin screen reads it at all, so
// support has no way to check "was payment X actually verified" without a
// direct Firestore console query.
//
// FIX: VerifiedPaymentRecord (packages/agrimore_core) is a plain, Firebase-
// free parsing model, tolerant of whichever subset of fields a given writer
// populated. VerifiedPaymentLookupScreen takes an injectable
// FirebaseFirestore (mirroring ADMR-48/49/51/52's now-established pattern),
// so it is testWidgets-testable from day one.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/security/verified_payment_lookup_screen.dart';

void main() {
  group('VerifiedPaymentRecord.fromMap', () {
    test('parses a full record', () {
      final record = VerifiedPaymentRecord.fromMap({
        'orderId': 'order_1',
        'userId': 'user_1',
        'status': 'captured',
        'amount': 499.0,
        'currency': 'INR',
        'method': 'upi',
        'upiId': 'user@bank',
        'signatureVerified': true,
        'isTest': false,
        'verifiedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      }, 'pay_123');

      expect(record.paymentId, 'pay_123');
      expect(record.orderId, 'order_1');
      expect(record.status, 'captured');
      expect(record.amount, 499.0);
      expect(record.signatureVerified, isTrue);
      expect(record.isTest, isFalse);
      expect(record.verifiedAt, DateTime(2026, 9, 1));
    });

    test('tolerates a minimal record missing most optional fields', () {
      final record = VerifiedPaymentRecord.fromMap({
        'status': 'captured',
      }, 'pay_456');

      expect(record.paymentId, 'pay_456');
      expect(record.orderId, isNull);
      expect(record.signatureVerified, isFalse);
      expect(record.isTest, isFalse);
    });

    test('a sandbox test payment is flagged as such', () {
      final record = VerifiedPaymentRecord.fromMap({
        'isTest': true,
        'method': 'test_sandbox',
      }, 'pay_test');

      expect(record.isTest, isTrue);
    });
  });

  group('VerifiedPaymentLookupScreen against a seeded fake Firestore', () {
    testWidgets('finds and renders a real seeded payment by its exact id', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('verified_payments').doc('pay_found').set({
        'orderId': 'order_found',
        'status': 'captured',
        'amount': 250.0,
        'currency': 'INR',
      });

      await tester.pumpWidget(
        MaterialApp(home: VerifiedPaymentLookupScreen(firestore: firestore)),
      );

      await tester.enterText(find.byType(TextField), 'pay_found');
      await tester.tap(find.text('Look Up'));
      await tester.pumpAndSettle();

      expect(find.text('Verified Payment'), findsOneWidget);
      expect(find.text('order_found'), findsOneWidget);
      expect(find.text('No verified payment found for that ID.'), findsNothing);
    });

    testWidgets('an unknown payment id shows the honest not-found message', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        MaterialApp(home: VerifiedPaymentLookupScreen(firestore: firestore)),
      );

      await tester.enterText(find.byType(TextField), 'does-not-exist');
      await tester.tap(find.text('Look Up'));
      await tester.pumpAndSettle();

      expect(find.text('No verified payment found for that ID.'), findsOneWidget);
    });

    testWidgets('a sandbox test payment is labeled distinctly from a real one', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('verified_payments').doc('pay_sandbox').set({
        'isTest': true,
        'status': 'captured',
      });

      await tester.pumpWidget(
        MaterialApp(home: VerifiedPaymentLookupScreen(firestore: firestore)),
      );

      await tester.enterText(find.byType(TextField), 'pay_sandbox');
      await tester.tap(find.text('Look Up'));
      await tester.pumpAndSettle();

      expect(find.text('Sandbox / Test Payment'), findsOneWidget);
      expect(find.text('Verified Payment'), findsNothing);
    });
  });
}
