# Agrimore — C13 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-board gallery](SEARCH_FILTER_SORT_COMPOSITION_BOARDS_2026-10-03.md) · [Locked C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and evidence limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 eligible source files / 271,604 lines** scanned across all five app lib trees, agrimore_ui/core/services and functions/src. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Focused semantic reads cover representative query/search pipelines, selection cardinality, sort adoption and staged/immediate reset behavior. This is a broad static inventory plus focused review, not a semantic audit of every line or a rendered review of every screen. Backend and service source provide query/scope context; no backend or query implementation changed.

Construction markers include comments and are not unique component/screen or defect counts. TextField-based and custom discovery controls are undercounted by named search-widget markers. Marker absence does not establish feature absence or complete adoption. Current observations are a timestamped local source snapshot; implementation may proceed in another chat.

| Scope | search_field | search_query | choice_chip | sort | query_order | query_limit | filter_apply | reset_clear |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 0 | 54 | 21 | 37 | 52 | 31 | 0 | 0 |
| delivery | 2 | 3 | 1 | 7 | 5 | 7 | 4 | 8 |
| employee | 0 | 8 | 3 | 0 | 5 | 6 | 0 | 0 |
| marketplace | 2 | 65 | 3 | 53 | 18 | 22 | 10 | 5 |
| seller | 5 | 5 | 14 | 14 | 8 | 13 | 9 | 0 |
| functions | 0 | 0 | 0 | 15 | 7 | 29 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 0 |
| agrimore_services | 0 | 0 | 0 | 4 | 18 | 12 | 0 | 0 |
| agrimore_ui | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Existing discovery infrastructure

SellerSearchField already exposes query clear and ProductFilterBar provides single operational filters; SellerProductProvider composes local query/filter/sort. DeliverySearchField and RiderHistory separate lookup from list filtering, with a staged history sheet. Associate uses saTokens and immediate local mode controls. Admin screen-local search/chips and provider sort methods have separate adoption status. Shared UI themes/responsive and safe feedback primitives are reuse anchors; a new generic search widget is not introduced here.

Verified infrastructure anchors:

- [SellerSearchField](../../apps/seller/lib/design_system/components/seller_search.dart)
- [DeliverySearchField](../../apps/delivery/lib/design_system/components/delivery_search.dart)
- [Associate tokens](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)
- [ErrorView](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)
- [Breakpoints](../../packages/agrimore_ui/lib/responsive/breakpoints.dart)

## Shared target discovery contract

1. Compose one canonical discovery state from query, applied domain filters and selected sort. Apply query/filter predicates before sorting the same source set; submission, clear, retry and reload must not silently bypass applied filters.
2. Name the search scope: loaded products, loaded attributed orders, owned exact order lookup or another verified domain scope. A bounded/local no-match is not proof of a global no-match. Expose Load more when appropriate and avoid claims of exhaustive results.
3. Persistent search label names the searchable fields. Clear query removes text only and preserves applied filters/sort in the target; typing/submit behavior is explicit. Decide debounce or explicit submission deliberately and protect against stale asynchronous responses.
4. Single-choice status/mode tabs replace the previous selection. Category multi-select remains independent. Active chips mirror committed state and remove only their named predicate; selection is not a server mutation, approval, publication, task completion or settlement.
5. Staged sheets copy applied state. Apply commits; Cancel/back/scrim discards draft. Clear draft changes staged controls only. Current Marketplace shop and Delivery sheet Reset are immediate committed resets, so preserve and label that behavior or migrate deliberately.
6. Name reset scope. Reset filters returns the relevant defaults while preserving query and sort where specified. Clear lookup is independent of history status/date reset. A reset-all control must explicitly list every state it clears; it is not inferred from Clear query.
7. Sort is single-choice and independent of query/filter. A fixed server order is read-only, without radio/dropdown affordance. Provider sorting capability does not prove screen adoption; Admin's selector is proposed. Define default sort, tie behavior and placement of unknown values.
8. Delivery exact order lookup is ownership scoped and independent of history status/date filters. Clearing lookup restores saved history state; filter reset does not clear lookup. Do not invent a combined Firestore query or an additional history sort selector.
9. Keep calendar semantics explicit: Delivery week bounds use IST; inclusive custom dates map to exclusive query bounds. Canonical filter keys/category IDs, defaults and persistence require domain implementation, not visual equivalence.
10. Loading, genuine no-match and unavailable/error are different states. Retry uses the same canonical discovery state. Display counts only from verified data and name population/query/page scope; boards deliberately omit fabricated counts.
11. Use labelled clear/remove/reset actions, meaningful group semantics, selected symbols, 48px targets and focus independent of selected. Restore focus after dismiss/clear, keep search keyboard clearance and active chips readable, reflow toolbars at narrow widths and 100–200% text scaling.
12. Preserve each C01 identity and role-correct dark inverse text. Extend SellerSearchField, ProductFilterBar and DeliverySearchField/history composition; reuse associate/shared themes/responsive/feedback patterns rather than duplicate generic controls. Runtime shared-package changes require five-app verification.

