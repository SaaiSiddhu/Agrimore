// ADMR-23 source-shape regression guard. Same rationale as ADMR-6/7/22's own
// guards: OffersScreen is wired through CouponProvider, which is directly
// wired to FirebaseFirestore.instance with no injectable seam, so a real
// widget-pump test would need Firebase initialized in the test binary, which
// this project does not set up. This asserts the committed source directly.
//
// The bug this guards against: two independent problems in the same screen.
// (1) "Apply" only ever set a local widget field (`_appliedCode`), never read
// by checkout, lost the instant the screen closed -- a fake success signal.
// (2) the screen fetched `coupons` documents directly and read field names
// that do not exist on the real coupon schema (minOrder/maxUses/expiry
// instead of minOrderAmount/usageLimit/validTo), so a real, admin-created
// coupon (via the live apps/admin/lib/screens/admin/coupon/** flow) always
// rendered "Min ₹0", "Expires N/A" and a unit-less discount number.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-23 offers screen real coupon schema + real apply guard', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/user/offers/offers_screen.dart',
      ).readAsString();
    });

    test('no longer fetches coupons directly from Firestore, or holds a fake local applied-code field', () {
      expect(source.contains("collection('coupons')"), isFalse,
          reason: 'this screen must source coupons from CouponProvider.availableCoupons '
              '(already parsed + pre-filtered to valid coupons), not a separate, '
              'unfiltered raw Firestore query.');
      expect(source.contains('_appliedCode'), isFalse,
          reason: 'the fake local applied-code field is back -- "Apply" must call the '
              'real CouponProvider.applyCoupon(), not set local widget state nothing '
              'else ever reads.');
    });

    test('calls the real CouponProvider fetch and apply methods', () {
      expect(source.contains('fetchAvailableCoupons'), isTrue,
          reason: 'must fetch via the real, shared CouponProvider, matching '
              'coupon_selection_screen.dart\'s own established pattern.');
      expect(source.contains('.applyCoupon('), isTrue,
          reason: '"Apply" must call the real CouponProvider.applyCoupon(coupon) so the '
              'coupon is genuinely usable at checkout, not a no-op.');
    });

    test('reads the real CouponModel field names, not the old mismatched ones', () {
      for (final realField in ['minOrderAmount', 'usageLimit', 'validTo']) {
        expect(source.contains(realField), isTrue,
            reason: '"$realField" is the real CouponModel field this screen must read.');
      }
      for (final wrongField in ["coupon['minOrder']", "coupon['maxUses']", "coupon['expiry']"]) {
        expect(source.contains(wrongField), isFalse,
            reason: '"$wrongField" does not exist on the real coupon schema -- reading it '
                'always returns null and silently shows a wrong default.');
      }
    });

    test('formats the discount label by the real coupon type, not a bare number', () {
      for (final type in ['CouponType.percentage', 'CouponType.flat', 'CouponType.buyOneGetOne']) {
        expect(source.contains(type), isTrue,
            reason: 'the discount label must branch on $type, matching the real schema '
                '(a plain number needs the type to know whether to show ₹ or %).');
      }
    });
  });
}
