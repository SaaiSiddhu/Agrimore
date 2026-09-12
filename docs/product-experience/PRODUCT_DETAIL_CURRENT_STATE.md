# Product Detail Page — current state audit

Measured 2026-09-12 at `develop` = `bf5c1e7`, in worktree `../Agrimore-pdp1` (branch
`agrimore/pdp1-product-detail-redesign`). Every claim below is `VERIFIED_REPOSITORY_FACT` unless
marked otherwise — read fresh from the files cited, not from memory or from any prior report.

## 1. Architecture (VERIFIED_REPOSITORY_FACT)

- Framework: Flutter (Dart 3.12.2), `apps/marketplace` (customer app). State management: `provider`
  (`ChangeNotifier`-based providers registered in `main.dart`'s `MultiProvider`, plus a handful of
  screen-scoped providers instantiated locally — see §4).
- Data access: direct Firestore reads from the Flutter client (`cloud_firestore`), no dedicated
  "product detail" REST/callable endpoint. `firestore.rules` gates writes; reads on `products` and
  `sellers` are `allow read: if true` (public catalog).
- Routing: `apps/marketplace/lib/app/routes.dart` (886 lines), a mix of named-route constants and
  `onGenerateRoute` prefix matching (`/product/<id>`, `/business/<sellerId>`).
- Design tokens: `packages/agrimore_ui` (`AppColors`, `AppTextStyles`, `Theme.of(context)`); the
  Product Detail screen mixes token usage with a large number of local hex-literal `Color(0xFF…)`
  values (pre-existing, not introduced by this phase — see §5).
- Images: `cached_network_image` (mobile) / `Image.network` (web, via `kIsWeb`), no CDN
  transformation layer, no thumbnail-sized variant requests.

## 2. Product Detail implementation — file inventory

| File | Lines | Role |
|---|---|---|
| `apps/marketplace/lib/screens/user/shop/product_details_screen.dart` | 1,957 | The screen. See §3 for the live/dead call-graph. |
| `apps/marketplace/lib/screens/user/shop/widgets/product_image_hero.dart` | 284 | LIVE. Full-bleed image carousel + floating back/search/wishlist/share bar. |
| `apps/marketplace/lib/screens/user/shop/widgets/product_image_carousel.dart` | 160 | DEAD (see §3). |
| `apps/marketplace/lib/screens/user/shop/widgets/variant_selector.dart` | 158 | Built, unused (see §3). |
| `apps/marketplace/lib/screens/user/shop/widgets/delivery_info_widget.dart` | 267 | Built, unused (see §3). |
| `apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart` | 267 | Built, unused from the PDP today (see §3) — fully functional (stats bars, first 3 reviews, add-review dialog). |
| `apps/marketplace/lib/screens/user/shop/widgets/specification_list.dart` | — | LIVE, used by `_buildViewDetailsDropdown`. |
| `apps/marketplace/lib/screens/user/shop/widgets/product_share_widget.dart` | 598 | LIVE, shown via `_showShareWidget`'s bottom sheet. |
| `apps/marketplace/lib/screens/rfq/widgets/request_quote_sheet.dart` | — | LIVE, B2B-gated bulk-quote entry (RFQ-2). |
| `apps/marketplace/lib/widgets/cart_fly_animation.dart` | — | LIVE, "fly to cart" animation on add. |
| `apps/marketplace/lib/providers/product_provider.dart` | 823 | LIVE. Owns `selectedProduct`, `selectedVariant`, variant selection, related-products loading, recently-viewed. |
| `apps/marketplace/lib/providers/cart_provider.dart` | 610 | LIVE. Untouched by this phase — see §6. |
| `apps/marketplace/lib/providers/wishlist_provider.dart` | 187 | LIVE, product-scoped (not variant-scoped). |
| `apps/marketplace/lib/providers/review_provider.dart` | — | Built; only reachable today via the (dead) reviews wrapper — see §3. |

## 3. Live vs. dead call graph — the central finding

`product_details_screen.dart`'s `build()` (lines 214-271, this commit) is a `Consumer<ProductProvider>`
that renders exactly: `ProductImageHero` → `_buildOverlappedInfoCard` (which internally renders
`_buildDeliveryRatingInline`, the variant chips via `_buildVariantChipsInline`, and
`_buildViewDetailsDropdown`) → `_buildSoldBySection` → `_buildSubscriptionOptions` →
`_buildSimilarProducts`, plus `_buildBottomBar` as `bottomNavigationBar`.

Confirmed by exact call-count grep (`grep -c "methodName(" file` — 1 occurrence = definition only,
never called; a count of 2+ was individually traced to confirm the caller itself is reachable from
`build()`, since a method can be "called" only from another dead method):

