// ADMR-22 source-shape regression guard. Same rationale as ADMR-6/PERF-2's own
// guards: RewardsScreen is wired directly to FirebaseAuth/Firestore with no
// injectable seams, so a real widget-pump test would need Firebase
// initialized in the test binary, which this project does not set up for
// apps/marketplace. This asserts the committed source directly.
//
// The bug this guards against: the empty state read "Place an order to win
// scratch cards!" — a causal promise that nothing in the backend keeps.
// Exhaustive grep of functions/src found exactly one file touching
// scratchCards at all: claimScratchCard.ts, the claim/redemption side only
// (real, correctly hardened — Phase FIX-N50). Nothing anywhere creates a
// scratchCards/{cardId} document for any order, ever — the customer-facing
// mirror of ADMR-9's already-fixed admin-side disclosure on the identical
// root cause. The fix removes the false causal claim rather than build the
// (real, undecided) issuance mechanism.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-22 customer scratch card empty-state truthfulness guard', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/user/rewards/rewards_screen.dart',
      ).readAsString();
    });

    test('no longer claims placing an order wins a scratch card', () {
      expect(
        source.contains('Place an order to win scratch cards'),
        isFalse,
        reason:
            'this causal claim is back — nothing anywhere creates a scratchCards '
            'document for any order (confirmed by grepping functions/src: only '
            'claimScratchCard.ts exists, and it only ever claims an ALREADY-existing '
            'card). If automatic issuance is built, this guard should be removed '
            'deliberately once the claim becomes true, not silently reverted.',
      );
    });

    test('the empty state makes no other specific triggering claim', () {
      for (final falseClaim in [
        'order to win',
        'orders unlock',
        'shop to win',
        'purchase to earn',
      ]) {
        expect(
          source.toLowerCase().contains(falseClaim),
          isFalse,
          reason: '"$falseClaim" would be another unfounded causal promise about '
              'how a scratch card is obtained.',
        );
      }
    });

    test('the real claim flow (claimScratchCard callable) is untouched', () {
      expect(source.contains("httpsCallable('claimScratchCard')"), isTrue,
          reason: 'this phase corrects the empty-state copy only; the real, '
              'working claim flow must not be touched.');
      expect(source.contains('scratchCards'), isTrue,
          reason: 'the screen must still stream users/{uid}/scratchCards — '
              'this phase does not remove any real functionality.');
    });
  });
}
