// ADMR-59 — Sales Associate 360.
//
// Same conventions as ADMR-56/57/58's own tests: TabBarView only builds the
// current tab, and a tall test viewport avoids later stacked sections in
// one ListView never being built at all.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/employees/associate_detail_screen.dart';

Future<void> _seedAssociate(FakeFirebaseFirestore db, String employeeId,
    {String name = 'Priya Menon', String status = 'approved'}) async {
  await db.collection('employees').doc(employeeId).set({
    'name': name,
    'email': '$employeeId@example.com',
    'phone': '9999999999',
    'employeeCode': 'EMP001',
    'status': status,
    'commissionRate': 5.0,
    'createdBy': 'self',
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> pumpScreen(
    WidgetTester tester, FakeFirebaseFirestore firestore, String employeeId) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: AssociateDetailScreen(employeeId: employeeId, firestore: firestore),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> switchToTab(WidgetTester tester, String tabLabel) async {
  final tab = find.widgetWithText(Tab, tabLabel);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders identity fields for the found associate', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedAssociate(db, 'assoc_1', name: 'Priya Menon');

    await pumpScreen(tester, db, 'assoc_1');

    expect(find.text('Priya Menon'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('5.0% commission'.toUpperCase()), findsOneWidget);
  });

  testWidgets('a missing associate shows an honest not-found state, not a crash', (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpScreen(tester, db, 'does_not_exist');

    expect(find.textContaining('Sales Associate not found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile tab shows onboarding-fee evidence and refund requests', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('employees').doc('assoc_fee').set({
      'name': 'Test Associate',
      'email': 'a@example.com',
      'phone': '1',
      'status': 'approved',
      'commissionRate': 5.0,
      'onboardingPaid': true,
      'onboardingFeeAmount': 500.0,
      'onboardingPaymentId': 'pay_123',
      'onboardingPaidAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
    });
    await db.collection('associate_refund_requests').add({
      'employeeId': 'assoc_fee',
      'amount': 500.0,
      'status': 'pending',
      'reason': 'Associate suspended',
    });

    await pumpScreen(tester, db, 'assoc_fee');

    expect(find.textContaining('Paid (₹500.00)'), findsOneWidget);
    expect(find.text('pay_123'), findsOneWidget);
    expect(find.text('₹500.00'), findsWidgets);
  });

  testWidgets('P01: attribution tab scopes orders to this associate only', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedAssociate(db, 'assoc_a', name: 'Associate A');
    await _seedAssociate(db, 'assoc_b', name: 'Associate B');
    await db.collection('orders').add({
      'employeeUid': 'assoc_a',
      'orderNumber': 'ORD-A1',
      'orderStatus': 'delivered',
      'orderMode': 'B2B',
      'total': 199.0,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('orders').add({
      'employeeUid': 'assoc_b',
      'orderNumber': 'ORD-B1',
      'orderStatus': 'delivered',
      'orderMode': 'B2B',
      'total': 299.0,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'assoc_a');
    await switchToTab(tester, 'Attribution');

    expect(find.text('Order #ORD-A1'), findsOneWidget);
    expect(find.text('Order #ORD-B1'), findsNothing);
  });

  testWidgets('wallet tab shows the real balance from the shared wallets collection',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedAssociate(db, 'assoc_wallet');
    await db.collection('wallets').doc('assoc_wallet').set({
      'userId': 'assoc_wallet',
      'balance': 750.0,
      'lifetimeEarnings': 2000.0,
      'coins': 0,
      'referralCode': '',
      'referralCount': 0,
      'isActive': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    await pumpScreen(tester, db, 'assoc_wallet');
    await switchToTab(tester, 'Wallet & Payouts');

    expect(find.text('₹750.00'), findsOneWidget);
    expect(find.text('₹2,000.00'), findsOneWidget);
  });

  testWidgets('bank and payout tab shows current destination and a pending change',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('employees').doc('assoc_bank').set({
      'name': 'Bank Associate',
      'email': 'b@example.com',
      'phone': '1',
      'status': 'approved',
      'commissionRate': 5.0,
      'accountHolderName': 'Priya Menon',
      'bankName': 'ICICI',
      'accountNumber': '9876543210',
      'ifscCode': 'ICIC0001',
    });
    await db.collection('employee_payout_change_requests').add({
      'employeeId': 'assoc_bank',
      'status': 'pending',
      'upiId': 'priya@upi',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'assoc_bank');
    await switchToTab(tester, 'Bank & Payout');

    expect(find.textContaining('ICIC0001'), findsOneWidget);
    expect(find.text('New destination requested'), findsOneWidget);
  });
}
