// ADMR-7 source-shape regression guards. Same rationale as ADMR-6's own
// guard (admr6_checkout_wallet_truthfulness_guard_test.dart) and PERF-2's
// before it: mobile_cart_screen.dart is wired directly to
// FirebaseAuth/Firestore/RazorpayService with no injectable seams, so a real
// widget-pump test would need Firebase initialized in the test binary, which
// this project does not set up. These assert the committed source directly.
//
// Two bugs of the same shape, both guarded here:
//
// 1. Wallet: toggling "use wallet balance" recomputed a locally-discounted
//    `finalTotal` and showed IT as the Grand Total — but the actual Razorpay
//    charge (`_buildBlinkitBottomBar`'s call site) deliberately ADDED THE
//    DISCOUNT BACK before charging, so the customer saw a lower total than
//    they were then charged.
// 2. Tip: choosing a delivery-partner tip added it to the displayed Grand
//    Total ("Includes ₹X tip") — but `_selectedTipAmount` was never sent to
//    createOrder, never stored on the order, and never reached the actual
//    Razorpay charge, so the customer saw a HIGHER total than they were then
//    charged, and the tip was never collected or paid to anyone.
//
// Both are removed rather than wired up for real, since a real
// implementation needs undecided product policy (wallet stacking/limits, or
// a real tip-to-rider payment path) that this phase does not invent.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-7 cart wallet/tip truthfulness guards', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/user/cart/mobile_cart_screen.dart',
      ).readAsString();
    });

    test('no wallet toggle state or its dedicated section survive', () {
      for (final needle in [
        '_useWalletBalance',
        '_buildWalletSection',
        'walletDiscount',
      ]) {
        expect(
          source.contains(needle),
          isFalse,
          reason: '"$needle" is back in mobile_cart_screen.dart — this is '
              'part of the non-functional wallet checkout discount removed '
              'by ADMR-7. The actual Razorpay charge and the order write '
              'never applied this discount; only the display did. A real '
              'redemption feature must change the SAME total used for the '
              'actual charge, not a shadow variable used for display only.',
        );
      }
    });

    test('no tip toggle state or its selector UI survive', () {
      for (final needle in [
        '_selectedTipAmount',
        '_buildTipSection',
        '_buildTipButton',
        '_buildCustomTipButton',
        '_showCustomTipDialog',
        '_buildQuickTipChip',
      ]) {
        expect(
          source.contains(needle),
          isFalse,
          reason: '"$needle" is back in mobile_cart_screen.dart — this is '
              'part of the non-functional delivery-partner tip feature '
              'removed by ADMR-7. The tip was shown added to the Grand '
              'Total but was never sent to createOrder, never stored on '
              'the order, never charged, and never reached a rider. A real '
              'tip feature needs a real payment/payout path, not a '
              'display-only addition.',
        );
      }
    });

    test('WalletProvider is no longer imported into this screen', () {
      expect(
        source.contains('providers/wallet_provider.dart'),
        isFalse,
        reason: 'mobile_cart_screen.dart still imports WalletProvider — the '
            'only prior use (the wallet discount toggle) was removed by '
            'ADMR-7; a new import here means something new is reading '
            'wallet state and this guard should be re-examined, not just '
            'deleted.',
      );
    });

    test(
      'the bottom bar charges pricingData[finalTotal] directly, with no '
      'discount-cancelling addition',
      () {
        final callSite = source.indexOf('_buildBlinkitBottomBar(');
        expect(callSite, greaterThan(-1),
            reason: '_buildBlinkitBottomBar call site not found — has the '
                'sticky bottom bar been restructured?');
        final nextCloseParen = source.indexOf(');', callSite);
        final args = source.substring(callSite, nextCloseParen);
        expect(
          args.contains('walletDiscount'),
          isFalse,
          reason: 'the _buildBlinkitBottomBar call site still references '
              'walletDiscount — before ADMR-7 this call deliberately ADDED '
              'the wallet discount back to cancel out the display-side '
              'subtraction. If a wallet discount concept returns, the '
              'charge and the display must use the exact same number.',
        );
        expect(
          args.contains("pricingData['finalTotal']"),
          isTrue,
          reason: 'the bottom bar (and therefore the actual Razorpay '
              "charge) no longer visibly traces to pricingData['finalTotal'] "
              '— confirm what it charges now is still the single, '
              'undiscounted total _calculateAdvancedPricing computes.',
        );
      },
    );

    test(
      '_calculateAdvancedPricing returns no walletDiscount key and '
      'finalTotal has no wallet subtraction',
      () {
        final fnStart =
            source.indexOf('Map<String, double> _calculateAdvancedPricing(');
        expect(fnStart, greaterThan(-1),
            reason: '_calculateAdvancedPricing not found — has it moved or '
                'been renamed?');
        final fnEnd = source.indexOf('\n  }', fnStart);
        final body = source.substring(fnStart, fnEnd);
        expect(
          body.contains('walletDiscount'),
          isFalse,
          reason: '_calculateAdvancedPricing still computes/returns '
              'walletDiscount — this pricing map feeds both the display '
              'and (via finalTotal) the actual charge, so a wallet term '
              'here must not silently diverge from what is charged again.',
        );
      },
    );
  });
}
