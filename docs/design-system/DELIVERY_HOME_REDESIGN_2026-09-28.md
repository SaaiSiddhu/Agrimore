# Delivery Home redesign — canonical colour system, Home, app bar, navigation

Phase **DLVHOME1** (branch `agrimore/dlvhome1-canonical-color-home-redesign`, claimed at
`40c36f00` from `develop` `413244a1`). Authority order: explicit owner brief (2026-09-28, pasted
implementation prompt) → six owner-supplied reference screenshots
(`apps/delivery/assets/design-references/zomato-home/`, untracked, copied from the primary
folder — visual references only, never bundled into the app) → existing business/security
contracts (providers, callables, rules) → platform accessibility. Tags: `OWNER_DECISION` (quoted
verbatim) · `DESIGN_DECISION` (made in this phase, reversible) · `SUPERSEDED` (an earlier
direction this phase replaces).

## D0 — Monochrome colour system (OWNER_DECISION, 2026-09-28)

Owner, verbatim: *"Light mode: white foundations, black foreground and primary actions. Dark
mode: black foundations, white foreground and primary actions... Existing burnt orange #C2410C
becomes a restrained supporting brand accent, not the dominant primary color."*

**SUPERSEDES** the Phase 01–03 direction in `delivery_colors.dart`'s own former doc comment:
*"Primary brand is Burnt Orange (`#C2410C` in light mode, `#FDBA74` in dark mode)"*. That
statement was true of `DeliveryColors.primary` specifically; it no longer is.

Audit performed before touching a value (owner's own instruction: *"Audit existing uses of
primary/onPrimary/brand/status colors so changing tokens does not create invisible text,
incorrect status meaning, or accidental orange-filled surfaces"*): `primary`/`onPrimary`/
`primaryContainer`/`onPrimaryContainer` (aliased `brand`/`onBrand`/`brandContainer`/
`onBrandContainer`) are the actual dominant-action tokens — 112 call sites across
`delivery_button.dart`, `delivery_chips.dart`, `delivery_badge.dart`, `delivery_timeline.dart`,
`delivery_card.dart`, `delivery_nav.dart`, `delivery_brand.dart`, `delivery_otp.dart`, and
`delivery_theme.dart`'s `ColorScheme`/component themes (filled/outlined/text buttons, chips,
switches, checkboxes, radios, nav-bar indicator, input focus).

**DESIGN_DECISION**: flip the *values* behind `primary`/`onPrimary`/`primaryContainer`/
`onPrimaryContainer`/`primaryStrong`/`primarySubtle` (and the foundation tokens
`background`/`surface`/`raised`/`sunken`/`textPrimary`/`textSecondary`/`textTertiary`/
`border`/`controlBorder`/`divider`) to true-neutral monochrome — this alone re-colours all 112
existing call sites correctly with zero per-call-site edits, which is what avoids the "accidental
orange-filled surfaces" risk the owner named: nothing had to be individually re-pointed at a new
colour and possibly missed.

| Token | Light (before → after) | Dark (before → after) |
|---|---|---|
| `background` | `#FFFAF5` → `#FFFFFF` | `#171210` → `#000000` |
| `surface` | `#FFFFFF` (unchanged) | `#251C17` → `#121212` |
| `primary` | `#C2410C` → `#171717` | `#FDBA74` → `#F5F5F5` |
| `onPrimary` | `#FFFFFF` (unchanged) | `#2B1206` → `#0A0A0A` |
| `textPrimary` | `#241A16` → `#171717` | `#F7EFEA` → `#F5F5F5` |
| `border` | `#E7DDD6` → `#E5E5E5` | `#3B2E27` → `#2E2E2E` |

A NEW, separate token family — `accent`/`onAccent`/`accentContainer`/`onAccentContainer` — carries
the *exact former `primary` values* forward unchanged (`#C2410C`/`#FFFFFF`/`#FFEDD5`/`#7C2D12`
light, `#FDBA74`/`#2B1206`/`#431E0E`/`#FFEDD5` dark). It is used in exactly one deliberate place:
the emergency/SOS icon in the redesigned Home app bar (`home_app_bar.dart`), matching the
reference's own SOS icon tint against an otherwise monochrome bar.

`DeliveryTone.brand`'s `tone()` mapping (badges/banners/default tones, 8 call sites) is left wired
to `primary`/`primaryContainer` — **deliberately not** repointed to the new `accent` — because
doing so would reintroduce exactly the "orange fills through a default/fallback tone path" risk
the owner warned against. It becomes monochrome for free, same as the buttons.

`successColor`/`warningColor`/`dangerColor`/`infoColor` and their containers are **unchanged**, in
both palettes, per the owner's own instruction to preserve accessible status distinctions.

## D1 — Home app bar (OWNER_DECISION)

Left: a compact Online/Offline toggle (`_AvailabilityToggle` in `home_app_bar.dart`), wired
directly to `DashboardScreen`'s own existing `_toggleOnline`/`_isOnline`/`_toggling` state — this
widget owns no availability logic of its own, so every existing readiness/permission/approval/
busy/error/server-acknowledgement path is unchanged. While `_toggling` is true, the switch is
replaced by a spinner (never shows Online mid-toggle or after a failure).