## Source findings and migration priority

| Priority | Source evidence | Target / verification |
| --- | --- | --- |
| Composition | Marketplace _performSearch searches/sorts without reapplying _filters; _applyFilters omits description from the query predicate. | Compose from one canonical state and verify submit, applied filters, retry and clear. |
| Reset scope | SearchFilters Clear All clears draft; shop FilterDrawer Reset immediately commits and closes. | Label draft versus immediate reset; unify filter payload shape deliberately. |
| Scope | Seller countFor counts allProducts by filter independently of text query. | Keep population scope explicit; no fictional matching-result counts. |
| Mode separation | RiderHistory exact lookup bypasses saved status/date; clearFilters does not clear search. | Show history versus lookup scope; preserve saved filters and query failure/not-found distinction. |
| Bounded search / safe feedback | Associate filters a newest-first loaded prefix; stream error renders snap.error. | No matches in loaded orders + conditional load more; safe error mapping and scoped retry. |
| Adoption | Admin provider has sort methods; targeted ProductManagementScreen exposes query and one filter without sort UI. | Proposed sort selector remains TARGET_IMPLEMENTATION; verify canonical sort persistence/reload. |

## Agrimore Marketplace

**Current implementation snapshot:** SearchScreen provides local product-name/description/category search and suggestions. SearchResultsScreen fetches a bounded 100-product catalog and applies local filters/sort; initial search includes description but _applyFilters only tests name/category. SearchFilters stages edits and clears its draft; shop FilterDrawer Reset commits immediately. SortBottomSheet chooses immediately.

**Target:** Compose query, committed category chips and visible sort order into one discovery header. Stage modal category changes, Apply/Cancel honestly, and distinguish Clear query, Clear draft and Reset filters. Name loaded-catalog scope; do not claim a full-catalog search.

**Domain character:** Spacious professional-green product discovery, natural-stone fields and restrained gold scope guidance.

| Panel | Specimen |
| --- | --- |
| Discovery header | Wide clean search field labelled Search products, entered synthetic query seeds with a clear X whose label is Clear query. Beside it buttons Filters and Sort: Newest first. Under it small caption Search within loaded products. No numeric results or filter-count badges. |
| Staged category filters | Inset mini sheet with heading Filters, small Draft changes label. Category checkbox Seeds checked; Fertilizers unchecked. Three distinct footer actions Clear draft, Cancel, Apply filters. Helper Apply commits; Cancel keeps applied filters. Make staged controls visually different from applied chip strip. |
| Sort composition | Single-choice Sort by rows: Newest first selected radio, Price: low to high unselected radio, Price: high to low unselected radio. Helper Choosing a sort updates order immediately. No Apply or Cancel buttons for this immediate sort choice. Tiny note Query and filters stay unchanged. |
| Applied state and recovery | Applied chips row Category: Seeds with removable X. Reset filters button with helper Clears filters; keeps query and sort. Small separate examples Searching loaded products, No matches in loaded products with Clear query, Search unavailable with Retry. Never a no-match state for failure. Small guidance No invented result counts. |

Gaps and invariants:

- Reapply the same query predicate and committed filters on submit, retry and clear; current initial versus filtered predicates differ.
- Current _performSearch bypasses existing _filters and only sorts; the target requires composition from one canonical query/filter/sort state.
- Search and shop reset payloads differ (minPrice/maxPrice versus priceRange) and relevance is an unsorted default, not a verified ranking algorithm.
- Clear query preserves filter/sort in the target; current SearchResultsScreen clear instead empties its result list. Treat this as a future behavior change.

Source anchors:

