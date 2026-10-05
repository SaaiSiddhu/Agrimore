# Agrimore — C15 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-board gallery](LISTS_PAGINATION_LOAD_MORE_RECOVERY_BOARDS_2026-10-03.md) · [Locked C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and evidence limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 eligible source files / 271,604 lines** scanned across all five app lib trees, agrimore_ui/core/services and functions/src. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Focused semantic reads covered list rendering, cursor and growing-prefix pipelines, refresh reset behavior, concurrent/stale response guards, deduplication, query scope and exhaustion/recovery footers. Broad static inventory plus focused review does not mean every line was semantically audited or every screen rendered. Functions/services were inventoried for data/auth context; no backend behavior or live state was validated.

Marker counts include comments and are not unique screens/components or defect counts. Plain list constructors, nested wrappers, nonstandard cursor names and ID maps are undercounted. ValueKey counts include controls/tests and are not evidence of stable record-row adoption. A zero marker count does not prove feature absence. Observations describe the local source snapshot; implementation can continue in another chat.

| Scope | list_builder | list_separator | refresh | cursor | paging_flag | id_key | dedup | query_limit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 18 | 20 | 8 | 11 | 20 | 49 | 23 | 31 |
| delivery | 0 | 5 | 1 | 11 | 34 | 118 | 23 | 7 |
| employee | 4 | 2 | 0 | 0 | 14 | 0 | 0 | 6 |
| marketplace | 52 | 9 | 16 | 1 | 8 | 3 | 8 | 22 |
| seller | 1 | 3 | 4 | 0 | 0 | 19 | 2 | 13 |
| functions | 0 | 0 | 0 | 32 | 4 | 0 | 27 | 29 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 4 | 0 |
| agrimore_services | 0 | 0 | 0 | 4 | 0 | 0 | 0 | 12 |
| agrimore_ui | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Existing infrastructure and reuse

Admin PaginatedQueryList already provides per-section cursor state, request guards and retry; RiderHistory models owned history cursor paging with deduplication/generation guard. Associate uses live newest-first prefixes and saTokens. Seller already has catalogue row/state primitives and ID-based selection; its data load remains a single full fetch. Marketplace storefront embeds ProductGrid in one outer scrollable and uses seller-scoped cursors. These are reuse anchors; no new generic list widget is introduced here.

Verified infrastructure anchors:

- [paginated_query_list.dart](../../apps/admin/lib/screens/admin/widgets/paginated_query_list.dart)
- [rider_history.dart](../../apps/delivery/lib/data/rider_history.dart)
- [product_grid.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)
- [error_view.dart](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)
- [database_service.dart](../../packages/agrimore_services/lib/database/database_service.dart)

The service getFilteredReviews accepts a cursor input but returns a list without continuation metadata and returns [] on error; no app call site was found in the focused rg search. This is a service-contract observation, not proof that a currently rendered review screen misreports pagination. Explicit error/exhaustion metadata is a future reuse requirement.

## Shared target list contract

1. Choose the actual list model per domain: snapshot replacement, expanding live prefix, cursor continuation or bounded one-shot fetch. Do not label a proposal as current.
2. Canonical query identity includes actor/tenant, scope, filters, ordering and bounds. A changed identity invalidates old requests and resets incompatible cursor/end/error state.
3. Stable record IDs drive widget identity, dedup/upsert, focus and selection; index position never becomes record identity.
4. Same-query append leaves prior records and scroll anchor visible. Reconcile changed/deleted records only with reliable current evidence; off-page absence is not deletion.
5. First load, retained-data refresh, next-page pending, next-page error and exhausted footer are separate states; next-page error never replaces a valid loaded list.
6. Load-more and retry allow one request per applicable scope; stale results are ignored, failure keeps the last successful cursor/limit and never triggers mutation replay.
7. Loaded-scope filters/search may produce no visible matches while raw continuation remains possible. Keep a scoped continuation path when evidence supports more.
8. hasMore derives from raw query evidence, not visible filtered row count. A full page/prefix means more may exist unless a lookahead or exhausted response proves otherwise.
9. Empty visible pages can advance a raw cursor; use progress detection and bounded continuation. Never loop indefinitely or prematurely report end.
10. End markers name the exact traversed query. Bounded category reads, partial financial scans, failed reads and cache are not complete global history.
11. Permission/auth/session failures use C14 sign-in/support restrictions; retry is for recoverable reads, not authorization bypass.
12. Initial/refresh/page loading and completion need concise semantics, static reduced-motion fallback and labelled 48px footer actions. Exact implementation remains future verification.
13. Keep independent owned order, payout, transaction, history, catalogue and admin-section scopes separate. Unknown values stay unavailable; no made-up totals, IDs, rates or financial outcomes.
14. All boards use isolated synthetic/sample list specimens and C01 metadata. C15 is PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; no runtime or approval claim.

