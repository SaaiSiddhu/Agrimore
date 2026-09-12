# Product Detail Page V2 — what PDP-1 shipped

Companion to [`PRODUCT_DETAIL_CURRENT_STATE.md`](PRODUCT_DETAIL_CURRENT_STATE.md) (the before-state
audit). This is the after-state: what changed, why, and what's still open. Measured at
`agrimore/pdp1-product-detail-redesign` = `6cf384b` (base `develop@bf5c1e7`).

## 1. Architecture (unchanged)

Same as §1 of the audit doc: Flutter, `provider`, direct Firestore reads, no dedicated product-detail
API. This phase did not touch that shape — it restructured one screen's presentation and reconnected
already-built pieces, not the app's data-access pattern.

## 2. Screen anatomy — before → after

```
Before (SingleChildScrollView, no persistent header):        After (CustomScrollView + pinned header):
  ProductImageHero (owns its own floating icon bar)            SliverPersistentHeader (pinned)
  _buildOverlappedInfoCard                                       -- back / search / wishlist / share
    _buildDeliveryRatingInline (hardcoded '30 MINS')             -- product name fades in once collapsed
    _buildVariantChipsInline                                   SliverToBoxAdapter
    _buildViewDetailsDropdown                                    ProductImageHero (media only now)
  _buildSoldBySection (shopName only)                             + tappable thumbnail strip (new)
  _buildSubscriptionOptions                                     _buildOverlappedInfoCard
  _buildSimilarProducts (same-category only)                      _buildDeliveryRatingInline (B2B-aware label)
  [reviews: built, never rendered]                                _buildProductBadges (new -- data-driven)
  [quantity stepper: built, never rendered]                       _buildVariantChipsInline (unchanged)
  bottomNavigationBar: Add to Cart only                            _buildViewDetailsDropdown (unchanged)
                                                                  _buildSoldBySection (+ Verified badge)
                                                                  _buildSubscriptionOptions (unchanged)
                                                                  _buildReviewsSection (now rendered)
                                                                  _buildSimilarProducts (relatedProductIds-first)
                                                                bottomNavigationBar: Add to Cart ⇄ [-] N [+]
```

13 methods and 2 classes with zero live call sites were deleted outright (full list in the audit doc
§3); their good parts were folded forward rather than rebuilt from scratch (see §3).

## 3. Variant switching

Unchanged in substance — this already worked correctly before this phase and nothing here regresses
it: `ProductProvider.selectVariantByName` → `notifyListeners()` → every `Consumer<ProductProvider>` in
the tree (gallery, price, stock, variant chips, bottom bar) rebuilds off `productProvider.selectedVariant`.
No navigation, no reload.

## 4. Media model

`ProductVariant.images` (already in the schema) is the variant-specific gallery; `ProductImageHero`
prefers it, falling back to `product.images` then `product.imageUrl`. New in this phase: a tappable
thumbnail strip below the hero image (`_buildThumbnailStrip` in `product_image_hero.dart`), driven by
the same `CarouselSliderController` so tapping a thumbnail animates the main carousel to it. The old
top-navigation icon bar that used to live inside `ProductImageHero` moved out into the screen's own
pinned sticky header (`_StickyHeaderDelegate`) so it stays reachable while scrolled past the image.

## 5. Seller integration

