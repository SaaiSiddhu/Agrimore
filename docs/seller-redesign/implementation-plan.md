# Seller redesign — implementation plan

Phase **SELLER-REDESIGN-1** · branch `agrimore/sredesign1-seller-ui` · worktree `../Agrimore-sredesign`
(the single folder stays on `develop` because concurrent phases merge there) · base `develop` `358d3da`.
Single agent. Nothing is deployed or pushed; the owner merges/pushes/deploys.

## 0. Inputs

- 86 canonical images in `apps/seller/assets/ui-mockups/` (24 phases) — inspected one by one; per-image
  notes in `mockup-inspection-notes.md`.
- Existing seller app: 85 Dart files (~15 k lines excl. generated l10n), 217 tests, canon 0 literals,
  built on the shared Workspace teal theme (UI-TEAL-0). Per the owner (D0) the seller moves onto its **own**
  design system inside the app; the shared Workspace system keeps serving the other apps unchanged.
- Contracts that do not change: `sellerTransitionOrder`, `issueSellerInvoice`, RFQ callables,
  `submitSellerApplication`, `replyToReview`, `seller_stats_daily`, notification prefs, store
  availability/schedule, storefront field allow-list, payouts (server-written).

## 1. Foundation — the seller's OWN design system (OWNER_DECISION D0)

Location: `apps/seller/lib/design_system/` (barrel `design_system.dart`). `packages/agrimore_ui` is not
touched; the seller stops importing it for anything visual.

1. `tokens/seller_colors.dart` — `SellerColors` ThemeExtension (light/dark per decisions D1) + `context.colors`.
2. `tokens/seller_tokens.dart` — `SellerSpace`, `SellerRadius`, `SellerSize`, `SellerIconSize`,
   `SellerOpacity`, `SellerElevation`, `SellerBreakpoints` / `sellerLayoutFor`.
3. `tokens/seller_typography.dart` — Inter (bundled in `apps/seller/assets/fonts/`), the board type scale,
   tabular figures, `context.text`.
4. `tokens/seller_motion.dart` — durations/curves, `context.reduceMotion`, `context.motion(d)`.
5. `theme/seller_theme.dart` — `SellerTheme.light` / `.dark`: single-border keyboard focus on every
   Material control, halos off, 48 dp controls, input boundaries, chips, switches with outlined off-track,
   sheets/dialogs, toasts, reduced-motion page transitions.
6. `icons/seller_icons.dart` — Lucide (`lucide_icons_flutter`, now a direct seller dependency).
7. `format/seller_format.dart` — ₹ en-IN money, counts, dates, masking.
8. `components/` — `SellerButton` · `SellerIconButton` · `SellerCard`/`SellerTappableCard` · `SellerListRow`/
   `SellerMenuGroup`/`SellerKeyValueRow`/`SellerSectionHeader` · `SellerTextField`/`SellerSelectField`/
   `SellerPickerField`/`SellerSliderField`/`SellerChoiceRow`/`SellerFormErrorSummary` · `SellerBanner` ·
   `SellerStatusBadge` · `SellerToast`/`sellerConfirm`/`showSellerSheet`/discard guard · `SellerEmptyState`/
   `SellerErrorState`/`SellerSkeleton`/`SellerProgressLabel` · `SellerChip`/`SellerChipBar` ·
   `SellerSegmented` · `SellerNavBar`/`SellerNavRail` · `SellerAppBar` · `SellerAvatar`/`SellerImage` ·
   `SellerMetricCard`/`SellerMoneyBreakdown` · charts (`SellerSparkline`, `SellerLineChart`, `SellerBarList`,
   `SellerDonut`, `SellerScoreRing`, `SellerDataTable`) · `SellerTimeline`/`SellerStepDots` ·
   `SellerOtpInput` · `SellerLogo` / `SellerIllustration` · `SellerTestModeRibbon`.
