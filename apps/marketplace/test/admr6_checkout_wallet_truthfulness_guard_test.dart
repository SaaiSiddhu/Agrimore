// ADMR-6 source-shape regression guards. Same rationale as PERF-2's own
// guards in perf2_guards_test.dart: PaymentMethodScreen is wired directly to
// FirebaseAuth/Firestore/RazorpayService with no injectable seams, so a real
// widget-pump test would need Firebase initialized in the test binary, which
// this project does not set up. These assert the committed source directly.
//
// The bug this guards against: the screen let a customer toggle "use wallet
// balance" / "use coins", which recomputed a locally-discounted
// `finalAmount` and displayed it as the order's Total Amount — but the
// actual charge (`_razorpayService.openCheckout(amount: finalTotal, ...)`)
// and the actual order write (`_createOrder` -> `_createSellerScopedOrders`)
// both independently called `cartProvider.calculateTotal(discount:,
// deliveryCharge:, tax:)`, a method with no wallet/coins parameter at all —
// so the wallet/coins toggle never touched the amount actually charged or
// recorded. A customer could see a lower "Total Amount" than they were then
// charged. The fix removes the dead-end UI rather than fabricate a
// redemption feature (stacking/limits/ledger effects are undecided product
// policy, out of scope to invent).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-6 checkout wallet/coins truthfulness guards', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/user/checkout/payment_method_screen.dart',
      ).readAsString();
    });

    test('no wallet/coins toggle state survives in this screen', () {
      for (final needle in [
        '_useWalletBalance',
        '_useCoins',
        '_coinsToUse',
        '_buildWalletSection',
      ]) {
        expect(
          source.contains(needle),
          isFalse,
          reason:
              '"$needle" is back in payment_method_screen.dart — this is '
              'part of the non-functional wallet/coins checkout discount '
              'UI removed by ADMR-6. If a real redemption feature is being '
              'reintroduced, it must actually change the Razorpay charge '
              'amount and the order write, not just the display.',
        );
      }
    });

    test('WalletProvider is no longer imported into this screen', () {
      expect(
        source.contains("providers/wallet_provider.dart"),
        isFalse,
        reason:
            'payment_method_screen.dart still imports WalletProvider — the '
            'only prior use (the wallet/coins discount toggle) was removed '
            'by ADMR-6; a new import here means something new is reading '
            'wallet state and this guard should be re-examined, not just '
            'deleted.',
      );
    });

    test(
      'the bottom bar and order summary are driven by the single, real '
      'total — no second, discount-shadowing amount variable',
      () {
        for (final needle in ['walletDiscount', 'finalAmount']) {
          expect(
            source.contains(needle),
            isFalse,
            reason:
                '"$needle" is back in payment_method_screen.dart. Before '
                'ADMR-6, this screen computed a locally-discounted amount '
                'and displayed IT as the Total Amount while the actual '
                'Razorpay charge and order write used the undiscounted '
                '`cartProvider.calculateTotal(...)` — the displayed price '
                'and the charged price silently diverged. Any reintroduced '
                'discount must flow into the SAME total used for the '
                'actual charge, not a shadow variable used for display '
                'only.',
          );
        }
      },
    );

    test(
      'the actual charge still comes from cartProvider.calculateTotal, '
      'never from a wallet-aware computation',
      () {
        final openCheckoutIndex = source.indexOf('.openCheckout(');
        expect(openCheckoutIndex, greaterThan(-1),
            reason: 'openCheckout call not found — has the Razorpay launch '
                'site moved or been renamed?');
        final amountLineEnd = source.indexOf(',', openCheckoutIndex);
        final nearby = source.substring(
          openCheckoutIndex,
          amountLineEnd > openCheckoutIndex ? amountLineEnd + 40 : openCheckoutIndex + 200,
        );
        expect(
          nearby.contains('finalTotal'),
          isTrue,
          reason:
              'openCheckout is no longer charging `finalTotal` — confirm '
              'what it charges now still traces back to '
              'cartProvider.calculateTotal(...), the same total the '
              'displayed price must equal.',
        );
      },
    );
  });
}