Right: three neutral 48dp circular icon buttons — emergency (opens the existing
`showEmergencySheet`, `accent`-tinted per D0), notifications (the existing real `InboxButton`,
wrapped in a neutral circular surface, unchanged unread-count logic), help (opens the new
`help_sheet.dart`). No profile avatar — Profile stays a bottom-tab-only destination, per the
owner's own explicit instruction. **SUPERSEDES** the old greeting-header layout
(`_buildHeader` in `dashboard_screen.dart`, removed) and its own sign-out icon button — sign-out
was already independently, fully implemented in `RiderProfileScreen._signOut` (confirmed by
reading that file before removing the header's copy), so nothing lost reachability.

## D2 — Map-first Home (OWNER_DECISION)

`home_map.dart`: a real `GoogleMap` (the app's existing SDK, already used by
`rider_route_card.dart`) fills Home's main area. Reuses `LocationProvider.currentPosition`
directly while the rider is online (zero second subscription); when offline, exactly one
best-effort `Geolocator.getCurrentPosition`/`getLastKnownPosition` call seeds the initial camera
— never a stream of its own. Honest states: loading (no target yet), permission-denied,
services-disabled, unavailable — each a real `DeliveryBanner` with a real recovery action
(`Geolocator.openAppSettings`/`openLocationSettings`, or retry), overlaid on the still-usable map
rather than replacing it. A user-initiated pan/pinch stops auto-follow (`onCameraMoveStarted`)
until the recenter button is tapped again — the map never snaps back on its own. Dark mode applies
Google's own published night-mode JSON style (`style:` param); light mode uses the SDK default.

## D3 — Operational content moved into an expandable panel (OWNER_DECISION)

`home_operations_panel.dart`: a `DraggableScrollableSheet` above the bottom nav (chevron handle,
matching the reference), purely presentational — `DashboardScreen` still owns every stream,
provider read and state transition; the panel only renders whatever widget it is handed. Hosts,
unchanged: `PendingProofBanner`, `StaleDataBanner`, the active-work states
(`ActiveWorkLoading`/`MultipleActiveOrders`/`ActiveOrderSummaryCard`/`ActiveWorkError`, each now
height-bounded at the `dashboard_screen.dart` call site so `Center` lays out correctly inside a
scrollable, `active_work_states.dart` itself untouched), and the existing quick-actions dashboard
content (earnings toggle, cash-held stat, quick-action cards) when there is no active order.

**SUPERSEDED**: the old full-width `DeliveryOnlineSwitch` card that used to sit directly under the
header. Its role — showing Online/Offline with an explanatory subtitle — is now the compact D1 app
bar toggle; keeping both would have been a literal duplicate the brief did not ask for. The
`DeliveryOnlineSwitch` component itself is untouched and still exported/tested; only Home stopped
using it. `test/delivery_shell_test.dart`'s own former `DLVDASH1` case (asserting the retired
card's exact copy) was replaced with a smaller case asserting the new compact toggle instead,
rather than deleted silently.

## D4 — Bottom navigation (OWNER_DECISION)

Same 5 destinations/order (Home/Deliveries/Earnings/Inbox/Profile), unchanged. Removed the
Material `NavigationBar`'s own pill indicator (`indicatorColor: Colors.transparent` in
`delivery_theme.dart`) — no selection pill, coloured rectangle, or oversized indicator, per the
owner's explicit instruction. Selected-state emphasis is colour (`primary`, monochrome, full
contrast) plus the pre-existing bold label weight; **no filled Lucide icon variant exists for any
of the 5 destinations** (Lucide is stroke-only, confirmed by inspecting the installed
`lucide_icons_flutter` package directly — zero `*Filled`/`*Fill` constants), so the "filled icon
where supported" instruction resolves to colour/weight only, exactly as the brief's own fallback
clause anticipates.

## D5 — Emergency and help sheets (OWNER_DECISION)

Both re-skinned to the reference's row layout (title + explicit close button, rounded top corners
via the existing `BottomSheetThemeData`, leading icon in a circular tinted surface / title /
optional subtitle / trailing chevron, subtle dividers, scrollable, safe-area-aware) — **the
underlying real actions are completely unchanged**:

- `emergency_sheet.dart`: same `_dial`/`_report` methods, same 112/support dial URIs, same real
  incident-report state machine (`sending`/`error`/live record). Only the `build()` layout changed.
- `help_sheet.dart` (new): reuses `help_support_screen.dart`'s existing real destinations verbatim
  (`openSupportCall`, `SubmitSupportRequestScreen` with its existing category constants,
  `MySupportRequestsScreen`, the standalone `showEmergencySheet`) — does **not** edit
  `help_support_screen.dart`, which remains unchanged and still reachable from Profile.

**Deliberately not built**, per the owner's own list of excluded reference features: ambulance
arrival-time promises ("10 mins"), insurance card, ID card, in-app language change, "Report Rain".
None of these have a real AgriMore-supported backend today; building UI for them would have been
exactly the kind of invented capability the brief explicitly forbids.