- [search_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_screen.dart)
- [search_results_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart)
- [search_filters.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart)
- [filter_drawer.dart](../../apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart)
- [sort_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart)

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

**Current implementation snapshot:** SellerSearchField clears text through its callback and preserves other controls. SellerProductProvider immediately combines name query, exactly one ProductListFilter and ProductSort. ProductFilterBar exposes All/Active/Draft/Low stock/Out of stock/Inactive and counts scoped to allProducts, independently of text search; sort menu applies one choice when selected.

**Target:** Keep immediate catalogue behavior, visibly compose name query, single status tab and sort. Add explicit filter-reset scope and active-state summaries as provisional enhancements; filter selection does not publish/hide records.

**Domain character:** Compact blue-teal catalogue discovery with copper guidance, cool-neutral inline state and operational sort controls.

| Panel | Specimen |
| --- | --- |
| Catalogue toolbar | Compact Search product names field entered seeds with clear X, Sort: Name A–Z outlined control. Caption Immediate catalogue controls. Beneath single-choice tabs All unselected, Active unselected, Low stock selected with a check. No counts. |
| Active discovery state | Grouped summary Query / seeds; Filter / Low stock; Sort / Name A–Z. Removable applied chip Low stock with X; helper Removing returns filter to All. Copper note Filtering does not change visibility. No publish/hide action. |
| Immediate sort | Sort mini sheet single-choice radios Name A–Z selected, Newest first unselected, Stock: low first unselected. Helper Choose one; applies immediately. Small note Closing without choosing keeps current sort. No Apply button. |
| Reset and results | Two clearly separated actions Clear query with helper Keeps filter and sort; Reset filters with helper Returns All; keeps query and sort. Small state examples Filtering catalogue neutral skeleton; No matches in catalogue; Catalogue unavailable with Retry. Label Reset filters as Target control. No stock amounts or percentages. |

Gaps and invariants:

- Counts from countFor are filter-population counts without text-query composition; label scope if retained, never invent counts on boards.
- Target Reset filters returns All while keeping search and sort; no dedicated reset control is verified in the current catalogue.
- ProductSort ties use newest timestamp without an explicit stable-ID tiebreak; stable tie ordering is a future verification item.
- Sort comparator uses product stock fields; unknown raw stock presentation and domain parsing remain separate implementation concerns.

Source anchors:

