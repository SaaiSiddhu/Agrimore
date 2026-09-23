# AgriMore Seller — Canonical System & Product Architecture (ADR)

| | |
|---|---|
| **Document** | `docs/design-system/SELLER_APP_CANONICAL_ADR.md` |
| **Status** | ACCEPTED as the target for the seller programme — owner approved gap list A–D on 2026-09-23. Decisions marked **OPEN** below are not decided. |
| **Scope** | `apps/seller` (Android + web), the shared pieces it needs in `packages/agrimore_ui` · `agrimore_services` · `agrimore_core`, the Cloud Functions / rules it depends on, and the seller-facing parts of `apps/marketplace` (storefront, "become a seller"). |
| **Measured at** | `develop` @ `db2e5a9` (2026-09-23) |
| **Canonical system reference** | `docs/design-system/SALES_ASSOCIATE_DESIGN_SYSTEM.md` + `packages/agrimore_ui/lib/themes/sales_associate_*.dart` — the **system** (tokens, rules, dark mode, component contract, test discipline). |
| **UX quality bar** | A tier-1 2026 marketplace seller platform: action-first home, SLA-driven order pipeline, catalogue quality and inventory health, truthful settlements, insights, desktop-class web. **Patterns only** — no other company's name, logo, colours, illustrations or proprietary layouts are reproduced. |
| **Supersedes** | Nothing in the repository. Complements, does not change, the Sales Associate spec. |

Classification tags used: `VERIFIED_REPOSITORY_FACT` · `OWNER_DECISION` · `CURRENT_IMPLEMENTATION` · `TARGET_IMPLEMENTATION` · `OPEN_DECISION`. Anything described as the seller app's future screen is `TARGET_IMPLEMENTATION` unless stated otherwise.

---

## Table of contents