`_buildSoldBySection` now shows a "Verified Seller" badge + checkmark when `sellers/{id}.status ==
'approved'` — a genuine signal, not a self-reported one: `firestore.rules`' `ownerCannotApproveSellerStatus()`
makes self-approval impossible for a seller. No seller rating is shown. The `reviews` collection is
product-scoped only (`ReviewModel` has no `sellerId` field, confirmed by full-file read) — there is no
real seller-level rating anywhere in this codebase to display honestly. A seller-rating aggregate
(rolling up a seller's product reviews via a Cloud Function trigger) is a real, buildable feature but
is new backend work, not a wiring gap — tracked as a candidate phase (`SELLER-METRICS-1`), not
attempted here to avoid fabricating a number.

## 6. Subscription integration (unchanged, disclosed)

The live mechanism is unchanged: the `[One-time] [Daily] [Weekly]` `ChoiceChip` row sets
`_subscriptionCadence`, which on Add to Cart calls `CartProvider.setCheckoutSubscriptionIntent(...)` —
an in-memory hint (not stored on the cart document) that the checkout screens read to set `orderType`
on the order created via `createOrder.ts`. This phase confirmed, but did not touch, a second, parallel
recurring-purchase mechanism in this codebase: `SubscriptionSetupScreen` /
`my_subscriptions_screen.dart` / a standalone `subscriptions` Firestore collection, written directly
client-side with a client-computed price. That screen is **not reachable from the Product Detail Page**
today (no import, no call site) — it's wired from elsewhere in the app. Reconciling the two parallel
mechanisms is an architecture decision for the owner, out of this phase's scope.

## 7. Cart integration (unchanged)

`CartProvider`'s `addItem`/`incrementQuantity`/`decrementQuantity`/`getItemQuantity`/`isInCart` were
not modified. New in this phase: the sticky bottom bar now calls `getItemQuantity`/`isInCart` to decide
whether to show "Add to cart" or a live `[-] N [+]` stepper wired straight to `incrementQuantity`/
`decrementQuantity` — the master-prompt's own "transform into quantity controls once in cart"
requirement. Add-to-cart always adds quantity 1 now (the dead pre-add quantity selector card was not
resurrected as a separate control — this app's own established pattern, matched by the new stepper, is
add-then-adjust, not select-quantity-then-add).

## 8. Recommendations integration

`_buildSimilarProducts` now prefers `product.relatedProductIds` (already resolved into
`ProductProvider.relatedProducts` by `loadProductById` on every load, previously computed but never
rendered) over the generic same-category query, when populated. Section title becomes "You May Also
Like" for the curated case, stays "Similar products" for the honest generic fallback. Today the
fallback is still the common path in practice (most products don't have `relatedProductIds` populated
yet) — this is a real, working preference, not a guarantee every product shows curated results.

## 9. API / database changes

None. Every change in this phase is client-only (`apps/marketplace/lib/**`). No `firestore.rules`,
`storage.rules`, `firestore.indexes.json`, or `functions/**` file was touched.

## 10. Analytics

Not instrumented in this phase — this codebase has no existing analytics-event convention on this
screen to extend (no `product_detail_viewed`/`product_variant_selected`-style calls found anywhere in
the pre-existing file), and inventing an event taxonomy from scratch is a bigger, separate decision
than a UI redesign phase should make unilaterally. Disclosed as not done, not silently skipped.

## 11. Testing

`flutter analyze apps/marketplace`: 0 errors at every commit in this phase (WS2 `9febfb0`, WS3
`b52efde`, WS4 `6cf384b`); total issue count improved from the WS2 dead-code deletion (174→152
warnings, 354→349 infos) and stayed flat through WS3/WS4 (zero new warnings/infos introduced).

No new automated test was added. `apps/marketplace/test`'s three existing files
(`product_provider_test.dart`, `category_provider_test.dart`, `routes_test.dart`) all test
provider/routing logic in isolation via `setupFirebaseCoreMocks()` + a fake `DatabaseService`
subclass — none of them render a widget tree. `ProductDetailsScreen` is a `StatefulWidget` wired to
five live providers (`ProductProvider`, `CartProvider`, `WishlistProvider`, `ThemeProvider`,
`CategoryProvider`) plus a direct Firestore read in `_buildSoldBySection` — a real widget test would
need to mock all of that from scratch, with no existing screen-level widget-test precedent in this
repo to mirror. That is a genuine, non-trivial undertaking, not "cheap test coverage" as the phase
contract scoped it — attempting a shallow version that doesn't actually exercise the real provider
wiring would prove nothing (this skill's own evidence discipline: "a test that does not exist" is not
proof, and neither is a hollow one). Disclosed as not done rather than faked.

## 12. Future enhancements (not this phase)

- `SELLER-METRICS-1`: a real seller-rating aggregate (Cloud Function trigger rolling up a seller's
  product reviews), so the Sold-by card and Seller Storefront can show an honest seller rating.
- A screen-level widget test harness for `ProductDetailsScreen` (or its own smaller, more testable
  sub-widgets), once one exists as a repo-wide pattern to follow.
- Reconciling the two parallel recurring-purchase mechanisms (checkout-intent auto-delivery vs. the
  standalone `subscriptions` collection) — an owner-level architecture decision.
- Fullscreen pinch-zoom gallery viewer (deferred, nice-to-have).
- Analytics instrumentation for this screen, once the app has a taxonomy convention to extend.
