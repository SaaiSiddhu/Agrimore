# Seller redesign — verification report

Phase **SELLER-REDESIGN-1**. Every result below is from a command run in this session; nothing is carried
over from memory or documents. "Simulated" means a test double stood in for an external service and the
real service was **not** exercised.

## Baseline (before any change) — branch at `ab600a5` (= develop `358d3da` + claim row)

Command: `bash .claude/skills/agrimore/scripts/gate.sh --full` (logs `/tmp/sredesign-gate-baseline/`),
then `cd apps/seller && flutter test`.

| Check | Result |
|---|---|
| functions:build | exit 0 |
| analyze marketplace | 0 errors · 141 warnings · 322 infos |
| analyze admin | 0 errors · 88 warnings · 532 infos |
| analyze seller | 0 errors · 0 warnings · 21 infos |
| analyze delivery | 0 errors · 0 warnings · 20 infos |
| analyze employee | 0 errors · 2 warnings · 0 infos |
| guards (client-secrets, secret-bindings, fee-truthfulness, deploy-bundle, delivery-states) | all exit 0 |
| canon seller / employee / delivery (ratchet) | exit 0 (seller 0 literals) |
| ledger validator | 2 warnings (ambient: branches of concurrent phases not yet on develop) |
| tests: marketplace, agrimore_ui, employee, agrimore_core, delivery, admin, core-web | all exit 0 |
| seller `flutter test` | 217 passed, 0 failed |

## Tooling available on this machine

| Tool | State |
|---|---|
| Flutter | 3.44.8 stable, Dart 3.12.2 |
| Android | SDK present, AVD `Pixel_8_API_35` (API 35) running as `emulator-5554` |
| iOS | **Not available**: `xcode-select -p` → `/Library/Developer/CommandLineTools`; `xcodebuild` requires Xcode; no `simctl`. |
| JDK 21 (Firebase emulators) | `/opt/homebrew/opt/openjdk@21` (hazards.md) — to be confirmed when the emulators start |

## Results after the redesign — branch at `9addff9`

Command: `bash .claude/skills/agrimore/scripts/gate.sh --full` (run 20260924-165041), `failed=0`.

| Check | Result |
|---|---|
| functions:build | exit 0 |
| analyze marketplace / admin / delivery / employee | 0 errors each (warnings/infos unchanged from baseline: 141/322 · 88/532 · 0/20 · 2/0) |
| analyze seller | **0 errors · 0 warnings · 0 infos** (baseline had 21 infos) |
| guards (client-secrets, secret-bindings, fee-truthfulness, deploy-bundle, delivery-states) | all exit 0 |
| canon seller / employee / delivery | exit 0; `canon_check.sh --count apps/seller/lib` TOTAL 0 |
| ledger validator | 1 warning, ambient (another session's branch `agrimore/dlv3d-status-lock`) |
| tests: marketplace, agrimore_ui, employee, agrimore_core, delivery, admin, core-web | all exit 0 |
| seller `flutter test` | **310 passed, 0 failed** (baseline 217), rerun after restoring the committed `pubspec.lock` (below) |

The shared packages (`packages/**`) are not modified by this phase (D0), so the other four apps are
untouched; their analyze counts match the baseline exactly.

### Revert-and-watch

- Selected-card focus width: reverting the fix made its focus test fail; restoring it made it pass.
- The device tour's three findings (below) were each seen failing on the device screenshot before the fix
  and passing after.

## Android device — `emulator-5554`, AVD Pixel_8_API_35 (API 35), 1080×2400

`flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screens_tour_test.dart -d emulator-5554`
→ "All tests passed". 18 screenshots in `evidence/android/`: Home light, dark and 200 % text; Orders light
and dark; order detail; Catalogue; product editor; Payments; quotes inbox and detail; Insights; Account
light and dark; Settings; Help; application step 1; application status. Every screenshot was inspected.

The data is illustrative TEST fixtures (`test/support/seller_fixtures.dart`), with no Firebase and no network.
The app renders under the real Android engine, fonts and GPU.

First run found, and the rerun confirmed fixed:

1. The Home greeting was cut off in the root app bar ("Good afternoo…") → the greeting now sits in the
   page and wraps. Home uses an actions-only bar (`SellerAppBar.actionsOnly`).
2. The "Catalogue" nav label wrapped mid-word → labels are one line, `labelSmall`, and follow text size up
   to 130 % (like the system bars). The full name is always in semantics.
3. The Orders preview provider called Firestore and showed an error whose retry read "Check status" →
   the preview never loads, and every list error retries with "Try again".

The emulator's system font scale is 1.5; the tour sets the text scale explicitly per shot (1.0, and 2.0
for shot 03).

## iOS — BLOCKED

- The scaffold was created at `apps/seller/ios` (`9addff9`):
  - bundle `com.agrimore.seller`, deployment target 13.0;
  - usage strings for camera, photo library and location when in use;
  - `LSApplicationQueriesSchemes` tel/sms/https/mailto, needed by `canLaunchUrl`.
