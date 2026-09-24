# Seller redesign — decisions

Phase **SELLER-REDESIGN-1** (branch `agrimore/sredesign1-seller-ui`, claimed at `ab600a5` from `develop` `358d3da`).
Authority order used for every call below: explicit owner corrections → canonical mockups
(`apps/seller/assets/ui-mockups/`, 86 images, all inspected — see `mockup-inspection-notes.md`) →
existing business/security contracts (functions, rules, providers) → platform accessibility.
Tags: `OWNER_DECISION` (quoted from the brief or a recorded owner answer) · `DESIGN_DECISION` (made here,
reversible) · `CONTRACT` (dictated by existing server/rules behaviour) · `DEVIATION` (intentional
difference from a raster concept, with the reason).

## D0 — The seller app has its own design system (OWNER_DECISION 2026-09-24, chat)

Owner, verbatim: *"seller app should be canonical but not to make canonical other apps also,.. seller app
should have its own desgin system , and other apps should have its own system,."*

- The seller's tokens, theme, typography, icons, formatting and components live **inside the seller app**:
  `apps/seller/lib/design_system/` (the seller's "system itself" — the only place in `apps/seller/lib`
  where literal colours/sizes are allowed; `canon_check.sh` skips it like it skips `lib/l10n/`).
- `packages/agrimore_ui` (the shared Workspace system used by the Sales Associate and Delivery apps, plus
  the marketplace/admin themes) is **not modified** by this phase. Edits made to it earlier in this session
  (never committed) were reverted before any commit.
- End state: `apps/seller/lib` imports nothing visual from `agrimore_ui`; the seller keeps using only the
  shared *non-visual* packages (`agrimore_core` models/constants, `agrimore_services` auth/notifications).
