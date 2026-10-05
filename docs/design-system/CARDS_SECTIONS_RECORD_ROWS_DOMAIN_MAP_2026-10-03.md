# Agrimore — C12 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-board gallery](CARDS_SECTIONS_RECORD_ROWS_BOARDS_2026-10-03.md) · [Locked C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and evidence limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 eligible source files / 271,604 lines** scanned across all five app lib trees, agrimore_ui/core/services and functions/src. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Focused semantic reads cover representative app card layouts, navigation affordances and record rows. This is a broad static inventory plus focused review, not a semantic audit of every line or a rendered review of every screen. Backend files provide domain context; they do not own card layouts.

Construction markers include comments and are not unique component/screen or defect counts. Custom Container-based cards are undercounted by the Card marker. A zero direct Semantics marker does not prove absence of implicit Material semantics. Current observations are a timestamped local source snapshot; implementation may proceed in another chat.

| Scope | card | list_tile | record_row | section_header | divider | interactive | semantics | ellipsis | grid |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 67 | 53 | 0 | 0 | 46 | 129 | 0 | 39 | 10 |
| delivery | 28 | 4 | 0 | 2 | 11 | 56 | 16 | 21 | 4 |
| employee | 9 | 5 | 0 | 0 | 15 | 27 | 0 | 9 | 3 |
| marketplace | 10 | 12 | 0 | 0 | 36 | 363 | 7 | 111 | 29 |
| seller | 66 | 0 | 60 | 21 | 11 | 92 | 73 | 7 | 5 |
| functions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 0 | 0 | 0 | 0 | 0 | 5 | 5 | 4 | 0 |

## Shared and app-local infrastructure

SellerCard/SellerListRow/MenuGroup/KeyValueRow and DeliveryCard/SectionHeader already cover reusable surfaces; reuse and extend them. Sales Associate uses shared saTokens with screen-local containers. Shared UI provides theme, responsive breakpoints, ErrorView, EmptyState and LoadingOverlay; SellerImage provides app-local media framing and loading/missing/error states. no generic Card/ListTile constructor marker was found in its scanned source. That marker result is not proof that the package has no relevant helpers. Marketplace and Admin domain cards need anatomy/theme alignment in a future bounded migration.

Verified shared/app-local anchors:

- [ErrorView](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)
- [EmptyState](../../packages/agrimore_ui/lib/widgets/common/empty_state_widget.dart)
- [LoadingOverlay](../../packages/agrimore_ui/lib/widgets/common/loading_overlay.dart)
- [Breakpoints](../../packages/agrimore_ui/lib/responsive/breakpoints.dart)
- [SellerImage](../../apps/seller/lib/design_system/components/seller_media.dart)

## Shared target surface contract

1. Cards group one identifiable domain record. Order identity, contextual stage, supporting metadata and primary detail/action are distinct slots. Group related key/value rows into a section instead of putting every label into a separate card.
2. Static surfaces have no fake chevron or button role. Navigable cards/rows get a visible affordance, accessible name and keyboard activation. Independently labelled nested actions have separate focus/targets and activate once without triggering the parent.
3. Selection, hover, press, focus, loading and domain status are independent. A focus outline is not a selection check; selection is not approval, publication, delivery completion or payment settlement.
4. Use stable domain IDs as record keys, retain identity during asynchronous updates, and reconcile selection and interaction availability when a record disappears or permissions change. Display order is not identity.
5. Preserve null, malformed and unavailable values distinctly from known zero. Price, stock, total, commission and route data come from the authoritative domain source. No invented badges, ratings, percentages, counts, elapsed times, ETA or guarantees.
6. Keep order stage, payment state, fulfillment state, commission eligibility and payout settlement separate. Product Credit is a distinct domain ledger, not a wallet balance. Example sample statuses never claim live server confirmation.
7. Related sections use shared header/caption/divider spacing. Contextual errors stay within the affected surface; retry only that scope. Loading preserves geometry without inventing record text; empty differs from read failure. Reuse existing media/feedback helpers and app surfaces.
8. Wide rows align identity, metadata and values; narrow layouts and 100–200% text stack content in meaningful reading order. Wrap essential names/status/values, keep safe image fallback, and do not truncate the only identifying field without an accessible full name.
9. Minimum target interaction region 48px; focus uses the C01 2px role. Decorative media/icons are excluded from duplicate semantics. Status has text as well as color. Semantics distinguish one grouped summary from independent actions.
10. Use each locked C01 palette, Inter hierarchy, 4/8/12/16/24/32 spacing, app-specific Card/Control radii and role-correct inverse text. Neutral near-black dark surfaces, restrained elevation and hairlines. Avoid nested raised-card stacks and status gradients.
11. Extend existing SellerCard/SellerListRow/SellerMenuGroup/SellerKeyValueRow and DeliveryCard/DeliverySectionHeader. Reuse associate saTokens and shared themes/responsive/feedback/media foundations. Any future shared-package migration must analyze all five apps and verify actual screens.

