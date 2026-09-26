import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:employee/screens/wallet/payout_request_screen.dart';
import 'package:employee/screens/wallet/payout_account_screen.dart';
import 'package:employee/screens/wallet/payout_review_screen.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Wallet Screens — Canonical Verification', () {
    testWidgets('PayoutRequestScreen validates amount entry against available balance', (tester) async {
      final walletSnap = FakeDocumentSnapshot({'balance': 8500.0});
      final employeeSnap = FakeDocumentSnapshot({
        'payoutMethod': 'bank',
        'accountNumber': '987654321000',
        'bankName': 'SBI',
        'accountHolderName': 'Suresh Kumar',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: PayoutRequestScreen(
            employeeUid: 'test-associate-uid',
            walletStream: Stream.value(walletSnap),
            employeeStream: Stream.value(employeeSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify Title & Balance Header
      expect(find.text('Request Payout'), findsOneWidget);
      expect(find.textContaining('8,500'), findsWidgets);

      // Verify Destination Card
      expect(find.text('SBI'), findsOneWidget);

      // Verify Quick Presets
      expect(find.text('₹1000'), findsOneWidget);
      expect(find.text('₹2500'), findsOneWidget);
      expect(find.text('₹5000'), findsOneWidget);

      // Tap preset ₹2500
      await tester.tap(find.text('₹2500'));
      await tester.pump();
      expect(find.text('2500'), findsOneWidget);

      // Verify Review button is enabled for valid amount
      final buttonFinder = find.byType(SaLoadingButton);
      expect(buttonFinder, findsOneWidget);
      final buttonWidget = tester.widget<SaLoadingButton>(buttonFinder);
      expect(buttonWidget.onPressed, isNotNull);

      // Enter an excessive amount
      final amountField = find.byType(TextFormField);
      await tester.enterText(amountField, '9000');
      await tester.pump();

      // Verify Review button is disabled for excessive amount
      final disabledButton = tester.widget<SaLoadingButton>(buttonFinder);
      expect(disabledButton.onPressed, isNull);
    });

    testWidgets('PayoutAccountScreen renders bank vs UPI form switch', (tester) async {
      final employeeSnap = FakeDocumentSnapshot({
        'payoutMethod': 'bank',
        'accountNumber': '987654321000',
        'bankName': 'SBI',
        'accountHolderName': 'Suresh Kumar',
        'ifscCode': 'SBIN0001234',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: PayoutAccountScreen(
            employeeUid: 'test-associate-uid',
            employeeStream: Stream.value(employeeSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify Title & Type Toggle
      expect(find.text('Payout Account'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);
      expect(find.text('UPI ID'), findsOneWidget);

      // Verify Bank Account fields
      expect(find.text('Account Number'), findsOneWidget);
      expect(find.text('IFSC Code'), findsOneWidget);
      expect(find.text('Bank Name'), findsOneWidget);
      expect(find.text('Save Bank Details'), findsOneWidget);
      expect(find.text('Security Notice'), findsOneWidget);

      // Switch to UPI mode
      await tester.tap(find.text('UPI ID'));
      await tester.pump();

      // Verify UPI fields
      expect(find.text('UPI ID / VPA'), findsOneWidget);
      expect(find.text('Save UPI Details'), findsOneWidget);
    });

    // ADMR-5: while a submitted bank/UPI change is pending review, the
    // associate sees its status instead of the edit form.
    testWidgets('PayoutAccountScreen shows the pending card instead of the form while a change is under review', (tester) async {
      final employeeSnap = FakeDocumentSnapshot({
        'payoutMethod': 'bank',
        'accountNumber': '987654321000',
        'bankName': 'SBI',
        'accountHolderName': 'Suresh Kumar',
        'ifscCode': 'SBIN0001234',
      });
      final walletSnap = FakeDocumentSnapshot({'payoutChangePending': 'req-123'});

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: PayoutAccountScreen(
            employeeUid: 'test-associate-uid',
            employeeStream: Stream.value(employeeSnap),
            walletStream: Stream.value(walletSnap),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The pending card is shown...
      expect(find.text('Change Waiting For Review'), findsOneWidget);
      expect(find.text('Cancel Request'), findsOneWidget);
      // ...and the edit form is not.
      expect(find.text('Save Bank Details'), findsNothing);
      expect(find.text('Bank Account'), findsNothing);
    });

    testWidgets('PayoutReviewScreen renders balance deduction breakdown and destination', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const PayoutReviewScreen(
            requestedAmount: 5000,
            availableBalance: 12500,
            destinationData: {
              'payoutMethod': 'bank',
              'bankName': 'HDFC Bank',
              'accountNumber': '123456789012',
              'accountHolderName': 'Ramesh Kumar',
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Review Payout'), findsOneWidget);
      expect(find.text('Confirm Payout Request'), findsOneWidget);
      expect(find.textContaining('5,000'), findsWidgets);
      expect(find.textContaining('12,500'), findsWidgets);
      expect(find.textContaining('7,500'), findsWidgets); // remaining balance
      expect(find.text('HDFC Bank'), findsOneWidget);
    });
  });
}
