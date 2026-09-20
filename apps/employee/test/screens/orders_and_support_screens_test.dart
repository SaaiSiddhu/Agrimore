import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:employee/screens/orders/orders_screen.dart';
import 'package:employee/screens/orders/order_detail_screen.dart';
import 'package:employee/screens/notifications/notifications_screen.dart';
import 'package:employee/screens/support/help_support_screen.dart';
import 'package:employee/screens/profile/profile_screen.dart';
import 'package:employee/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Orders, Notifications & Support Screens — Canonical Verification', () {
    testWidgets('OrdersScreen renders mode filters and empty state message', (tester) async {
      final emptyOrdersSnap = FakeQuerySnapshot([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: OrdersScreen(
            employeeUid: 'test-associate-uid',
            ordersStream: Stream.value(emptyOrdersSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Attributed Orders'), findsOneWidget);
      expect(find.text('All Orders'), findsOneWidget);
      expect(find.text('B2B Orders'), findsOneWidget);
      expect(find.text('Retail Orders'), findsOneWidget);
      expect(find.text('No attributed orders found'), findsOneWidget);
    });

    testWidgets('OrderDetailScreen renders complete order breakdown, commission status, and items', (tester) async {
      final sampleOrder = <String, dynamic>{
        'orderNumber': 'ORD-987654',
        'orderStatus': 'pending',
        'orderMode': 'B2B',
        'total': 45000.0,
        'createdAt': Timestamp.now(),
        'items': [
          {
            'productName': 'Organic Fertilizer 50kg',
            'quantity': 10,
            'price': 4500.0,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: OrderDetailScreen(
            orderId: 'doc-ord-987654',
            orderData: sampleOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Order #ORD-987654'), findsOneWidget);
      expect(find.text('B2B Wholesale'), findsOneWidget);
      expect(find.text('Commission Pending'), findsOneWidget);
      expect(find.text('Order Items (1)'), findsOneWidget);
      expect(find.text('Organic Fertilizer 50kg'), findsOneWidget);
    });

    testWidgets('NotificationsScreen renders empty state when no alerts', (tester) async {
      final emptyNotifSnap = FakeQuerySnapshot([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: NotificationsScreen(
            employeeUid: 'test-associate-uid',
            notificationsStream: Stream.value(emptyNotifSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('HelpSupportScreen renders contact options and expandable FAQ', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const HelpSupportScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Call Support'), findsOneWidget);
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders associate details and account options', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-001',
        'name': 'Sunil Kumar',
        'email': 'sunil.kumar@agrimore.in',
        'phone': '+919876543210',
        'department': 'Sales & Field Operations',
        'role': 'Associate',
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: ProfileScreen(
            employeeUid: 'test-associate-uid',
            employeeStream: Stream.value(employeeSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Sunil Kumar'), findsOneWidget);
      expect(find.text('AGRI-EMP-001'), findsOneWidget);
      expect(find.text('Payout Account'), findsOneWidget);
      expect(find.text('Onboarding Status'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders Appearance section and switches theme mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-001',
        'name': 'Sunil Kumar',
        'email': 'sunil.kumar@agrimore.in',
        'phone': '+919876543210',
        'department': 'Sales & Field Operations',
        'role': 'Associate',
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      final themeProvider = EmployeeThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<EmployeeThemeProvider>.value(
          value: themeProvider,
          child: MaterialApp(
            theme: SalesAssociateTheme.lightTheme,
            darkTheme: SalesAssociateTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: ProfileScreen(
              employeeUid: 'test-associate-uid',
              employeeStream: Stream.value(employeeSnap),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Tap the Dark Mode switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, isTrue);
    });
  });
}