1. [Context — what exists today](#1-context--what-exists-today)
2. [Design principles](#2-design-principles)
3. [Decision register (summary)](#3-decision-register-summary)
4. [Foundation decisions — the canonical system](#4-foundation-decisions--the-canonical-system)
5. [Teal token specification](#5-teal-token-specification)
6. [The zero-literal rule and its enforcement](#6-the-zero-literal-rule-and-its-enforcement)
7. [Component kit](#7-component-kit)
8. [Information architecture & navigation](#8-information-architecture--navigation)
9. [Authentication & onboarding architecture](#9-authentication--onboarding-architecture)
10. [Screen catalogue — every screen, specified](#10-screen-catalogue--every-screen-specified)
11. [Cross-cutting behaviour](#11-cross-cutting-behaviour)
12. [Data, backend & security architecture](#12-data-backend--security-architecture)
13. [Gap register (1–49) → screen → phase](#13-gap-register-149--screen--phase)
14. [End-to-end dependencies outside the app](#14-end-to-end-dependencies-outside-the-app)
15. [Phase plan with acceptance criteria](#15-phase-plan-with-acceptance-criteria)
16. [Quality gates & testing](#16-quality-gates--testing)
17. [Open decisions](#17-open-decisions)
18. [Appendices](#18-appendices)

---

## 1. Context — what exists today

### 1.1 The seller app (`VERIFIED_REPOSITORY_FACT`, `db2e5a9`)

| Area | Files | State |
|---|---|---|
| Entry | `lib/main.dart`, `lib/app/app.dart` | Inline `ThemeData` seeded **navy `#1A365D` + amber**; `PremiumSplashScreen`; `_AuthGate` on `SellerAuthProvider` |
| Shell | `screens/shell/seller_shell.dart` | 5 tabs (Dashboard · Products · Orders · Earnings · Profile), hand-built nav in hardcoded **green `#2D7D3C`** — a third brand colour |
| Auth | `login_screen.dart`, `seller_registration_screen.dart`, `pending_approval_screen.dart` | Email + password only; one long registration form writing `users` + `sellerRequests`; pending screen = two buttons |
| Home | `home/dashboard_screen.dart` (506 lines) | Greeting, period selector, stat grid, quick actions, recent products |
| Products | `products/seller_products_screen.dart`, `home/add_product_screen.dart` (**1,357 lines**), `posts/create_post_screen.dart` | Stock chips, search, card actions; monolithic editor |
| Orders | `orders/seller_orders_screen.dart`, `orders/seller_order_detail_screen.dart` | Filter chips; status moves **client-side** `confirmed → processing → ready_for_pickup`; no Accept for `pending` (`seller_order_detail_screen.dart:603`) |
| Earnings | `earnings/seller_earnings_screen.dart` | Read-only revenue summary + payout list |
| Profile | `profile/seller_profile_screen.dart`, `delivery_fee_sheet.dart`, `seller_ai_integration_screen.dart` | Menu of dialogs (bank, hours, notifications — static text) |
| Quotes | `rfq/seller_rfq_inbox_screen.dart`, `rfq/seller_rfq_detail_screen.dart` | Built; buried in Profile; callables **not deployed** |
| AI | `ai/seller_ai_chat_screen.dart` | Built; callables **not deployed** |
| Dead code | `widgets/order_detail_popup.dart`, `widgets/order_preview_card.dart` | Never instantiated |
| Tests | `apps/seller/test` | **0** screen tests |

**Literal debt:** `apps/seller/lib` contains **373** colour literals (`Color(0x…)` / `Colors.*`) and **561** raw spacing / radius / font-size numbers.

### 1.2 The canonical system (Sales Associate) — strengths and defects

Strengths (`VERIFIED_REPOSITORY_FACT`): `SaTokens` (light + dark palettes, 4-pt spacing, 3 radii, 6-step type scale, icon sizes, 52 px controls, 48 px targets), `SalesAssociateTokens` `ThemeExtension`, `SalesAssociateTheme.lightTheme/darkTheme`, 20 Lucide `SaIcons`, `SaLoadingButton`, `SaInfoBanner`, `StickyPhotoHeader`, a live component catalogue (`apps/employee/lib/catalogue/`), 33 screen tests.

Defects this ADR must not inherit:

| # | Defect | Evidence |
|---|---|---|
| D1 | **Inter never loads.** `fontFamily: 'Inter'` is declared but no font asset is bundled and `GoogleFonts` is never called — every device falls back to its platform font. | `sales_associate_theme.dart:28`; no `fonts:` in any pubspec; `git grep GoogleFonts` = 0 |
| D2 | **Most components are private to `apps/employee`** (`_MetricCard`, `_SectionHeader`, `_buildStatusBadge`, `_ActionTile`, OTP boxes, order card). Reusing them today means copying them. | `apps/employee/lib/screens/**` |
| D3 | **Literals remain** outside the catalogue: 25 colour literals and ~105 raw numbers. | grep, §6 |
| D4 | Some `Icons.*` (Material) mixed with `SaIcons` (Lucide), e.g. Home tab `Icons.home_outlined`. | `employee_shell_screen.dart:106` |
| D5 | Screen copy is hardcoded English strings — no localisation layer. | all screens |
| D6 | The token set lacks motion, elevation, opacity, breakpoints, data-viz, avatar/thumbnail sizes, compact control heights, a pill radius. | `sales_associate_tokens.dart` |

### 1.3 The marketplace storefront (`/business/:id`)

`apps/marketplace/lib/screens/business/business_profile_screen.dart` (683 lines): cover banner, logo, stats, Follow, About, trust strip, category chips, paginated grid. Defects: shows inactive products (no `isActive` filter, line 98); category filter unreachable past page 1 (line 158); storefront fields editable **only by admin** (`apps/admin/.../edit_seller_screen.dart`); seller rating never computed. It stays on the **marketplace** emerald theme — it is a customer surface.

### 1.4 Backend reality the seller app depends on

- 27 source functions are **not live**, including every seller-used callable except `verifyRazorpayPayment`: `createRfq`, `submitRfqOffer`, `respondToRfqOffer`, `createOrderFromRfq`, `createSellerAiActivationOrder`, `connectSellerAiProvider`, `sellerAiChatProxy`, `disconnectAiProvider`, `confirmDelivery`, `quoteOrderWithCredit`, …
- 25 live functions still on `nodejs20` (decommission **2026-10-30**).
- `seller_payouts` rows are created **server-side** on delivery (`functions/src/customer/sellerNotifications.ts:332`); bank details are split to `seller_payout_details` (FIX-2; production migration still open).
- **P0 on develop (commit `9e77189`)**: client-side mock OTP with derivable passwords (`packages/agrimore_services/lib/auth/auth_service.dart:75`) and an unverified-email admin allowlist in `firestore.rules` `isAdmin()`. This ADR's auth design (§9) replaces it.

---

## 2. Design principles

These decide every ambiguous case. When two conflict, the lower number wins.

1. **Truth over polish.** No number, badge or claim without a server-backed source. A missing metric is hidden or labelled "Not enough data", never estimated. Money shown is money the ledger holds.
2. **Action first.** The first screen answers "what needs me right now?" — orders to accept before their deadline, quotes expiring, stock running out, payouts blocked. Vanity metrics come second.
3. **Every number explains itself.** Every KPI shows its period, its comparison (Δ vs previous period) and opens a breakdown on tap.
4. **Speed is a feature.** Perceived load < 1 s: skeletons shaped like content, cached last state, optimistic updates with undo. No full-screen spinners after first launch.
5. **One-handed, thumb-first.** Primary actions in the bottom 40 % of the screen; sticky bottom action bars on task screens; swipe actions on lists.
6. **Calm density.** Enterprise density without clutter: 4-pt grid, one accent colour, semantic colour only for meaning, generous section spacing, tabular numerals.
7. **Undo over confirm** — except money, irreversible state changes (reject order, cancel, disconnect key) and anything a buyer is notified about, which use a confirm sheet.
8. **Bharat-first.** Low bandwidth (thumbnails, pagination, offline persistence), large text up to 200 %, English / हिन्दी / தமிழ் ready, ₹ with Indian digit grouping (₹1,23,456).
9. **System, not screens.** A screen may only compose tokens and kit components. If something is missing, it is added to the system first (§6, §7).

---

## 3. Decision register (summary)

| ID | Decision | Status |
|---|---|---|
| ADR-S01 | Sales Associate = the canonical **system**; UX bar = tier-1 seller platform patterns | OWNER_DECISION 2026-09-23 |
| ADR-S02 | Generalise the SA theme into a **brand-parameterised Workspace theme**; SA = blue, Seller = **teal** | OWNER_DECISION 2026-09-23 (plan C) |
| ADR-S03 | Teal palette as specified in §5 | OWNER_DECISION 2026-09-23 (plan C) |
| ADR-S04 | **Zero literals** in `apps/seller/lib` — colours, spacing, radii, type, durations, icons **and user-visible strings** | OWNER_DECISION 2026-09-23 |
| ADR-S05 | Bundle Inter as a font asset; tabular figures for all money/quantities | TARGET |
| ADR-S06 | Lucide only, via one shared `AgIcons` set | TARGET |
| ADR-S07 | Promote SA private widgets to `agrimore_ui` as the shared **Workspace kit**; seller adds only what the kit lacks, in the kit | TARGET |
| ADR-S08 | 5-destination IA: **Home · Orders · Catalogue · Payments · Account**; Quotes inside Orders; Insights from Home | TARGET |
| ADR-S09 | Responsive: phone bottom bar → tablet rail + master-detail → desktop rail + multi-column | TARGET |
| ADR-S10 | Auth = phone OTP (server) + Google linked to a verified phone + email for legacy accounts | OWNER_DECISION 2026-09-23 (plan A1–A4) |
| ADR-S11 | Mock OTP only as a **server-side, allow-listed, expiring test mode**; client flag deleted | OWNER_DECISION 2026-09-23 (plan SEC-P0) |
| ADR-S12 | **One** onboarding path: the seller app's stepped application; marketplace "Apply" hands off to it | OWNER_DECISION 2026-09-23 (plan A5) |
| ADR-S13 | Order state changes through a **server callable state machine**, not client writes | TARGET |
| ADR-S14 | GST invoices numbered and issued **server-side** | TARGET |
| ADR-S15 | Payments screens show the server ledger; a "Withdraw" action exists only if D-SELLER-PAYOUT-MODEL chooses it | OPEN (§17) |
| ADR-S16 | All strings through Flutter `gen-l10n` ARB files; `en` first, `hi`, `ta` next | TARGET |
| ADR-S17 | Skeleton / empty / error / offline states are kit components, mandatory on every data screen | TARGET |
| ADR-S18 | Every screen ships golden tests (light, dark, 1.0× and 2.0× text) + a widget test | TARGET |
| ADR-S19 | Delete dead code and the marketplace's duplicate seller screens | TARGET |
| ADR-S20 | Seller may write only an allow-listed field set on their own public docs; proven by emulator rules tests | TARGET |

---

## 4. Foundation decisions — the canonical system

### ADR-S01 · The system vs the experience

**Context.** The owner wants the seller app to be "canonical exactly like the Sales Associate app" in *system* terms, but explicitly **not** a copy of its screens: the seller experience must reach the standard of the best 2026 marketplace seller apps.

**Decision.**
- *Inherit from SA:* the token architecture, naming, 4-pt spacing, radii, type scale, semantic colour pairs, dark-mode mechanism (`ThemeExtension` + `context` accessor), flat bordered cards, 52 px controls, 48 px targets, component-first rule, catalogue app, test discipline.
- *Do not inherit:* SA's screen layouts, its 4-tab IA, its visual density, its hardcoded copy, defects D1–D6.
- *Seller-specific experience* is defined in §8–§11 of this document.

**Consequence.** A reviewer checks a seller screen against **this ADR**, and checks a token or component against the **system**. Neither "looks like the SA app" nor "looks like app X" is an acceptance criterion.

### ADR-S02 · One Workspace theme, two brands

**Context.** Copying `SalesAssociateTheme` into a `SellerTheme` would duplicate ~470 lines and fork the system on day one (the `uiux` lane's `ZERO_NEW_WIDGETS` stop condition applies in spirit to themes too).

**Decision.** Refactor, without changing any SA pixel:

```
packages/agrimore_ui/lib/workspace/
  ws_foundation.dart      // brand-neutral: spacing, radii, type, motion, elevation, breakpoints, neutrals, semantics, data-viz
  ws_brand.dart           // enum WorkspaceBrand { salesAssociate, seller } + WsBrandPalette (primary set, light+dark)
  ws_tokens.dart          // class WorkspaceTokens extends ThemeExtension<WorkspaceTokens> (all colour roles)
  ws_theme.dart           // WorkspaceTheme.build(WorkspaceBrand, Brightness) -> ThemeData
  ws_icons.dart           // AgIcons (superset of SaIcons)
  ws_format.dart          // AgFormat: ₹ en_IN, compact numbers, dates, relative time, phone masking
  kit/                    // §7 components
```

Compatibility shims keep `apps/employee` compiling unchanged:

```dart
typedef SalesAssociateTokens = WorkspaceTokens;           // extension type alias
abstract final class SalesAssociateTheme {
  static ThemeData get lightTheme => WorkspaceTheme.build(WorkspaceBrand.salesAssociate, Brightness.light);
  static ThemeData get darkTheme  => WorkspaceTheme.build(WorkspaceBrand.salesAssociate, Brightness.dark);
}
// SaTokens stays as a facade re-exporting WsFoundation + the salesAssociate palette.
```

**Acceptance.** SA golden screenshots before/after are pixel-identical (apart from D1's font fix, which is a separate, announced change); `flutter analyze` 0 errors in all five apps; employee's 33 tests pass.

### ADR-S05 · Typography

- **Inter** bundled under `packages/agrimore_ui/assets/fonts/` (Regular 400, Medium 500, SemiBold 600, Bold 700) and declared in `agrimore_ui/pubspec.yaml` `fonts:`; referenced as `package: 'agrimore_ui'`. No runtime font download (offline, privacy, first-paint).
- **Numerals:** every money, quantity, count and ID uses `FontFeature.tabularFigures()` via the `ws.num*` text styles so columns align and values don't jitter while updating.
- **Scale** (SA's six, plus three the seller UX needs):

| Token | Size / line | Weight | Use |
|---|---|---|---|
| `displayHero` *(new)* | 40 / 48 | 600 | Single hero KPI on desktop Home |
| `displayAmount` | 32 / 40 | 600 | Balances, settlement totals |
| `screenTitle` | 24 / 32 | 600 | Screen headers |
| `sectionHeading` | 18 / 26 | 600 | Card and section titles |
| `titleSmall` *(new)* | 16 / 24 | 600 | List-item titles, order IDs |
| `body` | 16 / 24 | 400 | Paragraphs |
| `label` | 14 / 20 | 500 | Buttons, field labels, tabs |
| `caption` | 12 / 18 | 400 | Metadata, timestamps, helper text |
| `micro` *(new)* | 11 / 16 | 600, +0.4 tracking, uppercase | Overlines, chart axis, badge text |

### ADR-S06 · Iconography

One set, **Lucide outline**, via `AgIcons` (superset of the 20 `SaIcons`). `Icons.*` and `FontAwesomeIcons.*` are forbidden in `apps/seller/lib`. Sizes are tokens only: `iconSupporting 16`, `iconControl 20`, `iconNav 24`, `iconFeature 32` *(new)*, `iconEmpty 48` *(new)*. Seller additions (names are Lucide's): `house`, `package`, `packageCheck`, `packageX`, `truck`, `clipboardList`, `receiptIndianRupee`, `indianRupee`, `wallet`, `landmark`, `fileText`, `fileDown`, `barChart3`, `lineChart`, `trendingUp`, `trendingDown`, `boxes`, `tag`, `tags`, `percent`, `store`, `image`, `camera`, `scanLine`, `messageSquare`, `messagesSquare`, `star`, `users`, `settings2`, `sparkles`, `search`, `filter`, `arrowUpDown`, `plus`, `pencil`, `trash2`, `moreVertical`, `chevronRight`, `clock`, `timer`, `calendar`, `mapPin`, `shieldCheck`, `badgeCheck`, `alertTriangle`, `wifiOff`, `refreshCw`, `externalLink`, `languages`, `moon`, `sun`, `lifeBuoy`.

---

## 5. Teal token specification

All values are `TARGET_IMPLEMENTATION` for `WorkspaceBrand.seller`. Neutrals and semantics are **shared** with SA (foundation); only the brand palette differs, plus the additions marked *new*.

### 5.1 Brand palette — seller (teal)

| Role | Light | Dark | Notes |
|---|---|---|---|
| `primary` | `#0F766E` teal-700 | `#2DD4BF` teal-400 | Light: 5.5 : 1 on white (AA). Dark: 9.6 : 1 on `#0F172A`. Brighter light-mode teals fail AA with white text. |
| `primaryPressed` | `#115E59` teal-800 | `#5EEAD4` teal-300 | |
| `primarySubtle` | `#F0FDFA` teal-50 | `#042F2E` teal-950 | Selected rows, info-tinted surfaces |
| `primaryMuted` *(new)* | `#CCFBF1` teal-100 | `#134E4A` teal-900 | Selected chip fill, progress track |
| `onPrimary` *(new)* | `#FFFFFF` | `#042F2E` | Text/icon on a primary fill. **Dark mode uses dark text on bright teal.** |
| `focusRing` *(new)* | `#0F766E` @ 40 % | `#2DD4BF` @ 50 % | 2 px outside ring |

SA palette for comparison (unchanged): `primary #2563EB / #3B82F6`, `pressed #1D4ED8 / #60A5FA`, `subtle #EFF6FF / #172554`, `onPrimary #FFFFFF / #FFFFFF`.

### 5.2 Neutrals (shared foundation — from SA, unchanged)

| Role | Light | Dark |
|---|---|---|
| `pageBackground` | `#F8FAFC` | `#0F172A` |
| `surface` | `#FFFFFF` | `#1E293B` |
| `surfaceElevated` *(new in light)* | `#FFFFFF` + `elevation1` | `#334155` |
| `surfaceSunken` *(new)* | `#F1F5F9` | `#0B1222` |
| `textPrimary` | `#0F172A` | `#F8FAFC` |
| `textSecondary` | `#475569` | `#94A3B8` |
| `textTertiary` *(new)* | `#64748B` (4.55 : 1 on page) | `#8594AA` (4.75 : 1 on surface — slate-500 measured 3.07 and was rejected by the UI-TEAL-0 contrast test) |
| `divider` | `#E2E8F0` | `#334155` |
| `inputBorder` | `#64748B` | `#475569` |
| `disabledContainer` | `#E2E8F0` | `#334155` |
| `disabledContent` | `#94A3B8` | `#64748B` |
| `scrim` *(new)* | `#0F172A` @ 48 % | `#000000` @ 64 % |

### 5.3 Semantic pairs (shared)

| Role | Light fg / bg | Dark fg / bg |
|---|---|---|
| `success` | `#15803D` / `#F0FDF4` | `#4ADE80` / `#052E16` |
| `warning` | `#B45309` / `#FFFBEB` | `#FBBF24` / `#451A03` |
| `error` | `#B91C1C` / `#FEF2F2` | `#F87171` / `#450A0A` |
| `info` *(new — needed now primary is not blue)* | `#1D4ED8` / `#EFF6FF` | `#60A5FA` / `#172554` |

### 5.4 Order / listing status mapping (semantic, not decorative)

| Status | Pair |
|---|---|
| New / Pending acceptance | `warning` |
| Accepted / Packing / Ready | `info` |
| Out for delivery / In transit | `info` |
| Delivered / Settled / Active / Approved | `success` |
| Cancelled / Rejected / Failed / Suspended | `error` |
| Draft / Inactive / Expired | neutral (`surfaceSunken` / `textSecondary`) |
| In review | `primarySubtle` / `primary` |

### 5.5 Data-visualisation palette *(new)*

Ordered series colours, validated for adjacency contrast in both themes. Series 1 is always the brand.

| # | Light | Dark |
|---|---|---|
| 1 | `#0F766E` | `#2DD4BF` |
| 2 | `#2563EB` | `#60A5FA` |
| 3 | `#B45309` | `#FBBF24` |
| 4 | `#7C3AED` | `#A78BFA` |
| 5 | `#BE123C` | `#FB7185` |
| 6 | `#475569` | `#94A3B8` |

Positive delta = `success.fg`, negative = `error.fg`, gridlines = `divider`, axis text = `micro` in `textSecondary`. Never encode meaning by colour alone — deltas also carry ▲/▼ glyphs (Lucide `trendingUp/Down`).

### 5.6 Spacing, size, shape

| Group | Tokens |
|---|---|
| Spacing (4-pt) | `space2`*, `space4`, `space8`, `space12`, `space16`, `space20`*, `space24`, `space32`, `space40`*, `space48`, `space64`* |
| Layout | `pagePadding 20` (phone) · `pagePaddingTablet 24`* · `pagePaddingDesktop 32`* · `contentMaxWidth 1280`* · `formMaxWidth 560`* |
| Controls | `controlHeight 52` · `controlHeightCompact 40`* (dense tables, filter chips) · `minTouchTarget 48` · `chipHeight 32`* |
| Radii | `radiusSmall 8`* (badges, thumbnails) · `radiusInput 12` · `radiusCard 16` · `radiusBottomSheet 24` · `radiusPill 999`* |
| Sizes | `hairline 1`* · `avatarSm 32`* · `avatarMd 40`* · `avatarLg 64`* · `thumbSm 48`* · `thumbMd 64`* · `thumbLg 96`* · `bottomBarHeight 64`* · `railWidth 88`* · `railWidthExpanded 256`* |

\* = new token.

### 5.7 Elevation, opacity, motion, breakpoints *(all new)*

| Group | Tokens |
|---|---|
| Elevation (shadow) | `elevation0` none (cards are flat + `divider` border, as SA) · `elevation1` y1 blur3 `#0F172A`@6 % (sticky bars) · `elevation2` y4 blur12 @8 % (menus, popovers) · `elevation3` y12 blur32 @12 % (sheets, dialogs). Dark mode uses surface steps, not shadows. |
| Opacity | `opacityDisabled .38` · `opacityHover .08` · `opacityPressed .12` · `opacityScrim .48` |
| Motion — duration | `durInstant 80` · `durFast 120` · `durStandard 200` · `durEmphasized 320` · `durSlow 480` (ms) |
| Motion — curve | `curveStandard = Cubic(.2,0,0,1)` · `curveEnter = Cubic(0,0,0,1)` · `curveExit = Cubic(.3,0,1,1)` |
| Breakpoints | `bpCompact < 600` (phone) · `bpMedium 600–839` (small tablet) · `bpExpanded 840–1199` (tablet / small web) · `bpLarge ≥ 1200` (desktop web) |
| Haptics | `hapticSelection` (tab, chip) · `hapticSuccess` (order accepted) · `hapticWarning` (destructive confirm) |

Reduced motion (`MediaQuery.disableAnimations`) → all durations collapse to `durInstant`, no parallax, no count-up animations.

---

## 6. The zero-literal rule and its enforcement

### ADR-S04 · Rule

Inside `apps/seller/lib/**` (generated `lib/l10n/**` excepted), a screen or widget may not contain:

| Forbidden | Use instead |
|---|---|
| `Color(0x…)`, `Colors.<anything>` except `Colors.transparent` | `context.ws.<role>` |
| Numeric literals in `EdgeInsets`, `SizedBox`, `Padding`, `Gap`, `BorderRadius`, `Radius`, `BoxConstraints`, `width:`/`height:` | `WsSpace.*`, `WsSize.*`, `WsRadius.*` |
| `TextStyle(` constructors, `fontSize:`, `fontWeight:`, `letterSpacing:`, `height:` on text | `context.text.<role>` (Theme `textTheme` + `ws` numeric styles) |
| `Duration(milliseconds: n)` for UI motion, raw `Curves.*` | `WsMotion.*` |
| `Icons.*`, `FontAwesomeIcons.*`, `CupertinoIcons.*` | `AgIcons.*` |
| `BoxShadow(` | `WsElevation.*` |
| `Text('…')`, `label: '…'`, `hintText: '…'`, `title: '…'`, snackbar/dialog strings | `context.l10n.<key>` |
| `NumberFormat(`/`DateFormat(` in screens | `AgFormat.*` |
| `ThemeData(` anywhere in the app | `WorkspaceTheme.build(WorkspaceBrand.seller, …)` |

**Allowed literals:** `0`, `1` only as a flex factor, `double.infinity`, `Colors.transparent`, list indices, and values inside `agrimore_ui/lib/workspace/**` (the system itself).

### Enforcement

1. **`canon_check.sh`** (new, in `.claude/skills/agrimore/scripts/`, called by `gate.sh` for any change touching `apps/seller/lib`): ripgrep patterns for every forbidden row above; prints `path:line  rule`; **exit 1 on any hit**. Baseline at adoption = the measured 373 + 561 + string count; the phase that migrates a screen must bring that screen to 0, and the total may never rise.
2. **Analyzer**: `analysis_options.yaml` for the seller app enables `prefer_const_constructors`, `avoid_hardcoded_color`-equivalent via the custom check above (no plugin dependency), `require_trailing_commas`.
3. **Review**: the `uiux` lane report must list `canon_check` output = 0 for touched files.
4. **The SA app** is brought to the same rule in a separate, small phase (defect D3) so the "canonical" reference is itself clean.

---

## 7. Component kit

### ADR-S07 · Promote, then extend — in the package

**Promotion** (from `apps/employee` private widgets → `packages/agrimore_ui/lib/workspace/kit/`, renamed `Ws*`, SA screens updated to import them; five-app analyze):

| Kit component | Source today | Notes |
|---|---|---|
| `WsButton` | `SaLoadingButton` | variants: primary · secondary (outlined) · tertiary (text) · destructive · tonal*; sizes standard/compact; loading, icon, full-width |
| `WsBanner` | `SaInfoBanner` | info · success · warning · error; optional title, action |
| `WsMetricCard` | employee `_MetricCard` | + Δ vs previous period, optional sparkline, tap → breakdown |
| `WsSectionHeader` | employee `_SectionHeader` | title + optional count + trailing action ("View all") |
| `WsStatusBadge` | employee `_buildStatusBadge` | driven by §5.4 mapping, never a free colour |
| `WsActionTile` | employee `_ActionTile` | icon, title, subtitle, trailing chevron/value/switch |
| `WsOtpInput` | employee OTP boxes | 6 cells, paste, SMS autofill (Android SMS Retriever), error shake |
| `WsStickyPhotoHeader` | `StickyPhotoHeader` | unchanged API |

**New kit components** the seller UX needs (each with a catalogue entry, all states, light/dark goldens):

| Component | Purpose |
|---|---|
| `WsAppBar` / `WsLargeTitleAppBar` | Collapsing large title, search affordance, actions ≤ 2 + overflow |
| `WsNavShell` | Bottom bar (compact) / `NavigationRail` (medium+) / expanded rail (large); badges; FAB slot |
| `WsSearchField` / `WsSearchScreen` | Debounced search, recent searches, scoped results groups |
| `WsFilterBar` | Horizontally scrolling chips + "Filters" sheet + active-filter count + clear |
| `WsSegmented` | 2–4 segment control (e.g. Orders · Quotes · Returns) |
| `WsTabsWithCounts` | Pipeline tabs with live count pills |
| `WsListItem` family | `WsOrderItem`, `WsProductItem`, `WsQuoteItem`, `WsLedgerItem`, `WsNotificationItem` — fixed anatomy, swipe actions, selection mode |
| `WsDataTable` | Desktop/tablet dense table: sortable columns, sticky header, row selection, pagination |
| `WsActionQueueCard` | Home "needs you now" items with SLA countdown |
| `WsCountdown` | Deadline chip: neutral > 2 h, warning ≤ 2 h, error overdue |
| `WsTimeline` | Vertical status timeline (order, application, payout) |
| `WsStepper` | Multi-step form header (step x of n, titles, completion) + sticky footer nav |
| `WsFormField` family | text, number, currency (₹, en_IN), phone (+91), dropdown, date/range, switch, radio group, image picker/gallery, document upload with progress |
| `WsBottomSheet` / `WsConfirmSheet` | Standard sheet; destructive confirm with reason list |
| `WsDialog` | Rare, blocking only |
| `WsSnack` | Replaces `SnackBar(` and `SnackbarHelper` in seller: success/info/error + Undo |
| `WsSkeleton` | Shimmer-free pulse skeletons per list-item family and card |
| `WsEmptyState` | Illustration-free: `iconEmpty` + title + body + primary action |
| `WsErrorState` | Message + retry + support link |
| `WsOfflineBanner` | Connectivity + "showing saved data from 10:42" |
| `WsChart` family | `WsLineChart`, `WsBarChart`, `WsDonut`, `WsSparkline` on `fl_chart`, tokenised (§5.5), accessible summaries |
| `WsKpiStrip` | Horizontal scroll of `WsMetricCard`s with period selector |
| `WsPeriodSelector` | Today · 7D · 30D · 3M · 6M · 1Y · Custom |
| `WsScoreRing` | 0–100 score (listing quality, account health) with band colour |
| `WsProgressChecklist` | Onboarding / setup tasks with completion % |
| `WsImageGallery` | Product/storefront media: reorder, crop 1:1/16:9, primary badge |
| `WsMoneyBreakdown` | Line items → total (order earnings, settlement) with tabular figures |
| `WsIdCard` | Account hub header: logo, shop name, seller ID copy, verified state |
| `WsChatBubble` / `WsComposer` | AI copilot + quote thread |
| `WsTestModeRibbon` | Persistent ribbon when server test-mode OTP is active (§9.3) |

Rule: **a component may only be created in the kit.** `apps/seller/lib/widgets/` may contain *compositions* (e.g. `OrderPipelineList`) built solely from kit components.

---

## 8. Information architecture & navigation

### ADR-S08 · Destinations

```
Home        Command centre · Insights · Notifications · Global search
Orders      [Orders | Quotes | Returns]  pipeline tabs, detail, invoices
Catalogue   Listings pipeline · Product editor · Inventory health · Bulk edit
Payments    Overview · Ledger · Settlement detail · Payout account · Statements
Account     Store profile (ID card) · Storefront · Reviews · Followers & posts ·
            Delivery & hours · Notification prefs · AI Copilot · Help · Settings
```

- **Global create (+)**, top-right on phone Home / Catalogue, rail FAB on tablet/web: *Add product · New post · Share store link*.
- **Global search** (Home app bar, `/` shortcut on web): order ID, buyer name/phone (masked), product name/SKU, quote ID.
- **Notifications bell** with unread count on every top-level app bar.
- Quotes live inside Orders because a quote is a pre-order; a live-quote count also appears in Home's action queue.

### ADR-S09 · Responsive layouts

| Width | Navigation | Content |
|---|---|---|
| `< 600` | Bottom bar, 5 items, labels always shown | Single column, sticky bottom action bar on task screens |
| `600–839` | Bottom bar | Wider cards, 2-column grids for metrics |
| `840–1199` | `NavigationRail` (88) + FAB | **Master-detail** for Orders, Quotes, Catalogue, Ledger (list 360–400 + detail) |
| `≥ 1200` | Expanded rail (256) with section labels | Home = 12-column dashboard; lists become `WsDataTable`; detail in side panel; keyboard shortcuts |

The seller app ships a **web** target (`apps/seller/web`): desktop is a first-class seller workspace, not a stretched phone.

### Route map

```
/                         → AuthGate
/login  /login/otp  /login/email  /login/google-link
/apply  /apply/:step  /application-status  /account-restricted
/home  /home/insights/:tab  /notifications  /search
/orders?tab=  /orders/:id  /orders/:id/invoice  /quotes/:id  /returns/:id
/catalogue?tab=  /catalogue/new  /catalogue/:id  /catalogue/:id/edit/:step  /catalogue/bulk  /inventory
/payments  /payments/ledger  /payments/settlements/:id  /payments/account  /payments/statements
/account  /account/storefront  /account/reviews  /account/network  /account/network/new
/account/delivery  /account/notifications  /account/copilot  /account/copilot/connect
/account/help  /account/settings
```

Deep links from push notifications open the exact route (e.g. `orders/:id`).

---

## 9. Authentication & onboarding architecture

### ADR-S10 · Methods

1. **Phone + OTP (primary).** `sendPhoneOTP` → `verifyPhoneOTP` Cloud Functions → **custom token** for the user's real UID (`functions/src/common/verifyPhoneOTP.ts:214`) — the same server path the marketplace uses. Voice channel fallback retained (TRAI DLT still open, D-DLT).
2. **Google (secondary), phone-gated.** Mirrors marketplace AUTH-3: Google credential → `resolveGoogleIdentity` (live) → if linked to an existing UID, sign in; otherwise require phone OTP first, then link Google to that UID. Google alone never creates a seller.
3. **Email + password (legacy only).** For admin-created sellers that have no phone login yet; offered as "Sign in with email" link, with reset. New sellers are never offered email sign-up.

### ADR-S11 · Test-mode OTP (replaces the client mock)

`TARGET_IMPLEMENTATION` (phase SEC-P0):

- Delete `AuthService.kDevMockPhoneOtp`, `_devMockOtpStore`, the derived-password sign-in and the hardcoded personal mapping from `packages/agrimore_services/lib/auth/auth_service.dart`.
- Config doc `auth_test_mode/config`: `{ enabled: true, allowlist: [E.164], expiresAt: Timestamp }`. Rules: `allow read, write: if false` for every client, admins included — edited only in the Firebase Console / Admin SDK, because whoever can write it can sign in as any allow-listed number (implemented in SEC-P0; deliberately stricter than an admin-writable `settings/` doc). The window may not exceed 7 days; there is no "allow everyone" switch.
- `sendPhoneOTP`: generates and stores the OTP hash **exactly as the real path**; if `enabled && now < expiresAt && phone ∈ allowlist`, skips the SMS/voice provider and returns `{ testOtp: "123456", testMode: true }` in the response. Otherwise unchanged.
- `verifyPhoneOTP`: **unchanged** — verification, UID resolution and custom token are identical in test and real mode, so there are no duplicate accounts and no passwords.
- Client: when `testMode` is true, `WsOtpInput` autofills and `WsTestModeRibbon` is shown for the session. Works in release builds only for allow-listed numbers during the window.
- Audit: each test-mode send writes `auth_test_mode_log/{id}` (`phoneMasked`, `channel`, `createdAt` — never the code), closed to all clients.

### ADR-S12 · One onboarding path

| Step | Screen | Writes |
|---|---|---|
| 0 | Sign in with phone (verified) | Auth user; `users/{uid}` (role `user`) via existing server path |
| 1 | Business: shop name, owner name, category focus, GSTIN (optional/required per `settings/seller_onboarding.gstRequired`) | draft in `sellerRequests/{uid}` |
| 2 | Location & coverage: address, pin, map pin, delivery radius | same doc |
| 3 | Documents (KYC): GST certificate, ID proof, shop photo | Storage `seller_kyc/{uid}/…` (owner write, admin read) |
| 4 | Payout account: bank (IFSC lookup) or UPI | `seller_payout_details/{uid}` (private, FIX-2 shape) |
| 5 | Review & submit | callable `submitSellerApplication` → status `pending`, notifies admin |

- Drafts autosave per step; the stepper resumes where the seller left off.
- Admin approval (existing admin flow, aligned to this shape) creates/updates `sellers/{uid}` (public profile) and sets the `seller` custom claim (`syncSellerRoleClaims`, live).
- `apps/marketplace` "Become a seller" (`seller_apply_screen.dart`, `seller_panel_screen.dart`, `seller_dashboard_screen.dart`, marketplace `seller_provider.dart`) is replaced by a single hand-off card: Play Store link on Android, seller web URL on web.
- `createSellerByAdmin` remains for assisted onboarding and writes the **same** shape.

### Auth gate states

| Condition | Route |
|---|---|
| No Firebase user | `/login` |
| User, no `sellerRequests/{uid}` and no `sellers/{uid}` | `/apply` |
| `sellerRequests.status == draft` | `/apply/:lastStep` |
| `pending` | `/application-status` (timeline) |
| `rejected` | `/account-restricted?reason=rejected` (reason + fix + resubmit) |
| `sellers.status == suspended` | `/account-restricted?reason=suspended` (reason + support) |
| `approved` **and** claim `role == seller` | `/home` |

The claim, not a Firestore read, is the gate of record; Firestore status supplies the copy.

---

## 10. Screen catalogue — every screen, specified

Format per screen: **Purpose · Layout (phone → desktop) · Content blocks · Actions · States · Data · Gaps closed**. All copy shown is illustrative and lives in ARB files. All colours/sizes are tokens.

### 10.1 Auth & onboarding (`A-*`)

**A-01 Sign in** · *Purpose:* fastest trustworthy entry.
```
┌──────────────────────────────┐
│  [store]  AgriMore Seller    │  ← wordmark lockup (brand asset)
│                              │
│  Sell to farms & families    │  screenTitle
│  across your district        │  body/secondary
│                              │
│  Mobile number               │
│  ┌──┬───────────────────────┐│
│  │+91│ 98xxx xxxxx           ││  WsFormField.phone
│  └──┴───────────────────────┘│
│  [      Get OTP      ]       │  WsButton.primary
│  ─────────── or ──────────── │
│  [ G  Continue with Google ] │  WsButton.secondary
│  Sign in with email          │  tertiary link (legacy)
│                              │
│  By continuing you agree to  │  caption + links
│  Terms · Privacy             │
└──────────────────────────────┘
```
Desktop: split layout — left brand panel (`primarySubtle` surface, three value props with `AgIcons`), right form card `formMaxWidth`. States: invalid number inline error; rate-limited (`PhoneOtpRateLimitException`) banner with countdown; OTP provider unavailable banner with voice fallback. · Gaps 1, 2, 4.

**A-02 Verify OTP** · `WsOtpInput`, masked number with "Change", resend countdown, "Get a call instead", `WsTestModeRibbon` + autofill when server says test mode. Error: shake + message; 5 failures → cool-down banner. · Gaps 1, 3.

**A-03 Link Google** · When Google identity is not linked: explains "Verify your mobile once to link Google", then A-01/A-02 in link mode. · Gap 2.

**A-04 Sign in with email (legacy)** · Email + password, show/hide, "Forgot password" → reset-link sheet, banner nudging to add phone login after sign-in. · Gap 4.

**A-05 Application stepper** (`/apply/:step`) · `WsStepper` 5 steps (§9 ADR-S12), sticky footer *Back · Save & continue*, autosave toast, per-step validation summary. Step 3 uses document upload with progress, retry, file-type/size limits (`image/*`, `application/pdf`, ≤ 10 MB). Step 4 validates IFSC via lookup and masks account number after entry. Desktop: stepper as left rail, form centre, "Why we ask" help panel right. · Gaps 5, 6, 9, 31.

**A-06 Application status** · `WsTimeline`: Submitted → Documents verified → Approved (+ timestamps), expected review time (config-driven, hidden if absent), "Edit application" while pending, support card, sign out. Pull to refresh; push notification on decision. · Gap 7.

**A-07 Account restricted** · Variants *rejected* (reason list from admin, fix-and-resubmit CTA) and *suspended* (reason, what it affects — listings hidden, orders paused — support contacts, appeal). · Gap 8.

### 10.2 Home (`H-*`)

**H-01 Command centre** · *Purpose:* "what needs me now, and how is my business doing".
```
┌──────────────────────────────┐
│ Good morning, Ravi Stores  🔔3│  greeting + bell
│ [🔍 Search orders, products ]│  WsSearchField (opens H-03)
│                              │
│ NEEDS YOU NOW          (5)   │  micro overline + count
│ ┌──────────────────────────┐ │
│ │ 3 orders to accept        │ │  WsActionQueueCard
│ │ ⏱ first due in 42 min  >  │ │  WsCountdown (warning)
│ ├──────────────────────────┤ │
│ │ 1 quote expires today   > │ │
│ │ 4 products low on stock > │ │
│ └──────────────────────────┘ │
│                              │
│ TODAY   [Today|7D|30D|…]     │  WsPeriodSelector
│ ┌────────┐┌────────┐┌──────┐ │  WsKpiStrip (scroll)
│ │₹18,450 ││ 23     ││ ₹802 │ │  sales · orders · AOV
│ │▲12% vs ││▲4      ││▼3%   │ │  Δ vs previous period
│ │~~~~~~~ ││~~~~~~~ ││~~~~~ │ │  sparkline
│ └────────┘└────────┘└──────┘ │
│                              │
│ Account health   86 ◔  Good >│  WsScoreRing → H-05
│ Next settlement  ₹12,300  Fri>│  → Payments
│                              │
│ Set up your store  3/6  ▓▓░  │  WsProgressChecklist (hidden at 100%)
│ Top products this week    >  │  3 WsProductItem rows
│ ✦ Copilot: "Tomatoes sold 2× │  AI insight card (only if connected)
│   faster on Saturdays…"      │
└──────────────────────────────┘
```
Desktop: 12-col grid — action queue (5 col) | KPI cards 2×2 (7 col); sales chart (8) | health + settlement (4); top products table (12). · Data: counts from `orders` by `sellerId`+status (aggregate `count()`), `rfqs` by seller + expiry, `products` by `stock <= lowStockThreshold`; KPIs from orders in period (server rollup `seller_stats_daily/{sellerId}_{yyyyMMdd}` — see §12.2). · States: skeleton per block; each block fails independently with inline retry. · Gaps 10, 11, 13.

**H-02 Notifications** · Grouped Today / Earlier; categories filter (Orders, Quotes, Payments, Catalogue, Account); unread dot; swipe to mark read; "Mark all read"; each item deep-links. Data `users/{uid}/notifications`. · Gap 12.

**H-03 Global search** · Recent searches; result groups Orders / Products / Quotes; order ID exact match jumps straight to detail. · Gap 21.

**H-04 Insights** (`/home/insights/:tab`) · Tabs *Overview · Sales · Products · Customers*. `WsPeriodSelector` incl. custom range; `WsLineChart` sales vs previous period; `WsBarChart` orders by status; top/bottom products table with sell-through; repeat vs new buyers; B2B vs retail split; export CSV (web) / share (phone). Every chart has a text summary for screen readers. · Gap 11.

**H-05 Account health** · Score 0–100 from transparent inputs: acceptance within SLA, cancellation rate, on-time handover, listing quality average, response time on quotes, rating. Each input: value, target, trend, "how to improve". Only inputs with data are shown and weighted. · Gaps 10, 35.

### 10.3 Orders (`O-*`, `Q-*`)

**O-01 Orders pipeline**
```
┌──────────────────────────────┐
│ Orders            🔍  ⋯      │
│ [ Orders | Quotes | Returns ]│  WsSegmented
│ New 3 · To pack 5 · Ready 2 ·│  WsTabsWithCounts (scroll)
│ In transit 4 · Delivered ·…  │
│ [All] [B2B] [Retail] [Today▾]│  WsFilterBar
│ ┌──────────────────────────┐ │
│ │ #AGR-10231   New   ⏱ 38m │ │  WsOrderItem
│ │ 3 items · ₹1,240 · Retail │ │
│ │ Madurai · 4.2 km          │ │
│ │ [Reject]        [Accept]  │ │  inline actions on New tab
│ └──────────────────────────┘ │
│ … (swipe → Accept / Reject)  │
│ ─────────────────────────────│
│ [☐ Select]  Accept all (3)   │  selection mode, sticky bar
└──────────────────────────────┘
```
Tablet/desktop: master-detail / `WsDataTable` (ID, placed, items, amount, type, SLA, status) with bulk *Accept*, *Mark packed*, *Download invoices*. Realtime stream per tab, paginated 20. Empty per tab with helpful copy. · Gaps 19, 20, 21.

**O-02 Order detail**
```
│ ← #AGR-10231        ⋯        │
│ New · Accept within ⏱ 38 min │  WsBanner(warning) + WsCountdown
│ ── Timeline ─────────────────│  WsTimeline
│ ● Placed 10:02  ○ Accepted   │
│ ○ Packed  ○ Handed over  ○ Delivered
│ ── Items (3) ────────────────│  WsProductItem compact + qty × price
│ ── Buyer ────────────────────│  name, masked phone, [Call] [Chat]
│ ── Delivery ─────────────────│  address, distance, slot, partner (when assigned)
│ ── Your earnings ────────────│  WsMoneyBreakdown: item total, platform fee,
│                              │  delivery fee share, tax, = You receive
│ ── Documents ────────────────│  GST invoice (after acceptance) → O-04
├──────────────────────────────┤
│ [Reject]   [Accept order]    │  sticky action bar (state-dependent)
```
Next action by state: *Accept* (pending) → *Mark packed* (accepted) → *Ready for pickup* (packed) → read-only while partner delivers (`confirmDelivery` is the partner's). All transitions call `sellerTransitionOrder` (§12.1), optimistic with rollback. · Gaps 19, 20, 22, 24, 32.

**O-03 Reject / cancel sheet** · `WsConfirmSheet` with required reason list (out of stock, can't deliver to area, price error, other + note), consequence line ("Buyer will be refunded and notified"), destructive button. · Gap 23.

**O-04 GST invoice** · Preview (PDF render), invoice number, GSTIN of both parties when present, HSN, tax split CGST/SGST/IGST, *Download* / *Share*. Issued by `issueGstInvoice` (§12.1). · Gap 22.

**O-05 Returns** · List and detail for return/refund requests: reason, photos, decision (approve pickup / reject with reason), timeline. Backed by the existing order cancellation/refund fields; new return states only if §17 D-RETURNS decides. · Gap 23.

**Q-01 Quotes inbox** (Orders → Quotes) · Tabs *Needs response · Negotiating · Accepted · Closed*; `WsQuoteItem` (buyer business, product, qty, target price, expiry countdown). · Gaps 25, 26.

**Q-02 Quote thread** · Header summary (product, qty, buyer's target); chronological offers as `WsChatBubble` cards (price × qty = total, notes, who/when); expiry; actions *Counter · Accept · Decline*; after acceptance: "Buyer can place order" state and link to the created order. Share quote → `threads` chat message with a quote card. · Gaps 26, 27, 28.

**Q-03 Counter-offer sheet** · Price, quantity, validity, note; live total and margin hint vs listed B2B price. · Gap 26.

### 10.4 Catalogue (`C-*`)

**C-01 Listings** · Tabs *Active · Draft · In review · Out of stock · Inactive* with counts; `WsProductItem` (thumb, name, variant count, price, stock, quality score badge, status); filter/sort (stock, price, updated, quality); swipe *Edit stock*; selection mode → bulk *Activate / Deactivate / Edit price & stock*. Desktop: `WsDataTable` with inline stock/price edit. · Gaps 16, 17.

**C-02 Product (seller view)** · Media carousel, status + approval banner (why in review / why rejected), quality score with checklist (images ≥ 3, description length, category, unit, B2B price), performance (views, add-to-cart, units sold, revenue for period — shown only when tracked, §12.2), variants table, coverage summary, *Edit* / *Preview as buyer* / overflow *Duplicate · Deactivate · Delete*. · Gaps 16, 18.

**C-03 Product editor** (`WsStepper`, 7 steps, drafts autosave)
1. **Basics** — search master catalogue first (`masterProducts`, existing mapping `product_price_mappings`), else name, category (tree picker), brand, unit.
2. **Media** — `WsImageGallery` (camera/gallery, crop 1:1, reorder, primary), guidance.
3. **Price & tax** — MRP, sale price, live discount %, GST rate, HSN, mapped-price reset (existing).
4. **Stock & variants** — single or variants (size/weight/pack); per-variant price/stock/SKU/image; low-stock threshold.
5. **Coverage & delivery** — full state / district / radius (existing), map preview.
6. **B2B** — B2B price, MOQ, tier pricing (optional), "accept quotes" toggle.
7. **Review** — rendered preview as buyer, quality score, *Submit for review* / *Save draft*.

Desktop: two-pane — form left, live buyer preview right. Replaces the 1,357-line `add_product_screen.dart` with one file per step. · Gaps 14, 15.

**C-04 Bulk edit** · Spreadsheet-style grid (desktop) / stacked editable rows (phone) for price & stock; validation per cell; review diff; apply as batch. · Gap 17.

**C-05 Inventory health** · Out of stock, low stock, slow movers, days-of-cover estimate *only when sales history exists*; quick restock inline. · Gap 13.

### 10.5 Payments (`P-*`)

**P-01 Payments overview**
```
│ Payments                     │
│ Next settlement              │  micro
│ ₹12,300.00                   │  displayAmount, tabular
│ Scheduled Fri, 26 Sep · 14 orders ›
│ ┌──────────┐┌──────────┐     │
│ │Pending   ││Paid (30D)│     │  WsMetricCard
│ │₹4,820    ││₹61,200   │     │
│ └──────────┘└──────────┘     │
│ Payout account  HDFC ••4821 ✓│  → P-04 (warning banner if missing/unverified)
│ RECENT                       │
│ Settlement #S-221  ₹9,880  Paid ›
│ Order #10231  +₹1,116  Pending ›
│ [ View ledger ]  [ Statements ]
```
Data: `seller_payouts` where `sellerId == uid` (server-created), `seller_payout_details/{uid}` (masked). **No "Withdraw" button** unless D-SELLER-PAYOUT-MODEL decides seller-initiated withdrawals (ADR-S15). · Gaps 29, 30.

**P-02 Ledger** · Filterable (period, type: order credit / fee / refund reversal / settlement), running balance, `WsLedgerItem`s, export. · Gap 30.

**P-03 Settlement detail** · `WsTimeline` (Created → Processing → Paid, UTR/reference when present), included orders with per-order `WsMoneyBreakdown`, destination (masked). · Gaps 30, 32.

**P-04 Payout account** · Bank (account holder, number ×2 confirm, IFSC lookup → bank/branch) or UPI ID; verification status; change requires OTP re-verification. Writes `seller_payout_details/{uid}` only. · Gap 31.

**P-05 Statements & tax** · Monthly statement PDFs, GST summary (tax collected per rate) for the period, TDS/TCS lines only if the server computes them. · Gaps 22, 30.

### 10.6 Account (`M-*`)

**M-01 Account hub** · `WsIdCard` (logo, shop name, seller ID with copy, verified badge, member since, rating when it exists), grouped `WsActionTile` sections: *Store* (Storefront, Reviews, Followers & posts, Delivery & hours) · *Business* (Documents & GST, Payout account) · *Tools* (AI Copilot, Notifications) · *Support* (Help) · *App* (Settings, About). Sign out at bottom with confirm. · Gaps 38, 42.

**M-02 Storefront editor** · Cover (16:9 crop), logo (1:1), description (500 chars, counter), highlights (up to 3 short tags), live **Preview as buyer** rendering the marketplace storefront layout. Writes only allow-listed fields on `sellers/{uid}` (§12.3) + Storage `sellers/{uid}/…` (seller-owned path, new rule). · Gaps 33, 34, 37.

**M-03 Reviews** · Rating summary (distribution bars), filter by stars/product/unanswered, reply composer (one public reply per review, editable 24 h), report review. Rating computed server-side (`SELLER-METRICS-1`). · Gap 35.

**M-04 Followers & posts** · Follower count and trend; post list (reach when tracked), edit/delete; *New post* → M-05. Data `follows`, `business_posts`. · Gap 36.

**M-05 Post composer** · Text, photo, optional product tag, preview, publish. Replaces `create_post_screen.dart`. · Gap 36.

**M-06 Delivery & hours** · Weekly hours grid with breaks and holiday closures, "Accepting orders" master switch, delivery radius with map, delivery-fee (flat / slab — existing `delivery_fee_sheet.dart` logic moved to a full screen). · Gap 39.

**M-07 Notification preferences** · Per category push toggles (new orders, quotes, payments, stock alerts, reviews, announcements), quiet hours; stored `users/{uid}/settings/notifications`, respected by the sending functions. · Gaps 40, 48.

**M-08 AI Copilot** · Chat (`WsChatBubble`, streaming), suggested prompts tied to seller data ("Which products should I restock?"), sources line ("Based on your last 30 days of orders"), seller-scoped only. Not-connected state → M-09. · Gap 43.

**M-09 AI connection** · Existing ₹50 activation + BYO key flow restyled; provider picker, key field (never re-displayed), status, disconnect confirm. · Gap 43.

**M-10 Help & support** · Search FAQs, categories, contact cards (call / email / WhatsApp from `agrimore_core` support constants), ticket-less "Report a problem" with auto-attached app version and seller ID. · Gap 41.

**M-11 Settings** · Theme (System/Light/Dark), language (English / हिन्दी / தமிழ் when shipped), text size preview, data saver (thumbnails only), app version/build, licences, legal. · Gap 42.

### 10.7 System (`X-*`)

**X-01 Launch** · Native splash only (no Flutter splash delay), brand mark on `pageBackground`. **X-02 Offline** · `WsOfflineBanner` everywhere + cached data; writes queued with "Will sync" chip. **X-03 Update required** · Blocking screen when `settings/app_versions.sellerMin` > installed build.

---

## 11. Cross-cutting behaviour

| Topic | Rule |
|---|---|
| **Loading** | First paint from cache; `WsSkeleton` matching the list-item family; never a centred spinner after launch. |
| **Empty** | `WsEmptyState` with a next action ("Add your first product"). Filtered-empty differs from truly-empty ("No orders match — Clear filters"). |
| **Errors** | Block-level `WsErrorState` with retry; never raw exception text (`e.toString()` forbidden in UI). Permission-denied → "You don't have access to this" + support. |
| **Feedback** | One mechanism: `WsSnack` (success/info/error, optional Undo, 4 s) — replaces mixed `SnackBar(` / `SnackbarHelper` / `AlertDialog` use. Confirmation only per principle 7. |
| **Optimism** | Stock edits, mark-read, toggles: optimistic + rollback + error snack. Money and order transitions: wait for the callable, button shows loading. |
| **Realtime** | Orders `New` tab and quote threads stream; other lists page with pull-to-refresh. New order while in app → top banner + haptic + sound (per prefs). |
| **Formatting** | `AgFormat.rupees` (`₹1,23,456.00`, en_IN), `AgFormat.compact` (`₹1.2L`, `₹3.4Cr`), dates `26 Sep`, times `10:02 am`, relative "12 min ago", phone masked `98••• ••321`. |
| **Localisation** | `gen-l10n`, `lib/l10n/app_en.arb` first; keys namespaced `orders.accept.cta`; plurals/ICU for counts; no string concatenation. |
| **Accessibility** | 48 px targets, 4.5 : 1 text contrast (3 : 1 ≥ 24 px), text scale to 200 % without clipping (goldens at 2.0×), semantic labels on icon buttons, charts with text summaries, focus order = visual order, visible focus ring on web, no colour-only meaning. |
| **Keyboard (web)** | `/` search, `g o` orders, `g c` catalogue, `a` accept (on selected new order), `?` shortcut sheet. |
| **Performance** | Thumbnails via sized URLs, `cached_network_image`, list item `const` constructors, pagination 20, Firestore offline persistence on, cold start budget < 2.5 s on Pixel 8-class, jank < 1 % frames. |
| **Privacy** | Buyer phone masked until the order is accepted; call/chat via in-app actions; bank numbers always masked after entry. |
| **Analytics** | Screen views and key actions (accept, reject, publish, payout account set) through one `SellerAnalytics` facade — no PII in event params. |

---

## 12. Data, backend & security architecture

### 12.1 New / changed server surface (`TARGET_IMPLEMENTATION`)

| Callable / trigger | Replaces | Why |
|---|---|---|
| `sellerTransitionOrder({orderId, to, reason?})` | client `orders.update({orderStatus})` in `seller_order_provider.dart:168/295/305` | Server-enforced state machine (`pending→accepted→packed→ready_for_pickup`, `pending→rejected`, `accepted/packed→cancelled` with reason), ownership check, timeline write, buyer notification, refund trigger on reject/cancel. Rules then deny seller writes to `orderStatus`. |
| `issueGstInvoice({orderId})` | nothing | Sequential per-seller invoice numbers (transaction on `seller_invoice_counters/{sellerId}`), immutable `invoices/{id}` doc + PDF in Storage `invoices/{sellerId}/{id}.pdf`. |
| `submitSellerApplication()` | direct `sellerRequests` / `sellers` writes from two apps | Validates completeness, sets `pending`, notifies admins. |
| `replyToReview({reviewId, text})` | nothing | One reply per review, seller must own the product. |
| `seller_stats_daily` rollup (order write trigger or scheduled) | client-side aggregation over all orders | Fast, cheap Home/Insights; enables Δ and sparklines. |
| `sellerRatingRollup` (review write trigger) | nothing (`rating` always 0) | Writes `sellers/{uid}.rating`, `reviewCount`. |
| `sendPhoneOTP` test-mode branch | client mock | ADR-S11. |

Existing callables the seller app needs **deployed** (source exists): `createRfq`, `submitRfqOffer`, `respondToRfqOffer`, `createOrderFromRfq`, `createSellerAiActivationOrder`, `connectSellerAiProvider`, `sellerAiChatProxy`, `disconnectAiProvider`, `confirmDelivery`, `quoteOrderWithCredit`.

### 12.2 Collections the seller app reads / writes

| Collection | Seller access (target) |
|---|---|
| `sellers/{uid}` | read public; **write only** `description, logoUrl, coverImageUrl, highlights, hours, acceptingOrders, deliveryRadiusKm, deliveryFee*` |
| `sellerRequests/{uid}` | owner read/write while `draft`; read-only after submit |
| `seller_payout_details/{uid}` | owner read/write; admin read; never public |
| `products` | owner create/update own (`sellerId == uid`), status fields limited to `isActive`, `draft`; `approvalStatus` admin-only |
| `orders` | read where `sellerId == uid`; **no direct status writes** after `sellerTransitionOrder` ships |
| `seller_payouts` | read own; write server-only |
| `rfqs` (+ offers) | via callables only |
| `reviews` | read; reply via callable |
| `follows`, `business_posts` | read own followers; CRUD own posts |
| `users/{uid}/notifications`, `users/{uid}/settings/*` | owner |
| `seller_stats_daily` | read own; write server-only |
| `invoices` | read own; write server-only |
| Storage `seller_kyc/{uid}/**` | owner write (type/size-checked), admin read, never public |
| Storage `sellers/{uid}/**` (storefront media) | owner write, public read |

### 12.3 Security invariants (must hold after every phase)

1. **Admin is a custom claim**, never an email allowlist — the `isAdmin()` email list added in `9e77189` is removed in SEC-P0; any email-based check must also require `email_verified == true`.
2. No client-side OTP generation, no derivable passwords.
3. A seller can read or change only their own seller-scoped data; proven by emulator rules tests for every collection in §12.2 (allow + deny cases).
4. Money, order status, ratings, invoice numbers, stats — server-written only.
5. Bank/KYC data never in a publicly readable document or path.
6. AI Copilot requests are scoped to the calling seller's UID server-side (`sellerAiChatProxy`); the key is never returned to any client.
7. Push payloads carry IDs, not PII.

---

## 13. Gap register (1–49) → screen → phase

| # | Gap | Screen(s) | Phase |
|---|---|---|---|
| 1 | Phone + OTP login | A-01, A-02 | SELLER-AUTH-1 |
| 2 | Google linked to verified phone | A-01, A-03 | SELLER-AUTH-1 |
| 3 | Test-mode OTP autofill (safe) | A-02 | SEC-P0 + SELLER-AUTH-1 |
| 4 | Email legacy + reset / switch method | A-01, A-04 | SELLER-AUTH-1 |
| 5 | One onboarding path | A-05, marketplace hand-off | SELLER-AUTH-1 |
| 6 | Stepped registration | A-05 | SELLER-AUTH-1 |
| 7 | Pending timeline + support | A-06 | SELLER-AUTH-1 |
| 8 | Rejected / suspended | A-07 | SELLER-AUTH-1 |
| 9 | KYC upload | A-05 step 3 | SELLER-AUTH-1 |
| 10 | Action queue | H-01, H-05 | SELLER-HOME-1 |
| 11 | Period stats + charts | H-01, H-04 | SELLER-HOME-1 |
| 12 | Notifications inbox | H-02 | SELLER-HOME-1 |
| 13 | Low/out-of-stock list | H-01, C-05 | SELLER-CATALOGUE-1 |
| 14 | Stepped product editor | C-03 | SELLER-CATALOGUE-1 |
| 15 | Variants | C-03 step 4, C-02 | SELLER-CATALOGUE-1 |
| 16 | Draft/active/inactive + approval state | C-01, C-02 | SELLER-CATALOGUE-1 |
| 17 | Bulk edit + search/sort/filter | C-01, C-04 | SELLER-CATALOGUE-1 |
| 18 | Product stats | C-02 | SELLER-CATALOGUE-1 (+ tracking) |
| 19 | Accept / reject | O-01, O-02, O-03 | SELLER-ORDERS-1 |
| 20 | Status timeline via server | O-02 | SELLER-ORDERS-1 |
| 21 | Search / date / B2B filters | O-01, H-03 | SELLER-ORDERS-1 |
| 22 | GST invoice | O-04, P-05 | SELLER-ORDERS-1 |
| 23 | Cancel / return reasons | O-03, O-05 | SELLER-ORDERS-1 |
| 24 | Call / chat buyer | O-02 | SELLER-ORDERS-1 |
| 25 | Quotes as first-class | Q-01, H-01 | SELLER-RFQ-2 |
| 26 | Counter history, expiry, badges | Q-01, Q-02, Q-03 | SELLER-RFQ-2 |
| 27 | Share quote in chat | Q-02 | SELLER-RFQ-2 |
| 28 | Deploy RFQ callables | — | Deploy batch |
| 29 | Payments overview | P-01 | SELLER-MONEY-1 |
| 30 | Ledger / settlement / statements (withdraw per D-SELLER-PAYOUT-MODEL) | P-02, P-03, P-05 | SELLER-MONEY-1 |
| 31 | Payout account (bank/UPI) + FIX-2 migration | P-04, A-05 step 4 | SELLER-MONEY-1 + owner migration |
| 32 | Per-order earnings breakdown | O-02, P-03 | SELLER-MONEY-1 |
| 33 | Storefront editor | M-02 | SELLER-STOREFRONT-EDIT-1 |
| 34 | Storefront preview | M-02 | SELLER-STOREFRONT-EDIT-1 |
| 35 | Review replies + server rating | M-03, H-05 | SELLER-ACCOUNT-1 |
| 36 | Followers & posts | M-04, M-05 | SELLER-ACCOUNT-1 |
| 37 | Storefront bugs (inactive products, category paging) | marketplace `/business/:id` | SELLER-STOREFRONT-EDIT-1 |
| 38 | Account ID card | M-01 | SELLER-UI-1 |
| 39 | Hours & radius screen | M-06 | SELLER-ACCOUNT-1 |
| 40 | Working notification prefs | M-07 | SELLER-ACCOUNT-1 |
| 41 | Help & support | M-10 | SELLER-ACCOUNT-1 |
| 42 | Theme, language, version, sign out | M-01, M-11 | SELLER-UI-1 |
| 43 | AI Copilot + deploy AI callables | M-08, M-09 | SELLER-ACCOUNT-1 + Deploy batch |
| 44 | Teal canonical theme, 0 literals | all | UI-TEAL-0 + SELLER-UI-1 |
| 45 | One feedback mechanism | all | SELLER-UI-1 |
| 46 | Dead code + marketplace duplicates removed | — | SELLER-UI-1 / SELLER-AUTH-1 |
| 47 | Screen tests | all | every phase |
| 48 | Push for orders/quotes verified end-to-end | H-02, M-07 | SELLER-HOME-1 |
| 49 | Release setup (signing, version, listing) | — | SELLER-RELEASE-1 |

---

## 14. End-to-end dependencies outside the app

Owner actions — the programme prepares, **never runs** them.

| # | Item | Detail |
|---|---|---|
| E1 | **Functions deploy** — always by explicit name | RFQ: `createRfq`, `submitRfqOffer`, `respondToRfqOffer`, `createOrderFromRfq` · AI: `createSellerAiActivationOrder`, `connectSellerAiProvider`, `sellerAiChatProxy`, `disconnectAiProvider` · Orders: `confirmDelivery`, `quoteOrderWithCredit` · Auth: `sendPhoneOTP`, `verifyPhoneOTP` (test mode) · New ones from §12.1 as each phase lands. Never `--only functions` bare (6 live orphans). |
| E2 | **Node 22** | 25 live `nodejs20` functions redeployed by name before **2026-10-30** (SEC-4 prepared). |
| E3 | **Rules & indexes** | `firestore:rules` (SEC-P0 admin fix, §12.2 seller scope), `storage:rules` (KYC, storefront media), `firestore:indexes` (orders `sellerId+orderStatus+createdAt`, products `sellerId+isActive+categoryId`, rfqs `sellerId+status+expiresAt`, notifications). |
| E4 | **Config docs** | `auth_test_mode/config` (Console only), `settings/seller_onboarding`, `settings/app_versions`, seller fee/commission settings. |
| E5 | **Google sign-in** | Register SHA-1/SHA-256 for `com.agrimore.seller` (release key **and** the debug keystore the build actually uses), re-download `google-services.json`, full rebuild. |
| E6 | **FIX-2 migration** | Move existing `sellers/*` bank fields to `seller_payout_details` (script dry-run → owner `--apply`). |
| E7 | **Credential rotation** | Keystore passwords, Maps keys, admin password (open since SEC-1/FIX-7). |
| E8 | **Play release** | Seller app first release: listing, screenshots (generated from goldens), privacy/data-safety form, internal → closed → production tracks. |
| E9 | **Push** | Verify FCM token registration for sellers and `notifySellerNewOrder` delivery on a real device. |

---

## 15. Phase plan with acceptance criteria

Every phase: claim row in `docs/active/BRANCH_DISPOSITIONS.md` first; branch `agrimore/<id>-<slug>` from `develop`; single agent; `gate.sh`; lanes per `surface.sh`; merge `--no-ff`; deploy consequence stated by explicit name.

| Order | Phase | Scope | Acceptance (falsifiable) |
|---|---|---|---|
| 0 | **SEC-P0** | ADR-S11 test-mode OTP; delete client mock; remove email admin allowlist; marketplace + seller clients read `testMode` | Emulator: unverified token with an allow-listed email is **denied** admin; test-mode OTP only for allow-listed numbers inside the window; same UID before/after for an existing phone; `git grep kDevMockPhoneOtp` = 0; five-app analyze 0 errors |
| 1 | **UI-TEAL-0** | ADR-S02/S05/S06/S07: Workspace theme, teal palette, Inter bundled, `AgIcons`, kit promotion + new kit components, `canon_check.sh`, catalogue shows both brands | SA goldens identical (font change announced separately); seller brand renders in catalogue light/dark; `canon_check` runs in gate; all five apps analyze 0 errors; employee 33 tests pass |
| 2 | **SELLER-AUTH-1** | A-01…A-07, onboarding callable, KYC storage rules, marketplace hand-off, delete marketplace duplicates | Emulator: every auth-gate state routes correctly; rules deny cross-seller KYC reads; goldens A-*; `canon_check` = 0 on touched files |
| 3 | **SELLER-UI-1** | `WsNavShell` (5 destinations, responsive), M-01, M-11, restyle remaining existing screens to kit, delete dead widgets, l10n scaffold | `canon_check` = 0 for **all** of `apps/seller/lib`; goldens for every screen; web ≥ 1200 shows rail + multi-column |
| 4 | **SELLER-ORDERS-1** | O-01…O-05, `sellerTransitionOrder`, `issueGstInvoice`, rules deny client `orderStatus` writes | Callable tests for every legal/illegal transition; invoice numbers strictly sequential under concurrency test; revert-and-watch on the rules change |
| 5 | **SELLER-MONEY-1** | P-01…P-05, payout account, FIX-2 migration script | Rules tests: payout details owner/admin only; ledger totals reconcile with `seller_payouts` fixture |
| 6 | **SELLER-CATALOGUE-1** | C-01…C-05, variants, bulk edit, stepped editor | Editor round-trips existing products without data loss (fixture of real field shapes); approval field not client-writable |
| 7 | **SELLER-RFQ-2** | Q-01…Q-03, share to chat | Flow test against emulator with deployed-equivalent callables |
| 8 | **SELLER-HOME-1** | H-01…H-05, `seller_stats_daily`, notifications inbox, push verification | Rollup matches a recomputation over fixtures; Δ correct at period boundaries (IST) |
| 9 | **SELLER-STOREFRONT-EDIT-1** | M-02, storefront rules/storage, marketplace storefront fixes (isActive, server category query) | Rules allow only listed fields; marketplace shows no inactive product (test) |
| 10 | **SELLER-ACCOUNT-1** | M-03…M-10, rating rollup, review reply, notification prefs honoured by senders | Pref off ⇒ no push (function test); one reply per review enforced |
| 11 | **SA-CANON-CLEAN** | Bring `apps/employee` to `canon_check` = 0 (D3, D4) | `canon_check` = 0 on `apps/employee/lib` |
| 12 | **SELLER-RELEASE-1** | Versioning, signing via `key.properties`, store assets from goldens, data-safety | Release build signs; version shown in M-11 matches `pubspec` |
| — | **Deploy batch** | §14 E1–E9 | Owner-run; `firebase functions:list` shows each name live |

---

## 16. Quality gates & testing

| Gate | Command / artefact | Pass |
|---|---|---|
| Analyze | `for a in marketplace admin seller delivery employee; do (cd apps/$a && flutter analyze); done` | 0 `error •` lines in all five |
| Canon | `bash .claude/skills/agrimore/scripts/canon_check.sh apps/seller/lib` | exit 0 |
| Goldens | `apps/seller/test/goldens/<screen>_{light,dark}_{1x,2x}.png` | match; updated only with a reviewed diff |
| Widget tests | one per screen: renders each state (loading, empty, error, data), primary action wired | pass |
| Functions | `cd functions && npm run build` + `functions/scripts/phase*_test.js` for new callables | exit 0 |
| Rules | emulator suites for §12.2 (allow + deny per collection / storage path) | all pass |
| E2E | `gate.sh --emulator` from `develop`; web run of the seller app at 390 px and 1440 px, light + dark | clean; screenshots attached to the phase report |
| Accessibility | goldens at 2.0× text; semantics test for icon buttons; contrast table in §5 re-checked when a token changes | pass |
| Performance | profile build on AVD `Pixel_8_API_35`: cold start, orders list scroll | budgets in §11 |

---

## 17. Open decisions

| ID | Question | Safe default until decided |
|---|---|---|
| D-SELLER-PAYOUT-MODEL | Automatic settlement cycle only, or also seller-initiated "Withdraw" (like SA payout requests)? What cycle (T+2 after delivery, weekly)? | Show ledger + schedule; no Withdraw button |
| D-SELLER-GST | Is GSTIN mandatory for all sellers or only above a turnover / for B2B? | Optional; invoices show GSTIN when present |
| D-RETURNS | Do returns exist for perishables, and who decides (seller vs admin)? | Cancellation only; O-05 hidden |
| D-SELLER-FEES | Platform fee / commission rates shown in earnings breakdown — source of truth doc? | Show only fields the server writes on `seller_payouts` |
| D-TEST-MODE-WINDOW | Which numbers go on the test allowlist, and for how long | Code caps the window at 7 days; Console-only; no numbers listed until the owner adds them |
| D-LANGUAGES | Which languages ship first after English | English only; strings externalised from day one |
| D-SELLER-WEB-HOSTING | Host the seller web build (4 hosting sites exist) and on which domain | Not hosted; web used for development |
| D-ACCOUNT-HEALTH | Which inputs and thresholds define the health score | Show individual metrics, no composite score |

---

## 18. Appendices

### A. `canon_check.sh` patterns (reference)

```
COLOR      Color\(0x|Colors\.(?!transparent\b)[a-zA-Z]
SPACING    EdgeInsets\.[a-zA-Z]+\([^)]*[1-9]|SizedBox\((height|width):\s*[1-9]|Gap\([1-9]
RADIUS     BorderRadius\.(circular|all)\([^)]*[1-9]|Radius\.circular\([1-9]
TYPE       TextStyle\(|fontSize:\s*[0-9]|fontWeight:\s*FontWeight\.|letterSpacing:\s*-?[0-9]
MOTION     Duration\((milli)?seconds:\s*[1-9]|Curves\.
ICONS      \bIcons\.|FontAwesomeIcons\.|CupertinoIcons\.
SHADOW     BoxShadow\(
STRINGS    Text\(\s*['"]|(label|hintText|labelText|title|message|tooltip):\s*['"]
FORMAT     NumberFormat\(|DateFormat\(
THEME      ThemeData\(
FEEDBACK   SnackBar\(|SnackbarHelper\.|AlertDialog\(
```
Scope `apps/seller/lib/**`, excluding `lib/l10n/**`. Output `path:line RULE`; exit 1 on any hit.

### B. Screen inventory — current file → target screen

| Current file | Target |
|---|---|
| `screens/auth/login_screen.dart` | A-01, A-04 |
| `screens/auth/seller_registration_screen.dart` | A-05 (replaced) |
| `screens/auth/pending_approval_screen.dart` | A-06, A-07 |
| `screens/shell/seller_shell.dart` | `WsNavShell` composition |
| `screens/home/dashboard_screen.dart` | H-01 |
| `screens/home/add_product_screen.dart` | C-03 (split per step) |
| `screens/products/seller_products_screen.dart` | C-01 |
| `screens/posts/create_post_screen.dart` | M-05 |
| `screens/orders/seller_orders_screen.dart` | O-01 |
| `screens/orders/seller_order_detail_screen.dart` | O-02, O-03 |
| `screens/earnings/seller_earnings_screen.dart` | P-01, P-02 |
| `screens/profile/seller_profile_screen.dart` | M-01 (+ M-06, M-07, P-04 as real screens) |
| `screens/profile/delivery_fee_sheet.dart` (+ `delivery_fee_validation.dart`) | M-06 (logic kept) |
| `screens/profile/seller_ai_integration_screen.dart` | M-09 |
| `screens/ai/seller_ai_chat_screen.dart` | M-08 |
| `screens/rfq/seller_rfq_inbox_screen.dart` | Q-01 |
| `screens/rfq/seller_rfq_detail_screen.dart` | Q-02, Q-03 |
| `widgets/order_detail_popup.dart`, `widgets/order_preview_card.dart` | **delete** |
| — (new) | A-02, A-03, H-02…H-05, O-04, O-05, C-02, C-04, C-05, P-03…P-05, M-02…M-04, M-10, M-11, X-01…X-03 |

### C. Glossary

**Workspace theme** — the brand-parameterised system shared by the Sales Associate and Seller apps. **Kit** — `packages/agrimore_ui/lib/workspace/kit/`. **Test mode** — server-side OTP bypass for allow-listed numbers inside a time window. **SLA** — the acceptance / handover deadline shown by `WsCountdown`. **Settlement** — a server-created `seller_payouts` record paying the seller for delivered orders.

### D. Change log

| Date | Change |
|---|---|
| 2026-09-23 | Initial ADR — owner approved plan A–D; system = Sales Associate, UX bar = tier-1 seller platform, brand = teal. |
| 2026-09-23 | UI-TEAL-0: dark `textTertiary` corrected to `#8594AA` after the automated WCAG test failed `#64748B`. |
| 2026-09-23 | SEC-P0: test-mode config moved to Console-only `auth_test_mode/config` (7-day cap, allowlist only); §9, §14 E4, §17 updated. |
