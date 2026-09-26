// ADMR-9 — rewards management screen config truthfulness.
//
// PROBLEM, confirmed by reading the backend directly: rewards_management_
// screen.dart's "Scratch Card Distribution" section wrote scratchMinOrder/
// scratchWinProbability/scratchMaxReward to settings/rewards, but grepped
// fresh across functions/src/** and apps/**: zero consumers of those field
// names anywhere. scratchCards/{cardId} is admin-seeded only per
// firestore.rules, and claimScratchCard.ts only ever claims an
// already-existing card — nothing in this codebase creates one, so this
// config has never had any effect. Separately, the "Referral Bonus
// Structure" section wrote referrerCoins/refereeCoins to the SAME
// settings/rewards document — but functions/src/customer/wallet.ts's
// applyReferralCode reads referrerBonus/referredBonus from a DIFFERENT
// document, settings/wallet_config, which already has its own correct,
// working editor at Settings > Wallet Settings
// (wallet_config_screen.dart). Editing this screen's referral sliders had
// zero effect on real referral bonuses while looking exactly like it
// worked — a full, silent duplicate of a feature that already existed
// correctly elsewhere under different names.
//
// FIX: removed the referral section entirely (a working editor for the
// same value already exists) and left a short pointer to it; kept the
// scratch-card sliders (some value in documenting the intended numbers even
// though nothing reads them yet) but added an honest banner saying so,
// rather than silently implying a working "X% of orders over ₹Y win a
// card" mechanic that does not exist. This project has no Firebase-mocking
// test setup (RewardsManagementScreen's own `FirebaseFirestore.instance`
// field initializer would crash construction outside a real Firebase app),
// so — matching this repo's other Firebase-free guards — this test asserts
// the committed source directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-9 rewards config truthfulness guards', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/admin/rewards/rewards_management_screen.dart',
      ).readAsString();
    });

    test('the non-functional referral-bonus duplicate is gone', () {
      for (final needle in [
        '_referrerCoins',
        '_refereeCoins',
        'referrerCoins',
        'refereeCoins',
        '_buildNumberTile',
        'Referral Bonus Structure',
      ]) {
        expect(
          source.contains(needle),
          isFalse,
          reason: '"$needle" is back in rewards_management_screen.dart — '
              'this was a full duplicate of Settings > Wallet Settings '
              '(wallet_config_screen.dart), writing to settings/rewards '
              'while wallet.ts reads settings/wallet_config with different '
              'field names (referrerBonus/referredBonus). Editing it here '
              'silently did nothing to real referral bonuses. If a '
              'referral control returns to this screen, it must write the '
              'SAME document and field names the backend actually reads, '
              'not a shadow copy.',
        );
      }
    });

    test('the screen now points admins at the real referral bonus editor '
        'instead of silently offering nothing in its place', () {
      expect(
        source.contains('Wallet Settings'),
        isTrue,
        reason: 'the pointer to the real referral-bonus screen '
            '(Settings > Wallet Settings) is missing — an admin who '
            'remembers the old section here should still be able to find '
            'where referral bonuses actually live.',
      );
    });

    test('scratch-card config still exists but now discloses it has no '
        'live consumer, instead of implying a working mechanic', () {
      for (final needle in [
        'scratchMinOrder',
        'scratchWinProbability',
        'scratchMaxReward',
      ]) {
        expect(source.contains(needle), isTrue,
            reason: '"$needle" was removed — this phase kept the '
                'scratch-card sliders (some value in documenting the '
                'intended numbers) and only added a disclosure banner; it '
                'did not remove the fields themselves.');
      }
      expect(
        source.contains('Not yet connected to live behaviour'),
        isTrue,
        reason: 'the scratch-card section no longer discloses that no '
            'automated issuance process exists — an admin adjusting these '
            'sliders again has no way to know saving them changes nothing '
            'live.',
      );
    });
  });
}