## Overlap with `agrimore/dlvc3-profile-lifecycle-notification-destinations`

DLVC3 was `ACTIVE` (uncommitted WIP) at this phase's claim time, owning
`rider_profile_screen.dart`, `rider_inbox.dart`, `inbox_screen.dart`, `rider_document_review.dart`
and `functions/src/delivery/riderNotices.ts`. This phase does not touch any of them — the
notification bell reuses `InboxButton` (defined in `inbox_screen.dart`) by *importing and
composing* it unchanged, never editing its source.

## D6 — Profile screen redesign (OWNER_DECISION, 2026-09-28, scope amendment)

Second reference set: `apps/delivery/assets/design-references/zomato-profile/` (two screenshots,
overview + settings). Excluded verbatim per the owner's own list, none has an AgriMore
equivalent: personal photo, rider ID, rating, partner tier, score, referral banner, Gigs/Trips
history shortcuts, offers, certificates, rest points, app/audio/support language, order-alert
sound, competitor branding footer.

**Baseline re-check (required by the brief before touching anything):** by the time this
sub-phase started, `agrimore/dlvc3-profile-lifecycle-notification-destinations` and
`agrimore/dlvc4-support-connected-journey` were both `MERGED_DEVELOP` (confirmed via
`git worktree list` + the ledger, not assumed from the brief's own "observations, not guaranteed
current tips" framing). This branch was still based on `develop`@`413244a1`, predating both —
`git merge develop --no-ff` (commit `ef182216`, develop tip `a647e144`) brought in DLVC3's real
`_UidBoundStream` auth-lifecycle rebuild, DLVDOC3's per-document review/replace flow, and the
safety-report entry point BEFORE any Profile edit, so this redesign builds on the current real
implementation, not the one this branch forked from.

**Before → after inventory**, read fresh from the merged tree (not assumed): every existing
action kept its exact `ValueKey` and handler --

| Action | Before | After |
|---|---|---|
| Identity header | plain `Text` name + email | `DeliveryAvatar` (initials, no photo) + name (2-line safe) + email |
| Request vehicle/name change | `DeliveryButton.secondary` | unchanged (a review-triggering action, kept visually distinct from plain navigation) |
| Edit contact | `DeliveryButton.secondary` -> `ContactEditSheet` | unchanged |
| Documents | custom Row, no leading icon | same `StreamBuilder`/`_view`/`_replace` logic, now with a leading icon circle (danger-tinted when rejected) |
| Payout summary + Change | `Text` + `DeliveryButton.secondary` | unchanged |
| Appearance (System/Light/Dark) | `DeliverySegmented<ThemeMode>` in a plain-title card | same segmented control (owner: do not replace with a 2-way toggle), card now uses `DeliverySectionHeader` |
| Device readiness | `DeliveryButton.secondary` | `DeliveryListTile` (chevron row) |
| Get help | `DeliveryButton.secondary` | `DeliveryListTile` |
| **My support requests** | reachable only nested inside Help & support | **new top-level row** (`my-support-requests`), reuses existing `l.mySupportRequestsEntry` string and `MySupportRequestsScreen`; the nested Help entry is untouched, not removed |
| My safety reports | `DeliveryButton.secondary` -> `MyIncidentsScreen` | `DeliveryListTile`, same destination |
| Call/email support | `SupportContactButtons()` | unchanged (reused component, not forked) |
| Sign out / Delete account | `DeliveryButton.secondary` / `.ghost` | unchanged, same order (sign-out first, delete lower-emphasis) |

Section titles/rows reuse `_row`/`_section` helpers, reimplemented on top of the app's own
canonical `DeliveryKeyValueRow`/`DeliverySectionHeader`/`DeliveryListTile`/`DeliveryAvatar`
(`design_system/components/delivery_list.dart`) instead of bespoke `Row`/`Text` — no new
components, no parallel Profile theme.

**Not touched** (reused via existing public entry points/backends only, per the brief's own
"do not silently rewrite completed lifecycle fixes"): `identity_change_screen.dart`,
`document_submission_screen.dart`, `rider_account_source.dart`, `rider_account.dart`,
`rider_document_review.dart`, `help_support_screen.dart`, `my_support_requests_screen.dart`,
`device_readiness_screen.dart`, `money_screen.dart`, `support_card.dart`.

Evidence: `flutter analyze` apps/delivery 0 issues; `canon_check.sh --ratchet apps/delivery/lib`
0 <= baseline 0; `flutter test` apps/delivery 437/437 (435 post-merge baseline + 2 new tests for
the "My support requests" row's own navigation and its distinctness from "My safety reports") --
`test/rider_profile_screen_test.dart` (19 cases: sign-out, deletion eligibility, the full DLVC3
auth-lifecycle group) and `test/rider_profile_document_preview_test.dart` needed **zero logic
changes**, only continuing to pass unchanged, confirming every `ValueKey` this redesign reused
landed on the right widget. Verified on-device (Samsung S26, `RZGL21W98TB`) separately from this
widget-test evidence, per the brief's own instruction to distinguish the two.