## Source findings and migration priority

| Priority | Evidence | Target / gate |
| --- | --- | --- |
| Consistency | Marketplace UnifiedProductCard grid uses 12px corners/0.5px border; OrderCard uses 14px/1.5px and a white Material surface. | Migrate deliberately to C01 role targets; validate six variants, nested wishlist/track actions and dark mode. |
| Reuse | SellerCard/ListRow/MenuGroup already implement semantic/focus and grouped surface patterns. | Preserve behavior and large-text stacking; avoid duplicate generic cards. |
| Reuse | DeliveryCard and RiderRouteCard already scope route/stream health within a composed surface. | Retain local retry/stale-state handling; card status never implies route health or completion. |
| Data presentation | Associate order total and transaction amount use missing-value 0.0 fallback in targeted source. | Future unavailable-versus-known-zero presentation needs domain parsing and null-case verification; no live-state financial assertion. |
| Consistency / interaction | AdminOrderCard uses white gradients, 20px corners, GestureDetector and shimmer; product card uses dark/light literals and 12px corners. | Use locked neutral surfaces/radii and explicit focus/semantics; validate actual keyboard/screen-reader behavior. |

## Agrimore Marketplace

**Current implementation snapshot:** UnifiedProductCard defines six layouts, while compact, search, shop and order-specific cards still coexist. Its grid uses a 12px radius, 0.5px border and multiple overlapping badges; this is a current implementation snapshot, not evidence that consolidation is complete.

**Target:** One product anatomy with grid/list/compact variants, controlled media ratio, explicit variant/availability and price provenance. Order summaries and wallet/product-credit rows remain different record types.

**Domain character:** Media-led shopping surfaces, generous product hierarchy and calm stone sections with green actions and restrained gold guidance.

| Panel | Specimen |
| --- | --- |
| Product cards | Two beautiful media-led specimens, a compact grid card and horizontal list card. Neutral seed-pack illustration, no brand claims. Exact content: Sample product; Seeds; Price unavailable; View product. A price slot is clearly unavailable, never zero. No ratings, verified badges or sale percentages. |
| Grouped sections | Heading Product details, caption Illustrative record, single grouped surface with rows Category / Seeds and Variant / Not selected. Plain divider, no separate card for each label. Gold is a small guidance accent. |
| Order record rows | One tappable row Sample order, neutral chip Pending (sample), helper Order details, right chevron. Separate static row Order total / Unavailable with no chevron. Annotate Navigate versus Read only. |
| Surface states | Three compact specimens Loading product with neutral skeleton; No saved products with quiet empty-state outline; Product unavailable with Retry scoped to this card. Small focused outline example labelled Keyboard focus. Footer Wrap long titles; keep price readable. |

Gaps and invariants:

- Consolidate anatomy deliberately without removing variant, B2B, stock or independent wishlist behavior.
- C01 target card radius is 16px; existing 12px layouts are a future migration, not changed here.
- Missing price, image or stock must remain explicit; badges require verified source data.

