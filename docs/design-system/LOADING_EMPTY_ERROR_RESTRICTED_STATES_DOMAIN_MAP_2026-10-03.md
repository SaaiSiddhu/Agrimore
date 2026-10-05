# Agrimore — C14 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-board gallery](LOADING_EMPTY_ERROR_RESTRICTED_STATES_BOARDS_2026-10-03.md) · [Locked C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and evidence limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 eligible source files / 271,604 lines** scanned across all five app lib trees, agrimore_ui/core/services and functions/src. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Focused semantic reads covered loading/empty/error primitives, data-state branch precedence, retained-cache handling, bounded order scope and account restriction/auth routes. Broad static inventory plus focused review does not mean every line was semantically audited or every screen rendered. Functions/services were inventoried for data/auth context; no backend behavior or live state was validated.

Marker counts include comments and are not unique screens/components or defect counts. Custom shimmers, wrapper widgets and other state spellings are undercounted by named patterns. A zero marker count does not prove feature absence. Observations describe the local source snapshot; implementation can continue in another chat.

| Scope | progress | skeleton | loading_flag | empty_branch | error_branch | state_widget | restricted | cache_evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 143 | 0 | 357 | 253 | 354 | 1 | 66 | 1 |
| delivery | 26 | 7 | 56 | 64 | 160 | 7 | 129 | 35 |
| employee | 0 | 0 | 41 | 15 | 24 | 0 | 15 | 0 |
| marketplace | 112 | 0 | 414 | 298 | 324 | 13 | 64 | 0 |
| seller | 1 | 14 | 42 | 105 | 123 | 30 | 60 | 0 |
| functions | 0 | 0 | 0 | 0 | 83 | 0 | 268 | 0 |
| agrimore_core | 0 | 0 | 1 | 39 | 34 | 0 | 22 | 0 |
| agrimore_services | 0 | 0 | 0 | 21 | 215 | 0 | 14 | 0 |
| agrimore_ui | 10 | 0 | 23 | 0 | 11 | 2 | 0 | 0 |

## Existing infrastructure and reuse

Seller already provides spinner/progress/skeleton/loading/empty/error families with relevant semantics and reduced-motion support. Delivery has skeleton/loading-list/empty/error components and ActiveWork retains last-known orders with permission/offline/unknown failure mapping. Associate uses saTokens and existing auth support pages; order initial-load/error feedback still needs composition. Shared LoadingOverlay, ErrorView and EmptyState are reuse candidates requiring theme/state review, not a reason to create duplicate primitives.

Verified infrastructure anchors:

- [loading_overlay.dart](../../packages/agrimore_ui/lib/widgets/common/loading_overlay.dart)
- [error_view.dart](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)
- [empty_state_widget.dart](../../packages/agrimore_ui/lib/widgets/common/empty_state_widget.dart)
- [seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart)
- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)
- [rider_work.dart](../../apps/delivery/lib/data/rider_work.dart)
- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)

Shared LoadingOverlay currently uses a dark scrim and fixed white inner surface, with no ModalBarrier evidenced in the inspected implementation. Review dark theme and actual interaction blocking/focus before adopting it for submissions. ErrorView offers Retry only with a handler and optional theme colors; EmptyState similarly exposes optional actions. The board is not evidence that those runtime gaps are fixed.

## Shared target state contract

1. Evaluate authentication/authorization and requested scope before interpreting data as empty; preserve security boundaries.
2. First load with no data gets labelled skeleton/progress, not fake records, prices, amounts, percentages or wait-time estimates.
3. Refresh retains safe available content with a visible progress/error indicator. Cached or failed-refresh records must be labelled last-known.
4. True empty requires a successful applicable read; filtered no-match, bounded loaded-prefix no-match and failed reads are distinct.
5. Permission errors are not ordinary recoverable network errors. Offer supported sign-in/support/navigation rather than blind retry or self-unlock.
6. Retry is scoped to the failed recoverable read, preserves controls, ignores duplicate taps while pending and never replays uncertain mutations.
7. Restricted actions depend on actual reason/status and server authority. Reopen/edit/resubmit only where supported; submission is not approval.
8. Unavailable balances, stock and counts stay unavailable/unknown; errors never imply zero, deletion, settlement or success.
9. Safe localized copy says what is unavailable and a meaningful next step; no raw exceptions, internal document paths or sensitive record details.
10. Reuse Seller/Delivery/SA/shared state families; separate app theme adapters and semantics rather than introducing duplicate components.
11. Loading uses one bounded announcement; icons have text explanations. Maintain focus and 48px targets, static skeletons for reduced motion. These are target requirements, not certification.
12. Four board panels are isolated illustrative scenarios, not simultaneous app states or real-account screenshots. All C14 boards remain provisional.

