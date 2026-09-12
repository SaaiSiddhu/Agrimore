# Current Home Architecture — AgriMore marketplace app

Written by phase HOME-1 (2026-09-12), base `develop@bf5c1e7`. Purpose: a single, evidence-based
reference for every later Home/CMS phase, so nobody re-derives this from scratch. Everything below
was read from source in this session; nothing is carried from the owner's pasted spec's own
assumptions about what "must" exist.

## 1. Screen composition (`apps/marketplace/lib/screens/user/home/mobile_home_screen.dart`)

A `CustomScrollView` with staggered fade/slide-in animations per section, pull-to-refresh (does not
touch cart state), shimmer loading on first load only (cached data skips it), and a scroll-to-top FAB.
Loads five providers in parallel on mount/refresh: `ProductProvider`, `CategoryProvider`,
`BannerProvider`, `CategorySectionProvider`, `SectionBannerProvider`.

Section order today (fixed in code, not admin-reorderable):

1. `BannerSlider` — hero carousel (§2.1)
2. `DealsForYou` (comment: "Bestsellers, admin-controlled") — backing data source not yet verified
   line-by-line in this phase; `_DisplayItem`/`_BestsellerCard` suggest a curated list, needs a
   follow-up read before any phase depends on its exact mechanism. CLAIMED_NOT_VERIFIED.
3. `GroceryKitchenHomeStrip` — renders `CategorySectionSlotModel` data (§2.4)
4. `RecentlyViewedWidget` — client-side view history, not CMS
5. `DynamicCategorySections(skipCount: 9)` — remaining categories not covered by #3/#6, with a
   visible `_AdminCategorySection` vs. `_FallbackCategorySection` split (admin-configured content
   with a graceful fallback when absent — exact trigger condition not traced in this phase)
6. Per-category `ProductSectionWidget` carousels — **entirely client-computed**: loops active
   categories, groups active products into each via `productBelongsToCategory`, caps at 8 sections /
   10 products each, inserts a `SectionBannerCarousel` after the 5th. Zero admin control over which
   categories get a section, their order, or their titles (category name is used verbatim).
7. Simple footer ("You're all caught up!")

## 2. The four fragmented banner/section systems

The single biggest reuse opportunity and risk in this programme. Each has its own Firestore
collection, its own `agrimore_core` model, its own provider, and its own **separate** `apps/admin`
screen. None supports scheduling (`startsAt`/`endsAt`) or a placement/CTA target model.

### 2.1 `BannerModel` → `banners` collection
Rendered on Home via `banner_slider.dart` (the hero carousel). Admin: two screens exist —
`apps/admin/lib/screens/admin/banners/banner_management_screen.dart` **and**
`apps/admin/lib/screens/admin/marketing/banner_management_screen.dart` (same file name, different
folder — likely one is legacy; which one is actually routed-to in `apps/admin`'s nav was not
determined in this phase — flagged for whoever touches this model next).
`apps/admin/lib/screens/admin/marketing/widgets/banner_uploader.dart` is an existing, reusable image
upload widget for this model.

### 2.2 `SectionBannerModel` → `section_banners` collection
Rendered mid-feed via `section_banner_carousel.dart`, inserted by `mobile_home_screen.dart` after the
5th client-computed product section. Admin:
`apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart` +
`add_edit_section_banner_dialog.dart`.

### 2.3 `SponsoredBannerModel` → `sponsored_banners` collection
Product-linked, not currently rendered anywhere found in `mobile_home_screen.dart`'s own render tree
in this phase's search — reachability from Home not confirmed. Admin:
`apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart` +
`add_edit_sponsored_banner_dialog.dart` + `sponsored_banner_card.dart`.

### 2.4 `CategorySectionSlotModel` (no dedicated collection name confirmed yet — read from `agrimore_core`)
The closest thing to a section-ordering CMS today, but narrow by design: a fixed `position` (int),
a `sectionName`, up to 8 `categoryIds`, and **exactly 8 named image fields** (`image1`..`image8`,
not a list) plus one `bgColorHex` and `isActive`. Admin:
`apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart` (744 lines)
+ `edit_category_section_screen.dart`. Confirmed admin capabilities (read from source, not assumed):
create, edit, delete, reorder via up/down buttons (`_reorderSection`, no drag-and-drop), active/
inactive toggle. **No scheduling, no draft/publish workflow beyond the boolean, no CTA.**