- [seller_search.dart](../../apps/seller/lib/design_system/components/seller_search.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [product_list_controls.dart](../../apps/seller/lib/screens/products/widgets/product_list_controls.dart)
- [seller_product_provider.dart](../../apps/seller/lib/providers/seller_product_provider.dart)

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

**Current implementation snapshot:** RiderHistory separates paginated history status/date filters from exact owned orderNumber lookup. Exact lookup bypasses status/date and uses a latest-search token; clearSearch restores the underlying history state. Inline status changes are immediate; HistoryFilterSheet stages choices until Apply, but Reset calls clearFilters immediately and closes. History queries order newest first.

**Target:** Make History list and Exact order lookup visibly separate scopes. Applied history status/date remain preserved during ID lookup. Keep newest-first as read-only ordering, not an invented sort menu. Explain immediate reset versus staged Apply/Cancel.

**Domain character:** High-contrast black/white history discovery, burgundy history context and burnt-orange mode/scope guidance; simple controls for field use.

| Panel | Specimen |
| --- | --- |
| History list composition | Heading History list. Single-choice chips All unselected and Delivered selected with check, applied Date: This week chip and Filters button. Read-only line Order: Newest first with no dropdown chevron. Caption Illustrative history controls; no record counts. |
| Exact lookup scope | Separate mini surface heading Exact order lookup with empty field labelled Order ID, placeholder Enter exact order ID. No ID values or fake order. Burnt-orange guidance ID lookup ignores history filters. Small return control Clear lookup with helper Returns to saved history filters. This is a separate mode specimen, never a combined search+history query. |
| Staged history filters | Inset sheet Filters / Draft changes. Status radio Delivered selected, All unselected. Date range This week selected, All time unselected. Apply filters and Cancel actions; helper Apply commits; Cancel discards edits. Read-only Newest first note; no sort dropdown or Apply-count. |
| Reset and lookup feedback | Reset history filters button, helper Immediately sets All status + All time; keeps lookup separate. Small independent state cards Looking up order, No matching order, Lookup unavailable with Retry. Exact failure is not not-found. No future tracking promise, ETA, address, handover code or fake numeric values. |

Gaps and invariants:

- Current screen keeps history controls alongside exact lookup; target mode separation/scope wording is a proposed UI enhancement, not a new combined query.
- Reset filters changes status/date only; clearFilters does not clearSearch. Never claim it clears order lookup.
- Week presets use IST bounds; custom inclusive dates convert to an exclusive upper bound. Keep date semantics through the composition.
- No additional sort selector is verified for history; fixed newest-first remains explicit.

Source anchors:

- [rider_history.dart](../../apps/delivery/lib/data/rider_history.dart)
- [rider_history_screen.dart](../../apps/delivery/lib/screens/history/rider_history_screen.dart)
- [history_filter_sheet.dart](../../apps/delivery/lib/screens/history/history_filter_sheet.dart)
- [delivery_search.dart](../../apps/delivery/lib/design_system/components/delivery_search.dart)

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

**Current implementation snapshot:** OrdersScreen streams attributed orders newest-first with limit(_pageSize), then filters orderNumber/doc ID substring and mode locally. Search and All/B2B/Retail mode chips apply immediately; Load more increases the loaded prefix. PayoutHistory separately uses local status filters over a bounded newest-first stream.

**Target:** Order discovery names its loaded scope and single mode selection. Query clear preserves mode; mode reset returns All and preserves query. Newest first is read-only server order. No invented date picker or sort selector for this screen.

**Domain character:** Premium royal-blue loaded-order discovery, indigo business/retail context and pearl/slate scope cues; relationship and ledger filters remain distinct.

| Panel | Specimen |
| --- | --- |
| Attributed order discovery | Search loaded orders field entered synthetic query sample with clear X. Single-choice mode chips All unselected, Business selected with check, Retail unselected. Read-only text Order: Newest first, no chevron. Caption Searches loaded attributed orders. |
| Applied mode state | Pearl/slate summary Query / sample; Mode / Business. Removable applied chip Mode: Business X. Indigo helper Removing mode returns All; query stays. Small note Order mode is not payout status. No real IDs, customer names or amounts. |
| Scope and ordering | Read-only ordering specimen Newest first with description Fixed server order, no selectable radio or dropdown. Separate bounded-search explanation More orders may be available. Button Load more orders, labelled Shown only when more may exist. No fake order count or end-of-results claim. |
| Reset and feedback | Clear query button with helper Keeps mode; Reset mode button with helper Returns All; keeps query. Independent states Searching loaded orders; No matches in loaded orders with Load more orders conditional note; Order search unavailable with Retry. Failure never shows as no-match. No fabricated total, commission or payout claim. |

Gaps and invariants:

- A no-match in the loaded prefix does not prove no attributed order exists; offer Load more when more may exist.
- Current stream error interpolates snap.error into UI; target uses safe Order search unavailable wording and scoped retry.
- Target applied-mode removal/reset and explicit scope labels are provisional controls, not current verified widgets.
- Payout requested/approved/paid status filtering is a separate collection/workflow; do not merge it with order-stage or mode chips.

Source anchors:

- [orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart)
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

**Current implementation snapshot:** ProductManagementScreen immediately filters loaded product names and exactly one All/Active/Low stock/Featured chip. Clear search removes text only. ProductProvider has price/name/rating/popularity/newest sorting methods, but a sort selector is not exposed in this targeted screen. getAllProducts sorts loaded products newest-first in memory.

**Target:** Compose query, one operational filter and a visibly proposed provider-backed sort selector. Align controls for wide layouts and stack on phones. Active-chip removal/reset returns All while preserving query and sort; neither selection nor filtering mutates records.

**Domain character:** Professional-blue operational discovery toolbar, cyan context, steel/slate aligned filters and dense wide-to-stacked composition.

| Panel | Specimen |
| --- | --- |
| Operational toolbar | Wide Search loaded products by name field entered seeds with clear X. Operational single-choice chips All unselected, Active unselected, Low stock selected with check, Featured unselected. Proposed sort control Newest first. Caption Sort selector: target enhancement. No sidebar or numeric badges. |
| Active query summary | Aligned summary Query / seeds; Filter / Low stock; Sort / Newest first. Removable Filter: Low stock X, Reset filters action. Helper Reset returns All; keeps query and sort. Small cyan note Filters do not approve or publish records. |
| Proposed sort and reflow | Clearly labelled Proposed sort menu: Newest first selected radio, Name A–Z unselected, Price: low to high unselected. Helper Choosing updates loaded-record order. Small narrow-layout toolbar specimen stacks search over filter/sort controls with same choices. No bulk actions. |
| Reset and recovery | Clear query control with helper Keeps filter and sort. Separate states Searching loaded products skeleton; No matches in loaded products; Product search unavailable with Retry. No fake global count or permissions/approval receipt. Small note Scope follows loaded source data. |

Gaps and invariants:

- Proposed sort selector must connect to ProductProvider deliberately and maintain canonical state across reloads; provider capability is not current screen adoption.
- Low stock already uses shared isLowStock; retain that canonical definition and distinguish stock filter from approval state.
- Current product query uses service data that filters active products; do not claim full inactive/draft discovery coverage.
- Reset/filter/search changes must reconcile stable selected record IDs and bulk action eligibility explicitly; no hidden bulk mutation.

Source anchors:

- [product_management_screen.dart](../../apps/admin/lib/screens/admin/products/product_management_screen.dart)
- [product_provider.dart](../../apps/admin/lib/providers/product_provider.dart)
- [database_service.dart](../../packages/agrimore_services/lib/database/database_service.dart)
- [product_stock_utils.dart](../../packages/agrimore_core/lib/utils/product_stock_utils.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Run query + applied filters + sort through submit, clear, reload, retry and pagination; verify predicate equivalence and stable state/IDs.
- Test search scope with a match beyond the loaded prefix, true no-match, load failure, stale responses and ownership boundaries; counts must name their scope.
- Stage filters, edit, Apply, Cancel/back/scrim, reopen and clear draft. Separately verify immediate shop/history reset and inline controls.
- Clear query, remove one applied chip, reset one filter group and any explicit reset-all; query/sort/selection retention must match the stated scope.
- Delivery lookup ignores status/date, clear lookup restores history, reset history keeps lookup independent; latest query wins. Keep IST/custom-date bounds.
- Fixed order stays read-only in Delivery/Associate; proposed Admin sort connects to provider and stays canonical across reload. Verify ties and unavailable sort values.
- Narrow and wide layout, light/dark, text scaling, keyboard/screen-reader roles, selected/focus distinction and labelled 48px clear/remove actions.
- Reuse equivalents; any future shared UI changes require all five app analyzers and actual rendered before/after checks.

## Delivery scope and design lanes

27 new repository files: ten PNGs, five per-app README/prompts/manifest sets, two master documents. Earlier C01–C12 files preserved. C13 is provisional; no owner approval inferred. User explicitly requested image prompt provenance, so these prompts.md are image records rather than exported implementation-worker prompts.

UIUX/feedback design review: app-specific identities, discovery composition, reset/scope semantics, safe query-feedback copy and fixed/proposed order distinctions visually reviewed on generated boards. Runtime gates are not applicable evidence for an assets-only task; Flutter analysis, emulator, real account access and runtime accessibility were not performed. No Dart/TypeScript/runtime, pubspec registration, staging/commit/branch, deploy or other-chat interruption by this task. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset verification evidence

Assets-only verification completed 2026-10-03: **PASS**. Ten PNGs form five light/dark pairs; all 27 declared new repository files exist. PNG dimensions/chunk CRCs, saved-source/output hashes, exact inherited C01 palette/status/typography/spacing/radius/border metadata and reference hashes verified. All **16** original/refinement prompt blocks reproduce their recorded hashes; **84** local document links resolve. All **675** earlier design files remain byte-identical.

All 817 inventoried runtime source hashes and recorded platform configurations remained unchanged through packaging and verification. HEAD stayed `97f171f00f8330f1ae7c831845e4dd94a8ae2c33`; current checkout branch was `agrimore/foundation-f3c-distance-delivery-pricing`, belonging to the existing implementation work. This task did not change branches or the index.

The repository surface classifier returned the **docs** lane for these paths. UIUX and feedback semantics/copy were also reviewed on generated specimens, including loaded search scope, fixed versus proposed ordering, immediate versus staged controls, reset preservation and unavailable versus no-match. Verification establishes file/provenance integrity, not exact raster token rendering, implemented discovery behavior or runtime accessibility. Query examples are synthetic; small raster/layout variations between paired themes are illustrative.