## Branch precedence and recovery map

| Situation | Target presentation | Action boundary |
| --- | --- | --- |
| Authentication or forbidden scope | Sign-in/restricted explanation before empty or operational records | Supported sign-in/support/safe navigation; never bypass or replay forbidden work |
| First applicable read pending, no data | Labelled skeleton; unknown values remain placeholders | No duplicate request; bounded announcement |
| Recoverable failure, no data | Safe error explanation instead of empty | Retry failed read, retain query/filter and request scope |
| Refresh pending with data | Keep safe available rows + visible refresh status | Guard operations requiring current data according to actual server rules |
| Refresh failed/cache | Last-known/cached label + scoped recovery | No live-state guarantee or invented offline mutation permission |
| Successful current empty base collection | Domain-specific absence copy | Only supported creation/browse/history action |
| Successful filtered empty loaded prefix | No matches in loaded records | Scoped clear; load more only when more may exist |
| Account review/rejection/suspension | Reason-specific restriction and limits | Edit/reopen/resubmit only for supported status; submission never equals approval |

## Source findings and migration priority

| Area | Verified local evidence | Future implementation direction |
| --- | --- | --- |
| Marketplace | OrderProvider assigns an unauthenticated error for missing userId and can expose raw listener errors. SearchResultsScreen catches/logs failures without a dedicated error branch. | Explicit sign-in requirement and safe data error; never substitute no-match/empty for failure. |
| Seller | Catalogue error is checked before initial loading; no-match has no reset action in the inspected branch. Rejected-only reopen action refreshes auth. | Review state precedence/refresh; scoped target reset; preserve reject-only draft reopening. |
| Delivery | ActiveWork.failed retains known orders and sets loaded; isEmpty alone can be true on failure. Dashboard exposes StaleDataBanner with known data. | Error/cache evidence precedes true empty. Permission recovery differs from connection retry; no invented offline-action authority. |
| Associate | Initial no-data OrdersScreen returns SizedBox.shrink; stream error interpolates snap.error; search is over loaded prefix. | Visible initial skeleton, mapped safe error/reconnect and bounded no-match wording; never zero earnings from read failure. |
| Admin | Catalogue sliver lacks an explicit error branch. Seller-product stream errors and update exceptions render raw details. Seller-product query is not pending-only. | Safe error branches and truthful collection-specific emptiness; admin role denial directs to sign-in without grant automation. |
| Shared | LoadingOverlay fixes inner surface to white; ErrorView mixes optional theme colors with AppColors. | Theme-aware surface/interaction/accessibility review using existing equivalents. |

## Agrimore Marketplace

**Current implementation snapshot:** OrdersScreen already separates initial empty loading, load error, no orders and locally filtered no-results. OrderProvider returns an unauthenticated error when userId is missing and may store raw listener error text. EmptyOrders provides Start shopping only when its callback exists. SearchResultsScreen logs search exceptions without a dedicated visible error branch. The web AuthGuard redirects unauthenticated sessions to LandingScreen; it returns its child on mobile.

**Target:** A shopping-focused state family separates first load, truly empty cart, order-load failure and personal-order sign-in requirement. Preserve query/filter state on a recoverable retry; keep browsing available through an existing safe destination. Loading unknown prices remain placeholders.

**Domain character:** Spacious professional-green shopping states with natural-stone skeletons, warm-gold guidance and a gentle path back to product discovery.