### Cross-programme note
`agrimore/cat1-category-content-redesign` (a parallel, same-day phase, claimed before this one)
independently found this same four-way fragmentation from the category-page side and provisionally
proposed extending `BannerModel` with `placement`/`categoryId`/`startsAt`/`endsAt`
(PROVISIONAL_DIRECTION, not owner-confirmed). Any future Home CMS schema phase needs the identical
capability — **this should be one shared foundational phase, not two independent schema evolutions
of the same model.** Flagged as an owner decision, not resolved by this phase.

## 3. App bar (`apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart`)

Recently redesigned already (code comments reference porting from "the reference build"). Real,
verified behavior:
- **Location**: `AddressProvider` — saved addresses (default flagged, labelled e.g. HOME/OFFICE),
  falling back to live GPS reverse-geocoding (`Geolocator` + `geocoding`, with an HTTP Google
  Geocoding fallback for web), falling back to "Set delivery location". Tapping opens
  `AddressBottomSheet`. This is real, not decorative.
- **Delivery promise**: `'Agrimore in' / '30 minutes'` — **the `'30 minutes'` is a literal hardcoded
  string, unconditional.** No ETA/serviceability engine exists anywhere in this repository to
  replace it with a computed value — the only serviceability signal found anywhere is a hardcoded
  city allowlist (`_serviceableCities` in `mobile_home_screen.dart`'s `_AutoLocationSheet`, used only
  for a first-run "is my city serviceable" bottom sheet, never for an ETA number). Real distance-based
  ETA would need product/warehouse location data that mostly doesn't exist today
  (`agrimore-repo-topology`/decisions.md's own `D-LOCATION-BACKFILL`: 62 of 64 live products carry no
  location field, still an open owner decision). **VERIFIED_REPOSITORY_FACT, real gap, not fixed by
  this phase** — proposed as HOME-2 (needs an owner decision on fallback copy, not a silent fix).
- **B2B/B2C mode switch**: a full gradient colour change (emerald↔amber) plus a pill toggle,
  `MarketModeProvider`. Not depicted anywhere in the reference mockup, but real, shipped, and
  affects pricing/catalog elsewhere in the app — **must never be removed or hidden by a visual
  redesign chasing the mockup.**
- **Wallet button** and **profile avatar** (real photo via `AuthProvider.currentUser.photoUrl`,
  graceful icon fallback) both real and already wired to real routes.
- **Search bar**: tapping navigates to the existing `/search` route; a result routes to
  `AppRoutes.shopWithSearch`. Not a fake/decorative launcher.

**This phase does not touch `home_app_bar.dart` at all** — see §6.

## 4. Bottom navigation (`apps/marketplace/lib/screens/user/main_screen.dart`, 919 lines)

Corrected from this phase's own first-pass (grep-only) audit, which was wrong on two points before
a full read — recorded here so the ledger row can be corrected too (§7):

- **5 real destinations already exist**, not 4: Home (index 0), **Shop** (index 1, `ShopScreen`,
  reachable independently and also targeted by `ShopEntryProvider.openShopWithCategory()` from
  category chips elsewhere in the app), **Categories** (index 2, `CategoriesScreen`, rendered as a
  special elevated center button, not a plain icon), Cart (index 3, real live badge via
  `Consumer<CartProvider>.itemCount`), Profile (index 4). Shop and Categories are two genuinely
  distinct, separately-wired screens — neither is a dead alias of the other.
