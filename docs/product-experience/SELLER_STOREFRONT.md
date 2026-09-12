# Seller Storefront — what SELLER-STOREFRONT-1 shipped

What `BusinessProfileScreen` (BUSINESS-NETWORK-1/2, `apps/marketplace/lib/screens/business/
business_profile_screen.dart`) became once ADMIN-SELLER-CMS-1 made `sellers/{uid}.logoUrl` /
`.coverImageUrl` / `.description` real, admin-writable fields. Measured at
`agrimore/seller-storefront1-enrich-business-profile` = `3bb0769` (base `develop@2579c16`, which
already contains ADMIN-SELLER-CMS-1 merged as `68e8ad7`).

## 1. Architecture (unchanged)

Same direct-Firestore-read shape as before: `_load()` reads `sellers/{sellerId}` and queries
`products` filtered by `sellerId`, no dedicated storefront API, no `functions/**` involvement. This
phase evolved the screen's presentation and its query shape (adding an aggregate count and a
document-cursor page), not the app's data-access architecture.

## 2. Screen anatomy — before → after

```
Before:                                          After:
  AppBar (shopName or 'Business Profile')          AppBar (unchanged)
  header card (white/dark)                         cover banner (new -- coverImageUrl or an
    CircleAvatar (storefront icon only)               accent-gradient fallback)
    shopName / shopAddress                          header card
    Follow button                                     CircleAvatar (logoUrl-aware, same icon
  "Products (_products.length)"                          fallback when absent)
  ProductGrid(_products) -- capped .limit(60),           shopName / shopAddress
    client-side length shown as the count               metrics row (new): real product count
                                                            (count() aggregate), tenure (from
                                                            createdAt), Verified badge (status)
                                                          Follow button
                                                        About Seller (new, conditional): description
                                                          (collapsible) + full shopAddress
                                                        trust strip (new): Verified Seller + Secure
                                                          Payments -- platform-backed claims only
                                                        "Products (_productCount)" -- real total
                                                        category chips (new, conditional on 2+
                                                          categories present): client-side filter
                                                        ProductGrid(_filteredProducts) -- first
                                                          page (20), shrinkWrap fixed (see §5)
                                                        "Load more" (new, hidden while filtered)
```

## 3. Metrics row (WS1)

Three real signals, each independently omittable when its source is absent:
- **Product count**: `products.where('sellerId', isEqualTo: id).count().get()` — the first use of
  Firestore's aggregate-count API anywhere in this codebase (`cloud_firestore: 5.6.12`, confirmed to
  support it; no existing `.count()` call site found by grep before this phase). Not the client-side
  length of the paginated fetch, which is deliberately smaller.
- **Tenure**: derived from `sellers/{uid}.createdAt`, a server timestamp set at seller approval
  (`createSellerByAdmin.ts` / the admin approval batch) — never client-writable.
- **Verified badge**: `sellers/{uid}.status == 'approved'`, rules-enforced
  (`ownerCannotApproveSellerStatus()` — a seller can never self-approve). Meaningful here in a way it
  wasn't in ADMIN-SELLER-CMS-1's own admin list screen (which pre-filters to approved sellers only):
  `BusinessProfileScreen` opens any `sellerId` directly, so a pending or rejected seller's profile is
  reachable and correctly shows no badge.

## 4. About Seller, category chips, trust strip (WS2)

- **About Seller**: renders only when the seller has a `description` and/or `shopAddress` set — never
  a broken empty section. `description` collapses to 3 lines with a "Read more"/"Show less" toggle
  (a small local `bool`, not a new shared widget — `agrimore_ui` has no expandable-text primitive to
  reuse, and this is a single-use, screen-scoped toggle, not a duplicate of one).