## Domain continuation models

| App/scope | Current local model | Target boundary |
| --- | --- | --- |
| Marketplace storefront | Raw document cursor; visible-product predicate after read; separate bounded category request | Page failure retains tiles/cursor; category cap is not category exhaustion |
| Seller catalogue | One full collection fetch; local search/filter/sort; ID-based selection | Pagination controls explicitly proposed; resolve query/count strategy before migration |
| Delivery history | Newest-first cursor + extra raw row; guards/dedup; refresh resets items/search | Retain rows on append failure; refresh exits lookup; scoped history end |
| Sales Associate orders / wallet / payouts | Increasing live-query limit, not cursor append; local loaded-prefix filters | Pending expansion guard; no-match keeps possible continuation; live ID reconciliation |
| Admin support sections | Per-instance cursor/resetKey/request guard; filter key invalidates old list | ID dedup/upsert + scoped end; same-query retained refresh is proposed |

## List state and recovery boundaries

| State | Target presentation | Data rule |
| --- | --- | --- |
| Initial read | Labelled skeleton without invented values | No available data; auth/scope already checked |
| Same-query refresh | Retain safe previous rows + refresh strip | Reconcile current response; latest generation wins; last-known label on failure |
| Query/entity change | New list state and invalidated old requests | Reset cursor/hasMore/error and prevent cross-account data retention |
| Next read pending | Disabled outlined footer with progress label | One request per scope; existing rows and scroll anchor stay |
| Next read fails | Inline error + Retry loading more | Keep successful cursor/limit and prior rows; no mutation replay |
| Filtered no-match with continuation evidence | Loaded-scope no-match + possible Load more | Do not hide continuation solely because visible filtered rows are empty |
| Visible empty raw page with more | Advance using raw cursor within explicit bounds | Do not infer end from visible length; stop no-progress/repeat loops |
| End / exhausted current scope | Plain query-specific end marker | Needs complete current-query evidence, not full-page length, failed read or cap |
| Permission failure | C14 sign-in/support restriction | No blind footer retry of forbidden scope |

## Source findings and migration priority

| Area | Verified local evidence | Future direction |
| --- | --- | --- |
| Marketplace | _loadMoreProducts appends without ID dedup/generation guard; raw page controls hasMore. Category fetch is separately capped and cached. | Guard refresh/append races; stable row IDs; persistent page recovery; disclose category boundedness. |
| Seller | No catalogue cursor/hasMore/loadMore in inspected provider; local filter/sort/counts use fully fetched product list. | Do not claim paginator implementation; design bounded query/filter/count strategy before adding target footer. |
| Delivery | History takes a raw page and lookahead; deduplicates against existing IDs; generation guard. refresh clears items/search. | Preserve cursor retry; target retained refresh; robust batch dedup; permission recovery remains separate. |
| Associate | Increasing _pageSize recreates a newest-first live stream. Filtered-empty branch returns before Load more footer. | Retain possible continuation in no-match; guarded expansion/reconnect; stable live record identity; do not pretend cursor append. |
| Admin | PaginatedQueryList preserves docs/cursor on page error and invalidates resetKey requests; _docs.addAll has no ID dedup and no explicit end marker. | Reuse with stable ID upsert, scoped exhaustion and retained same-query refresh; preserve section independence. |
| Distinct finance scope | Finance reconciliation upserts findings by ID and carries incomplete/coverage state; statement has cursor progress/auto-continue guard. | These mechanisms are separate patterns, not proof a support/history list has them or that list exhaustion certifies money. |

## Agrimore Marketplace

**Current implementation snapshot:** BusinessProfileScreen fetches seller-scoped products with a document cursor and busy guard. Visible products are filtered after the raw page is read; hasMore follows raw page length. Initial reload replaces the visible screen with a loading body. Load-more failure keeps products/cursor and shows safe snackbar copy. Selected categories use a separate bounded server fetch cached by category, and the main continuation footer is hidden in category mode. ProductGrid nests a non-scrolling shrink-wrapped grid in the outer list and creates cards without explicit per-product keys.

