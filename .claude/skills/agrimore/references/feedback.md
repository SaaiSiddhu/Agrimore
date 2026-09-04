# `feedback` lane — every message a user sees (binding whenever anything renders one)

**Fires when** a change touches any user-visible surface: a screen, dialog, snackbar, toast, banner,
empty/error/loading state, or copy in `packages/agrimore_ui`. A checkout phase, a wallet phase and an
admin phase all qualify the moment they render a message. Authority order for a UI change: this file
(what to use, never re-implement) → `uiux.md` (theme and widgets) → the phase's own workstreams.

**Honest scope (measured 2026-09-04 at `c8f6f30`).** Agrimore has a canonical helper layer but no
localisation system (0 `.arb` files; `easy_localization` is declared by `apps/admin` and used by 0
files) and no design constitution. Adoption is mixed: raw `showSnackBar(` vs `SnackbarHelper.` per app
— marketplace 126 / 3 · admin 47 / 122 · seller 4 / 16 · delivery 7 / 4 · employee 12 / 0 (it uses
`DialogHelper` once). This lane does not demand a rewrite of that history; it forbids **new**
divergence and **any** new duplicated helper.

## 1. Never build a new one — the canonical surfaces exist

```
packages/agrimore_ui/lib/widgets/snackbar_helper.dart      SnackbarHelper.showSuccess · showError · showWarning · showInfo · showCustom
                                                            · showWithAction · showLoading · hide · clearAll
packages/agrimore_ui/lib/widgets/dialog_helper.dart        DialogHelper.showConfirmation · showDeleteConfirmation · showInfo · showError
                                                            · showSuccess · showLoading · hideLoading · showInput · showChoice · showBottomSheet
packages/agrimore_ui/lib/widgets/common/confirmation_dialog.dart   ConfirmationDialog
packages/agrimore_ui/lib/widgets/common/empty_state_widget.dart    EmptyStateWidget
packages/agrimore_ui/lib/widgets/common/error_view.dart · error_widget.dart   read-failed states
packages/agrimore_ui/lib/widgets/common/loading_indicator.dart · loading_overlay.dart · shimmer_loading.dart
packages/agrimore_ui/lib/widgets/common/network_image_widget.dart   NetworkImageWidget (data-URI safe; never CachedNetworkImage directly)
apps/marketplace/lib/screens/employee/onboarding/onboarding_fee_text.dart   authoritativeFeeText — the ONE fee formatter
```

Success → `SnackbarHelper.showSuccess`. Failure of an action → `SnackbarHelper.showError` with a
user-safe sentence. Read failed → `ErrorView`. Nothing to show → `EmptyStateWidget`. Destructive →
`DialogHelper.showDeleteConfirmation` / `ConfirmationDialog`, then a snackbar. Long operation →
`DialogHelper.showLoading` + `hideLoading` in `finally`. A snackbar fired during navigation is torn
down — show it on the destination screen.

## 2. Copy rules (no localisation layer exists — do not invent one)

- Never render `e.toString()`, `error.message`, an `HttpsError` message verbatim, a Firestore
  permission string, or a stack trace. Map to a user-safe sentence; log the detail with
  `debugPrint`/Crashlytics (`apps/marketplace` only has Crashlytics).
- Never claim a state the server did not confirm ("Payment successful" only after
  `verifyRazorpayPayment` returned `verified:true`; "Order placed" only after `createOrder` returned).
- **Money-adjacent copy is regulated.** The associate onboarding page (`apps/marketplace/lib/screens/
  employee/onboarding/*`) renders the fee via `authoritativeFeeText` only, and its **mobile branch
  wording is a Play-policy surface** (external payment steering) — never reword it without a fresh
  Play assessment (`decisions.md` §3). Benefit-program surfaces never use *guarantee · interest ·
  invest · return · deposit · maturity · principal · profit · yield · assured*
  (`findProhibitedClaims` in `functions/src/employee/onboardingConfig.ts` is the server-side scanner;
  the client mirrors it by grep). "Product Credit" is *redeemable towards AgriMore products*, never a
  "balance".
- User-facing term is **"Sales Associate"**, never "Employee" (internal identifiers stay `employee`).
- Rupee amounts through `price_formatter.dart` (`packages/agrimore_core/lib/utils/`), never string
  concatenation with a hardcoded symbol in a new file.
- Every string is English and hardcoded today; keep sentence case, no exclamation-mark stacking, no
  emoji in production copy (the codebase's `debugPrint`s have emoji — those are logs, not UI).

## 3. Colour of feedback

Use `AppColors` from `packages/agrimore_ui/lib/themes/app_colors.dart` (primary `0xFF0D9B5C`
Emerald) — check it for the named success/error/warning colour before writing a literal. Hardcoded
`Color(0x…)` literals exist in 96 / 33 / 9 / 1 / 6 files (marketplace / admin / seller / delivery /
employee) — ambient, not a licence. A new status colour literal in a feedback surface is a finding.
Dark mode: every app declares `darkTheme`; a feedback colour must read on both.

## 4. What the lane checks (by command, not by reading)

```bash
git diff --name-only <base>..HEAD | grep -E '\.dart$'                                   # surfaces touched
git diff <base>..HEAD -- '*.dart' | grep -nE '^\+.*(showSnackBar\(|showDialog\(|AlertDialog\()'   # new raw surfaces → justify or replace
git diff <base>..HEAD -- '*.dart' | grep -nE '^\+.*(\.toString\(\)|e\.message|error\.message)' | grep -iE 'snack|dialog|text\('   # leaked errors
git diff <base>..HEAD -- '*.dart' | grep -nE '^\+.*Color\(0x'                            # new colour literals in feedback code
git diff <base>..HEAD -- 'apps/marketplace/lib/screens/employee/onboarding/*' | grep -nE '^\+.*(₹|Rs\.|500)'   # fee literals → must be authoritativeFeeText
grep -rnE 'guarantee|interest|invest|deposit|maturity|principal|profit|yield|assured' <new benefit-program files>   # must be 0
```

## 5. Lane report

```
FEEDBACK LANE — <phase>
Verdict: PASS | PASS_WITH_FINDINGS | BLOCKING
Surfaces touched: path · surface kind · canonical helper used (or the documented screen-local pattern it follows)
Copy: leaked error strings (count, path:line) · Play-sensitive or regulated copy touched (yes/no, diff) · term "Sales Associate" respected
Colour: new literals in feedback code (path:line)
Evidence: what was rendered (AVD / web preview) and what could not be (AuthGuard screens without a real login)
Findings: severity · path:line · rule (§1–§4) · fix
```

`BLOCKING` = a new snackbar/dialog helper duplicating `SnackbarHelper`/`DialogHelper`, a rendered raw
error/stack string, a reworded Play-sensitive or regulated money surface without the owner's word, a
success message shown before the server confirmed, a fee literal outside `authoritativeFeeText`.