- **Category chips**: derived from the *currently loaded* products' own `categoryId` (a required
  `ProductModel` field — no schema change), resolved to a real name via the app-wide
  `CategoryProvider` (`main.dart`'s own registration, `getCategoryById`). Visual style mirrors
  `mobile_shop_screen.dart`'s own `_buildFilterChip` exactly (pill shape, active/inactive colors) —
  reused pattern, not a new one. Only shown when the seller's catalog spans 2+ categories.
- **Trust strip**: exactly two claims, both platform-backed, neither seller-specific fabrication —
  "Verified Seller" (same `status` signal as the metrics-row badge, shown again here since it belongs
  next to the seller's own description) and "Secure Payments" (a platform-wide fact per
  `security.md`'s own invariant I5 — every order's payment is HMAC-verified against a live Razorpay
  status regardless of which seller it's for; copy/icons mirror `landing_screen.dart`'s own
  `_trustBadge('Secure Payments')` for the identical true claim in a different context).
  **Deliberately excluded**: any delivery-speed ("Fast Delivery") or return-rate ("Easy Returns"/
  "98% On-Time") claim — no per-seller fulfilment-metric data exists anywhere in `functions/src` or
  any app to back one honestly, even though `landing_screen.dart`'s own generic trust badges include
  a "Fast Delivery" claim at the platform level.

## 5. Pagination (WS3)

Replaced the one-shot `products.where('sellerId', ...).limit(60).get()` with a document-cursor page
of 20 (`_kProductsPageSize`), tracking `_lastProductDoc` / `_hasMoreProducts`; a "Load more" control
fetches the next page via `.startAfterDocument()` and appends. Category-chip filtering (§4) stays
client-side over whatever pages are currently loaded — **not** extended to a server-side
`categoryId` filter, because combining it with the existing `sellerId` equality filter and a cursor
would need a new `sellerId + categoryId` composite index this phase had no live emulator (seeded with
realistic multi-category product data) to verify safe against. Disclosed simplification: "Load more"
is hidden while a category chip is selected, so the control can never appear to silently do nothing.

**Also fixed, discovered while wiring this**: `product_grid.dart`'s `GridView.builder` had no
`shrinkWrap`/`physics`, so it would throw at layout time ("RenderBox was not laid out: ... has
infinite height") the moment it actually rendered a non-empty list nested inside this screen's outer
`ListView` — a pre-existing bug from BUSINESS-NETWORK-1, presumably never caught because every seller
exercised during that phase's own review happened to have an empty product list (hitting the
empty-state branch, never `ProductGrid` itself). Confirmed via `grep` that this screen is
`ProductGrid`'s **only** caller anywhere in the app before fixing it, so the fix has zero effect on
any other screen.

## 6. Follow / feed integration (unchanged)

`BusinessFollowProvider` and the `/business-feed` entry point were not touched. `firestore.rules`'
`follows/{followId}` and `business_posts/{postId}` blocks (confirmed present, unchanged, at claim
time) were never in this phase's `may_write` and remain untouched.

## 7. API / database changes

None. Every change in this phase is client-only (`apps/marketplace/lib/**`). No `firestore.rules`,
`storage.rules`, `firestore.indexes.json`, or `functions/**` file was touched — this phase only reads
fields ADMIN-SELLER-CMS-1 already made writable and adds one new query shape (`.count()`, `.startAfterDocument()`)
against an existing, already-indexed `sellerId` filter.

## 8. Testing

`flutter analyze apps/marketplace`: 0 errors at every commit (WS1 `26837fe`, WS2 `0ff6c5f`, WS3
`3bb0769`); warnings/infos held flat at the claim-time baseline (149/331) through all three
workstreams — WS1 introduced one new lint (an unnecessary string-interpolation brace) and fixed it in
the same commit; WS2 and WS3 introduced zero new lints.

No new automated test was added, for the same reason `PRODUCT_DETAIL_V2.md` §11 already documents
for `ProductDetailsScreen`: `BusinessProfileScreen` is a `StatefulWidget` wired to two live providers
(`ThemeProvider`, `CategoryProvider`, plus a screen-owned `BusinessFollowProvider` instance) and three
direct Firestore reads (`sellers` doc, `products` query, `products.count()`), with no existing
screen-level widget-test precedent in this repo to build from. A shallow test that mocks none of that
would prove nothing; disclosed as not done rather than faked.

## 9. Future enhancements (not this phase)

- `SELLER-METRICS-1`: a real seller-rating aggregate (the `reviews` collection is product-scoped only
  — `ReviewModel` has no `sellerId` field, reconfirmed at claim time — so no rating can be shown
  honestly today).
- Server-side category filtering combined with pagination, once a `sellerId + categoryId` composite
  index is added and verified against real emulated data (currently a disclosed, deliberate gap — §5).
- A screen-level widget-test harness, once one exists as a repo-wide pattern.
- Any per-seller delivery-speed or fulfilment-rate metric, if this codebase ever gains real
  fulfilment-tracking infrastructure to back one.
