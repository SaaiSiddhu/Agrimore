// ADMR-54 — revive UserDetailsModal, give it real order history.
//
// PROBLEM: UserDetailsModal (291 lines) was entirely dead code — referenced
// nowhere outside its own file, never shown to any admin. user_management_
// screen.dart's UserCard had both an onTap and a dedicated onEdit button,
// both wired to the same navigate-to-edit action, a genuine redundancy.
//
// FIX: the whole-card tap now opens this revived modal (a real "view"
// action, distinct from the dedicated Edit button); the modal gains one
// real, live section — Recent Orders — via an injectable FirebaseFirestore
// (mirroring ADMR-48/49/51/52/53's now-established pattern), so it is
// testWidgets-testable from day one.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/users/widgets/user_details_modal.dart';

UserModel _user({String uid = 'user_x', String name = 'Test User'}) {
  return UserModel(
    uid: uid,
    email: '$uid@example.com',
    name: name,
    role: 'user',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  Future<void> pumpModal(WidgetTester tester, FakeFirebaseFirestore firestore, UserModel user) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserDetailsModal(
            user: user,
            onEdit: () {},
            onClose: () {},
            firestore: firestore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a real seeded order for this specific user', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final user = _user();
    await firestore.collection('orders').add({
      'userId': user.uid,
      'orderNumber': 'ORD-7001',
      'orderStatus': 'delivered',
      'total': 349.0,
      'subtotal': 349.0,
      'paymentMethod': 'cod',
      'items': <Map<String, dynamic>>[],
      'deliveryAddress': <String, dynamic>{},
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
    });

    await pumpModal(tester, firestore, user);

    expect(find.text('Order #ORD-7001'), findsOneWidget);
    expect(find.text('₹349.00'), findsOneWidget);
  });

  testWidgets('does not show another user\'s order', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final user = _user(uid: 'user_x');
    await firestore.collection('orders').add({
      'userId': 'user_y',
      'orderNumber': 'ORD-8002',
      'orderStatus': 'delivered',
      'total': 100.0,
      'subtotal': 100.0,
      'paymentMethod': 'cod',
      'items': <Map<String, dynamic>>[],
      'deliveryAddress': <String, dynamic>{},
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
    });

    await pumpModal(tester, firestore, user);

    expect(find.text('Order #ORD-8002'), findsNothing);
    expect(find.text('No orders yet.'), findsOneWidget);
  });

  testWidgets('a user with no orders shows the honest empty state, not a crash', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await pumpModal(tester, firestore, _user());

    expect(find.text('No orders yet.'), findsOneWidget);
  });

  testWidgets('the profile fields this modal already showed still render', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await pumpModal(tester, firestore, _user(name: 'Priya Sharma'));

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