**Target:** Keep existing storefront cursor continuation, but show stable product identity, retained-content refresh and persistent inline next-page recovery. Main seller catalogue and bounded category fetches remain distinct scopes; never claim a full category has been traversed when it has not.

**Domain character:** Professional-green storefront product grids, natural-stone tile surfaces and warm-gold scope hints; continuation belongs to one seller’s visible catalogue.

| Panel | Specimen |
| --- | --- |
| Stable records | A small storefront product grid explicitly labelled "Sample products". Two simple neutral thumbnails; titles "Sample seeds" and "Sample soil care". No price, stock, ratings or quantity. Helper "Keep each product’s place during append". Small warm-gold annotation "One storefront scope". |
| Refresh | Retained sample product tiles visible beneath a small refresh strip "Refreshing products". Compact spinner, no percentage. Helper "Keep filters and scroll position". Separate quiet last-known note "Refresh unavailable" and action "Retry refresh", labelled "Separate failed-refresh example". Never replace available products with blank skeletons. |
| Load more | A list-tail example labelled "Storefront catalogue". Secondary OUTLINED green action "Load more products". Separate pending variant with spinner and "Loading more products" inside a disabled outlined control. Helper "Loaded products stay visible". Gold caption "Category view uses a separate bounded read". No fake page numbers or global totals. |
| Recovery and end | Two clearly separate small examples. Page failure: "More products couldn’t be loaded", helper "Your loaded products are still here", OUTLINED action "Retry loading more". End example: "End of storefront catalogue", small caption "Only when this query is exhausted". Never use end-of-category or all-products global completion claim. |

Gaps and invariants:

- No explicit business sort/orderBy is present in the storefront product query; agree a stable business ordering before changing it, and keep cursor/order/filter consistent.
- Load-more append currently adds records without ID deduplication or a request-generation guard; refresh/category/account changes must invalidate stale responses.
- An empty visible page can still have raw pages to traverse. Do not show an end marker based on visible item count alone.
- Category fetch is capped and has no own continuation footer. A category fetch error is logged only; future UI must distinguish failed, bounded no-match and complete results.
- Retaining content during refresh and inline page retry are target enhancements; current refresh/loading hides the list and page failure is transient snackbar feedback.

Source anchors:

- [business_profile_screen.dart](../../apps/marketplace/lib/screens/business/business_profile_screen.dart)
- [storefront_visibility.dart](../../apps/marketplace/lib/screens/business/storefront_visibility.dart)
- [product_grid.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart)
- [database_service.dart](../../packages/agrimore_services/lib/database/database_service.dart)

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

**Current implementation snapshot:** SellerProductProvider fetches the seller’s product collection in one get, then applies local search/filter/sort. There is no catalogue cursor, hasMore or loadMore in the inspected provider/screen. SellerProductsScreen uses RefreshIndicator with existing rows when data remains, selected records are tracked in a Set of product IDs, and _ProductCard is built without an explicit per-record widget key. Refresh errors with retained products are not surfaced by the empty-data error branch.

**Target:** Preserve stable identity/selection and add retained-row refresh failure feedback. Illustrate a clearly labelled proposed pagination footer without claiming a current backend or cursor implementation. Any future bounded query must deliberately preserve search/filter/sort semantics and population counts.

**Domain character:** Compact blue-teal catalogue rows, copper operational guidance and cool-neutral selection surfaces; current full-fetch behavior is distinguished from a proposed bounded catalogue.

| Panel | Specimen |
| --- | --- |
| Stable records | Compact catalogue list labelled "Sample catalogue". Rows "Sample seeds" and "Sample soil care", neutral thumbnail blocks and square selection boxes; first row checked. Helper "Selection stays with the product". Copper annotation "Keep row identity through reorder". No selection count, stock or prices. |
| Refresh | Existing compact sample rows stay visible under a small "Refreshing catalogue" strip. Spinner plus text, no completion percent. Helper "Keep search, filter and sort". Separate thin failed-refresh example "Refresh unavailable" with OUTLINED "Retry refresh". No mutation buttons. |
| Load more | Make the panel explicitly labelled "Proposed pagination" at the top of the specimen. OUTLINED blue-teal action "Load more products", and a separate disabled outlined pending variant "Loading more products" with spinner. Copper annotation outside the UI specimen "Current catalogue uses one full fetch". Helper "Existing rows stay in place". Never imply this cursor backend is implemented. |
| Recovery and end | Explicit small "Proposed pagination states" caption. Separate page-failure block "More products couldn’t be loaded", helper "Keep loaded rows and selection", OUTLINED "Retry loading more". Separate end example "End of this catalogue view" with note "Only after the chosen query is exhausted". No fabricated counts, stock or product visibility changes. |