- **Scroll-aware auto-hide is already fully implemented**, not missing: `_handleScrollNotification`
  (a `NotificationListener<ScrollNotification>` wrapping the body) ignores horizontal scrolls (so a
  banner `PageView` doesn't trigger it), hides past a 25px downward-scroll threshold, re-shows on
  upward scroll or on reaching the top, driven by `AnimatedSlide` + `AnimatedOpacity`. This mechanism
  is correct and is preserved as-is by this phase — only the bar's own visual chrome changes (§6).
- Bottom nav is **deliberately hidden on every tab except Home** (`bottomNavigationBar: _currentIndex
  != 0 ? null : …`) — Shop/Categories/Cart/Profile are each a standalone screen with its own back
  button; this is a documented, intentional design (commit `5775d26`, "Hide bottom nav on
  Shop/Categories/Cart, wire proper contextual back buttons"), not a gap.
- **`_buildNavItem` (a FontAwesome-icon-based nav item builder with a purple/blue "special" gradient
  state) is confirmed dead code** — grepped for call sites: only its own definition, zero invocations.
  Its only consumer of the `font_awesome_flutter` import. Safe to delete along with the import.
- **Orders is already reachable — from Profile, not the bottom nav**, and prominently: a "My Orders"
  menu row and a "Your orders" stat card, both showing a live Firestore-backed order count and
  routing to `AppRoutes.orders` (`profile_screen.dart` lines 254-256, 575-578). This matches this
  repository's own established precedent (ledger phase RFQ-2B: a new destination becomes a Profile
  menu item, not a 6th bottom-nav tab, when the existing 5-item nav is already functionally complete)
  — **so this phase does not add a 6th "Orders" tab.**
- Current visual style is a flat, edge-to-edge, non-rounded bar (`main_screen.dart`'s own inline
  comment: "Flat rectangular design - no margin, no rounded corners"). Checked `git log --follow` on
  this file for a documented reason this was chosen over a floating/rounded style: none found — no
  commit message mentions reverting a pill/floating design or a bug that caused one. This is simply
  the current visual choice, not a guarded decision — safe to restyle.

## 5. Adjacent systems reused as-is (not touched by this phase)

- **Cart**: `CartProvider`, one store, `{variant}`-keyed (confirmed independently by the concurrent
  PDP-1 phase's own audit of `product_details_screen.dart`).
- **Address/location**: `AddressProvider` (§3).
- **Analytics**: `packages/agrimore_services/lib/analytics/analytics_service.dart` — existing methods
  `logScreenView`, `logViewProduct`, `logAddToCart`, `logRemoveFromCart`, `logAddToWishlist`,
  `logBeginCheckout`, `logPurchase`, `logSearch`, `logShare`, `logCustomEvent`, `setUserId`,
  `setUserProperty`. No Home-specific events (`home_view`, `home_section_impression`, etc.) exist yet
  — a future phase should extend this service, not create a parallel one.
- **Feature flags**: no generic service exists — only `benefit_feature_flags_model.dart`, scoped
  entirely to the (flag-gated-off) Customer Product Benefit Program. A future Home rollout flag would
  need its own small Firestore-settings-doc convention, matching how `settings/associate_onboarding`
  is used elsewhere, not a new generic flag service.

## 6. What this phase (HOME-1) does and does not do

**Does**: this document; a visual-only restyle of `main_screen.dart`'s bottom nav to a floating,
inset, elevated container (preserving all 5 real destinations, the existing scroll-hide mechanism,
the real cart badge, and the hide-on-non-Home behavior exactly); deletion of the confirmed-dead
`_buildNavItem` method and its now-unused `font_awesome_flutter` import.

**Does not**: touch `home_app_bar.dart` (recently redesigned, carries real B2B/wallet logic the
reference mockup doesn't depict — a cosmetic rewrite here risks destroying shipped functionality,
which this repository's decision-priority order ranks above matching a visual reference); fix the
hardcoded ETA text (real gap, needs an owner decision on fallback copy — proposed as HOME-2); touch
any of the four banner/section models, `firestore.rules`, or `functions/**` (zero schema change in
this phase).

## 7. Proposed follow-on phases (not planned in detail; sketch only)

- **HOME-2**: delivery-promise honesty — admin-configurable serviceability/ETA copy states
  (serviceable / not serviceable / checking), reusing the existing city-allowlist-style
  serviceability signal; no fabricated distance/time computation. Needs an owner decision on exact
  copy and fallback states.
- **HOME-3**: visual polish pass on the existing `BannerSlider`/product cards if density/spacing
  gaps remain vs. the reference mockup.
- **HOME-4** (blocked on an owner decision): consolidate the four fragmented banner/section systems
  into one schedulable, placement-aware, orderable section model + admin section editor with
  draft/publish/schedule — coordinated with CAT-1's provisional CAT-2 rather than built twice.
- **HOME-5+**: homepage composition API, product-section source-modes, Home-specific analytics
  events on the existing `AnalyticsService`, media-library reuse for the consolidated section model.