Source anchors:

- [unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [product_card_compact.dart](../../apps/marketplace/lib/screens/user/home/widgets/product_card_compact.dart)
- [order_card.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_card.dart)
- [cart_item_card.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
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
| user/cart | 9 |
| user/categories | 2 |
| user/checkout | 7 |
| user/flash_sale | 1 |
| user/help | 1 |
| user/home | 27 |
| user/main_screen.dart | 1 |
| user/notifications | 1 |
| user/offers | 1 |
| user/orders | 15 |
| user/profile | 9 |
| user/rewards | 1 |
| user/rfq | 3 |
| user/search | 3 |
| user/settings | 1 |
| user/shop | 20 |
| user/subscriptions | 2 |
| user/wallet | 9 |
| user/wishlist | 5 |

## Agrimore Seller

**Current implementation snapshot:** SellerCard supplies tones, selected/focused outlines, optional interaction and semantics. SellerListRow, SellerMenuGroup and SellerKeyValueRow already provide reusable grouped and record layouts; list values stack at large text. These are reuse anchors rather than reasons to duplicate components.

**Target:** Compose stock/product/order/RFQ summaries from existing Seller surfaces. Give each record a stable identity, status and one primary detail path; group key/value rows and keep unknown stock distinct from zero.

**Domain character:** Compact blue-teal operational cards, copper section cues, cool neutral grouped rows and precise inventory hierarchy.

| Panel | Specimen |
| --- | --- |
| Operational cards | Structured Sample product card with box outline icon, Inventory subtitle, neutral Draft (sample) chip, Stock / Unknown, View product action. Beside it a small Sample quote summary marked Draft (sample), no money or approval claims. |
| Inventory sections | Copper eyebrow INVENTORY DETAILS; grouped label/value rows Product / Sample product, Variant / Not selected, Stock / Unknown. Comfortable blue-teal section title and hairline separators. Explain Unknown is not zero. |
| Record rows | Navigable Sample order row with Order details subtitle and chevron; adjacent static Invoice total / Unavailable row with no chevron. Narrow/large-text rendition puts long value below label. |
| Surface states | Small Rest, Selected, Focused specimens clearly distinct; Selected has check and tinted fill, Focused has 2px focus outline without a check. Separate scoped Inventory unavailable with Retry and loading skeleton. Note One row, one activation. |

Gaps and invariants:

- Retain existing independent selection/focus semantics and large-text stacking.
- Stock values must use validated domain data; do not turn malformed or missing stock into zero.
- An invoice or quote summary is distinct from payment confirmation.

Source anchors:

- [seller_card.dart](../../apps/seller/lib/design_system/components/seller_card.dart)
- [seller_list.dart](../../apps/seller/lib/design_system/components/seller_list.dart)
- [seller_layout.dart](../../apps/seller/lib/design_system/components/seller_layout.dart)
- [order_invoice_card.dart](../../apps/seller/lib/screens/orders/widgets/order_invoice_card.dart)
- [quote_tile.dart](../../apps/seller/lib/screens/rfq/widgets/quote_tile.dart)
- [stock_count_validation.dart](../../apps/seller/lib/screens/products/stock_count_validation.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
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

## Agrimore Delivery

**Current implementation snapshot:** DeliveryCard supports standard, muted, brand, outlined and elevated variants, with interactive state handling through DeliveryInteractive. RiderRouteCard composes route Map/Details and scoped stream/stale-location feedback within the card. DeliverySectionHeader already handles title, subtitle, eyebrow and trailing content.

**Target:** Compose assignment, route and stop summaries through DeliveryCard. Separate pickup/drop-off identity, task state, route health and ledger information; leave unavailable location/address data explicit.

**Domain character:** High-contrast black/white task cards with burgundy contextual accents and burnt-orange guidance; larger scan targets and simple stop rows.

| Panel | Specimen |
| --- | --- |
| Task cards | Large Sample task card, Assigned (sample) neutral status chip, prominent monochrome title. Two stacked stops Pickup / Collection point and Drop-off / Delivery point, generic address subtitle Address unavailable. Main action View task. Orange appears as guidance only. |
| Route sections | Single grouped surface heading Route details, burgundy eyebrow TASK CONTEXT; Pickup and Drop-off rows with connected simple outline markers; No route estimate annotation. Never render map, distance or ETA. |
| Stop record rows | Pickup details navigable row with chevron and strong monochrome label. Static Address / Unavailable row no chevron. Narrow specimen wraps generic multi-line location label. Touch areas generous. |
| Surface states | Loading task skeleton; No assigned tasks quiet empty card; Route unavailable scoped Retry inside its surface. Separate 2px burnt-orange focus outline labelled Focused. Footer Assignment is not completion. No success receipt or tracking promise. |

Gaps and invariants:

- Preserve route-health and stale-location feedback within the affected section.
- Assigned is not picked up, delivered or paid; a card selection never confirms a handover.
- Keep address wrapping and independently labelled actions; never invent ETA, distance, live tracking or handover code.

Source anchors:

- [delivery_card.dart](../../apps/delivery/lib/design_system/components/delivery_card.dart)
- [rider_route_card.dart](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart)
- [active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)
- [rider_history_screen.dart](../../apps/delivery/lib/screens/history/rider_history_screen.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
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

## Agrimore Sales Associate

**Current implementation snapshot:** OrdersScreen builds tappable order containers using saTokens, identity, stage, mode/date and total. WalletScreen builds read-only transaction ListTile containers. Both targeted sources coerce missing monetary values to 0.0; the proposal instead requires explicit unavailable values. This snapshot does not assert a live financial defect.

**Target:** Reusable order/relationship summary anatomy with readable identities and indigo context; group order details separately from commission/payout records. Navigable order rows have an affordance; read-only ledger rows have none.

**Domain character:** Premium royal-blue relationship and order surfaces, indigo supporting cues, pearl/slate rows and clear separation of commercial versus ledger information.

| Panel | Specimen |
| --- | --- |
| Order summary cards | Refined Sample order card with subtle bag outline, Business order subtitle, Pending (sample) chip, Total / Unavailable, View order action. Indigo is a small context accent, no invented customer identity. |
| Relationship sections | Single grouped Order context surface, rows Account / Sample account; Order mode / Business; Commission / Unavailable. Pearl/slate background and indigo eyebrow. No invented commission percentage or eligibility promise. |
| Ledger record rows | Read-only Sample payout request row with Requested (sample), Amount unavailable, no chevron. Clearly separate Sample order row with chevron. Small explanation Requested is not settled. |
| Surface states | Loading order skeleton; No linked orders quiet empty-state surface; Ledger unavailable scoped Retry. Separate Focused order row 2px blue outline. Narrow example stacks label and value. Footnote Missing amount stays unavailable. |

Gaps and invariants:

- Preserve separate order stage, commission eligibility and payout settlement semantics.
- Unavailable monetary values must not display as a known zero.
- Retain saTokens reuse; verify long identity and date/value layouts with text scaling.

Source anchors:

- [orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart)
- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| auth | 5 |
| home | 1 |
| notifications | 1 |
| orders | 2 |
| profile | 2 |
| shell | 1 |
| support | 1 |
| wallet | 6 |

## Agrimore Admin

**Current implementation snapshot:** AdminProductCard uses Card/InkWell, fixed media, hardcoded dark/light colors and badges. AdminOrderCard uses GestureDetector, white gradients, 20px corners, status strip and shimmer. Different surface and interaction structures need a canonical target, not a claim they already match C01.

**Target:** Compact record anatomy with identity, type, stage and explicit detail action. Group operational fields once, adapt wide aligned columns to stacked mobile rows, and keep review/selection independent from authorization or mutation.

**Domain character:** Professional blue review cards, cyan context cues, steel/slate grouped records and dense but readable wide-to-stacked layouts.

| Panel | Specimen |
| --- | --- |
| Review cards | Compact Sample product record card, Product subtitle, Draft (sample) chip, Category / Seeds, explicit View record button. Professional-blue action; cyan is a tiny context cue, no verified/approved badge. |
| Structured sections | Record details grouped surface with Product / Sample product, Category / Seeds, Visibility / Draft (sample). Label/value grid aligned, neutral surface with hairlines, no gradient status strip. |
| Wide and narrow rows | Wide compact mini table with headers Record / Type / State / Action and one Sample product / Product / Draft (sample) / View row. Below show same record stacked for mobile with View record action. No sidebar, checkbox or batch mutation. |
| Surface states | Static summary, Interactive record and Focused record specimens, clearly separate. Focused has 2px blue outline. Small Records unavailable with Retry and loading skeleton. Caption Selection is not approval. Neutral dark surfaces only. |

Gaps and invariants:

- Future migration must replace hardcoded white order surfaces and differing radii with theme roles.
- GestureDetector-only order cards need keyboard focus/activation and accessible role verification.
- Selection or a review badge does not approve, publish, pay or change permissions.

Source anchors:

- [admin_product_card.dart](../../apps/admin/lib/screens/admin/products/widgets/admin_product_card.dart)
- [admin_order_card.dart](../../apps/admin/lib/screens/admin/orders/widgets/admin_order_card.dart)
- [user_card.dart](../../apps/admin/lib/screens/admin/users/widgets/user_card.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Render actual cards/rows in both themes at phone and applicable web widths, 100–200% text scaling, long names/values, missing images, null/malformed/zero numeric values and localized dates/numbers.
- Verify source-backed status labels, stage/payment/commission/ledger separation and sample placeholders removed from production. No premature success or invented records.
- Keyboard and screen-reader traversal: single grouped record identity, explicit button/link role where interactive, full essential labels, independent nested actions, focus distinct from selected, one activation.
- Loading/empty/scoped read error, retry behavior, stale data and disappearing records. Preserve stable IDs and available values; selection never invokes a bulk action by itself.
- Responsive grouped key/value wrapping, table-to-stacked reading order, media aspect/fallback, restrained elevation and target size.
- Reuse existing equivalents; no runtime duplicated Card/row/helper implementation. Shared package changes require all five app analyzers and actual rendered before/after evidence.

## Delivery scope and design lanes

27 new repository files: ten PNGs, five per-app README/prompts/manifest sets, two master documents. Earlier C01–C11 files preserved. C12 is provisional; no owner approval inferred. User explicitly requested image prompt provenance, so these prompts.md are image records rather than exported implementation-worker prompts.

UIUX/feedback design review: app-specific identities, grouped hierarchy, safe missing-value copy and scoped feedback visually reviewed on generated boards. Runtime gates are not applicable evidence for an assets-only task; Flutter analysis, emulator, real account access and runtime accessibility were not performed. No Dart/TypeScript/runtime, pubspec registration, staging/commit/branch, deploy or other-chat interruption by this task. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset verification evidence

Assets-only verification completed 2026-10-03: **PASS**. Ten PNGs form five light/dark pairs; all 27 declared new repository files exist. PNG dimensions and chunk CRCs, selected-source/output hashes, exact C01 palette/status/typography/spacing/radius/border metadata and reference hashes verified. All 13 original/refinement prompt blocks reproduce their recorded hashes; 84 local document links resolve. All **648** earlier design files remain byte-identical.

All 817 inventoried runtime source hashes remained unchanged through packaging and verification; the recorded platform configurations also remained unchanged. HEAD stayed `97f171f00f8330f1ae7c831845e4dd94a8ae2c33`; current checkout branch was `agrimore/foundation-f3c-distance-delivery-pricing`, belonging to the existing implementation work. This task did not change branches or the index.

The repository surface classifier returned the **docs** lane for these asset/document paths. UIUX and feedback copy were additionally reviewed as design specimens. Verification proves saved-file/provenance integrity, not exact raster token rendering, working interactions, runtime accessibility or implementation completion.