**Confirmed DEAD (defined, never reachable from `build()`):** `_buildSliverAppBar`,
`_ProductDetailsSliverHeader` (its own class, a `SliverPersistentHeaderDelegate` with a correctly
implemented pinned/transparent-to-solid scroll transition — the ONE piece of dead code worth folding
forward rather than deleting, see §7), `_TabBarDelegate` (its own class, no other reference),
`_buildProductShowcase` (the only call site of the imported `ProductImageCarousel` widget — so that
import is also effectively dead), `_buildProductHeaderCard`, `_buildPremiumBadge` (only called from
the dead `_buildProductHeaderCard`), `_buildAdvancedPrice` (same), `_buildRatingRow` (same),
`_buildKeyInfoCard`, `_buildQuantitySelector` (**so is `_buildQuantityButton`, its only caller** — there
is no reachable quantity stepper anywhere in the file; `_quantity` starts at 1 and nothing in the live
tree ever changes it), `_buildDescriptionSection`, `_buildSpecificationsSection`, `_buildReviewsSection`
(**the only call site of `ReviewsSectionInline`** — the fully-built review system, stats bars, first-3
reviews, "Add Review" dialog, renders nowhere on the live screen), `_buildDeliveryRatingRow` (a second,
unused hardcoded-ETA implementation, duplicate of the live one below), `_buildProductInfo` (a bare
product-name `Text`, redundant with the live product-name display), `_buildExpandableDetails` (a THIRD
implementation of the description+specs accordion, duplicate of the live `_buildViewDetailsDropdown`),
`_buildSectionHeader` (an icon+title header helper, zero callers).

**Confirmed LIVE, with concrete gaps:**
- `_buildDeliveryRatingInline` (line ~387) hardcodes the literal string `'30 MINS'` — not derived from
  any product or serviceability data. `widgets/delivery_info_widget.dart`'s `DeliveryInfoWidget`
  already reads `product.shippingDays`/`isFreeDelivery`/`expressDelivery`/`expressDeliveryDays` for a
  real answer and sits unused in the same folder.
- `_buildVariantChipsInline` (line ~445) is a working, correct variant selector, but it is a second,
  hand-rolled implementation of the same UI `widgets/variant_selector.dart`'s `VariantSelector` already
  provides (also unused) — a duplicate-widget finding per `uiux.md` §1 rule 1.
