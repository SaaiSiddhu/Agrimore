# Agrimore C05 — motion, haptics and reduced motion domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 palettes/type/shape references remain OWNER_DECISION / APPROVED_LOCKED. C05 is a review proposal; no runtime behavior changed.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

[All ten boards](MOTION_HAPTICS_REDUCED_MOTION_BOARDS_2026-10-03.md) · [Approved C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Source coverage and evidence boundary

Fresh inventory at HEAD f87ce8cd53b6971650dd0aeb79ee164aa3865ef8: **815 files / 271,458 lines**, spanning the five apps' lib directories, three shared packages' lib directories and functions/src TypeScript. Generated .g/.freezed files, firebase_options.dart and secret/credential-named files are excluded. All included files were read for inventory, checksums, motion/feedback markers and screen families; relevant implementations were then read in context. This is broad static analysis, not a claim of line-by-line semantic review or rendered review of every screen.

Textual syntax counts below may include references/comments. They are not unique controls, adoption rates or accessibility failures. Framework/shared widgets contribute behavior even when local explicit matches are zero.

| App | Haptic calls | Controllers | Implicit animation | Reduction markers | Progress constructors | Repeat markers |
| --- | --- | --- | --- | --- | --- | --- |
| marketplace | 264 | 62 | 46 | 0 | 112 | 8 |
| seller | 6 | 1 | 3 | 9 | 1 | 1 |
| delivery | 7 | 1 | 2 | 7 | 26 | 1 |
| sales-associate | 12 | 0 | 2 | 0 | 0 | 0 |
| admin | 45 | 4 | 20 | 0 | 143 | 0 |

The pattern inventory includes AnimatedContainer/Opacity/Switcher/Scale/Size/Positioned/Slide/Padding/CrossFade, reduction/navigation flags, circular/linear progress and explicit controllers. Duration constants for debounce, expiry or timeouts are not visual tokens. This source snapshot can change independently in the other implementation chat.

## Common C05 contract — proposed

1. **Keep meaning with less movement.** Reduce nonessential visual transitions to 0 ms; retain text, focus, enabled/busy state, actual data and true outcome. Stop decorative loops explicitly; framework controller defaults do not establish that third-party confetti or every repeating ticker stops.
2. **Progress remains understandable.** Standard pending uses a spinner with a useful label; reduced pending uses a static hourglass with the same label. Real determinate progress may show its measured value in text. Unknown duration never gets a fabricated percentage or timed-success sequence.
3. **Separate visual and operational timing.** These durations do not alter backend latency, request deadlines, offer expiry, OTP timers, debounce, grace periods or retry limits. Map locations and real countdowns still update.
4. **Confirm the precise outcome.** Cart updated, stock saved, proof attached, request accepted and list refreshed are distinct results. Feedback follows the relevant provider/callable/clipboard outcome. Request submitted is not payout paid; proof received is not delivery completed; query refreshed is not approval or financial repair.
5. **Haptics supplement visible feedback.** Every table entry is optional, device supported and user enabled. Trigger once per meaningful foreground event; no automatic-retry, background-sync or rebuild pulse. Desktop defaults to none. Reduction and haptic preferences remain separate; no invented waveform or physical-strength guarantee.
6. **Preserve busy, failure and recovery.** Retain duplicate-submit guards, stable logical request IDs and stale-response protection. Disable the pending action, keep explanatory text and readable error/retry messages, and avoid announcing every animation tick. Preserve destructive confirmation; no error shaker or vibration loop.
7. **Keep content anchored.** Remove slide/zoom, moving skeleton, chart sweep and balance count-up in reduced mode. Directly update real figures and markers; retain keyboard focus, list context and navigation.
8. **Respond to preferences live.** Read supported OS signals and respond if settings change while the screen is open. An optional app setting can further reduce movement; it must not override a system reduction request. No settings storage/runtime wrapper has been added here.

Current Flutter documentation distinguishes disableAnimations and the separate iOS reduceMotion signal. Existing Seller/Delivery wrappers read maybeDisableAnimationsOf; complete platform/version coverage requires later Android/iOS testing. The local SDK symlink points at a 3.44.8 installation; no SDK change/build was run. [Flutter disableAnimations documentation](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).

Controller animationBehavior defaults do not replace deliberate reduced-mode states and loop shutdown. [Flutter AnimationController.animationBehavior](https://api.flutter.dev/flutter/animation/AnimationController/animationBehavior.html). Flutter haptics use platform defaults and do not provide precise physical waveform control. [Flutter HapticFeedback](https://api.flutter.dev/flutter/services/HapticFeedback-class.html).

## Five independent systems

Each app's light/dark pair has the same role values, workflow labels and haptic intent; its C01 palette changes with theme. These are target role choices, not measurements of every runtime transition. Seller and Delivery retain their existing 120/200/320 vocabulary while applying different domain policies. Marketplace, Sales Associate and Admin receive distinct proposed role maps.

## Agrimore Marketplace

Identity: Professional green; warm gold and natural stone. App directory: apps/marketplace.

**TARGET_IMPLEMENTATION direction:** Responsive shopping feedback; gentle contained fades, no playful bounce or flying-cart effect. Inter 700/600/400.

| Screen families / domain | Motion and feedback responsibility |
| --- | --- |
| Home, browse, search, filters, wishlist and products | Use short contained feedback; keep selected/filter state in text. No staggered entrance cascades or flying item effects in reduced motion. |
| Cart, quantity, coupons, checkout, payment and RFQ | Pending preserves quantities and totals, blocks repeat submission; confirm cart/order/payment only from the corresponding provider/callable outcome. Do not invent timed completion. |
| Orders, live tracking, delivery stages and notifications | Snap marker positions under reduced motion while retaining actual location, freshness and ETA updates; decorative pulses stop. Order state changes stay readable. |
| Chat, business enquiry, associate/seller entry, auth, OTP and profile | Static labeled pending/retry states; meaningful stream data remains current. Reduce route/modal movement without suppressing navigation, OTP timers or validation. |
| Landing, legal, onboarding and splash | Avoid mandatory animation delays, confetti and moving decorative content; show usable content as soon as readiness permits. |

### Current-source observations

- 264 HapticFeedback markers and 62 explicit AnimationController constructors were counted; no local reduced-motion marker matched. Counts are syntax inventory, not a count of inaccessible controls.
- OrderSuccessScreen starts an 800 ms elastic scale/fade, 3-second confetti and heavy then delayed medium impact in initState. It has no explicit reduced-motion branch in that file; framework controller behavior alone does not prove confetti stops.
- LiveTrackingScreen starts a repeating 1400 ms pulse and uses a 900 ms location-move controller. The proposal stops decorative pulse and snaps location visually while maintaining real tracking updates.

Source anchors:

- [order_success_screen.dart](../../apps/marketplace/lib/screens/user/checkout/order_success_screen.dart)
- [live_tracking_screen.dart](../../apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart)
- [mobile_cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart)
- [checkout_screen.dart](../../apps/marketplace/lib/screens/user/checkout/checkout_screen.dart)

### Proposed role map

| Visual role | Duration (ms) |
| --- | --- |
| Press state | 100 |
| Content fade | 180 |
| Result reveal | 280 |
| Sheet enter | 320 |
| Reduced motion | 0 |

Curve: ease-out · cubic(0.2, 0, 0, 1). Curve drawings are schematic; the numeric curve is the implementation specification.

| Storyboard state | Visible feedback |
| --- | --- |
| Ready | Add to cart |
| Pending | Adding item… |
| Confirmed | Added to cart |

Entity: **Fresh tomatoes · 1 kg**. Show confirmation after the cart update succeeds. Values/IDs are illustrative fixtures, not live records or data bindings. The compact storyboard omits error/retry branches; preserve them under the common contract above.

| Foreground event | Optional feedback |
| --- | --- |
| Quantity change | Selection click |
| Cart update confirmed | Optional light impact |
| Loading or refresh | None |

Reduced-motion rules:

- Instant state changes · 0 ms
- Static hourglass + progress text
- No confetti, pulse, slide or zoom
- Keep tracking updates; snap marker

Source inventory under lib/screens (includes supporting files; not unique rendered screens):

| Source family | Files |
| --- | --- |
| auth | 9 |
| business | 3 |
| chat | 11 |
| employee | 7 |
| landing | 1 |
| legal | 2 |
| not_found_screen.dart | 1 |
| onboarding | 1 |
| seller | 1 |
| splash | 1 |
| user | 118 |

[Light/dark assets and exact prompts](../../apps/marketplace/assets/ui-mockups/05-motion-haptics-reduced-motion/README.md).

## Agrimore Seller

Identity: Blue-teal; copper and cool neutrals. App directory: apps/seller.

**TARGET_IMPLEMENTATION direction:** Efficient inventory and quotation workspace; retain SellerMotion vocabulary, gentle fades and anchored sheets. Inter 600/500/400.

| Screen families / domain | Motion and feedback responsibility |
| --- | --- |
| Catalogue, stock, storefront, posts, search and insights | Reuse SellerMotion durations and existing reduced-motion controls. Preserve stock values during save; use confirmed provider result for success; no chart or count tween under reduced motion. |
| Orders, quotes/RFQ, payments and reviews | Distinguish submitting quote, accepted quote, saved stock and paid status. Stable rows and values during fetch; optional single confirmation haptic only after corresponding result. |
| Application/onboarding, auth/OTP, account, profile and restricted states | Preserve access-state truth, OTP/debounce timings and visible validation. Existing auth AnimatedSwitcher uses context.motion; new documentary 0 ms policy applies visual transitions, not business timers. |
| AI, notifications and shell | Stop cosmetic auto-scroll/typing pulse under reduced motion while preserving streamed content and new-message text. Avoid replaying haptics on rebuild. |

### Current-source observations

- SellerMotion already defines fast 120, standard 200, slow 320 ms, cubic(0.2,0,0,1), and context.motion returning zero when maybeDisableAnimationsOf is true.
- SellerSpinner uses a static hourglass in that reduced-motion branch. SellerSkeleton stops repeat() and fixes its value; normal pulse period derives from slow × 3 = 960 ms.
- Seller app builder uses NoSplash with reduced motion; auth switcher and several components use context.motion. Seller theme wraps Android/desktop transitions but retains Cupertino transitions on iOS/macOS; full platform route coverage has not been proven.
- SellerProductsScreen awaits the stock-edit sheet and only shows stock-saved toast for saved == true; retain that confirmation boundary.

Source anchors:

- [seller_motion.dart](../../apps/seller/lib/design_system/tokens/seller_motion.dart)
- [seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart)
- [seller_theme.dart](../../apps/seller/lib/design_system/theme/seller_theme.dart)
- [app.dart](../../apps/seller/lib/app/app.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)

### Proposed role map

| Visual role | Duration (ms) |
| --- | --- |
| Press state | 120 |
| Content fade | 200 |
| Result reveal | 200 |
| Sheet enter | 320 |
| Reduced motion | 0 |

Curve: ease-out · cubic(0.2, 0, 0, 1). Curve drawings are schematic; the numeric curve is the implementation specification.

| Storyboard state | Visible feedback |
| --- | --- |
| Ready | Save stock |
| Pending | Saving stock… |
| Confirmed | Stock updated |

Entity: **Fresh tomatoes · 250 packs**. Show confirmation after the stock update succeeds. Values/IDs are illustrative fixtures, not live records or data bindings. The compact storyboard omits error/retry branches; preserve them under the common contract above.

| Foreground event | Optional feedback |
| --- | --- |
| Catalogue selection | Selection click |
| Stock update confirmed | Optional light impact |
| Background sync | None |

Reduced-motion rules:

- Instant state changes · 0 ms
- Static hourglass + progress text
- Static skeleton; no pulse or ripple
- Keep values and validation visible

Source inventory under lib/screens (includes supporting files; not unique rendered screens):

| Source family | Files |
| --- | --- |
| account | 8 |
| ai | 1 |
| auth | 6 |
| home | 4 |
| insights | 3 |
| notifications | 2 |
| onboarding | 10 |
| orders | 6 |
| payments | 3 |
| posts | 2 |
| products | 6 |
| profile | 5 |
| reviews | 2 |
| rfq | 7 |
| search | 2 |
| shell | 1 |
| storefront | 2 |

[Light/dark assets and exact prompts](../../apps/seller/assets/ui-mockups/05-motion-haptics-reduced-motion/README.md).

## Agrimore Delivery

Identity: Black/white; burgundy and burnt orange. App directory: apps/delivery.

**TARGET_IMPLEMENTATION direction:** Direct field-task feedback, larger stable actions, no zoom on critical tasks. Burnt orange timing guides, burgundy proof context; neutral primary actions. Inter 700/600/400.

| Screen families / domain | Motion and feedback responsibility |
| --- | --- |
| Incoming offers, readiness and assignment transitions | Keep offer expiry countdown and true availability updating even when visual transitions stop. Acceptance pending is distinct from successful assignment; do not invent countdown duration or change offer deadline. |
| Home map, active route, order stages and operations panel | Snap marker/panel changes in reduced mode; preserve live positions, staleness warnings, steps and cash meaning. Foreground task haptics are optional and do not replace text. |
| Proof photo, pending-proof recovery, issues and support | Proof attached and delivery confirmed are separate outcomes. Show receipt only after saveDeliveryProof true; failed evidence remains pending/recoverable. Camera thumbnail stays static in reduced mode. |
| Money, statements, cash account, history, inbox, profile and auth | Stable money figures and lists; no success pulse for navigation, retry or background sync. Labels and retry guidance survive reduced motion. |

### Current-source observations

- DeliveryMotion defines 120/200/320 ms, 900 ms pulse and zero-duration context.motion when maybeDisableAnimationsOf is true. countdownTick, timeouts and assignment grace are operational timing and must not be zeroed.
- DeliveryInteractive suppresses pressed scale and zeroes duration in its reduced-motion branch; DeliverySkeleton stops repeating. DeliveryLoadingState still directly constructs CircularProgressIndicator without a local static alternative.
- IncomingOfferScreen._accept emits mediumImpact before awaiting provider.accept; it handles failure separately. Proposed confirmation haptics move to the confirmed result, never imply assignment from the initial tap.
- ActiveOrderScreen confirms delivery and saves proof through separate steps. The saveDeliveryProof false path retains staged pending proof and shows proofNotSaved. The storyboard is a proof-transfer state specimen, not a replacement order-completion flow.

Source anchors:

- [delivery_motion.dart](../../apps/delivery/lib/design_system/tokens/delivery_motion.dart)
- [delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart)
- [incoming_offer_screen.dart](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart)
- [active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)
- [pending_proof_banner.dart](../../apps/delivery/lib/screens/home/pending_proof_banner.dart)
- [proof_photo_recovery.dart](../../apps/delivery/lib/delivery/proof_photo_recovery.dart)

### Proposed role map

| Visual role | Duration (ms) |
| --- | --- |
| Press state | 120 |
| Panel fade | 200 |
| Result reveal | 200 |
| Sheet enter | 320 |
| Reduced motion | 0 |

Curve: ease-out · cubic(0.2, 0, 0, 1). Curve drawings are schematic; the numeric curve is the implementation specification.

| Storyboard state | Visible feedback |
| --- | --- |
| Ready | Upload proof |
| Pending | Uploading proof… |
| Confirmed | Proof received |

Entity: **Order ORD-2048 · Proof photo**. Proof received does not mean delivery completed. Values/IDs are illustrative fixtures, not live records or data bindings. The compact storyboard omits error/retry branches; preserve them under the common contract above.

| Foreground event | Optional feedback |
| --- | --- |
| Task selected | Optional light impact |
| Proof receipt confirmed | Optional medium impact |
| GPS or upload retry | None |

Reduced-motion rules:

- Instant state changes · 0 ms
- Static hourglass + progress text
- No pulse, camera fly-in or zoom
- Keep offer timer and GPS updates

Source inventory under lib/screens (includes supporting files; not unique rendered screens):

| Source family | Files |
| --- | --- |
| auth | 3 |
| history | 2 |
| home | 6 |
| inbox | 1 |
| money | 3 |
| offers | 1 |
| orders | 4 |
| profile | 3 |
| settings | 1 |
| support | 5 |

[Light/dark assets and exact prompts](../../apps/delivery/assets/ui-mockups/05-motion-haptics-reduced-motion/README.md).

## Agrimore Sales Associate

Identity: Premium royal blue; indigo and pearl/slate. App directory: apps/employee.

**TARGET_IMPLEMENTATION direction:** Calm financial trust; contained opacity changes and static monetary figures. Indigo payout context, blue actions. Inter 600/500/400.

| Screen families / domain | Motion and feedback responsibility |
| --- | --- |
| Dashboard, associate code and notifications | Keep code fixed, await clipboard success before copied confirmation, and distinguish invoking share sheet from successful sharing. No celebratory balance counting. |
| Orders, commissions, wallet and history | Static prices and commission values; update authoritative values directly. Requested, processing, paid and failed states remain distinct text-backed states. |
| Payout request, review/detail and payout account | Busy blocks repeat submission; preserve the logical request ID on retry. Confirm request accepted, never paid, from response/record. Under reduced motion show static pending cue and clear outcome. |
| Auth/OTP, onboarding/pending/suspended, profile, support and shell | Retain navigation and business states, suppress decorative route movement; loading labels, validation and retry controls remain available. |

### Current-source observations

- Employee app has 12 HapticFeedback markers, two implicit-animation markers and no explicit local controller/reduced-motion match; shared widgets still supply behavior, so zero local matches does not mean zero animation.
- SaLoadingButton already disables onPressed while loading and shows a 20 px spinner with optional loading text. It does not explicitly branch to a static pending cue.
- PayoutReviewScreen uses _isSubmitting and a stable _requestId, calls requestEmployeePayout, then navigates with requested status. Its mediumImpact fires before submission, so it cannot mean payment/request success.
- Dashboard copy invokes Clipboard.setData without await before haptic/snackbar; share also haptics before Share.share. A future implementation should confirm clipboard completion and avoid claiming a share-sheet invocation means content was shared.
- WsMotion declares instant 80 ms and documents collapse-on-disable, but the declaration itself is not a runtime preference wrapper; workspace OTP/step headers use durations directly.

Source anchors:

- [payout_review_screen.dart](../../apps/employee/lib/screens/wallet/payout_review_screen.dart)
- [dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)
- [sa_loading_button.dart](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart)
- [ws_foundation.dart](../../packages/agrimore_ui/lib/workspace/ws_foundation.dart)
- [ws_step_header.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_step_header.dart)
- [requestEmployeePayout.ts](../../functions/src/customer/requestEmployeePayout.ts)

### Proposed role map

| Visual role | Duration (ms) |
| --- | --- |
| Press state | 120 |
| Content fade | 180 |
| Result reveal | 240 |
| Dialog enter | 280 |
| Reduced motion | 0 |

Curve: ease-out · cubic(0.2, 0, 0, 1). Curve drawings are schematic; the numeric curve is the implementation specification.

| Storyboard state | Visible feedback |
| --- | --- |
| Ready | Submit request |
| Pending | Sending request… |
| Confirmed | Request submitted |

Entity: **₹2,400.00 · Request review**. Request submitted means awaiting review, not paid. Values/IDs are illustrative fixtures, not live records or data bindings. The compact storyboard omits error/retry branches; preserve them under the common contract above.

| Foreground event | Optional feedback |
| --- | --- |
| Code copied successfully | Optional light impact |
| Request accepted by server | Optional light impact |
| Balance refresh | None |

Reduced-motion rules:

- Instant state changes · 0 ms
- Static hourglass + progress text
- No balance count-up or card zoom
- Keep payout status and amount visible

Source inventory under lib/screens (includes supporting files; not unique rendered screens):

| Source family | Files |
| --- | --- |
| auth | 5 |
| home | 1 |
| notifications | 1 |
| orders | 2 |
| profile | 2 |
| shell | 1 |
| support | 1 |
| wallet | 6 |

[Light/dark assets and exact prompts](../../apps/employee/assets/ui-mockups/05-motion-haptics-reduced-motion/README.md).

## Agrimore Admin

Identity: Professional blue; cyan and steel/slate. App directory: apps/admin.

**TARGET_IMPLEMENTATION direction:** Restrained operational desktop feedback; rows remain anchored, focus stable, no table slides or celebration. Cyan context, institutional blue actions distinct from royal blue. Inter 600/500/400.

| Screen families / domain | Motion and feedback responsibility |
| --- | --- |
| Dashboard, analytics, finance/reconciliation and wallet | Keep charts/static totals and existing data during refresh when appropriate; real determinate progress only when known. Reconciliation is read-only investigation; completion of scan is not money repaired or payout paid. |
| Products, sellers, vendors, categories, orders and subscriptions | Stable rows and selection across update, no misleading success on click. Approval/delete waits for operation result; focus remains anchored and row movement disabled in reduced mode. |
| Delivery, employee/associate, users, applications and support | Separate read/list refresh, reviewed, approved, suspended and rejected outcomes. Retain permission-disabled state and change pending state without announcing every animation tick. |
| Banners, content sections, rewards, coupons and program settings | No gratuitous reorder animation or chart sweep; retain accessible order alternatives and actual validation. Suppress background haptics. |
| Security, notifications, auth and settings | Desktop haptics none by default; optional mobile feedback must respect capability/settings. Keep visible error/retry and focus cues without movement. |

### Current-source observations

- Admin scan counted four controller constructors, 20 implicit-animation markers, 45 HapticFeedback calls and 143 progress constructors, with no local reduced-motion marker matched. These are syntax counts, not rendered-state certification.
- FinanceReconciliationScreen maintains _loading/_loadingMore, request generation and ignores superseded results. Preserve that stale-response protection; list refresh does not fix financial findings.
- SellerProductApprovalScreen directly renders a circular spinner while waiting. Static labeled progress is a target proposal.
- Admin router uses shared PremiumSplashScreen, which starts repeating glow and rotation controllers. No explicit reduced-motion branch matched in the shared splash; a future patch must stop these decorative loops explicitly.

Source anchors:

- [finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart)
- [seller_product_approval_screen.dart](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart)
- [app_router.dart](../../apps/admin/lib/app/app_router.dart)
- [premium_splash_screen.dart](../../packages/agrimore_ui/lib/widgets/premium_splash_screen.dart)

### Proposed role map

| Visual role | Duration (ms) |
| --- | --- |
| Hover / press | 80 |
| Row fade | 160 |
| Result reveal | 160 |
| Dialog enter | 240 |
| Reduced motion | 0 |

Curve: ease-out · cubic(0.2, 0, 0, 1). Curve drawings are schematic; the numeric curve is the implementation specification.

| Storyboard state | Visible feedback |
| --- | --- |
| Ready | Apply filter |
| Pending | Loading applications… |
| Confirmed | List updated |

Entity: **Seller applications · Pending**. A list refresh does not approve any application. Values/IDs are illustrative fixtures, not live records or data bindings. The compact storyboard omits error/retry branches; preserve them under the common contract above.

| Foreground event | Optional feedback |
| --- | --- |
| Mobile selection | Optional selection click |
| Confirmed admin action | Optional light impact |
| Desktop or background refresh | None |

Reduced-motion rules:

- Instant state changes · 0 ms
- Static hourglass + progress text
- No row slide, chart sweep or pulse
- Keep keyboard focus and table context

Source inventory under lib/screens (includes supporting files; not unique rendered screens):

| Source family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

[Light/dark assets and exact prompts](../../apps/admin/assets/ui-mockups/05-motion-haptics-reduced-motion/README.md).

## Implementation handoff and validation boundary

Extend existing app-specific motion, progress, button and feedback primitives rather than introducing duplicate widgets. Marketplace/Admin remaining literals need bounded migration. Seller/Delivery wrappers need caller and platform coverage. Shared Sales Associate/workspace controls need explicit reduced-mode progress and duration handling. Map documented role names to concrete components and stop loops on settings changes/disposal.

Later runtime verification must cover normal/reduced × light/dark, pending/confirmed/error/retry, large text, screen-reader pending/outcome announcements, keyboard focus/row context, supported Android/iOS settings, and foreground/background haptics. A failed request must never produce success feedback. Switching reduction on must stop active decorative loops while actual timers/state updates continue. Verify clipboard completion, stable request-ID retries, superseded-result rejection, separate delivery/proof outcomes and duplicate-submit guards.

These ten PNGs are still Storybook-style boards. They do not demonstrate animation playback, measured easing/duration, device vibration, runtime hit geometry or accessible semantics. Hex/numeric manifest specifications are exact targets; generated raster colors and curve sketches are approximate visual references. No automated OCR, pixel-exact palette, device haptic or runtime accessibility certification is claimed.

This task writes new documentary app assets and these two design documents only. No runtime Dart/TypeScript, package-folder restructure, pubspec registration, shared widget/token, C01–C04 reference, branch, index, commit or active-work ledger is changed.