Gaps and invariants:

- Proposed pagination cannot simply page the current collection then pretend local filter/no-match/countFor describes the entire catalogue.
- Resolve server versus loaded-scope query/filter/sort strategy before adopting the illustrated Load more products control.
- Selection remains tied to product IDs across append/refresh; only confirmed deletion or access loss invalidates it, never an off-page absence alone.
- Refresh failure with existing rows needs inline recovery; do not retry create/update/delete mutations from a list footer.
- Stable row keys, deterministic tie handling, bounded fetch and request lifecycle guards are future work; no runtime component introduced here.

Source anchors:

- [seller_product_provider.dart](../../apps/seller/lib/providers/seller_product_provider.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [product_list_controls.dart](../../apps/seller/lib/screens/products/widgets/product_list_controls.dart)
- [seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart)

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

**Current implementation snapshot:** RiderHistory reads cursor pages newest-first with one extra raw document to determine hasMore; the raw-page cursor advances independently of client-side historyMatches filtering. It guards concurrent reads and stale generation, and deduplicates against existing order IDs. Retry keeps the last successful cursor and loaded rows. refresh clears search and pagination, then reloads the first page. History screen already retains rows with a footer loading/error/load-more/end state. Statement paging separately guards cursor progress and deduplicates statement order IDs.

**Target:** Retain real history pagination and localized footer recovery while making stable records, scope and pending state clear. Preserve status/date through same-history retry. Show a target refresh that keeps safe previous rows and clearly exits exact lookup rather than claiming current refresh preserves search.

**Domain character:** High-contrast black/white delivery-history rows, burgundy historical context and burnt-orange connection hints, with generous field-use footer controls.

| Panel | Specimen |
| --- | --- |
| Stable records | History list labelled "Sample history". Two simple parcel-outline rows titled "Sample history entry" and "Sample delivery entry", with no IDs, addresses, money, dates or ETA. Burgundy small context label "Delivery history". Helper "Newest first; no duplicate entries". No invented completed status or payment outcome. |
| Refresh | Same sample history rows retained under text "Refreshing history" and a compact spinner. Helper "Keep status and date filters". Burnt-orange board annotation "Refresh exits exact lookup". A tiny "Target retained-content refresh" caption. No claim that lookup search stays unchanged. |
| Load more | Wide secondary OUTLINED black/white control "Load more history". Separate disabled outlined pending variant "Loading more history" with spinner. Helper "Keep earlier history visible". Small burnt-orange note "One read at a time". No page numbers, task counts or automatic work acceptance. |
| Recovery and end | Separate examples. Connection failure "More history couldn’t be loaded", helper "Earlier entries remain available", OUTLINED action "Retry loading more". End marker "End of this history view", caption "After this status/date query is exhausted". Tiny note "Access restrictions need sign-in or support". Never add a permission-bypass retry or settlement guarantee. |

Gaps and invariants:

- Current history refresh clears items/search before reading; retained-row refresh is a target change, and refresh leaves exact order lookup intentionally.
- History deduplication compares incoming rows against existing IDs but does not explicitly add incoming IDs to the seen set during the batch; robust append should prevent within-batch duplicates too.
- Current history footer maps permission failures but still provides retry. Permission/account restriction belongs to C14 recovery, not blind next-page retry.
- A page that has no visible matching records may still have a raw cursor and more pages; continue within disclosed bounds, not a fake end or unbounded loop.
- Statement cursor-progress/auto-continue limits apply to statement flow; do not claim those guards are already used in RiderHistory.

Source anchors:

- [rider_history.dart](../../apps/delivery/lib/data/rider_history.dart)
- [rider_history_screen.dart](../../apps/delivery/lib/screens/history/rider_history_screen.dart)
- [statement_screen.dart](../../apps/delivery/lib/screens/money/statement_screen.dart)
- [rider_money.dart](../../apps/delivery/lib/money/rider_money.dart)
- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)

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

**Current implementation snapshot:** OrdersScreen, wallet transaction list and payout history use newest-first live queries with a growing _pageSize limit. Load more increases the limit rather than fetching/appending a cursor page. Local filters run over the loaded prefix; the early filtered-empty branch hides the continuation footer even when raw docs reach the limit. Existing live snapshots can change membership/order. No dedicated pending load-more guard or safe retained-data error footer is evidenced; errors render raw exception text and initial no-data is blank.

