import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:seller/app/emulator.dart';
import 'package:seller/main.dart' as app;

/// SELLER-WALLET-1 end-to-end on a real Android device against the LOCAL
/// Firebase emulators (decision D13) — never the live project:
///
///   sign in (email, Auth emulator) → Payments shows the balance the real
///   payout trigger wrote → add a UPI ID → [admin approves] → withdraw →
///   [admin pays with a UTR] → the phone shows it paid → Followers & posts.
///
/// The admin steps are functions/scripts/e2e/seller_wallet_admin_actor.js,
/// calling the same callables the admin app's Seller Payouts screen calls.
/// Data comes from functions/scripts/e2e/seller_wallet_seed.js (TEST data).
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/wallet_journey_test.dart -d emulator-5554 \
///     --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var converted = false;

  Future<void> pumpUntil(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 90), String? why}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for ${why ?? f}');
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 400));
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await tester.pump();
    await binding.takeScreenshot('e2e_$name');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await pumpUntil(tester, f, why: '"$text"');
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('seller wallet journey against the emulators', (tester) async {
    expect(kSellerUsesEmulator, isTrue, reason: 'run with --dart-define=USE_FIREBASE_EMULATOR=true — never against the live project');
    app.main();
    await pumpUntil(tester, find.text('Sign in with email instead'), why: 'sign-in screen');
    await shot(tester, '01_sign_in');

    await tapText(tester, 'Sign in with email instead');
    await pumpUntil(tester, find.text('Email address'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'e2e-seller@example.com');
    await tester.enterText(fields.at(1), 'e2e-pass-123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntil(tester, find.text('Payments'), why: 'the seller shell');
    await shot(tester, '02_home');

    await tapText(tester, 'Payments');
    await pumpUntil(tester, find.text('Wallet balance'));
    await pumpUntil(tester, find.textContaining('Withdraw ₹'), why: 'the balance from the payout trigger');
    await shot(tester, '03_wallet');

    // Add a UPI ID — sent for an admin to verify.
    await tapText(tester, 'Change');
    await pumpUntil(tester, find.text('Change payout account'));
    await tapText(tester, 'UPI ID');
    await tester.enterText(find.byType(TextField).first, 'kaveri.test@okbank');
    await tester.pump();
    await shot(tester, '04_upi_form');
    await tapText(tester, 'Send for verification');
    await pumpUntil(tester, find.text('New details waiting for review'), why: 'the pending change');
    await shot(tester, '05_change_pending');

    // The admin actor approves: the pending banner goes, the UPI is on file
    // and Withdraw comes back by itself (the wallet re-reads its balance).
    final end = DateTime.now().add(const Duration(minutes: 3));
    while (find.text('New details waiting for review').evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('New details waiting for review'), findsNothing, reason: 'the admin approved the change');
    await pumpUntil(tester, find.textContaining('UPI ·'), why: 'the approved UPI on file');
    await pumpUntil(tester, find.textContaining('Withdraw ₹'), why: 'Withdraw enabled after approval');
    await shot(tester, '06_change_approved');

    // Withdraw.
    await tester.ensureVisible(find.textContaining('Withdraw ₹').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('Withdraw ₹').last);
    await pumpUntil(tester, find.widgetWithText(FilledButton, 'Withdraw'), why: 'the confirmation');
    await shot(tester, '07_withdraw_confirm');
    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
    await pumpUntil(tester, find.text('Cancel withdrawal'), why: 'the open withdrawal');
    await shot(tester, '08_withdrawal_requested');

    // The admin actor pays it with a UTR.
    await pumpUntil(tester, find.textContaining('Ref UTRTEST123456'), timeout: const Duration(minutes: 3), why: 'the paid withdrawal');
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, '09_withdrawal_paid');

    // Followers & posts (count + the seeded post).
    await tapText(tester, 'Account');
    await tapText(tester, 'Followers & posts');
    await pumpUntil(tester, find.text('Fresh tomatoes in today (TEST)'), why: 'the seeded post');
    await pumpUntil(tester, find.text('3'), why: 'the follower count');
    await shot(tester, '10_followers');
    expect(tester.takeException(), isNull);
  });
}
