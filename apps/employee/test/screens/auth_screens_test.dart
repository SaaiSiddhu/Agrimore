import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart';
import 'package:employee/providers/auth_provider.dart';
import 'package:employee/screens/auth/login_screen.dart';
import 'package:employee/screens/auth/associate_otp_screen.dart';
import 'package:employee/screens/auth/pending_approval_screen.dart';
import 'package:employee/screens/auth/suspended_screen.dart';
import 'package:employee/screens/auth/forgot_password_screen.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Auth Screens — Canonical Design System Verification', () {
    testWidgets('LoginScreen renders phone/email segmented tabs and validates phone input', (tester) async {
      final authProvider = EmployeeAuthProvider();

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: ChangeNotifierProvider<EmployeeAuthProvider>.value(
            value: authProvider,
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify branding and titles
      expect(find.text('AgriMore'), findsOneWidget);
      expect(find.text('Sales Associate Portal'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Verify segmented mode options
      expect(find.text('Mobile number'), findsNWidgets(2)); // Tab + input label
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);

      // Validate 10-digit phone requirement
      final phoneField = find.byType(TextFormField).first;
      await tester.enterText(phoneField, '98765');
      await tester.pump();

      await tester.tap(find.text('Send code'));
      await tester.pump();

      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

      // Enter valid number
      await tester.enterText(phoneField, '9876543210');
      await tester.pump();

      // Switch to Email tab
      await tester.tap(find.text('Email'));
      await tester.pump();

      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('AssociateOtpScreen renders 6-digit matrix and formatted masked phone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const AssociateOtpScreen(
            phone: '+919876543210',
            channel: 'sms',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Enter verification code'), findsOneWidget);
      expect(find.textContaining('3210'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('EmployeePendingApprovalScreen renders canonical warning state and next steps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const EmployeePendingApprovalScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Application Pending Approval'), findsOneWidget);
      expect(find.text('What happens next?'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('SuspendedScreen renders error state and contact channels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const SuspendedScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.text('Need Assistance?'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders email reset form', (tester) async {
      final authProvider = EmployeeAuthProvider();

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: ChangeNotifierProvider<EmployeeAuthProvider>.value(
            value: authProvider,
            child: const ForgotPasswordScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
    });
  });
}