- `_buildSoldBySection` (line ~1014) does its own inline `FirebaseFirestore.instance.collection('sellers').doc(...).get()` fetch (a second, independent seller read alongside `BusinessProfileScreen`'s own) and renders only `shopName` behind a `chevron_right` — no verification badge, no seller identity beyond the shop name.
- `_buildPremiumBadge` (dead today, so not a live regression, but not worth resurrecting as-is) renders
  an unconditional "Authentic" badge with no data backing — see §5.
- `_buildSimilarProducts` (line ~1563) queries `productProvider.products` filtered to the same
  `categoryId`, independent of and never reading `product.relatedProductIds` — which `product_provider.dart`'s
  own `loadProductById`/`_loadRelatedProducts` already populates into a `relatedProducts` getter that
  is itself never rendered by this screen. Two parallel "related products" mechanisms exist; only the
  weaker (same-category) one is wired to the screen.
- `_buildBottomBar` (line ~1138) renders exactly one CTA: `ElevatedButton` → `'Add to cart'` /
  `'Out of Stock'`, calling `_addToCart(context, buyNow: false)`. **No Buy Now button exists anywhere
  in the live tree.** `_addToCart`'s own `{bool buyNow = false}` parameter has a `buyNow: true` branch
  (skip the fly animation, navigate straight to cart) that is never invoked from any call site — dead,
  pointless, and a standing invitation to add a Buy Now button later by accident.

## 4. Data model (VERIFIED_REPOSITORY_FACT, `packages/agrimore_core/lib/models/`)

`ProductModel` (`product_model.dart`, 579 lines) already carries: `variants: List<ProductVariant>`,
`variantOptions: List<VariantOption>`, `relatedProductIds: List<String>?`, `specifications: Map<String,
String>?`, `rating`/`reviewCount` (product-level), `isFeatured`/`isVerified`/`isTrending`/`isNew`
(booleans, data-driven badge material), `sellerId` (product-level, not variant-level — one seller per
product, confirmed), `discount` (computed getter, safe against `sellingPrice >= mrp`).
`ProductVariant` already carries its own `images: List<String>`, `salePrice`/`originalPrice`, `stock`,
`sku`, `options: Map<String,String>`, and its own `discount` getter. **Variant-specific media is not
a gap in the data model — it already exists and is already wired reactively** (see §6).

No `ProductVariant.subscriptionEligible` field exists — every variant is implicitly subscription-eligible
today; the "switch to a variant that doesn't support subscription" edge case (master-prompt §16/81) has
no real failure mode to reproduce because no variant currently declares itself ineligible.

`ReviewModel`/`ReviewStats` (`review_model.dart`) are product-scoped only: `productId`, `userId`,
`rating`, `comment`, `isVerifiedPurchase`, no `sellerId` field anywhere. **There is no seller-level
rating anywhere in this codebase** — `sellers/{uid}` carries no rating field, and no aggregation exists.
Any "seller rating" shown on a seller-facing surface would be new work, not a wiring gap (tracked as a
candidate phase, `SELLER-METRICS-1`, deliberately out of this phase's scope).

## 5. Gaps — the delta between what a customer sees today and the target

1. No tappable thumbnail strip below the hero image (pagination dots only).
2. Reviews render nowhere (dead code, §3).
3. No quantity stepper anywhere reachable (dead code, §3) — a customer cannot add more than 1 unit
   from this screen today.
4. `'30 MINS'` hardcoded delivery time (live code, §3).
5. Unconditional "Authentic" trust badge exists only in dead code — do not resurrect verbatim; badges
   must key off `product.isVerified`/`isFeatured`/`isTrending`/`isNew`.
6. Sold-by card is a bare shop-name link; no Verified-seller signal even though
   `sellers/{id}.status=='approved'` is a real, rules-enforced fact available for it
   (`ownerCannotApproveSellerStatus()` in `firestore.rules` — a seller cannot self-approve).
7. Recommendations prefer a generic same-category query over the curated `relatedProductIds` field
   when the latter is populated.
8. The dead reviews wrapper's "View all N reviews" button has an empty `onPressed` — a pre-existing
   dead control (`reviews_section_inline.dart:122-125`, comment: `// Could navigate to full reviews page`).
9. `_buildLoadingState` is a centered spinner + text, not a sectional skeleton.

## 6. Confirmed ALREADY WORKING — do not rebuild

- Variant selection reactively drives the main gallery: `ProductImageHero` (`product_image_hero.dart:46-51`)
  reads `productProvider.selectedVariant?.images` via a listening `Provider.of<ProductProvider>(context)`,
  falling back to `product.images` then `product.imageUrl`. Tapping a variant chip calls
  `productProvider.selectVariantByName(...)`, which `notifyListeners()`s, which rebuilds the hero with
  the new variant's own images — already exactly the master-prompt's headline "tap 1L, image changes"
  requirement, with no navigation and no reload.
- Variant selection reactively drives price and stock (`_buildAdvancedPrice`/dead but `_buildKeyInfoCard`/dead
  used `Consumer<ProductProvider>` correctly; the LIVE `_buildVariantChipsInline` and `_buildBottomBar`
  both correctly read `productProvider.selectedVariant?.salePrice ?? product.salePrice` etc.).
- `CartProvider`'s `addItem`/`removeItem`/`updateQuantity`/`incrementQuantity`/`decrementQuantity`/
  `isInCart`/`getItemQuantity`/`getCartItem` are ALL keyed on `(productId, {String? variant})`, keeping
  cart quantity independent per variant (`cart_provider.dart:98-585`) — the master-prompt's cart+variant
  edge case (§82) is already handled correctly.
- Wishlist (product-scoped, `WishlistProvider`), share (`ProductShareWidget` bottom sheet), and the
  RFQ bulk-quote entry (`_showRequestQuoteSheet`, B2B-gated on `product.isB2BEnabled`) all work today.
- No Buy Now button exists anywhere live (§3).

## 7. What this phase will do about it

See the phase contract (`~/.agrimore/run/agrimore/state.json`, phase `PDP-1`) for the bounded
workstream list. In one sentence: convert the outer scroll to a `CustomScrollView`/Slivers (folding
`_ProductDetailsSliverHeader`'s already-correct pinned-header pattern forward rather than rebuilding
it), resurrect the reviews section and a real quantity stepper into the live tree, wire real delivery
data, make badges data-driven, enrich the Sold-by card with a Verified badge only, prefer
`relatedProductIds` for recommendations when populated, delete the confirmed-dead identifiers listed in
§3, wire the dead review-list button, and remove the pointless `buyNow` parameter — without touching
`cart_provider.dart`, `firestore.rules`, `functions/**`, or the subscription/RFQ mechanisms this screen
already correctly delegates to.

## 8. Explicitly out of scope for this phase (see phase contract for why)

- The parallel `subscriptions` collection / `SubscriptionSetupScreen` / `my_subscriptions_screen.dart`
  path — confirmed NOT reachable from this screen. The live recurring-purchase mechanism is the
  `ChoiceChip` cadence selector (`_buildSubscriptionOptions`) + `CartProvider.setCheckoutSubscriptionIntent`
  + `orderType` at checkout via `createOrder.ts`. Two parallel mechanisms exist in this codebase;
  reconciling them is an owner-level architecture decision, not this phase's.
- A seller-level rating/review aggregate (§4) — no real data source exists.
- Nutrition-specific structured fields — no backend field exists; the generic `specifications` Map
  already renders live via `SpecificationList` and is sufficient for a seller/admin to enter nutrition
  rows as free-form key/value pairs today.
- Fullscreen pinch-zoom gallery viewer — nice-to-have, deferred.
- Cart concurrency/debounce hardening — pre-existing, cross-cutting, its own phase.
