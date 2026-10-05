# Agrimore — C20 connectivity, freshness and recovery: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C20 is not owner-approved; this deliverable is assets/docs only.

[Ten-board gallery](CONNECTIVITY_FRESHNESS_RECOVERY_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: 066981a885caffbb917c102ef4d14de9fb64c9dc. 818 eligible files / 272048 source lines across five app lib trees, three shared package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files were excluded. Files were indexed/hashed and searched for cache source, pending-write metadata, read retry, request identity, saved recovery and connection context. Focused semantic reads covered Marketplace catalogue/cache/checkout and shared database, Seller catalogue/order providers and stock caller, Delivery cache state/provider/history/proof and proof backend, Associate streams/payout review and requestEmployeePayout, and Admin order provider/callers/adminOrderActions. This is broad static coverage plus focused review, not a line-by-line semantic certification of every file or rendered screen.

Marker totals include comments and call sites, not unique components or defect counts. For example, retry can refer to a read or a mutation; pending may refer to approval rather than queued offline work. No global connectivity service was found by scoped lib name/content searches; that is not proof no transitive SDK network behavior exists. Firestore may serve cache without provider/view metadata; get/stream completion alone must not be called proven server freshness. Concurrent implementation may advance source or HEAD during this design task.

| Scope | cache_source | pending_write | read_recovery | request_identity | resume_flow | connection_context |
| --- | --- | --- | --- | --- | --- | --- |
| admin | 1 | 0 | 33 | 94 | 106 | 31 |
| delivery | 30 | 0 | 55 | 46 | 98 | 135 |
| employee | 0 | 0 | 3 | 7 | 16 | 6 |
| marketplace | 26 | 0 | 82 | 272 | 113 | 29 |
| seller | 0 | 0 | 33 | 5 | 78 | 11 |
| functions | 0 | 0 | 55 | 144 | 117 | 34 |
| agrimore_core | 0 | 0 | 2 | 0 | 54 | 7 |
| agrimore_services | 0 | 0 | 5 | 0 | 15 | 4 |
| agrimore_ui | 0 | 0 | 5 | 0 | 3 | 1 |

## Shared target recovery contract

1. Keep device connectivity observations, service reachability, data source/freshness, authenticated access and rider availability as separate states. An exception or cache hit alone does not prove offline.
2. Show cached/last-known/unverified context honestly, including partial datasets. Failure is not empty, counts unavailable are not zero, and refresh completion is not a universal live-state guarantee.
3. Freshness badges/times require real provenance with defined meaning. Local cache write time is not server sync time; do not fabricate age, countdown, current badge or conflict-free state.
4. Propagate snapshot source and pending-write metadata where appropriate; pending local writes must not be displayed as server-confirmed Saved/Synced. Source capability must be verified per provider.
5. Retry reads under the current owner/query and lifetime, preserving useful context and filters without duplicate loads. Drop stale replies as in C19; no old-account cached projection.
6. Read retry, mutation outcome check, same-logical-action retry and saved-stage resume have separate labels and prerequisites. No universal offline queue, autosync or blind replay.
7. An ambiguous mutation may already have committed. Preserve original owner/request/payload identity; reconcile actual state before new action. Known rejection and changed-state conflict have distinct recovery.
8. Supported resume depends on actual domain journals, stage, access, file and eligibility window. Locally retained data is not a remotely completed/paid/delivered/approved outcome.
9. Marketplace resumes only its owner-bound saved checkout stage; existing gateway reopen may be allowed. Seller stock has no evidenced universal durable replay journal.
10. Delivery cached work remains unverified; retained proof retries attach the photo only after file/window/assignment checks, never reconfirm delivery. Account-keyed local proof schema is not assumed.
11. Associate payout identity is retained by review-screen lifetime; admin pending identity is most-recent in-memory action. No safe across-restart resume claim without durable identity/status recovery.
12. Keep accessible persistent freshness/error explanation, labelled comfortable controls and duplicate-retry busy feedback. Accessible announcements, contrast, focus and runtime reconnection need separate rendered verification.
13. Reuse existing provider/journal/retry/state/feedback equivalents. Offline/cache design cannot weaken server authorization, stage validation or payment integrity.

## Five distinct domain systems

| App | Observed source/freshness | Read recovery | Supported operation boundary |
| --- | --- | --- | --- |
| Marketplace | SharedPreferences catalogue preview; expired blob retained; no snapshot freshness projection at model-returning database layer | forceRefresh/read retry; preserve current location/query | Owner-bound saved checkout, stage-dependent; can reopen original eligible gateway order; unpaid draft requires cart review |
| Seller | Products get / orders stream; provider does not expose snapshot cache/pending-write metadata | Reload seller products/orders under current owner; preserve filters | Unknown stock save needs state read; no evidenced durable stock replay journal |
| Delivery | Active work includeMetadataChanges / isFromCache; failed read retains last-known rows | retry current rider binding/read, not rider Online toggle | Retained proof attachment only; file/window/assignment validation; no reconfirm-delivery |
| Sales Associate | Operational and payout StreamBuilder hasError/data paths; no inspected cache freshness projection | Proposed explicit retry/read refresh with useful copy | Same-screen payout requestId retained; backend actor-scoped idempotency; no durable restart identity |
| Admin | Order reads without inspected freshness projection; canonical actions return stale_state / already_applied | Read current authorised order and context | Most-recent identical in-memory pending action preserves requestId; no general bulk or restart resume |

## State and action policy

| Observed condition | Presentation | Permitted recovery / boundary |
| --- | --- | --- |
| Device network observation unavailable | Do not invent an Offline badge | Domain read can still fail for service/access/timeout reasons |
| Read unavailable with no known rows | Explain unavailable and offer read retry | Do not display No records / zero metrics |
| Cached snapshot or retained older rows | Source-appropriate cached/last-known warning | Do not claim device is offline or records are current |
| Source metadata absent | Latest data not verified | Proposed provider metadata / read refresh; no fabricated cache badge/time |
| Local write pending | Pending acknowledgement wording only if observed | No Synced/Saved server confirmation from optimistic local projection |
| Refresh in progress | Indeterminate progress; retry disabled; context retained | Current owner/query generation; no duplicate read or stale result |
| Connectivity returns | Refresh appropriate current context | Do not replay all writes, payments, proof/steps, payouts or admin actions |
| Mutation reply lost / unknown | Outcome unknown; may have finished | Original operation identity and authoritative state reconciliation |
| Definite server rejection | Readable reason and relevant review | Do not present as same as ambiguous timeout or guaranteed rollback of other side effects |
| Server state changed | Review fresh state before next action | Expected-state guard where actually supplied; no overwrite from stale screen |
| Saved stage resumable | Domain-specific Continue/Retry photo/Retry same request | Owner/access/file/stage/window prerequisites and retained identity |
| Journal/file absent or expired | Explain unavailable/expired and supported next action | No forever retry, invented disk draft or new replacement financial request |
| Owner or route changed | Hide earlier owned content, drop late UI side effects | Retain C19 account/episode/entity/query/lifetime boundaries |

## Current evidence and target corrections

| Area | Verified source | Proposed improvement / constraint |
| --- | --- | --- |
| Marketplace catalogue | ProductProvider reads stale SharedPreferences blob, then database fetch; local cache timestamp recorded | Label saved preview; expose actual provenance, scope and verification state. Do not call cache-save timestamp last server sync |
| Marketplace checkout | Existing saved stages: unpaid draft, awaiting_payment, ready, completed; owner locks and current UID/disposal checks | Do not replace with generic Pay again. Continue can reconcile and sometimes reopen original eligible gateway order |
| Seller catalogue | Error retains prior products; snapshots do not expose metadata here; mutations followed by reload | Treat latest state unverified; read check after unknown stock save, no invented durable stock journal or offline success |
| Delivery work | isFromCache explicitly projected; stale banner for cached/error rows; unavailable/deadline maps offline | Use conservative unavailable copy and distinguish cache source from internet connectivity |
| Delivery proof | Persistent order/file/type/capturedAt; missing file dismiss; expired local window dismiss; upload attachment retry only | Preserve file/window branches and backend assignment check; local schema has no owner field, so scoped presentation needs deliberate review |
| Associate requests | Payout review one screen-lifetime requestId; backend actor-scoped transaction returns existing result for same amount | Separate unknown outcome from definite failure/settlement. No safe across-restart retry with freshly minted ID; current backend rereads approved destination |
| Associate lists | Error branches display raw error; streams lack explicit metadata rendering in reviewed blocks | Human-readable read recovery and optional provenance; no fabricated wallet balance or current/paid badge |
| Admin actions | Pending identical action reuses requestId; unknown bare error networkError; ambiguous callable retains ID but classification validationFailed | Introduce typed uncertainty UX while preserving known rejection; backend supports expected status but callers must actually supply it |
| Admin reads | loadOrderById and list loading/error paths have no current freshness projection in inspected provider | Reload order is a read; operation outcome interpretation remains authoritative and domain-specific |
| Shared UI and C19 | Existing error/feedback/buttons/auth ownership are available | Extend existing canonical equivalents rather than duplicate generic network/mutation queue helpers |

## Agrimore Marketplace

**Current implementation snapshot:** ProductProvider loads a SharedPreferences catalogue preview, including an expired blob, before another database fetch; preserves preview on fetch error and supports forceRefresh. It stores local cache-write time, not a proven server verification time, and DatabaseService model-returning reads do not expose snapshot metadata here. OrderProvider supplies loading/errors and streams without cache metadata presentation. MobileCheckoutFlow serializes current-UID/disposal guarded recovery; saved checkout stages distinguish unpaid draft (review cart), awaiting_payment (existing payment order outcome/reopen eligibility), ready and completed. The journal is owner-scoped; no general offline payment queue is evidenced.

**Target:** Separate catalogue read unavailability, a labelled saved preview that does not certify price/stock, read-only refresh and original-account saved checkout. Preserve draft review and actual stage-dependent recovery; never start another payment merely because a reply was lost.

**Domain design:** Professional-green shopping recovery, warm-gold freshness notes, natural-stone catalogue surfaces and generous checkout spacing.

| Panel | Specimen |
| --- | --- |
| Catalogue connection | Card "Catalogue unavailable", connection-slash icon, body "We could not refresh the catalogue." PRIMARY "Try again". Gold BOARD note "Read failure / no empty-catalogue claim". No definitive Offline badge from an unclassified error. |
| Saved catalogue preview | Card "Saved catalogue preview", compact gold warning "Latest availability not verified". EMPTY neutral product-row skeletons. Body "Refresh before relying on availability." Gold BOARD note "Preview is not current stock or price". No product/photo/value/time/count badge. |
| Read retry | Card "Refreshing catalogue", indeterminate spinner, EMPTY skeleton rows, muted DISABLED "Refreshing…" control. BOARD note "Read retry / keep the current filters" and "No payment replay". No percentage, completed tick or timed progress. |
| Saved checkout recovery | Card "Saved checkout", body "Check the earlier payment outcome before starting again." PRIMARY "Continue checkout". Gold BOARD annotations "Original account only" and "Action depends on saved stage". No Pay again, guaranteed paid/confirmed/cancelled status or claim offline checkout works. |

Gaps and preserved boundaries:

- A persisted catalogue timestamp is local cache-write time, not server last-synced proof; no fabricated age or Latest badge.
- Expired cached catalogue may still be previewed; keep stale label and revalidate availability/pricing through canonical checkout.
- Inspect cache location/query/ownership scope before treating a stored catalogue as appropriate for current context; no generic account-sensitive cache guarantee.
- Read retry cannot repeat payment/order mutation. Saved checkout can reopen its existing eligible gateway order; do not claim recovery is entirely read-only or automatic.
- No global connectivity detector was found in the scoped lib search; a timeout does not prove the device has no internet.

Source anchors:

- [product_provider.dart](../../apps/marketplace/lib/providers/product_provider.dart)
- [order_provider.dart](../../apps/marketplace/lib/providers/order_provider.dart)
- [mobile_checkout_flow.dart](../../apps/marketplace/lib/services/mobile_checkout_flow.dart)
- [checkout_recovery_service.dart](../../apps/marketplace/lib/services/checkout_recovery_service.dart)
- [saved_checkout_card.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart)
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

**Current implementation snapshot:** SellerProductProvider reads products through Firestore get, retains previous list on error, and reports loading/error; snapshot freshness metadata is not propagated in the inspected provider. SellerOrderProvider listens to seller orders but does not expose isFromCache/hasPendingWrites to its view. Product mutations use add/update/delete and then reload; no general durable stock mutation journal or offline replay UX is evidenced. Seller application step persistence and AI retryLast are separate domains, not universal stock recovery.

**Target:** Use readable catalogue failure and latest-not-verified rows, read-only reload progress and a stock-outcome check. Keep old data useful only under the current seller and current filters; a failed refresh does not prove empty stock or failed save.

**Domain design:** Compact blue-teal merchant recovery, copper stock-outcome guidance, cool-neutral catalogue rows and precise read refresh controls.

| Panel | Specimen |
| --- | --- |
| Catalogue read failure | Card "Could not load products", connection-slash icon, body "Your product list could not be refreshed." PRIMARY "Reload products". Copper BOARD note "Read failure / not an empty shop". No count or offline-online guarantee. |
| Unverified stock view | Card "Product list", copper caution chip "Latest data not verified", EMPTY product/stock row skeletons. Body "Reload to check the current catalogue." BOARD note "Freshness presentation proposed". No Cached badge, stock digits, fake timestamp or Saved badge. |
| Product read recovery | Card "Reloading products", indeterminate spinner, EMPTY row skeletons, muted DISABLED "Reloading…" control. Copper BOARD note "Read only / keep filters" and "No stock replay". No save-complete tick or percentage. |
| Uncertain stock save | Card "Stock update needs checking", body "Read the product before trying the update again." PRIMARY "Reload products". Copper BOARD note "Earlier write may have finished" and "No automatic resubmission". No Save again, stock-zero, guaranteed rollback or durable draft claim. |

Gaps and preserved boundaries:

- Do not label ordinary successful get as proven server-fresh; metadata/source must be propagated before claiming current/cache-specific UI.
- Do not show Saved/Synced when a write is pending or its outcome is unknown; current provider return paths are not a universal offline acknowledgement protocol.
- Check current authorised product state before reissuing stock mutation; no supported stock journal/autosync/resume promise in this proposal.
- Preserve existing stock caller UID checks and extend episode/provider/route checks where needed from C19.
- AI offline copy or an offline icon is not a global device connectivity service.

Source anchors:

- [seller_product_provider.dart](../../apps/seller/lib/providers/seller_product_provider.dart)
- [seller_order_provider.dart](../../apps/seller/lib/providers/seller_order_provider.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [seller_application_provider.dart](../../apps/seller/lib/providers/seller_application_provider.dart)
- [seller_ai_chat_provider.dart](../../apps/seller/lib/providers/seller_ai_chat_provider.dart)

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

**Current implementation snapshot:** DeliveryOrderProvider uses includeMetadataChanges and ActiveSnapshot.fromCache from Firestore isFromCache. ActiveWork.failed retains last-known orders; dashboard shows StaleDataBanner when cached/error records exist and separate ActiveWorkError if no records. unavailable/deadline-exceeded maps to RiderDataError.offline, a coarse read classification rather than definitive network measurement. retry rebinds current rider reads. PendingProofStore durably records order/photo path/type/capture time; retry reads bytes and attaches proof only, never reconfirms delivery. Missing file is explained and dismissed, expired local window exposes dismiss, in-flight retries disabled. Backend attachProofCore checks original assignment, delivered state, existing attachment and proof window. Local schema has no explicit owner field, so do not claim account-keyed journal.

**Target:** Show work read unavailable separately from cached rider work, read retry progress, and a retained eligible proof-upload action. Keep last-known work labelled; proof retained locally is not attached, and rider availability toggle is not internet connectivity.

**Domain design:** High-contrast black/white field recovery, burgundy proof attention, burnt-orange stale-work guidance and large comfortable single-purpose controls.

| Panel | Specimen |
| --- | --- |
| Work read unavailable | Card "Could not refresh rider work", connection-slash icon, body "Check your connection and try again." PRIMARY "Try again", black light / off-white with dark labels dark. Orange BOARD note "Read unavailable / no no-work claim". No rider Online toggle, map/location or assignment count. |
| Cached rider work | Card "Last-known rider work", orange caution "Latest work not verified", EMPTY work-row skeletons. Body "Cached work may have changed." Orange BOARD note "Cache source / not live assignment confirmation". No task identifier, Delivered tick, refreshed timestamp or invented count. |
| Work read retry | Card "Reloading rider work", indeterminate spinner and EMPTY rows, DISABLED "Reloading…" control. Orange BOARD note "Work reads only" and "No task-step replay". No accept-offer, online status or route map. |
| Retained proof recovery | Card "Proof photo not yet attached", small outlined photo icon without thumbnail, body "A retained photo can be retried for the original delivery." PRIMARY "Retry photo upload". Burgundy attention accent. Orange BOARD notes "Eligible file and window only" and "Does not reconfirm delivery". No delivered-success tick, file values, photo, countdown or guaranteed upload success. |

Gaps and preserved boundaries:

- isFromCache is evidence of cache source, not proof device is offline. Read error retaining previous rows is last-known data, not necessarily a cache snapshot.
- Pending proof retry requires retained bytes, eligible window and actual authorised assignment; missing/expired cases need distinct recovery, not a forever Retry button.
- Retry uploads/attaches photo only; no reconfirm delivery, repeat step, new assignment or delivered-success claim.
- Backend rejects other-rider proof attachment; local journal lacks owner field. Add/check owner-scoped presentation before showing prior account artifacts; no automatic cross-account resume.
- Counts unavailable/stale are not zero; maps, location permission, app lifecycle tracking and rider online availability are separate states.

Source anchors:

- [rider_work.dart](../../apps/delivery/lib/data/rider_work.dart)
- [order_provider.dart](../../apps/delivery/lib/providers/order_provider.dart)
- [rider_history.dart](../../apps/delivery/lib/data/rider_history.dart)
- [active_work_states.dart](../../apps/delivery/lib/screens/home/active_work_states.dart)
- [dashboard_screen.dart](../../apps/delivery/lib/screens/home/dashboard_screen.dart)
- [pending_proof_banner.dart](../../apps/delivery/lib/screens/home/pending_proof_banner.dart)
- [proof_photo_recovery.dart](../../apps/delivery/lib/delivery/proof_photo_recovery.dart)
- [riderExceptions.ts](../../functions/src/delivery/riderExceptions.ts)

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

**Current implementation snapshot:** Dashboard recent-order and payout-history StreamBuilders have hasError/loading/data branches but inspected streams do not expose freshness metadata; error text includes raw error details and no dedicated retry affordance in inspected blocks. PayoutReviewScreen retains one requestId for its mounted lifetime with duplicate-submit guard; retry invokes the same logical requested amount. Backend requestEmployeePayout requires approved employee and actor-scoped requestId, checks existing amount and returns original result without a second debit. Destination is read server-side transactionally; client review fields do not guarantee destination consistency. No disk-persisted payout request journal or across-restart retry identity is evidenced.

**Target:** Separate operational read failure, unverified list freshness, current-account read refresh and a clearly bounded payout retry. Unknown payout reply is not failure, payment settlement or approval; retained same-screen identity may retry the same request while actual history/status is checked.

**Domain design:** Premium royal-blue associate read recovery, indigo request-outcome caution, pearl/slate operational rows and restrained payout request guidance.

| Panel | Specimen |
| --- | --- |
| Associate data failure | Card "Could not load recent activity", connection-slash icon, body "Your activity could not be refreshed." PRIMARY "Try again". Indigo BOARD note "Proposed read recovery / no raw error". No account name, order value or offline guarantee. |
| Unverified records | Card "Recent activity", indigo caution chip "Latest data not verified", EMPTY neutral record rows. Body "Refresh to check current records." BOARD note "Freshness metadata needed". No Cached badge, earnings, wallet value, paid badge or timestamp. |
| Read refresh | Card "Refreshing activity", indeterminate spinner, EMPTY rows, DISABLED "Refreshing…" control. Indigo BOARD note "Read only / preserve list context". No new payout button, completion tick or numeric progress. |
| Retained payout request | Card "Payout request outcome unknown", body "Retry the same request from this review." PRIMARY "Retry same request". Indigo BOARD notes "Retained review screen only" and "Existing request identity / no new request". No paid/approved/settled/failed badge, amount, destination, guarantee of future payment or claim restart recovery exists. |

Gaps and preserved boundaries:

- A stream record is not a server-fresh financial guarantee; propose metadata exposure and readable failure instead of raw exceptions.
- Keep zero/empty/paid status separate from unavailable reads; no fake balance, earnings or settled badge in specimens.
- Same-request retry is supported for this retained review screen only; after leaving/restart do not mint a new request to resolve an unknown outcome.
- Backend rereads payout destination; server result/history is authoritative, not the original UI destination snapshot.
- Preserve C19 current account/session/route safeguards before retry feedback/navigation; same requestId is not session ownership.

Source anchors:

- [dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)
- [payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart)
- [payout_review_screen.dart](../../apps/employee/lib/screens/wallet/payout_review_screen.dart)
- [payout_details_screen.dart](../../apps/employee/lib/screens/wallet/payout_details_screen.dart)
- [requestEmployeePayout.ts](../../functions/src/customer/requestEmployeePayout.ts)

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

**Current implementation snapshot:** Admin OrderProvider loads order reads without a freshness projection in inspected methods. updateOrderStatus retains PendingStatusUpdate for identical order/target/reason after ambiguous failures and reuses requestId; definite response clears it. Bare exceptions return networkError; ambiguous FirebaseFunctionsException currently retains pending identity but maps to validationFailed rather than networkError, so UX needs typed uncertainty treatment. Backend canonical action transaction uses order/adminActions requestId, rejects mismatched target/reason, handles already_applied and expectedCurrentStatus stale_state. Expected status is optional in client/provider; not every caller supplies it. Pending identity is in memory, most recent action only, not universal durable journal.

**Target:** Separate operational read unavailable, latest-not-verified order context, read refresh and unknown action reconciliation. Show read-only Reload order to inspect server state; same-action retry is a conditional implementation path using retained identity, never a generic Replay or bulk-resume claim.

**Domain design:** Professional-blue operational recovery, cyan read/context guidance, steel/slate order surfaces and precise uncertain-action boundaries.

| Panel | Specimen |
| --- | --- |
| Operational read failure | Card "Could not load order data", connection-slash icon, body "Order records could not be refreshed." PRIMARY "Reload order". Cyan BOARD note "Read unavailable / no empty-record claim". No order ID, customer, metric or definitive internet state. |
| Unverified order context | Card "Order context", cyan caution chip "Latest state not verified", EMPTY order-row skeletons. Body "Reload before choosing the next action." BOARD note "Freshness presentation proposed". No Cached/approved/cancelled badge, timestamp or stock/money value. |
| Order read refresh | Card "Reloading order", indeterminate spinner, EMPTY rows, DISABLED "Reloading…" control. Cyan BOARD note "Read only / preserve the current record". No apply-status, success tick or percentage. |
| Unknown action outcome | Card "Action outcome unknown", body "The earlier action may have finished. Reload the order to review its state." PRIMARY "Reload order". Cyan BOARD note "Reconcile before another action" and "Same-action retry requires retained identity". No Apply again, guaranteed cancellation/refund/rollback, completed status or universal resume queue. |

Gaps and preserved boundaries:

- Propagate cache/source/pending-write metadata before Last synced/current claims; a fetch completion is not all-dashboard freshness.
- Expose ambiguous callable outcome explicitly rather than treating every validationFailed as definitely rejected.
- Keep identical pending order/action/reason identity for a permitted retry; new payload/new action requires its own identity. No durable restart/bulk resume guarantee.
- Pass/verify expected status at callers where concurrency guard is intended; provider/backend support alone does not prove every caller prevents stale writes.
- Reload order is read-only and does not resolve payment/refund/approval or guarantee no earlier mutation committed. Preserve C19 account/route ownership.

Source anchors:

- [order_provider.dart](../../apps/admin/lib/providers/order_provider.dart)
- [order_management_screen.dart](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart)
- [adminOrderActions.ts](../../functions/src/admin/adminOrderActions.ts)
- [auth_provider.dart](../../apps/admin/lib/providers/auth_provider.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Reuse and authority

Reuse current provider/journal/retry/loading/error/feedback equivalents, session predicates and canonical server actions. C01 locked colors/type/spacing/radii override historical emerald-only notes. C16 feedback placement, C18 access and C19 session ownership remain separate applicable foundations. No new widget, global connectivity manager, general mutation queue, package folder or runtime implementation is delivered here. Exact requested image prompts are asset provenance, not exported implementation-worker prompts.

## Future implementation verification

- Cache-only start, no cache, stale cache, partial query, server unavailable despite device network, permission error despite working network, service recovery and app resume. Each actual source maps to truthful copy; no empty/zero/current result from failure.
- Preserve account/query/filter context across refresh; concurrent loads, owner changes, same-UID new auth episode, route disposal and late metadata updates. No previous account cache or late loading/error overwrite; C19 safeguards apply.
- Pending local writes, server acknowledgement/rejection and metadata-only changes. Do not show synced before acknowledgement; metadata absence stays unverified. Verify real freshness time semantics rather than infer from record timestamps or cache writes.
- Marketplace: expired/invalid/location-mismatched catalogue cache; force refresh/read timeout; checkout draft versus existing gateway versus ready/completed. No second purchase/payment from an unknown reply; receipt/cart/journal ownership persists.
- Seller: unknown stock write followed by failed reload; preserved list and filters; current owner reload. No Save again without state reconciliation and no generic durable offline save promise.
- Delivery: cached empty/nonempty work, failed refresh, invalid assignment, no counts; metadata changes. Retained proof eligible/missing/expired bytes, attachment refused/already attached, different rider, duplicate retry and restart. Photo retry never reconfirms delivery; local order-only journal presentation must be owner-safe.
- Sales Associate: payout request reply dropped before/after commit; same-screen identity retry, amount conflict, account change, server destination change, leaving/restarting review. History/state reconciliation before any new financial request; requested is not paid/settled.
- Admin: unknown bare/callable failures, definite refusal, same action requestId replay, different reason/target, stale expected status, multiple pending records and provider restart. Distinguish support in provider/backend from actual caller behavior; no generic bulk resume guarantee.
- All five themes: render comfortable retry targets, disabled progress, persistent readable freshness warning, screen-reader announcements/focus, large text/narrow widths, reduced motion, contrast and no white-on-pale dark primary text. Raster boards do not certify these runtime properties.
- Future runtime source edits need targeted meaningful tests and applicable app analyzers. No Flutter/runtime tests, emulator, live auth/OTP, Firebase writes, server deployment or security/accessibility certification was run for this image deliverable.

## Delivery scope and design review

27 new files: ten PNGs, five per-app README/prompts/manifest sets and two master documents. C01–C19 and existing C16 remain preserved. C20 is provisional, not owner-approved. Classifier: docs; voluntary UIUX/feedback design review covers locked identity, truthful freshness/uncertainty, read versus action recovery, supported stage/file/request identity and dark surfaces.

This task writes only its design assets/docs. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption was performed by this task. Concurrent implementation source/HEAD changes are observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/providers/address_provider.dart, apps/marketplace/lib/screens/auth/onboarding_address_screen.dart, apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart.

## Asset verification — first post-packaging snapshot

PASS: ten PNGs / five light–dark pairs; PNG headers, dimensions and chunk CRCs; selected-output byte hashes; ten exact prompt blocks and input/output provenance hashes; C01 APPROVED_LOCKED reference hashes and token metadata; 87 local document links; exactly 27 declared new repository files. All 864 earlier design files matched their pre-task hashes, including C16 and C01–C19.

Static inventory: 818 eligible source files / 272,048 lines at HEAD 066981a885caffbb917c102ef4d14de9fb64c9dc. The first post-packaging check observed that same HEAD on branch agrimore/foundation-f3c-distance-delivery-pricing. Concurrent source changes between inventory and packaging were observed in Marketplace address_provider.dart, onboarding_address_screen.dart and address_bottom_sheet.dart and preserved. No additional baseline source changes were observed between packaging and that check; ten inspected platform configuration hashes matched. This is a bounded observation, not a claim that a shared checkout will remain unchanged.

All ten selected outputs were reviewed through native image previews for domain recovery wording, source/freshness uncertainty, app identity, readable dark inverse labels, empty specimens and absence of unsupported sync/replay/success claims. No refinement was needed. Image integrity and exact token metadata do not certify pixel-exact palette, runtime recovery, security or accessibility.

Verification covered assets/docs only. This task wrote its 27 declared files and did not stage, commit, change runtime code, deploy or interrupt another chat.