- `plutil -lint` passes.
- `flutter create` re-resolved `apps/seller/pubspec.lock` (226 lines, version bumps). I did not intend
  that, so the committed lockfile was written back. `flutter pub get --enforce-lockfile` passes, and the
  seller analyze and tests above were rerun on it.
- Build and run: **not done**, for two reasons:
  - `xcodebuild` is unavailable (Command Line Tools only);
  - the shared `DefaultFirebaseOptions.ios` in `packages/agrimore_core/lib/config/firebase_options.dart`
    targets the marketplace bundle, not `com.agrimore.seller`. A seller iOS build that signs in needs a
    Firebase iOS app registered for this bundle. That is an owner action on the live project, and was
    not taken.
- Nothing in `evidence/ios/`.

## SELLER-WALLET-1 — end to end (2026-09-24)

**Environment.**
- Android emulator `emulator-5554` running the real app (`integration_test/wallet_journey_test.dart`,
  `USE_FIREBASE_EMULATOR=true`).
- Local Auth, Firestore, Functions and Storage emulators, started with an empty Firebase CLI config.
  The log says "not currently authenticated", so the emulated functions hold no live credentials.
- TEST data only (`functions/scripts/e2e/seller_wallet_seed.js`, refuses non-local hosts).
- The admin played by `functions/scripts/e2e/seller_wallet_admin_actor.js` through the same callables the
  admin Seller Payouts screen calls.

**Result: PASSED** — "All tests passed", 10 screenshots `evidence/android/e2e_*.png`, all inspected.

| Step | Evidence |
|---|---|
| Two orders delivered, and the real `calculateSellerPayout` trigger writes 2 payouts (₹940 gross, 5 %, **₹893 net**) | seed output |
| Seller signs in (email, Auth emulator) → Payments shows ₹893 | e2e_02, e2e_03 |
| Seller adds a UPI ID → "New details waiting for review", Withdraw blocked | e2e_04, e2e_05 |
| Admin `reviewSellerPayoutChange` → 200 approved; the phone updates by itself, Withdraw returns | e2e_06 |
| Seller withdraws ₹893 (2 orders) → open withdrawal | e2e_07, e2e_08 |
| Admin `markSellerWithdrawalPaid` (UTR, UPI) → 200; withdrawal and both payouts `paid`; seller notified "Withdrawal paid" | actor output, e2e_09 |
| Followers & posts: 3 followers, +3 in 30 days, the seeded post | e2e_10 |

**What the device run found, all fixed and re-run:**
1. Android blocked cleartext to the emulators → debug-only network config.
2. The seller's real FCM token was saved into emulator data, so the approval tried live FCM (60 s
   hang; isolation held, no call succeeded) → no push registration in emulator runs.
3. After approval the wallet kept its stale "change pending" block → it re-reads (test
   revert-and-watched).
4. `rollupSellerStats` crashed under the emulator (`admin.firestore.Timestamp`) → modular imports.
5. At the emulator's 150 % font: nav labels truncated, "September" broke mid-word, and the ribbon was
   narrow → fixed.

Emulator suites:
- `phaseSWALLET1_wallet_test` 13/13;
- `phaseSWALLET1_rules_test` 21/21;
- `phaseSHOME1_stats`, `SHOME1B_notify`, `SMONEY1_payout_rules`, `phase47_seller_follow`, `SDEL1`, `phase26`,
  `phase28`, `phase44`, `phase48` all exit 0.

Gate `--full` at `d24cc87`: failed=0.

**Not covered by the device run:** the admin app's own screens were not driven in a browser. They are
covered by widget/helper tests (`apps/admin/test/seller_wallet_admin_test.dart`), and their callables
were exercised over HTTP above.

## Journeys (brief §15) — sign-in/onboarding journeys still NOT EXECUTED against a backend

| # | Journey | How | Result |
|---|---|---|---|
| 1–25 | Sign-in → onboarding → orders → catalogue → payments → quotes → account | — | **NOT RUN.** The isolated-emulator switch (D13) is not built, and the OTP sign-in path is frozen by the owner (D16). No run touched `agrimore-66a4e`. |
| — | Per-screen behaviour (accept/reject, stock save, bulk publish, counter/decline, schedule save, discard guard, error/retry, …) | Widget tests with test doubles, which are **simulated** | 310/310 pass |
| — | Visual render of every screen on a real device | Device tour (above) | 18/18 pass, inspected |

## Open items

- D17: mock OTP in production. Not built; it needs the owner's decision (an account-takeover risk).
- Journeys against the Firebase emulators (D13), then brief §15 journeys 1–25.
- iOS build and run (Xcode, plus a Firebase iOS app for `com.agrimore.seller`).
- A manual TalkBack / VoiceOver pass.
