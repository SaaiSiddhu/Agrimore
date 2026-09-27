// ADMR-49 — payment security log events, already collected, never shown.
//
// PROBLEM: functions/src/customer/payment.ts and wallet.ts both already
// write a real payment_security_logs document every time a Razorpay HMAC
// signature check fails (a possible spoofing attempt, per that code's own
// log message) — firestore.rules already grants admins read access — but no
// admin screen anywhere reads this collection, so an actively-accumulating
// attack would be invisible to every admin.
//
// FIX: PaymentSecurityLogRecord (packages/agrimore_core) is a plain,
// Firebase-free parsing model, mirroring DeliveryExceptionRecord's/
// RiderIncidentRecord's established shape (ADMR-40) exactly. It gets a
// direct unit test. PaymentSecurityLogsScreen takes an injectable
// FirebaseFirestore (mirroring ADMR-48's own newly-established pattern),
// so it gets a real testWidgets test against a seeded fake Firestore too —
// not just pure-function extraction, since there is no legacy shape here
// forcing that compromise.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/security/payment_security_logs_screen.dart';

void main() {
  group('PaymentSecurityLogRecord.fromMap', () {
    test('parses a wallet top-up signature mismatch', () {
      final record = PaymentSecurityLogRecord.fromMap({
        'type': 'wallet_topup_signature_mismatch',
        'paymentId': 'pay_123',
        'orderId': 'order_456',
        'uid': 'user_789',
        'receivedSignatureLength': 64,
        'signatureMatched': false,
        'flaggedAt': Timestamp.fromDate(DateTime(2026, 9, 27, 10, 0)),
      }, 'log1');

      expect(record.logId, 'log1');
      expect(record.paymentId, 'pay_123');
      expect(record.orderId, 'order_456');
      expect(record.uid, 'user_789');
      expect(record.receivedSignatureLength, 64);
      expect(record.signatureMatched, isFalse);
      expect(record.flaggedAt, DateTime(2026, 9, 27, 10, 0));
      expect(record.typeLabel, 'Wallet top-up signature mismatch');
    });

    test('parses a plain payment signature mismatch with no uid field', () {
      final record = PaymentSecurityLogRecord.fromMap({
        'type': 'signature_mismatch',
        'paymentId': 'pay_999',
        'orderId': 'order_111',
        'receivedSignatureLength': 12,
        'signatureMatched': false,
      }, 'log2');

      expect(record.uid, isNull);
      expect(record.typeLabel, 'Payment signature mismatch');
    });

    test('an unrecognized type falls back to the raw string, not hidden', () {
      final record = PaymentSecurityLogRecord.fromMap({
        'type': 'some_future_type',
        'paymentId': 'p',
        'orderId': 'o',
        'receivedSignatureLength': 0,
        'signatureMatched': false,
      }, 'log3');

      expect(record.typeLabel, 'some_future_type');
    });
  });

  group('PaymentSecurityLogsScreen against a seeded fake Firestore', () {
    Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore firestore) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentSecurityLogsScreen(firestore: firestore),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders a real seeded mismatch event', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('payment_security_logs').add({
        'type': 'signature_mismatch',
        'paymentId': 'pay_abc',
        'orderId': 'order_xyz',
        'receivedSignatureLength': 40,
        'signatureMatched': false,
        'flaggedAt': Timestamp.fromDate(DateTime(2026, 9, 20)),
      });

      await pumpScreen(tester, firestore);

      expect(find.text('Payment signature mismatch'), findsOneWidget);
      expect(find.text('Payment ID: pay_abc'), findsOneWidget);
      expect(find.text('Order ID: order_xyz'), findsOneWidget);
    });

    testWidgets('an empty collection shows the honest empty state, not a crash', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await pumpScreen(tester, firestore);

      expect(find.text('No payment signature mismatches recorded.'), findsOneWidget);
    });

    testWidgets('multiple events each render their own card', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('payment_security_logs').add({
        'type': 'signature_mismatch',
        'paymentId': 'pay_1',
        'orderId': 'order_1',
        'receivedSignatureLength': 10,
        'signatureMatched': false,
        'flaggedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });
      await firestore.collection('payment_security_logs').add({
        'type': 'wallet_topup_signature_mismatch',
        'paymentId': 'pay_2',
        'orderId': 'order_2',
        'uid': 'user_2',
        'receivedSignatureLength': 20,
        'signatureMatched': false,
        'flaggedAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
      });

      await pumpScreen(tester, firestore);

      expect(find.text('Payment ID: pay_1'), findsOneWidget);
      expect(find.text('Payment ID: pay_2'), findsOneWidget);
      expect(find.text('User: user_2'), findsOneWidget);
    });
  });
}