**Target:** Preserve the expanding live-prefix mechanism explicitly. Continue beyond a filtered no-match when more may exist. Add one-in-flight pending state, safe retained-data reconnect and stable row identity/focus during snapshot replacement; do not describe this as frozen cursor history or duplicate appended pages.

**Domain character:** Premium royal-blue attributed-order rows, pearl/slate stable surfaces and indigo loaded-scope guidance; continuation expands a live prefix rather than appending cursor pages.

| Panel | Specimen |
| --- | --- |
| Stable records | Relationship-style list labelled "Sample attributed orders". Two record rows titled "Sample business order" and "Sample retail order"; subtle indigo B2B and Retail context chips. No order IDs, names, amounts or status outcomes. Helper "Stable identity across live updates". Caption "Newest first within loaded orders". |
| Refresh | Retained sample order rows under a small strip "Updating attributed orders" and spinner. Helper "Keep search and mode". Indigo annotation "Live records may change". Separate small failed-update example "Update unavailable" and OUTLINED action "Retry connection"; caption "Proposed recovery". No misleading frozen-history guarantee. |
| Load more | Secondary OUTLINED royal-blue "Load more orders". Separate disabled outlined pending control "Loading more orders" with spinner. Caption "Expands the loaded list". A small distinct inset "No matches in loaded orders" with an outlined "Load more orders" control and helper "Only when more may exist". No cursor terminology in the app-facing specimen. |
| Recovery and end | Separate examples. Expanded-read failure "More orders couldn’t be loaded", helper "Keep available orders and filters", OUTLINED "Retry loading more", caption "Proposed recovery". End "End of attributed orders", helper "Only after a complete current read". No earnings amount, balance, paid status, earning promise or global search claim. |

Gaps and invariants:

- Full-prefix refetch is not cursor pagination; increased limit needs a guarded pending state and safe retention while the expanded stream reconnects.
- No matches in loaded orders is not a global absence. Keep Load more orders accessible when the underlying query may extend, even with no visible filtered rows.
- A full raw prefix only means more may exist; verify exhaustion before End of attributed orders wording.
- Use IDs to reconcile live snapshot changes and protect focus/scroll, not list indexes. Deletions/order changes are live data changes rather than pagination duplicates.
- Order, transaction and payout continuations are distinct owned queries; failure or end never implies zero earnings, commission settlement or paid payout.

Source anchors:

- [orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart)
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

**Current implementation snapshot:** PaginatedQueryList already owns cursor, concurrent-read guard, request-id guard, resetKey and per-instance error state. SupportQueueScreen orders by updatedAt and selects exactly one status or My cases mode, passing a filter key/resetKey. Loaded docs remain on load-more failure with retry above; no explicit end label, append deduplication or general refresh API is present. ActorSupportCasesSection refreshes by changing the widget key. Finance reconciliation separately upserts findings by ID and guards generations.

**Target:** Reuse the existing paginated section pattern for support queue and People-360, with persistent inline continuation recovery, stable IDs and explicit scoped end markers. Reset filter/entity clears incompatible pages and invalidates old requests. Same-query retained-content refresh is a proposed enhancement; sibling sections remain independent.

**Domain character:** Dense professional-blue support-case sections, steel/slate table rows and restrained cyan query-scope cues; each administrative section owns its continuation and recovery.

| Panel | Specimen |
| --- | --- |
| Stable records | Dense support-record rows under "Sample support cases", column labels Case and Status. Two synthetic text titles "Sample catalogue question" and "Sample delivery question"; neutral "Open" sample status chips. No case IDs, assignee names or counts. Cyan annotation "One support section". Helper "Stable case identity". |
| Refresh | Retained sample support rows under a slim "Refreshing this section" strip and spinner. Helper "Keep this query; preserve other sections". Small caption "Target retained-content refresh". Cyan note "Filter changes start a new list". No combined My cases and status filters. |
| Load more | Compact secondary OUTLINED professional-blue control "Load more cases". Separate disabled outlined pending variant "Loading more cases" with spinner. Helper "Earlier cases stay visible". Cyan annotation "One section request at a time". No fake totals, selected counts or reconciliation coverage numbers. |
| Recovery and end | Separate examples. Page failure "More cases couldn’t be loaded", helper "Other sections remain available", OUTLINED "Retry loading more". End "End of this support view", caption "Only when this query is exhausted". Tiny note "Not a whole-system review result". No approval, assignment or permission grant action. |

