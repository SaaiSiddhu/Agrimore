// ADMR-11 — subscription plans truthfulness.
//
// PROBLEM, confirmed by reading both apps directly: apps/admin's
// "Subscriptions Management" screen writes named "Subscription Plans"
// (name/price/durationDays/frequency/isActive) to settings collection
// subscription_plans -- but the actual customer subscription flow
// (apps/marketplace/lib/screens/user/subscriptions/subscription_setup_
// screen.dart) is per-product and ad-hoc: a customer picks one product,
// quantity, frequency and delivery slot, and writes straight to the
// `subscriptions` collection with a `nextRunDate` -- it has never
// referenced subscription_plans at all (grepped fresh across
// functions/src/** and every app: zero matches outside this one admin
// screen). Creating or toggling a plan here has never had any effect on
// what a customer can subscribe to.
//
// The screen also had a fake "Export" button whose onPressed only showed
// a SnackBar reading "Exporting data..." -- no file, no data, nothing.
//
// SEPARATE, MORE SERIOUS, NOT-FIXABLE-HERE FINDING (see this phase's own
// ledger row for the full account, not re-tested here since there is no
// safe way to test code that does not exist): nextRunDate/subscriptions
// are referenced nowhere in functions/src either -- the only plausible
// consumer is `subscriptionChecker`, confirmed via a fresh, live
// `firebase functions:list` to be a currently-deployed SCHEDULED v1
// function on agrimore-66a4e with NO source anywhere in this repository.
//
// This project has no Firebase-mocking test setup
// (SubscriptionManagementScreen's own `FirebaseFirestore.instance` field
// initializer would crash construction outside a real Firebase app), so —
// matching this repo's other Firebase-free guards — this test asserts the
// committed source directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-11 subscription plans truthfulness guards', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/admin/subscriptions/subscription_management_screen.dart',
      ).readAsString();
    });

    test('the fake "Exporting data..." button is gone', () {
      expect(
        source.contains('Exporting data'),
        isFalse,
        reason: 'the Export button\'s fake "Exporting data..." toast is '
            'back — it never generated a file or moved any data. If a '
            'real export is being built, it should replace this guard, '
            'not silently defeat it.',
      );
    });

    test('the Subscription Plans section discloses it is disconnected '
        'from checkout', () {
      expect(
        source.contains('Not yet connected to checkout'),
        isTrue,
        reason: 'the disclosure banner above "Subscription Plans" is '
            'missing — an admin creating or toggling a plan here has no '
            'way to know it has zero effect on what any customer can '
            'subscribe to (the real flow is per-product, in '
            'subscription_setup_screen.dart, apps/marketplace).',
      );
    });

    test('the real subscription stats (reading the actual subscriptions '
        'collection) are untouched', () {
      expect(
        source.contains("collection('subscriptions')"),
        isTrue,
        reason: 'the stats StreamBuilder reading the REAL subscriptions '
            'collection is gone — that part was honest and should not '
            'have been removed by this phase.',
      );
      expect(
        source.contains("collection('subscription_plans')"),
        isTrue,
        reason: 'this phase discloses the Subscription Plans section, it '
            'does not remove it (unlike the wallet/tip fixes elsewhere) — '
            'some admin record-keeping value remains even disconnected.',
      );
    });
  });
}
