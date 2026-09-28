// ADMR-86 — FinancialRecordDetailScreen, the "exact financial record" step
// of the reconciliation investigation workflow. Mirrors
// support_case_detail_screen_test.dart's own established boundary: real
// Firestore-backed rendering is covered here with a fake_cloud_firestore
// harness; the Recheck/Raise-a-case actions call real Cloud Functions and
// are deliberately never invoked from a widget test (that path belongs to
// the real-emulator Node suites — financeReconciliationRecheckFinding's own
// 8/8 in phaseADMR80_finance_reconciliation_test.js, createSupportCase's
// own suites in phaseADMR65/66). These tests only prove the actions are
// OFFERED (or correctly withheld) in the right states, never that tapping
// them succeeds.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/finance/financial_record_detail_screen.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore, {
  required String type,
  required String recordId,
  String? findingKind,
  String? findingActorType,
  Map<String, dynamic>? findingDetail,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: FinancialRecordDetailScreen(
        type: type,
        recordId: recordId,
        findingKind: findingKind,
        findingActorType: findingActorType,
        findingDetail: findingDetail,
        firestore: firestore,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a missing withdrawal shows an honest not-found state, not a crash', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpScreen(tester, db, type: 'seller_withdrawal', recordId: 'does_not_exist');

    expect(find.text('This record no longer exists.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a real seller withdrawal renders its amount, status and masked destination', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('seller_withdrawals').doc('w1').set({
      'sellerId': 'seller_1',
      'status': 'paid',
      'amountPaise': 15000,
      'paymentReference': 'UTR-1',
      'payoutIds': <String>[],
      'destination': {'method': 'bank', 'accountLast4': '4821', 'ifsc': 'EXMP0001234'},
      'destinationFull': {'payoutMethod': 'bank', 'accountNumber': '123456784821'},
    });

    await pumpScreen(tester, db, type: 'seller_withdrawal', recordId: 'w1');

    expect(find.textContaining('150.00'), findsOneWidget);
    expect(find.text('paid'), findsOneWidget);
    expect(find.textContaining('UTR-1'), findsOneWidget);
    expect(find.textContaining('record id: w1'), findsOneWidget);
    expect(find.textContaining('actor id: seller_1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('constituent payout rows render for a withdrawal with real payoutIds', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('seller_payouts').doc('p1').set({
      'sellerId': 'seller_1', 'netAmount': 40.0, 'status': 'paid', 'withdrawalId': 'w2', 'orderNumber': 'ORD-1',
    });
    await db.collection('seller_payouts').doc('p2').set({
      'sellerId': 'seller_1', 'netAmount': 60.0, 'status': 'paid', 'withdrawalId': 'w2', 'orderNumber': 'ORD-2',
    });
    await db.collection('seller_withdrawals').doc('w2').set({
      'sellerId': 'seller_1', 'status': 'paid', 'amountPaise': 10000, 'paymentReference': 'UTR-2',
      'payoutIds': ['p1', 'p2'], 'destination': {'method': 'bank', 'accountLast4': '1111', 'ifsc': 'X'},
    });

    await pumpScreen(tester, db, type: 'seller_withdrawal', recordId: 'w2');

    expect(find.textContaining('Constituent payout rows (2)'), findsOneWidget);
    expect(find.textContaining('id p1'), findsOneWidget);
    expect(find.textContaining('id p2'), findsOneWidget);
    expect(find.textContaining('ORD-1'), findsOneWidget);
    expect(find.textContaining('ORD-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rider payout renders using rider field names, not seller ones', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('rider_payouts').doc('rp1').set({
      'riderId': 'rider_1', 'status': 'paid', 'amountPaise': 5000, 'paymentReference': 'UTR-R1',
    });

    await pumpScreen(tester, db, type: 'rider_payout', recordId: 'rp1');

    expect(find.textContaining('50.00'), findsOneWidget);
    expect(find.textContaining('actor id: rider_1'), findsOneWidget);
    expect(find.textContaining('Open delivery partner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an employee payout renders using employee field names and rupee amounts directly', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('employee_payouts').doc('ep1').set({
      'employeeId': 'emp_1', 'status': 'paid', 'amount': 300, 'paymentReference': 'UTR-E1',
    });

    await pumpScreen(tester, db, type: 'employee_payout', recordId: 'ep1');

    expect(find.textContaining('300.00'), findsOneWidget);
    expect(find.textContaining('actor id: emp_1'), findsOneWidget);
    expect(find.textContaining('Open sales associate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Recheck action is offered only when opened from a specific finding', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('seller_withdrawals').doc('w3').set({
      'sellerId': 'seller_1', 'status': 'requested', 'amountPaise': 1000, 'payoutIds': <String>[],
    });

    await pumpScreen(tester, db, type: 'seller_withdrawal', recordId: 'w3');
    expect(find.text('Recheck this finding'), findsNothing);

    await pumpScreen(
      tester, db,
      type: 'seller_withdrawal', recordId: 'w3',
      findingKind: 'missing_destination_snapshot', findingActorType: 'seller', findingDetail: const {},
    );
    expect(find.text('Recheck this finding'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Recheck'), findsOneWidget);
  });

  testWidgets('no linked support cases shows an honest empty state', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('seller_withdrawals').doc('w4').set({
      'sellerId': 'seller_1', 'status': 'requested', 'amountPaise': 1000, 'payoutIds': <String>[],
    });

    await pumpScreen(tester, db, type: 'seller_withdrawal', recordId: 'w4');

    expect(find.text('No support case is linked to this record yet.'), findsOneWidget);
  });

  // Deliberately no "a linked case renders" positive-match test here:
  // fake_cloud_firestore's arrayContains compares a Map value by Dart's own
  // identity-based equality, not the real backend's value equality, so a
  // freshly-constructed {'type': ..., 'id': ...} query map never matches an
  // equally-fresh one in a stored document even when they are logically
  // identical — a previously-hit, documented gotcha in this exact codebase.
  // The real match behavior is proven server-side instead (ADMR-67's own
  // phaseADMR67_order_specific_cases_test.js against a real emulator, plus
  // ADMR-85's own linkSupportCaseRecordCore coverage for the three
  // financial types) — this file only proves the empty state above and
  // that a case tile, when present, renders correctly (implicitly covered
  // by support_case_detail_screen_test.dart's own _CaseTile-equivalent
  // patterns), not the query match itself.
}