Gaps and invariants:

- Add ID dedup/update reconciliation before append; current generic component _docs.addAll can duplicate records when order membership shifts between reads.
- Retained same-query refresh and a visible end footer are target enhancements; current resetKey/key refresh clears loaded state.
- Support queue uses status OR My cases, not a combined query. Never invent combined filters or global coverage from a bounded section.
- Initial error and page error need distinct safe surfaces; no raw exception or forbidden-query retry. List retries do not approve cases or repeat mutations.
- Finance scan continuation carries coverage/incomplete metadata and a separate repository cursor; do not claim support-list cursor/complete marker certifies financial reconciliation.

Source anchors:

- [paginated_query_list.dart](../../apps/admin/lib/screens/admin/widgets/paginated_query_list.dart)
- [support_queue_screen.dart](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart)
- [actor_support_cases_section.dart](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart)
- [finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Initial read, same-query refresh, refresh failure with rows, append success/failure/retry, final short/empty page and visible-empty raw page with continuation. End must remain scoped and truthful.
- Duplicate IDs across/within batches, reordered/updated/deleted live records, deterministic ordering and tie/cursor compatibility; preserve focus, selection and scroll anchors by ID. Off-page absence is not deletion.
- Double tap, concurrent refresh/append, late response after filter/entity/account change, unmount and no-progress cursor; latest applicable query wins and no unbounded continuation loop.
- Marketplace category cap versus main storefront cursor; visibility filtering must not prematurely exhaust raw pages. Persist safe inline next-page failure separately from first-load error.
- Seller one-shot versus proposed bounded strategy; preserve current operational filter/sort semantics and truthful count scope deliberately. Retry never replays stock/publish/create/delete mutations.
- Associate no-match at a full raw prefix still exposes possible continuation; expanded live-stream pending/failure keeps prior rows. Orders/transactions/payouts remain separate; no invented zero/settled outcome.
- Admin status OR My cases query identity; per-section failures do not clear siblings. Financial partial-scan metadata cannot be replaced by a generic support-list end marker.
- Light/dark, narrow/wide, long translated labels, text scaling, keyboard/screen-reader focus, one concise pending announcement, labelled 48px footer actions and reduced-motion static indicator. Raster board is not certification.
- Reuse equivalents; future shared UI changes require all five app analyzers and actual rendered before/after checks.

## Delivery scope and design lanes

27 new repository files: ten PNGs, five per-app README/prompts/manifest sets, two master documents. Earlier C01–C14 files are preserved. C15 is provisional; no owner approval inferred. User explicitly requested image-prompt provenance; prompts.md records image generation, not an exported implementation-worker prompt.

UIUX/feedback design review covers app identities, sample-list scope, stable identity, refresh/append distinction, scoped continuation/recovery/end, honest proposal labels and neutral dark surfaces. Classifier lane: docs; UIUX/feedback design review voluntarily attached. Runtime gates are not applicable evidence for assets-only delivery; no Flutter analysis/emulator/live-account/runtime-accessibility checks were performed. No Dart/TypeScript/runtime source, pubspec registration, staging/commit/branch changes, deploy or other-chat interruption by this task. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset delivery verification

**VERIFIED_REPOSITORY_FACT / assets-only integrity PASS.** Ten selected PNGs, five app/theme pairs and 27 new repository files. PNG dimensions, chunk CRCs, source-output/image hashes, exact C01 reference hashes and all palette/type/spacing/radius/border metadata were verified. All 729 pre-existing design files remained byte-identical. Twelve exact initial/refinement prompt blocks and 87 local Markdown links were checked. Associate/Admin light refinements are retained in prompt provenance; the Associate end copy now requires query exhaustion and Admin sample rows omit invented overflow menus. Requested raster action-color corrections remain approximate, not a measured pixel-exact guarantee.

The 817 observed source files / 271,604 lines and platform configuration hashes remained unchanged between inventory and packaging, and during packaging. HEAD remained 97f171f00f8330f1ae7c831845e4dd94a8ae2c33 on agrimore/foundation-f3c-distance-delivery-pricing. These checks establish asset/provenance integrity and observed source preservation; they do not establish runtime pagination, server query/index validity, live permissions, animations, contrast or accessibility. C15 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.