| Panel | Specimen |
| --- | --- |
| Loading | Product-discovery skeleton: two neutral product tile placeholders with media boxes and text bars, no real product or price. Heading "Loading products". Small helper "Refresh keeps available content visible". Tiny accessibility note "Announce once; static when motion is reduced". No percentage or ETA. |
| Empty | Large cart outline icon. Title "Your cart is empty". Body "Browse products to start an order." Primary button "Start shopping". A separate small inset, labelled Filtered view, says "No matches in loaded products" with text action "Clear filters". True empty and filtered no-match are visibly separate examples. |
| Error | Restrained error icon/status container. Title "Orders unavailable". Body "We couldn’t load your orders. Check your connection and try again." Primary button "Retry". Small note "Retry the read; keep filters". Do not display raw exception, money, totals or a success tick. |
| Restricted | Lock outline on neutral green-tinted surface. Title "Sign in to view your orders". Body "Your order history belongs to your account." Primary button "Sign in", secondary text action "Browse products". Small caption "Authentication required". No account suspension or approval claim. |

Gaps and invariants:

- Map unauthenticated reads to a sign-in explanation rather than presenting them as a retryable connection error.
- Search failures must not become empty results. Orders with retained data need refresh/error indication instead of silently hiding the failure.
- Current provider exposes raw error text and shared/default empty-state styling varies; safe copy and C01 themes are future implementation work.
- A missing userId is not proof of zero orders; auth and successful data completion precede true-empty decisions. Cart and orders are separate collections/contexts.

Source anchors:

- [orders_screen.dart](../../apps/marketplace/lib/screens/user/orders/orders_screen.dart)
- [order_provider.dart](../../apps/marketplace/lib/providers/order_provider.dart)
- [empty_orders.dart](../../apps/marketplace/lib/screens/user/orders/widgets/empty_orders.dart)
- [empty_cart.dart](../../apps/marketplace/lib/screens/user/cart/widgets/empty_cart.dart)
- [search_results_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart)
- [auth_guard.dart](../../apps/marketplace/lib/screens/auth/auth_guard.dart)

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

**Current implementation snapshot:** SellerSpinner/SellerProgressLabel/SellerLoadingView/SellerSkeletonList already cover loading, including reduced-motion support in spinner and skeleton families. SellerEmptyState and SellerErrorState provide optional actions and localized copy. SellerProductsScreen chooses error when no base data, then skeleton, then catalogue empty/no-match. AccountRestrictedScreen reopens the application only for rejected sellers; suspension has support and sign-out.

**Target:** Reuse the existing state primitives with the approved C01 identity. Catalogue loading and recovery stay operational and compact; first-product creation differs from filtered no-match. The rejected path reopens a draft; suspension cannot be self-cleared.

**Domain character:** Compact blue-teal catalogue operations with cool-neutral loading rows, restrained copper context and clearly different rejected versus suspended account treatments.

| Panel | Specimen |
| --- | --- |
| Loading | Compact catalogue skeleton rows with neutral square thumbnails and two text bars. Heading "Loading catalogue". Helper "Keep existing rows during refresh". Small note "One loading announcement; reduced-motion static". No product counts or stock numbers. |
| Empty | Catalogue box outline. Title "No products yet". Body "Create your first catalogue item." Primary "Add product". Separate thin inset labelled Filtered catalogue: "No matching products" with text action "Clear filters". Note "Keep search and sort". These are independent illustrative cases. |
| Error | Compact error block title "Catalogue unavailable". Body "We couldn’t load your products. Try again." Filled blue-teal button "Retry". Copper helper "Retry loading; keep catalogue controls". No raw server error, fake stock or publish action. |
| Restricted | Two separately labelled small cases. Rejected: title "Application not approved", helper "Reopen the application as a draft", button "Fix and resubmit". Divider. Suspended: title "Seller account suspended", helper "Contact support to resolve access", actions "Contact support" and "Sign out". No retry or self-reactivate control for suspension. No automatic approval or immediate-resubmit success. |

