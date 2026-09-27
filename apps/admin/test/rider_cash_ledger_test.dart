// ADMR-52 — surface the rider cash ledger, already collected, never shown.
//
// PROBLEM: functions/src/delivery/riderMoney.ts already writes a real
// rider_cash_ledger document for every change to a rider's cashHeld (a COD
// collection, an admin-recorded deposit, cash netted against a payout
// statement) — firestore.rules already grants admin read — but no admin
// screen reads it, so an admin resolving a cash discrepancy has no history
// to check, only the current balance.
//
// FIX: RiderCashLedgerEntry (packages/agrimore_core) is a plain, Firebase-
// free parsing model mirroring PaymentSecurityLogRecord's established shape
// (ADMR-49). RiderCashLedgerScreen takes an injectable FirebaseFirestore
// (mirroring ADMR-48/49/51's now-established pattern), so it is
// testWidgets-testable from day one.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/delivery/rider_cash_ledger_screen.dart';

void main() {
  group('RiderCashLedgerEntry.fromMap', () {
    test('parses a cash_collected entry', () {
      final entry = RiderCashLedgerEntry.fromMap({
        'riderId': 'rider1',
        'type': 'cash_collected',
        'amountPaise': 45000,
        'orderId': 'order_abc',
        'at': Timestamp.fromDate(DateTime(2026, 9, 1)),
      }, 'entry1');

      expect(entry.entryId, 'entry1');
      expect(entry.riderId, 'rider1');
      expect(entry.amount, 450.0);
      expect(entry.orderId, 'order_abc');
      expect(entry.reference, isNull);
      expect(entry.typeLabel, 'Cash collected (COD)');
    });

    test('parses a deposit entry with reference and recordedBy', () {
      final entry = RiderCashLedgerEntry.fromMap({
        'riderId': 'rider1',
        'type': 'deposit',
        'amountPaise': 200000,
        'reference': 'DEP-001',
        'recordedBy': 'admin_uid_1',
        'at': Timestamp.fromDate(DateTime(2026, 9, 2)),
      }, 'entry2');

      expect(entry.amount, 2000.0);
      expect(entry.reference, 'DEP-001');
      expect(entry.recordedBy, 'admin_uid_1');
      expect(entry.orderId, isNull);
      expect(entry.typeLabel, 'Cash deposited');
    });

    test('parses a netted_against_payout entry with a statementId', () {
      final entry = RiderCashLedgerEntry.fromMap({
        'riderId': 'rider1',
        'type': 'netted_against_payout',
        'amountPaise': 100000,
        'statementId': 'rider1_2026W39',
      }, 'entry3');

      expect(entry.statementId, 'rider1_2026W39');
      expect(entry.typeLabel, 'Netted against payout');
    });

    test('falls back to amount * 100 when amountPaise is missing', () {
      final entry = RiderCashLedgerEntry.fromMap({
        'riderId': 'rider1',
        'type': 'deposit',
        'amount': 55.0,
      }, 'entry4');

      expect(entry.amountPaise, 5500);
    });

    test('an unrecognized type falls back to the raw string, not hidden', () {
      final entry = RiderCashLedgerEntry.fromMap({
        'riderId': 'rider1',
        'type': 'some_future_type',
        'amountPaise': 100,
      }, 'entry5');

      expect(entry.typeLabel, 'some_future_type');
    });
  });

  group('RiderCashLedgerScreen against a seeded fake Firestore', () {
    Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore firestore, String riderId) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiderCashLedgerScreen(riderId: riderId, firestore: firestore),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders a real seeded ledger entry for the requested rider', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rider_cash_ledger').add({
        'riderId': 'rider_x',
        'type': 'cash_collected',
        'amountPaise': 30000,
        'orderId': 'order_1',
        'at': Timestamp.fromDate(DateTime(2026, 9, 5)),
      });

      await pumpScreen(tester, firestore, 'rider_x');

      expect(find.text('Cash collected (COD)'), findsOneWidget);
      expect(find.text('Order: order_1'), findsOneWidget);
    });

    testWidgets('only shows entries for the requested rider, not other riders', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rider_cash_ledger').add({
        'riderId': 'rider_x',
        'type': 'deposit',
        'amountPaise': 10000,
        'reference': 'DEP-X',
        'at': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });
      await firestore.collection('rider_cash_ledger').add({
        'riderId': 'rider_y',
        'type': 'deposit',
        'amountPaise': 20000,
        'reference': 'DEP-Y',
        'at': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      await pumpScreen(tester, firestore, 'rider_x');

      expect(find.text('Reference: DEP-X'), findsOneWidget);
      expect(find.text('Reference: DEP-Y'), findsNothing);
    });

    testWidgets('an empty ledger shows the honest empty state, not a crash', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await pumpScreen(tester, firestore, 'rider_with_no_history');

      expect(find.text('No cash ledger entries yet for this rider.'), findsOneWidget);
    });
  });
}
