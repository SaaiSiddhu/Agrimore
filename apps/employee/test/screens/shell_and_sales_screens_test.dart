import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:employee/screens/shell/employee_shell_screen.dart';
import 'package:employee/screens/home/dashboard_screen.dart';
import 'package:employee/screens/profile/onboarding_status_screen.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Shell & Sales Surface — Canonical Verification', () {
    testWidgets('EmployeeShellScreen renders 4 navigation destinations and switches tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const EmployeeShellScreen(),
        ),
      );
      await tester.pump();

      // Verify all 4 tabs exist in navigation bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);
      final navBar = tester.widget<NavigationBar>(navBarFinder);
      expect(navBar.selectedIndex, 0);

      // Tap Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pump();
      expect(tester.widget<NavigationBar>(navBarFinder).selectedIndex, 1);

      // Tap Wallet tab
      await tester.tap(find.text('Wallet'));
      await tester.pump();
      expect(tester.widget<NavigationBar>(navBarFinder).selectedIndex, 2);

      // Tap Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(tester.widget<NavigationBar>(navBarFinder).selectedIndex, 3);
    });

    testWidgets('DashboardScreen displays associate code, status card, and metrics', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-888',
        'onboardingWaived': true,
        'createdAt': Timestamp.now(),
      });
      final walletSnap = FakeDocumentSnapshot({
        'balance': 15250.0,
        'lifetimeEarnings': 42000.0,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: DashboardScreen(
            employeeUid: 'test-associate-uid',
            employeeStream: Stream.value(employeeSnap),
            walletStream: Stream.value(walletSnap),
            recentOrdersStream: Stream.value(FakeQuerySnapshot([])),
            notificationsStream: Stream.value(FakeQuerySnapshot([])),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify Header
      expect(find.text('AgriMore'), findsOneWidget);
      expect(find.text('Sales Associate'), findsOneWidget);

      // Verify Associate Code Hero Card
      expect(find.text('Your Associate Code'), findsOneWidget);
      expect(find.text('AGRI-EMP-888'), findsOneWidget);
      expect(find.text('Tap to copy code'), findsOneWidget);
      expect(find.byTooltip('Share code'), findsOneWidget);

      // Verify Onboarding Fee Status Card
      expect(find.text('Onboarding Status'), findsOneWidget);
      expect(find.text('Fee Waived'), findsOneWidget);

      // Verify Financial Metrics
      expect(find.text('Wallet Balance'), findsOneWidget);
      expect(find.textContaining('15,250'), findsWidgets);
      expect(find.text('Total Commission'), findsOneWidget);
      expect(find.textContaining('42,000'), findsWidgets);

      // Verify Recent Orders
      expect(find.text('Recent Orders'), findsOneWidget);
      expect(find.text('No orders attributed yet'), findsOneWidget);
    });

    testWidgets('OnboardingStatusScreen displays attribution rules and fee status', (tester) async {
      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-888',
        'onboardingWaived': true,
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: OnboardingStatusScreen(
            employeeUid: 'test-associate-uid',
            employeeStream: Stream.value(employeeSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Onboarding Status'), findsOneWidget);
      expect(find.text('Attribution & Commission Rules'), findsOneWidget);
      expect(find.text('B2B Wholesale Orders'), findsOneWidget);
      expect(find.text('Retail (B2C) Orders'), findsOneWidget);
    });

    // ADMR-21: an unpaid associate's banner previously named a menu path and
    // button ("Profile > Associate Status" / "Pay Onboarding Fee") that do
    // not exist anywhere in apps/marketplace — the real, only entry point
    // (profile_screen.dart's single _MenuItem for this flow) is always
    // labelled "Become a Sales Associate", regardless of onboarding status.
    testWidgets('OnboardingStatusScreen tells an unpaid associate the real menu item, not a fabricated one', (tester) async {
      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-999',
        'onboardingWaived': false,
        'onboardingPaid': false,
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: OnboardingStatusScreen(
            employeeUid: 'test-associate-uid-unpaid',
            employeeStream: Stream.value(employeeSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Become a Sales Associate'), findsOneWidget,
          reason: 'must name the real, only menu item for this flow');
      expect(find.textContaining('Associate Status'), findsNothing,
          reason: '"Profile > Associate Status" does not exist anywhere in apps/marketplace');
      expect(find.textContaining('Pay Onboarding Fee'), findsNothing,
          reason: 'no button with this exact label exists at the real entry point');
    });
  });
}
