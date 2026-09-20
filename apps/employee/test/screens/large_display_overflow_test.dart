import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:employee/screens/shell/employee_shell_screen.dart';
import 'package:employee/screens/home/dashboard_screen.dart';
import 'package:employee/screens/profile/onboarding_status_screen.dart';
import 'package:employee/screens/orders/order_detail_screen.dart';
import 'package:employee/screens/wallet/payout_details_screen.dart';
import 'package:employee/screens/wallet/payout_review_screen.dart';
import 'package:employee/screens/profile/profile_screen.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Large Display & Large Font Scale Resilience Tests', () {
    testWidgets('OnboardingStatusScreen renders without overflow at 1.5x and 2.0x font scale', (tester) async {
      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-999',
        'onboardingPaid': false,
        'onboardingWaived': false,
        'createdAt': Timestamp.now(),
      });

      for (final scale in [1.5, 2.0]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.25; // 520 dpi

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              size: const Size(332, 738),
            ),
            child: MaterialApp(
              theme: SalesAssociateTheme.lightTheme,
              home: OnboardingStatusScreen(
                key: ValueKey(scale),
                employeeUid: 'test-associate-uid',
                employeeStream: Stream.value(employeeSnap),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Onboarding Status'), findsOneWidget);

        // Fling down through entire list to verify all cards render without overflow
        await tester.fling(find.byType(ListView), const Offset(0, -600), 1000);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);

        // Fling back up
        await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Onboarding Status'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('DashboardScreen renders without overflow at 1.5x and 2.0x font scale', (tester) async {
      final employeeSnap = FakeDocumentSnapshot({
        'employeeCode': 'AGRI-EMP-888',
        'onboardingWaived': true,
        'createdAt': Timestamp.now(),
      });
      final walletSnap = FakeDocumentSnapshot({
        'balance': 25500.0,
        'lifetimeEarnings': 89000.0,
      });

      for (final scale in [1.5, 2.0]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.25;

        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint('DASHBOARD_ERROR_DETAILS: ${details.toString()}');
          originalOnError?.call(details);
        };

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              size: const Size(332, 738),
            ),
            child: MaterialApp(
              theme: SalesAssociateTheme.lightTheme,
              home: DashboardScreen(
                key: ValueKey(scale),
                employeeUid: 'test-associate-uid',
                employeeStream: Stream.value(employeeSnap).asBroadcastStream(),
                walletStream: Stream.value(walletSnap).asBroadcastStream(),
                recentOrdersStream: Stream.value(FakeQuerySnapshot([])).asBroadcastStream(),
                notificationsStream: Stream.value(FakeQuerySnapshot([])).asBroadcastStream(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Your Associate Code'), findsOneWidget);
        expect(find.text('AGRI-EMP-888'), findsOneWidget);

        // Fling down through entire dashboard to verify metrics and orders render without overflow
        await tester.fling(find.byType(ListView), const Offset(0, -600), 1000);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);

        // Fling back up
        await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Your Associate Code'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OrderDetailScreen renders without overflow at 1.5x and 2.0x font scale', (tester) async {
      final orderData = {
        'orderNumber': 'ORD-B2B-2026-9999',
        'orderStatus': 'delivered',
        'orderMode': 'B2B',
        'total': 185000.0,
        'commissionPaid': true,
        'commissionAmount': 9250.0,
        'createdAt': Timestamp.now(),
        'items': [
          {
            'name': 'Urea Bio-Fertilizer 50kg Heavy Bag',
            'quantity': 25,
            'price': 7400.0,
          }
        ],
      };

      for (final scale in [1.5, 2.0]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.25;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              size: const Size(332, 738),
            ),
            child: MaterialApp(
              theme: SalesAssociateTheme.lightTheme,
              home: OrderDetailScreen(
                orderId: 'test-order-999',
                orderData: orderData,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Order Summary'), findsOneWidget);
        expect(find.text('Order Number'), findsOneWidget);
        expect(find.text('Order Channel'), findsOneWidget);
        expect(find.text('Order Total'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('PayoutDetailsScreen and PayoutReviewScreen render without overflow at 1.5x and 2.0x font scale', (tester) async {
      final payoutData = {
        'amount': 25000.0,
        'status': 'completed',
        'method': 'bank',
        'referenceId': 'REF-AGRI-PAYOUT-987654321',
        'destination': 'HDFC Bank •••• 9876',
        'createdAt': Timestamp.now(),
        'completedAt': Timestamp.now(),
      };

      for (final scale in [1.5, 2.0]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.25;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              size: const Size(332, 738),
            ),
            child: MaterialApp(
              theme: SalesAssociateTheme.lightTheme,
              home: PayoutDetailsScreen(
                key: ValueKey(scale),
                payoutId: 'test-payout-123',
                initialData: payoutData,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('COMPLETED'), findsOneWidget);
        expect(find.text('Requested Payout Amount'), findsOneWidget);

        // Scroll down to reveal reference ID and destination without overflow
        await tester.scrollUntilVisible(find.text('Destination'), 50);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Reference ID'), findsOneWidget);
        expect(find.text('Payout Method'), findsOneWidget);
        expect(find.text('Destination'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('EmployeeShellScreen NavigationBar adapts to 1.5x and 2.0x font scale without overflow', (tester) async {
      for (final scale in [1.5, 2.0]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.25;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              size: const Size(332, 738),
            ),
            child: MaterialApp(
              theme: SalesAssociateTheme.lightTheme,
              home: const EmployeeShellScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Orders'), findsOneWidget);
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