Gaps and invariants:

- Review initial-error/loading precedence and refresh with retained catalogue data so an old error does not suppress new progress or vanish behind records.
- The current no-match branch does not expose an explicit reset action; Clear filters is a target enhancement with stated scope.
- Fix and resubmit reopens a rejected application draft; it is not approval, publishing or account reinstatement.
- Only show permitted actions with handlers. Reduced-motion and semantics must remain intact during token adoption.

Source anchors:

- [seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [seller_product_provider.dart](../../apps/seller/lib/providers/seller_product_provider.dart)
- [account_restricted_screen.dart](../../apps/seller/lib/screens/auth/account_restricted_screen.dart)
- [seller_application_provider.dart](../../apps/seller/lib/providers/seller_application_provider.dart)
- [app_en.arb](../../apps/seller/lib/l10n/app_en.arb)

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

**Current implementation snapshot:** DeliveryLoadingList/DeliverySkeleton and DeliveryEmptyState/DeliveryErrorState already exist. ActiveWork explicitly models first load, ready/cache and failure with last-known orders. RiderDataError distinguishes permission, offline and unknown. Dashboard retains known orders and shows StaleDataBanner when cached or refresh fails. PendingApprovalScreen separates pending/rejected/suspended/deactivated; only pending/rejected may edit/resubmit.

**Target:** Show first-load and a true successfully loaded empty active-work read independently of connectivity failure. Cached work remains visibly last-known, never an instruction to perform offline mutations. Account restriction gives supported support/edit/sign-out actions rather than retrying a forbidden operation.

**Domain character:** High-contrast black/white field-use states with large controls, burgundy restrictions, burnt-orange connectivity cues and calm neutral cached-data guidance.

| Panel | Specimen |
| --- | --- |
| Loading | Wide task skeleton with neutral icon block and text bars. Heading "Loading active work". Helper "Checking assigned orders". Thin neutral inset "Cached work / Last-known information" with text "Refresh unavailable"; note "Do not treat cached status as live". No map, address, task ID or fabricated job. |
| Empty | Minimal parcel outline. Title "No active assignments". Body "Your assigned-work list is empty." Outlined button "View history". Small burnt-orange caption "Only after a successful current read". Do not promise work will arrive, imply online status, or display Go online. |
| Error | Offline icon with title "Couldn’t connect". Body "Check your connection and try loading again." Large primary button "Retry". Separate small inset labelled Access error: "Can’t read orders" and text actions "Sign in again" and "Contact support". No generic Retry on the permission-error inset. |
| Restricted | Two distinct small cases. Pending review: "Application under review", helper "Work access waits for approval", button "Edit application". Suspended: "Account suspended", helper "An admin must restore work access", actions "Contact support" and "Sign out". Burgundy restricted accents; burnt-orange context. No approval time, automatic reinstatement or resubmit action on suspended case. |

Gaps and invariants:

- ActiveWork.isEmpty is loaded && orders.isEmpty even in failed state; consumers must prioritize error and cache evidence before true-empty copy.
- Current ActiveWorkError presents Retry even for mapped permission failure; target permission recovery differs from a connection retry.
- DeliverySkeleton respects reduced motion; the generic CircularProgressIndicator loading state has no dedicated reduced-motion branch in the inspected code.
- Pending/rejected edit or resubmit is supported. Suspended/deactivated do not get edit, resubmit, go-online, accept-order or self-unlock actions. No refresh-status endpoint is invented.

Source anchors:

- [rider_work.dart](../../apps/delivery/lib/data/rider_work.dart)
- [delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart)
- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)
- [active_work_states.dart](../../apps/delivery/lib/screens/home/active_work_states.dart)
- [dashboard_screen.dart](../../apps/delivery/lib/screens/home/dashboard_screen.dart)
- [pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart)
- [app_en.arb](../../apps/delivery/lib/l10n/app_en.arb)

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