9. `canon_check.sh` skips `*/lib/design_system/*` (the app's system itself), exactly like `lib/l10n/`.

## 2. Shell and global behaviour (apps/seller)

- `SellerShell`: seller nav bar (< 600) / rail (≥ 600), badges ("99+"), per-tab state kept, Android back on a
  non-home tab returns to Home before leaving.
- App: seller theme + dark theme + `themeMode` (existing persisted setting), reduced-motion page
  transitions, text scaling respected (no clamps), emulator switch (D13).
- Orders list + detail side by side from 840 dp.

## 3. Screens, in dependency order (each: seller design system only, zero literals, l10n, states, focus, semantics, tests)

1. Auth: sign-in (phone), OTP (+ resend, call instead, test-mode ribbon), Google-link state, email
   sign-in + reset sheet, loading.
2. Onboarding: intro, 5-step application (business, location & delivery, documents, payout, review &
   submit), pending status, rejected (fix & resubmit), suspended.
3. Home: greeting header (search, bell), store availability banner, "Needs you now", KPIs with period,
   account health, next settlement, quick actions.
4. Orders: list (search, stage chips with counts, period + B2B chips), card; detail (stage + timeline,
   customer & delivery, items/options, payment, invoice card, stage actions); reject/cancel sheet;
   invoice (bill of supply / tax invoice, copy).
5. Catalogue: list (search, sort menu, chips with counts, product card, visibility switch, overflow),
   update-stock sheet, selection mode + bulk bar, delete dialog; editor + Pack options / Pricing & tax /
   Coverage / Wholesale.
6. Payments: overview, all settlements, settlement detail (timeline, financials, reference copy),
   monthly statements (+ copy), payout account (masked, missing, unavailable).
7. Quotes: inbox (4 chip tabs), detail (offer on the table, comparison, expiry, history timeline,
   footer actions per turn), counter sheet (validity chips, MOQ warning, live total), decline sheet,
   accept confirm, linked order.
8. Insights & health: KPI cards, period selector, comparisons, sales chart (two series + data table),
   stage bars, ranked products, B2B share; account health ring + measures + explanation sheets.
9. Account & store: account root (store header, status card, menus, sign out), store status sheet
   (pause 1/3/7 days/until resumed), weekly off & holidays, business details (time pickers), delivery fees
   (flat / by order value), storefront editor + full-screen preview, reviews & replies (distribution,
   filters, reply sheet, 24 h edit), followers & posts (+ new post, delete).
10. AI, notifications, preferences, support: AI assistant (web-only activation notice, chat, states,
    retry), AI connection (provider, masked key, disconnect), notifications inbox, notification
    preferences + quiet hours, settings (appearance, licences, version), help & support (FAQ search,
    contacts), seller policies, sign-out sheet, global search.

## 4. Missing functionality closed (details in `screen-matrix.md`)

Live-updating order detail · masked buyer phone + SMS hand-off · per-product bulk results · stock sheet
saving/error/retained input · invoice-number copy feedback · settlement reference copy · all-settlements
list · localised fee-validation and AI copy · AI chat retry · time pickers for business hours · unsaved
changes guards · form error summary with focus to the first invalid field · seller policies screen ·
store status card on Account/Home · orders list + detail on tablets · tagged product on posts.

## 5. Verification

- Per area: `flutter analyze` (seller; all five apps whenever `packages/**` moves), seller tests, canon
  check (seller strict 0 outside `lib/design_system/`).
- Design-system tests (`apps/seller/test/design_system/`): single-border focus (no extra outline widgets, geometry unchanged), contrast table,
  48 dp targets, loading/duplicate-submission, label semantics, reduced motion.
- Screen tests updated/added for every screen state; large-text (2.0×) and dark renders.
- `integration_test/` journeys on the Android emulator against the local Firebase emulators (seeded
  fixtures, `demo` data only); third-party services (Razorpay, Gemini, 2Factor, FCM) simulated and labelled.
- Device QA: Android AVD `Pixel_8_API_35` (+ a small-phone AVD) light/dark/large text/keyboard; screenshots
  under `evidence/android/`, each inspected against its board.
- iOS: scaffold created; build/run **blocked** on this machine (no Xcode, no iOS Firebase app) — recorded.

## 6. Collision management

Concurrent ACTIVE phases at claim time: DLV-P1 (`ws_icons.dart`, `kit/ws_feedback.dart`) and UI-SA1
(`ws_tokens.dart`, SA theme/tokens, `workspace_system_test.dart`). After D0 this phase edits **no** file in
`packages/agrimore_ui`, so there is no overlap with either. Shared files still touched: the ledger row
(union on merge), `canon_check.sh` (one exclusion line), `references/decisions.md` (one appended entry),
and — only if the emulator switch lands — `packages/agrimore_services/lib/auth/auth_service.dart` (five-app
analyze). Before the final merge: `git merge develop` into the branch, re-run everything on the result.
