// ADMR-57 — Seller 360.
//
// Same TabBarView caveat as ADMR-56's customer_detail_screen_test.dart:
// only the current tab's content is built (PageView doesn't build every
// child up front), so switchToTab is required before asserting on a
// tab's content.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/sellers/seller_detail_screen.dart';

Future<void> _seedSeller(FakeFirebaseFirestore db, String sellerId,
    {String shopName = 'Green Grocers', String status = 'approved'}) async {
  await db.collection('sellers').doc(sellerId).set({
    'shopName': shopName,
    'name': 'Ravi Kumar',
    'email': '$sellerId@example.com',
    'mobile': '9999999999',
    'shopAddress': '12 Market Road',
    'status': status,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

Future<void> pumpScreen(
    WidgetTester tester, FakeFirebaseFirestore firestore, String sellerId) async {
  // ListView lays out children lazily via slivers (viewport + cache extent)
  // even with a plain `children:` list -- the default 800x600 test surface
  // leaves later sections (e.g. Finance's "Per-order payouts", below
  // withdrawals) genuinely unbuilt, not just scrolled off-screen. A tall
  // surface avoids needing to scroll to each section by hand.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SellerDetailScreen(sellerId: sellerId, firestore: firestore),
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
  testWidgets('renders identity fields for the found seller', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_1', shopName: 'Green Grocers');

    await pumpScreen(tester, db, 'seller_1');

    // Shown both in the header and the Overview tab's own info tile.
    expect(find.text('Green Grocers'), findsNWidgets(2));
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('an unapproved/missing seller shows an honest not-found state, not a crash',
      (tester) async {
    final db = FakeFirebaseFirestore();

    await pumpScreen(tester, db, 'does_not_exist');

    expect(find.textContaining('Seller not found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P01: seller A never shows seller B\'s products', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_a', shopName: 'Shop A');
    await _seedSeller(db, 'seller_b', shopName: 'Shop B');
    await db.collection('products').add({
      'sellerId': 'seller_a',
      'name': 'Product A1',
      'salePrice': 50.0,
      'stock': 10,
      'isActive': true,
      'categoryId': 'cat1',
      'images': <String>[],
      'location': 'x',
      'locationType': 'x',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('products').add({
      'sellerId': 'seller_b',
      'name': 'Product B1',
      'salePrice': 99.0,
      'stock': 5,
      'isActive': true,
      'categoryId': 'cat1',
      'images': <String>[],
      'location': 'x',
      'locationType': 'x',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'seller_a');
    await switchToTab(tester, 'Catalog');

    expect(find.text('Product A1'), findsOneWidget);
    expect(find.text('Product B1'), findsNothing);
  });

  testWidgets('finance tab shows wallet balance, withdrawals and order payouts separately',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_fin');
    await db.collection('seller_wallets').doc('seller_fin').set({
      'balance': 2500.0,
      'payoutChangePending': null,
    });
    await db.collection('seller_withdrawals').add({
      'sellerId': 'seller_fin',
      'amountPaise': 100000,
      'status': 'requested',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('seller_payouts').add({
      'sellerId': 'seller_fin',
      'orderNumber': 'ORD-500',
      'netAmount': 450.0,
      'grossAmount': 500.0,
      'commissionAmount': 50.0,
      'status': 'paid',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'seller_fin');
    await switchToTab(tester, 'Finance');

    expect(find.text('₹2,500.00'), findsOneWidget);
    expect(find.text('₹1,000.00'), findsOneWidget);
    expect(find.text('Order ORD-500'), findsOneWidget);
  });

  testWidgets('bank and payout tab shows a pending change request with approve/reject',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_bank');
    await db.collection('seller_payout_details').doc('seller_bank').set({
      'payoutMethod': 'bank',
      'accountHolder': 'Ravi Kumar',
      'bankName': 'HDFC',
      'accountNumber': '1234567890',
      'ifsc': 'HDFC0001',
    });
    await db.collection('seller_payout_change_requests').add({
      'sellerId': 'seller_bank',
      'status': 'pending',
      'payoutMethod': 'upi',
      'upiId': 'ravi@upi',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    await pumpScreen(tester, db, 'seller_bank');
    await switchToTab(tester, 'Bank & Payout');

    expect(find.textContaining('HDFC'), findsOneWidget);
    expect(find.text('New destination requested'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('bank and payout tab shows no pending change when none exists', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_clean');
    await db.collection('seller_payout_details').doc('seller_clean').set({
      'payoutMethod': 'upi',
      'upiId': 'clean@upi',
    });

    await pumpScreen(tester, db, 'seller_clean');
    await switchToTab(tester, 'Bank & Payout');

    expect(find.text('No bank/UPI change waiting.'), findsOneWidget);
  });

  testWidgets('support tab shows the application decision when one exists', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_app');
    await db.collection('sellerRequests').doc('seller_app').set({
      'status': 'approved',
      'reviewedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

    await pumpScreen(tester, db, 'seller_app');
    await switchToTab(tester, 'Support & Audit');

    expect(find.textContaining('approved'), findsWidgets);
  });

  testWidgets('support tab discloses no case system exists when there is no application record',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSeller(db, 'seller_noapp');

    await pumpScreen(tester, db, 'seller_noapp');
    await switchToTab(tester, 'Support & Audit');

    expect(find.textContaining('No application record found'), findsOneWidget);
    expect(find.textContaining('No dedicated seller support-case system exists yet'),
        findsOneWidget);
  });
}