- Supersedes, for `apps/seller` only: ADR-S01/S02 (Sales Associate as the canonical system / one Workspace
  theme with two brands), ADR-S06 (shared `AgIcons`), ADR-S07 ("a component may only be created in the
  shared kit") and the uiux lane's "reuse `agrimore_ui` before you build" rule. The zero-literal rule
  (ADR-S04) and every functional/security contract still apply.
- The unused `WorkspaceBrand.seller` constants stay in the shared package (removing them would edit a
  package other active phases are changing); a later clean-up is the owner's call.

## D1 — Seller palette (DESIGN_DECISION from boards 01–03, supersedes ADR §5.1–5.3 for the seller app)

The boards define a seller-specific neutral set (green-tinted, not the Sales Associate slate) and a
black-and-teal dark theme. Implemented as `SellerColors` in `apps/seller/lib/design_system/tokens/`
(D0); no other app's colours change.

| Role | Light | Dark | Source |
|---|---|---|---|
| pageBackground (canvas) | `#F5F8F7` | `#050908` | 02, 03 |
| surface | `#FFFFFF` | `#0B1513` | 02, 03 |
| surfaceElevated (raised) | `#FFFFFF` | `#12221E` | 03 |
| surfaceSunken | `#EDF3F1` | `#08100E` | derived |
| primary | `#0F766E` | `#5EEAD4` | 01–03 |
| onPrimary | `#FFFFFF` | `#042F2E` | 03 |
| primaryPressed (strong) | `#134E4A` | `#2DD4BF` | 02 / derived |
| primaryMuted (mint, selected fills) | `#DDF3EA` | `#134E4A` | 01–03 |
| primarySubtle (tinted cards) | `#EEF8F4` | `#0D2622` | derived |
| textPrimary | `#142D2A` | `#ECFDF5` | 02, 03 |
| textSecondary (muted) | `#526660` | `#A3B8B0` | 02, 03 |
| textTertiary | `#5A6E68` | `#8FA69E` | derived (≥ 4.5:1 incl. on mint) |
| divider (border) | `#D8E3DF` | `#29433A` | 02, 03 |
| inputBorder (control boundary) | `#7C8F89` | `#5F7D74` | derived for ≥ 3:1 (see D5) |
| success fg / bg | `#15803D` / `#EEF8F1` | `#86EFAC` / `#0E2A1B` | 02, 03 (bg derived) |
| warning fg / bg | `#B45309` / `#FDF3E3` | `#FCD34D` / `#2C2108` | 02, 03 |
| error fg / bg | `#B91C1C` / `#FDECEC` | `#FCA5A5` / `#321515` | 02, 03 |
| info fg / bg | `#1D4ED8` / `#EAF0FD` | `#93C5FD` / `#0F1E38` | 02, 03 |
| focus border | `#0F766E` | `#5EEAD4` | 24-02 |
| focus stroke on filled controls | `#0B1513` | `#0F766E` | derived (D2) |

Measured contrast (scratch script, re-asserted by `apps/seller/test/design_system/seller_colors_test.dart`):
every text role on every surface it is used on ≥ 4.5:1 (lowest: light tertiary on mint 4.68, light success
on its tint 4.62); control boundaries ≥ 3:1 (light input border 3.42 on surface / 3.20 on canvas; dark 4.13);
focus borders ≥ 3:1 against the page in both themes.

## D2 — Single-border keyboard focus (OWNER_DECISION, brief §6; board 24-02 is authoritative, 24-01's double ring is superseded)

- Focus is shown **only** by the component's own outline getting a stronger colour and a heavier stroke,
  drawn inside the existing boundary (`BorderSide.strokeAlignInside`) so geometry never changes.
- Outlined components (fields, outlined buttons, cards/rows acting as controls, chips, dropdown and
  picker triggers, icon buttons, nav items, choice rows): focused border = focus colour, 2 dp (3 dp where
  the resting outline is already 1.5 dp).
- Filled buttons have a resting hairline in `primaryPressed` (their "existing outline"); focused it becomes
  3 dp of the focus-on-fill stroke (light `#0B1513` 3.39:1 vs the fill, dark `#0F766E` 3.70:1 vs the fill
  and 3.66:1 vs the page).
- Material focus overlays/halos are switched off in the seller theme (`focusColor` transparent,
  `overlayColor` focused → transparent on buttons, chips, switches, checkboxes, radios, sliders).
- The indicator shows only in keyboard highlight mode (`FocusHighlightMode.traditional`), except text
  fields, whose focused border is the normal editing state.
- Platform screen-reader focus (TalkBack/VoiceOver rectangles) is never imitated.

## D3 — Shape & type (DESIGN_DECISION, boards 02, 05, 08)

In the seller design system (D0): controls 48 dp tall
(compact 40), control radius 8, card radius 12, sheet radius 20, chips pill. Type (Inter, bundled):
Display 32/40 w700 · Heading 24/32 w600 · Title 20/28 w600 · Section 18/24 w600 · List title 16/24 w600 ·
Body 16/24 · Label 14/20 w600 · Caption 12/16 · Micro 11/16. Money/IDs use tabular figures.

## D4 — Navigation (boards 04, 07; DESIGN_DECISION)

- Roots: Home · Orders · Catalogue · Payments · Account (unchanged order). Root app bars carry a large
  left title and **no back arrow** (23-08's back arrow on "Account" is a mockup inconsistency — `DEVIATION`).
- Bottom bar below 600 dp; navigation rail from 600 dp (board 04 "Medium 600–839 = rail"; supersedes the
  ADR's 840 dp rail breakpoint); list + detail for Orders from 840 dp.
- Custom `SellerNavBar` / `SellerNavRail` (not Material `NavigationBar`) so a focused destination can
  show the single-border focus on its indicator and announce "Orders, 3 need action, tab 2 of 5".
- Quotes stay reachable from Home's action queue and the Account/Orders entry points (ADR-S08: a quote is
  a pre-order); Insights from Home.

## D5 — Accessibility adaptations that change the look slightly (DEVIATION, WCAG over raster)

- Field boundaries use `inputBorder` (≥ 3:1) instead of the very light border drawn on the boards, so
  inputs are identifiable in both themes (WCAG 1.4.11).
- Persistent labels above fields (`SellerTextField`) exactly as the boards show; the label and field are
  merged for screen readers.
- Chips and nav items are drawn at the board sizes but keep a 48 × 48 dp hit area.
- No `FittedBox` shrinking of amounts: large values wrap or the layout reflows (brief §5 "do not shrink
  text"). The previous KPI card did shrink; fixed.
- Reduced motion: spinners become a static hourglass + text (board 24-05), skeletons stop pulsing, page
  transitions are instant, success confirmations stay visible instead of sliding away.

## D6 — Product editor structure (boards 18-04…18-08; DESIGN_DECISION)

One editor for create and edit (18-04) with the core fields inline and four link rows to sub-screens:
Pack options, Pricing & tax, Coverage, Wholesale. Sub-screens edit the same in-memory draft; their
primary button reads **"Apply changes"** and returns to the editor; only the editor's sticky footer
("Save as draft" / "Save product" or "Update product") persists. `DEVIATION` from the boards' "Save changes"
label on sub-screens: those screens do not persist anything, and a label implying they do would mislead.
18-05's tab strip (Basic info · Pricing · Stock · Pack options) conflicts with 18-04's link rows; link rows win.
Unsaved changes are guarded ("Discard changes?", board 14).

## D7 — Catalogue card actions (board 18-02 is the selected revision)

Card = photo, name, draft tag, category, price + MRP, stock badge (from 18-01/18-03, using each product's own
low-stock threshold), "Visible to buyers" switch, wide **Edit** + overflow (**Update stock**, **Delete**).
Stock and visibility stay separate states (18-02 note). A draft's switch publishes it (existing contract).

## D8 — Bulk publish / hide reports per product (brief §8 phase 18; CONTRACT fix)

The previous implementation committed in 450-product batches and reported one boolean: a failure after an
earlier batch had committed was reported as a total failure while half the products had changed, and the
local list was not updated for the committed half. Now each product is updated individually (seller
catalogues are small), results are collected, local state changes only for successes, and the toast reports
"N updated · M couldn't be updated" with the failed ones kept selected for a retry.

## D9 — Messaging a buyer (board 17-02; DESIGN_DECISION)

"Message customer — Opens SMS app" replaces the old "chat" action, which created an empty
`threads/{order}_seller_customer` document and showed "Chat ready" with no seller chat screen to open.
Call and SMS hand off to the phone's own apps. The buyer's number is masked on screen (ADR §11 privacy);
the dialer/SMS app receives the full number only when the seller taps.

## D10 — Order detail stays open and updates in place (boards 17-05; CONTRACT unchanged)

The detail screen now follows the live order from `SellerOrderProvider` (Firestore stream) instead of a
snapshot passed at navigation, so after Accept → Start packing → Ready the screen shows the new stage and
the next permitted action. Transitions still go only through `sellerTransitionOrder`.

## D11 — Payments scope (OWNER_DECISION, brief §8 phase 19)

No wallet, no withdraw, no payout request. Amounts are exactly the server's `seller_payouts`
(`grossAmount`, `commissionAmount`, `netAmount`); the app sums them for totals only and never recomputes
commission. Masked identifiers only (bank `•••• 1234`, UPI masked). "Pending", "Paid", "Not available"
(read failed) and ₹0 are distinct states.

## D12 — AI assistant (OWNER_DECISION D-SELLER-AI-WEB-ONLY; brief §8 phase 23)

Mobile shows the activation explanation and the existing web-only notice (`aiWebOnly`, a Play-sensitive
string — **not reworded**). Chat, connection status and disconnect are restyled only; payment/verify/connect
logic is untouched. Server error text is no longer shown raw: callable error codes map to localised copy.
The provider's greeting and error strings move to ARB. The board's sample chat text is never shipped.

## D13 — Emulator switch for isolated end-to-end runs (DESIGN_DECISION, mirrors marketplace/employee)

`--dart-define=USE_FIREBASE_EMULATOR=true` (+ host/ports) points Auth, Firestore, Functions and Storage
at the local emulators and routes the shared `AuthService` OTP/Google-resolve HTTP calls to the functions
emulator instead of the hard-coded production URL (compile-time constant; release builds are
bit-identical). Without it the OTP journey could only be tested against production, which the brief and
`agrimore-near-miss-real-otp-via-partial-emulator-isolation` forbid.

## D14b — Brand mark, illustrations and font

No asset in the repository matches the boards' two-leaf "AgriMore SELLER" mark (`assets/images/seller_logo.png`
is the older green-awning launcher icon; the untracked `app_icons/` folder is the marketplace brand). The seller
design system draws the leaf mark and the simple organic illustrations (mint blob + leaves + a Lucide glyph) as
theme-aware vectors, so they work in light and dark. The launcher icon is unchanged (a store-listing asset — owner's
call). Inter 4.1 (SIL OFL 1.1) is bundled in `apps/seller/assets/fonts/` with its licence.

## D14 — Mockup collection is not committed

`apps/seller/assets/ui-mockups/` (132 MB, the owner's untracked WIP) is referenced by path, never added to
git or to `pubspec.yaml` assets (only `assets/images/` is declared).

## D15 — Things the boards show that the product does not have (not invented)

- Rejection/suspension reasons: sellers' records carry none, so the restricted screens use the fixed
  explanations (16-07/16-08 say "use the supplied account explanation; do not invent a reason").
- "Grade A", "Verified purchase" (shown only when the review document says so), follower identities,
  per-centre pricing tiles (shown only when the product is linked to a master product and a centre).
- Quote decline reasons are free text on the server (`respondToRfqOffer` `reason`, ≤ 500 chars); the
  reason list is the existing `kQuoteDeclineReasons`.

## D16 — Sign-in: logic kept, look redesigned (OWNER_DECISION 2026-09-24, revised the same day)

First instruction: "leave auth as it is". That was read as covering the look too, so the sign-in screens
first kept the shared Workspace theme. After seeing it on the device, the owner said the login page
"looks fully outdated not as like in the ui mockup". So the owner meant the sign-in logic, not the look.

- **Now:** A-01…A-04 are rebuilt on the seller design system to boards 16-01 and 16-02: the logo and
  landscape, a mobile field with +91, Get OTP, OR, Continue with Google with Google's own "G" (Google
  branding rules), an email link, and the legal line.
- **Google verify-mobile-once step:** back arrow, G mark, info card and Cancel.
- **OTP:** six boxes, with a wrong code said under the boxes (icon + text), the resend countdown, then
  "Resend code | Get a call instead".
- **Email:** a reset bottom sheet with success and failure notices.
- **Unchanged:** every call into `SellerAuthProvider` (send, verify, Google, link, email, reset), the
  validation rules, the cooldown and the test-mode fill.
- **Removed:** `LegacyAuthTheme` and the unused `support_contact_card.dart`. The seller app no longer
  depends on `agrimore_ui`.

## D17 — "Mock OTP in production": not implemented (OPEN_DECISION)

Owner asked for the mock OTP system in production too. `sendPhoneOTP.ts` already returns the code to
anyone who sends `debugMock: true` (only debug builds send it). Making the release app send it would let
anyone sign in as any seller with only their phone number (account takeover of live users). Nothing was
changed; a safer alternative (a fixed allow-list of test numbers, already supported server-side via the
SEC-P0 test-mode list) was offered. Needs the owner's explicit decision.

## D18 — Toasts rise above sticky footers

A floating toast covered the sticky Save for 4 s (found by a test). `SellerStickyFooter` registers with
its route and `SellerToast` adds its height to the toast margin (board 13: "above the bottom controls").

## D19 — No invented centres

`SellerProductProvider.loadCenters()` returned four hard-coded centres when the database had none; that is
invented data. It now returns the real list only (empty = none shown).