**Current implementation snapshot:** OrdersScreen filters a bounded newest-first attributed-order stream locally. Its initial no-data state returns SizedBox.shrink, while error output includes snap.error. No-match text differs from no-attributed-order copy, but loaded-prefix scope needs explicit guidance. PendingApprovalScreen provides support/sign-out; SuspendedScreen explains that new order attribution is paused and links HelpSupportScreen.

**Target:** Make the currently blank initial load visible with a scoped skeleton. Separate successful empty attribution from a no-match in loaded orders. Replace raw exceptions with safe, scoped recovery. Pending review and suspended attribution remain distinct account states without earnings or approval guarantees.

**Domain character:** Premium royal-blue relationship and attributed-order states, pearl/slate surfaces and restrained indigo context, with financial absence never fabricated as zero.

| Panel | Specimen |
| --- | --- |
| Loading | Pearl/slate record skeleton with small relationship icon placeholder, text bars and no financial values. Heading "Loading attributed orders". Helper "Your records are being loaded". Small note "Refreshing keeps available rows". No balance, order count, percentage or commission amount. |
| Empty | Simple linked-record outline. Title "No attributed orders yet". Body "No orders are currently linked to your account." No forced commercial CTA. Separate indigo-accent inset labelled Filtered view: "No matches in loaded orders" with action "Clear filters". Caption "Load more only when more may exist". No fabricated payout balance. |
| Error | Safe error title "Orders unavailable". Body "We couldn’t load attributed orders. Try again." Primary royal-blue button "Retry" with small caption "Proposed reconnect action". Helper "Keep search and mode". No exception text, code, success, settlement or earnings implication. |
| Restricted | Two distinct cases. Pending: title "Application under review", helper "Approval is still pending", actions "Contact support" and "Sign out". Suspended: title "Account suspended", helper "New order attribution is paused", actions "Contact support" and "Sign out". No auto-approval, activation ETA, earning guarantee or reactivate control. |

Gaps and invariants:

- A filtered empty loaded prefix is not proof of no attributed orders elsewhere; Load more is conditional on the provider/stream evidence.
- Retry is a target reconnection affordance, not an existing dedicated retry handler in the inspected stream view.
- An unavailable order or payout read never implies zero earnings, lost commission, settlement or a change to attribution.
- Support and sign-out are supported. No invented reactivation, appeal submission, immediate active code or approval deadline.

Source anchors:

- [orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [pending_approval_screen.dart](../../apps/employee/lib/screens/auth/pending_approval_screen.dart)
- [suspended_screen.dart](../../apps/employee/lib/screens/auth/suspended_screen.dart)
- [help_support_screen.dart](../../apps/employee/lib/screens/support/help_support_screen.dart)
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

**Current implementation snapshot:** ProductManagementScreen displays loading before an empty-product branch and has query-sensitive empty copy; its inspected list branch has no explicit product-load error state. SellerProductApprovalScreen separates stream error/no-data/empty but interpolates snapshot.error and update exceptions into UI. The approval collection shows all seller products rather than a verified pending-only queue. AuthScreen and app router enforce admin access and show a safe access-denied message.

**Target:** Provide a compact operational read-state family that never turns a failed read into an empty queue. Existing catalogue and seller-product review contexts remain distinct. Admin access denial directs to an authorized sign-in path without granting roles or exposing operational data.

**Domain character:** Dense professional-blue operational states with steel/slate record skeletons, cyan read-scope guidance and precise authorization boundaries.

| Panel | Specimen |
| --- | --- |
| Loading | Dense neutral table/record-row skeleton. Heading "Loading catalogue records". Helper "Keep available rows during refresh". Small cyan guidance "Refresh status stays visible". No fake table values, identifiers, selection totals or backend status. |
| Empty | Compact catalogue outline. Title "No catalogue products". Body "No products are available in this view." Secondary button "Add product". Separate thin inset labelled Filtered catalogue: "No matching loaded records" with action "Clear filters". Never "No pending approvals" or a completed-review claim. |
| Error | Operational error panel title "Catalogue unavailable". Body "Records couldn’t be loaded. Try the read again." Filled professional-blue "Retry" action. Small note "Keep query and filters". Separate quiet line "Retained records: last-known" and "Guard actions that need current data". No data details or fictional result count. |
| Restricted | Shield/lock outline. Title "Admin access unavailable". Body "This account cannot access the admin app." Primary button "Return to sign in". Small helper "Use an authorized admin account". No Request access, Grant role, approve, retry bypass or operational record exposure. |

Gaps and invariants:

- Do not call the seller-product screen an empty pending queue: the current query reads all products and filters sellerId, without a pending-status predicate.
- Add a mapped load-error branch to catalogue management; avoid reporting catalogue absence after a provider failure.
- Raw stream/update exceptions require safe user copy and scoped telemetry; repeated retry must not duplicate mutations or lose selections.
- Proposed retry/read refresh and retained-data guards require future wiring. Access denied is not solved by retry, request-role automation or bypassing authorization.

Source anchors:

- [product_management_screen.dart](../../apps/admin/lib/screens/admin/products/product_management_screen.dart)
- [seller_product_approval_screen.dart](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart)
- [admin_provider.dart](../../apps/admin/lib/providers/admin_provider.dart)
- [auth_screen.dart](../../apps/admin/lib/screens/auth/auth_screen.dart)
- [auth_provider.dart](../../apps/admin/lib/providers/auth_provider.dart)
- [app_router.dart](../../apps/admin/lib/app/app_router.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Exercise first load, refresh with data, recoverable failure with/without retained data, cache reconnect, empty success and filtered no-match independently. Never infer emptiness from a failed read.
- Verify request cancellation/latest response, single subscription, duplicate retry suppression, retained filters, safe exception mapping and telemetry correlation without exposing internals.
- Verify authentication transitions, permission failures and each actual account status. Rejected/pending edits stay conditional; suspended/deactivated cannot self-unlock. No data leaks across account switches.
- Associate no-match scope and conditional Load more; unavailable money stays unavailable. Admin seller products never masquerade as a completed pending-review queue.
- Verify retained data operation guards with real server authority; last-known cache is not a blanket offline mutation rule. Submission retries require idempotency/status reconciliation separately.
- Light/dark, narrow/wide, large text, one bounded loading announcement, clear focus, explicit state text, 48px labelled actions and reduced-motion static skeleton. Do not claim certification from these boards.
- Reuse equivalent components. Future shared UI changes require all five app analyzers and actual rendered before/after review.

## Delivery scope and design lanes

27 new repository files: ten PNGs, five per-app README/prompts/manifest sets, two master documents. Earlier C01–C13 files are preserved. C14 is provisional; no owner approval inferred. User explicitly requested image-prompt provenance; prompts.md records image generation, not an exported implementation-worker prompt.

UIUX/feedback design review covers app identities, state distinction, meaningful supported actions, safe copy and neutral dark surfaces. Classifier lane: docs; UIUX/feedback design review voluntarily attached. Runtime gates are not applicable evidence for assets-only delivery; no Flutter analysis/emulator/live-account/runtime-accessibility checks were performed. No Dart/TypeScript/runtime source, pubspec registration, staging/commit/branch changes, deploy or other-chat interruption by this task. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset delivery verification

**VERIFIED_REPOSITORY_FACT / assets-only integrity PASS.** Ten selected PNGs, five app/theme pairs and 27 new repository files. PNG dimensions, chunk CRCs, source-output/image hashes, exact C01 reference hashes and all palette/type/spacing/radius/border metadata were verified. All 702 pre-existing design files remained byte-identical. Thirteen exact initial/refinement prompt blocks and 96 local Markdown links were checked. Three no-output network failures were retried successfully and recorded in manifests; three selected dark boards include a targeted action-role/variant refinement.

The 817 observed source files / 271,604 lines and platform configuration hashes remained unchanged between inventory and packaging, and during packaging. HEAD remained 97f171f00f8330f1ae7c831845e4dd94a8ae2c33 on agrimore/foundation-f3c-distance-delivery-pricing. These checks establish asset/provenance integrity and observed source preservation, not runtime, live permission, animation, contrast or accessibility certification. C14 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.
