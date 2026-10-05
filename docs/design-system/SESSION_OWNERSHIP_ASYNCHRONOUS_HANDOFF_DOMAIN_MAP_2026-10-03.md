# Agrimore — C19 session ownership and asynchronous handoff: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C19 is not owner-approved and does not change runtime authentication, domain commands or authorization.

[Ten-board gallery](SESSION_OWNERSHIP_ASYNCHRONOUS_HANDOFF_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: 785d7b91391079cc9fdb4cc275ae8caf2a64c934. 818 eligible files / 271801 source lines across the five app lib trees, three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files were excluded. Files were indexed/hashed and searched for ownership, generations, mounted guards, listener lifetimes and request identity. Focused semantic reads covered all five auth providers, shared AuthService, Marketplace checkout/recovery/RFQ/credit, Seller products/orders/stock caller, Delivery gate/order/active-task/proof schema, Associate payout requests and Admin settings/support handlers. This is a broad static inventory plus focused review, not a semantic audit of every line or rendered screen. Backend inventory is context, not live-state/security certification.

Counts include comments/call sites and are not unique components or defect counts. Mounted markers do not prove current ownership; zero named ownership markers do not prove unsafe behavior because route disposal or other guards may apply. Auth, entity, route and lifecycle ownership need independent runtime verification. Concurrent implementation may advance source or HEAD during this design task.

| Scope | owned_predicate | auth_episode | mounted_guard | listener_lifetime | request_identity | late_result_context |
| --- | --- | --- | --- | --- | --- | --- |
| admin | 24 | 15 | 355 | 265 | 95 | 17 |
| delivery | 25 | 27 | 150 | 100 | 46 | 23 |
| employee | 13 | 14 | 20 | 37 | 7 | 1 |
| marketplace | 83 | 37 | 329 | 438 | 272 | 21 |
| seller | 10 | 10 | 130 | 173 | 5 | 4 |
| functions | 0 | 0 | 0 | 0 | 163 | 33 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 6 |
| agrimore_services | 21 | 0 | 0 | 24 | 0 | 2 |
| agrimore_ui | 0 | 0 | 3 | 11 | 0 | 0 |

## Shared target handoff contract

1. Capture current account, auth episode, entity/operation, route and provider lifetime before starting asynchronous work. Mounted alone is insufficient.
2. On account change, invalidate old UI ownership, cancel/rebind scoped listeners and hide prior sensitive projection before loading the new account. Hiding UI is not deleting remote records.
3. Recheck the captured ticket after every await and before writes initiated from a stale dialog, local state changes, feedback, loading cleanup, modal close or navigation.
4. A later same-UID auth episode can revoke an old UI ticket. UID-only equality and canceled streams are not universal proof of episode ownership.
5. Late reads/listeners/commands must not overwrite current account or current entity data, clear a newer spinner, show old success/error or pop a replacement route.
6. Ignored UI response is not canceled server work, rollback, refund, unsent request or failed mutation. Reconcile original action outcome under its authorised owner before repeat action.
7. Confirmed missing/expired auth can require sign-in again. Network error, profile read failure, rate limit, recent-login challenge and account suspension are distinct; never infer expiry from every exception.
8. During sign-in/role restoration keep protected content hidden and re-evaluate C18 profile/approval/access requirements; no automatic privileged shell or work availability.
9. Recovery stays bound to original owner and operation identity; current-account read/navigation recovery is separate from mutation replay. Persisted journals must never expose another account’s payload.
10. Sensitive local edits do not transfer across accounts. Preserve evidenced owner-scoped checkout recovery; no universal disk-draft, proof-owner schema or automatic form-resume promise.
11. Use indeterminate loading without fabricated countdowns, metrics or success badges. Accessible transition/error announcements and focus after safe routing need rendered AT verification.
12. Reuse existing auth services, session predicates, domain providers and feedback/navigation equivalents. No duplicate helper and no weakened server/rules authorization.

## Per-app boundaries

| App | Existing ownership | Domain outcome to protect | Recovery presentation |
| --- | --- | --- | --- |
| Marketplace | Auth epoch; owner/session/list generations in RFQ; checkout UID/disposal/journal-owner checks | Order/payment receipt, changed cart, quote and credit data; suppress old UI without deleting owner journal | Original-account saved checkout, stage-dependent Continue; no charge-again |
| Seller | Auth/access-read epoch; explicit UID checks in stock caller; no provider generation in inspected product/list methods | Stock/product list and merchant feedback; listener cancellation is not universal episode proof | Read current products; original write may already be committed |
| Delivery | Auth session; RiderSessionGate closes old routes and drops work/tracking; bound work generation | Different rider task cannot advance from old step reply; direct invocation result still returned | Retry current rider work only; no proof/step replay |
| Sales Associate | Auth epoch/approval projection; payout handlers currently mounted-gated | Review submission/cancellation feedback and sensitive settings must not transfer across accounts | Open current authorised settings and read request before repeat mutation |
| Admin | Auth sessionVersion; settings logout/form owns session and route; support _call mounted-gated | Old operator/case callback cannot notify, refresh, dismiss or navigate new context | Proposed reload of authorised current case; reconcile earlier action separately |

## Transition and result policy

| State / event | UI presentation | Operation boundary |
| --- | --- | --- |
| Account change begins | Hide previous owned records; indeterminate Loading current account | Invalidate UI tickets and rebind scoped state; do not delete remote records |
| Confirmed sign-out / expired identity | Sign in again through existing app auth; no sensitive context | Re-evaluate role/profile/approval before protected destination |
| Auth/profile read unavailable | Safe read-error recovery, no false expiry or suspension | Do not sign out/reclassify merely from a network exception |
| Late read or listener callback | Drop old data/error/loading update for replacement owner/query | Recheck account, episode, entity/query and provider lifetime |
| Stale dialog confirmation | No old consent dispatch after ownership changed | Validate route/session before server mutation, not only after reply |
| Late mutation response | No old success/error, local overwrite or navigation in current session | Original server operation may have completed; UI rejection is not rollback |
| Same account re-authenticated | Fresh episode and access decision; no revived stale modal | UID equality alone may not identify the same auth episode |
| Domain operation outcome unknown | Owner-bound status read/reconciliation before replay | Preserve actual journal/request identity; do not create replacement mutation |
| Recovery in a different account | Only its authorised records; never expose former account payload | Do not move previous request, bank input or proof into this account |
| Page/entity replaced | Restore focus to safe current destination; no stale pop/toast | Mounted route is not necessarily the original route/entity |

## Verified local findings and proposed corrections

| Area | Current source evidence | Target / limitation |
| --- | --- | --- |
| Auth foundations | All five providers have owned projection/read checks; shared _OwnedAuthSession revokes on later events including same UID | Reuse/extend existing predicates; no claim that every domain operation already follows them |
| Shared restore | restoreSession checks owned session but catch may return a fallback role-user model | Read failure is not proof of expired session or a definitive new role decision; future typed outcomes must be deliberate |
| Marketplace checkout | UID/disposal checks and owner journal locks; confirmation checks after receipt/cart/acknowledgement; changed cart preserved | Preserve actual recovery and extend route/episode tickets where needed; no blanket epoch guarantee |
| Marketplace RFQ/credit | Current source owner/list/load generation guards clear stale projection and reject old command results | These fresh observations supersede older design snapshots; screen-level route/error feedback still needs checks |
| Seller products/orders | Product provider stores awaited results without explicit generation; old order listener is canceled before new one, callbacks not generation-ticketed | Check actual provider/shell lifetime and add current-owner/episode guards where needed; source alone does not prove exposure |
| Seller stock caller | Caller checks captured UID after initial read, before onSave and before final success toast | Keep these protections; same-UID episode and sheet/provider ownership remain separate |
| Delivery | Gate closes old routes, stops tracking, clears offers; provider drops old shared state but returns direct stale invocation result | Retain gate cleanup; verify screen-owned result ticket rather than assume provider suppression covers every UI callback |
| Delivery proof | PendingProof fields include orderId/photoPath/contentType/capturedAt, with no explicit owner field in inspected schema | Do not invent owner-keyed proof journal or automatic resume guarantee; assignment/backend checks need separate audit |
| Associate payout | Submit/cancel feedback and busy cleanup use mounted in inspected methods | Capture current authorised associate/session/route/entity; no sensitive draft transfer or guaranteed approval |
| Admin | Settings logout and credential form carry session/route guards; support _call success/error/tick/busy cleanup uses mounted | Extend session/route/case ownership to support feedback; mounted-only is a gap, not proof backend permits cross-account writes |

## Agrimore Marketplace

**Current implementation snapshot:** AuthProvider exposes owned projection, sessionOwner/sessionVersion/isSessionCurrent and renews epochs on auth events. MobileCheckoutFlow exposes pending only for the current UID, serializes work and checks live UID/disposal around awaits; CheckoutRecoveryService locks/checks the original owner. finishMobileCheckout rechecks mounted/current UID after receipt read, cart change and acknowledgement before navigation, validates receipt/order ownership and preserves a changed cart. These checkout checks are UID-based rather than a universal auth-epoch guard. RfqProvider now tracks owner/session/list generations, clears scoped state and rejects late commands; ProductCreditProvider hides stale balance/ledger and uses load ownership. Shared restoreSession can return a fallback user model on read/reload failure; failure alone is not evidence of session expiry.

**Target:** Show a clean shopper-account transition, confirmed sign-in-required boundary, no old checkout reply in a new account, and owned saved-checkout recovery only after account/access checks. Preserve checkout journals and reconcile server outcome before another purchase; no automatic payment replay or cart clearing from a stale response.

**Domain design:** Professional-green shopper transitions, warm-gold outcome guidance, natural-stone cards and generous checkout-recovery spacing.

| Panel | Specimen |
| --- | --- |
| Shopping account transition | Card "Updating your shopping account", indeterminate spinner, body "Loading the current account." Empty skeleton rows, no cart/order/balance values. Gold BOARD annotation "Hide previous account content before loading" and "Existing records are not deleted". No success tick or account-switch button. |
| Sign-in required | Card "Sign in to continue", lock icon, body "Your shopping session is no longer available." green PRIMARY "Sign in again". Gold BOARD note "Confirmed session end / not a network error". No timer, password/code fields, bank data or promise the checkout is paid/canceled. |
| Late checkout boundary | Neutral card "Current checkout view" with EMPTY record skeleton, NO order/paid/success badge. Separate gold board diagram: "Earlier checkout reply" arrow to a small crossed boundary "Not applied to this view". Board note "Late reply ignored / server outcome not canceled". No foreign account or receipt values; do not put an old-customer toast into current account. |
| Owned checkout recovery | Card "Saved checkout", caption "Current-account specimen", body "Check the earlier payment outcome before starting again." green PRIMARY "Continue checkout". Gold board note "Only for the original checkout account" and "Action depends on saved stage". No charge-again, new payment, cancellation, refund, confirmed order or successful-payment indicator. |

Gaps and preserved boundaries:

- Extend route/action episode checks where UID-only ownership cannot distinguish a later same-account session; do not claim all checkout paths already use auth epochs.
- A stale UI response does not cancel or roll back an earlier server order/payment; keep recovery journal ownership and original request identity.
- Never reveal old cart, order, quote, credit or customer details while a new account is loading.
- Use known auth absence/expiry for Sign in again; network/profile read failure stays a read-recovery state.
- Saved-checkout controls depend on actual journal stage; no generic Continue that recharges, no invented payment-complete badge.

Source anchors:

- [auth_provider.dart](../../apps/marketplace/lib/providers/auth_provider.dart)
- [rfq_provider.dart](../../apps/marketplace/lib/providers/rfq_provider.dart)
- [product_credit_provider.dart](../../apps/marketplace/lib/providers/product_credit_provider.dart)
- [mobile_checkout_flow.dart](../../apps/marketplace/lib/services/mobile_checkout_flow.dart)
- [checkout_recovery_service.dart](../../apps/marketplace/lib/services/checkout_recovery_service.dart)
- [mobile_checkout_confirmation.dart](../../apps/marketplace/lib/services/mobile_checkout_confirmation.dart)
- [saved_checkout_card.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart)
- [auth_service.dart](../../packages/agrimore_services/lib/auth/auth_service.dart)

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

**Current implementation snapshot:** SellerAuthProvider clears pending phone/Google identity and projection, renews session/access-read generations and rejects late reads/auth actions. SellerProductProvider loadSellerProducts and mutations write provider state after awaits without an explicit owner/generation guard in the inspected methods. SellerOrderProvider cancels old listener when loading but callbacks do not carry an explicit generation ticket. The stock editor caller DOES capture UID and checks it before initial read feedback, onSave and final toast; this is narrower than full provider or same-UID episode ownership. Auth gate/shell lifetime may dispose pages and reduce races; these reads alone do not prove a cross-account exposure.

**Target:** Preserve existing stock caller UID checks and auth ownership while proposing explicit provider/route generations. Clear previous merchant records during account change; only the current merchant can receive save feedback or reload products. An old stock save may still have committed for its original owner; UI suppression is not rollback.

**Domain design:** Compact blue-teal merchant rebinding surfaces, copper save-outcome context, cool-neutral product rows and precise stock-reload controls.

| Panel | Specimen |
| --- | --- |
| Merchant account transition | Card "Updating seller workspace", indeterminate spinner and text "Checking the current seller account." Empty product-row skeletons. Copper BOARD notes "Previous merchant data hidden" and "Remote stock is not deleted". No counts, product names or active-store status. |
| Sign-in required | Card "Sign in to seller", lock icon, body "Sign in again. Seller access will be checked before opening the workspace." blue-teal PRIMARY "Sign in again". Copper BOARD annotation "Confirmed session end / approval checked separately". No pending/approved/suspended badge fabricated from an expired session. |
| Late stock boundary | Neutral card "Current product view", EMPTY stock-row skeleton with no numeric value. Copper board diagram "Earlier stock-save reply" arrow crossed at "Not applied to this workspace". BOARD note "No old-session saved toast" and "Server write may already have finished". No Stock saved, reset stock, undo or Save again control. |
| Current product recovery | Card "Reload current products", body "Read products for the current seller account." PRIMARY "Reload products", caption "Proposed read recovery". Copper note "Read only / verify an earlier save separately". No product values, repeat-save, stock-zero result or assertion the earlier mutation failed. |

Gaps and preserved boundaries:

- Do not falsely say stock caller has only mounted checks: existing UID checks are evidenced and must stay.
- Provider-level state reads/listeners need current owner plus generation and disposal guards; canceled listener alone is not proof queued events cannot publish.
- Same UID after re-auth is a new episode for UI side effects; protect old sheets, captured product and return route.
- No blanket Stocks saved message or fresh save under another merchant after late response.
- Product reload is a read; unknown stock mutation outcome is reconciled under the original authorised merchant, not retried blindly.

Source anchors:

- [seller_auth_provider.dart](../../apps/seller/lib/providers/seller_auth_provider.dart)
- [seller_product_provider.dart](../../apps/seller/lib/providers/seller_product_provider.dart)
- [seller_order_provider.dart](../../apps/seller/lib/providers/seller_order_provider.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [app.dart](../../apps/seller/lib/app/app.dart)

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

**Current implementation snapshot:** DeliveryAuthProvider ties projection and actions to current UID/session. RiderSessionGate binds order/history state to the currently operable rider; when the binding ends it closes old routes, clears offer launches/notifications and stops location tracking. DeliveryOrderProvider.bind increments a generation, clears previous work/counters/errors and drops old stream/read results. advanceStep/releaseOrder protect shared error state with generation but still return the original invocation result to its caller. ActiveOrderScreen checks mounted after awaited step and then updates local step/toast; the gate closing old routes is a mitigating lifecycle behavior, not a universal caller-owned ticket. PendingProofStore data in the inspected record shape is keyed by order and has no explicit owner field; safe cross-account proof recovery must be demonstrated by authorised order/assignment checks rather than assumed.

**Target:** Show rider work cleared while rebinding, sign-in required without an online claim, no late step response applied to a different rider task, and read-only retry of current rider work. Preserve current gate cleanup. Never replay a step, confirm delivery or upload another rider proof merely because a UI session changed.

**Domain design:** High-contrast black/white rider rebinding, burgundy stale-task boundaries, burnt-orange field guidance and large single-purpose recovery controls.

| Panel | Specimen |
| --- | --- |
| Rider work transition | Card "Updating rider workspace", indeterminate spinner and "Loading work for the current rider." EMPTY work-row skeletons. Orange BOARD notes "Previous rider work hidden" and "Old task screens close". No job values, rider name, live-map marker, online toggle or assigned-count metric. |
| Sign-in required | Card "Sign in to delivery", lock icon, body "Sign in again. Rider access will be checked before work opens." black PRIMARY "Sign in again" in light, off-white with dark text in dark. Orange BOARD note "Confirmed session end / not proof of suspension". No delivered/online/suspended badge. |
| Late task boundary | Neutral card "Current rider task", EMPTY task skeleton. Burgundy BOARD diagram "Earlier step reply" arrow crossed at "Not applied to this rider view". Orange board note "No step completion from an old session" and "Server outcome is checked separately". No delivered tick, replay step, proof-photo thumbnail or released-order success. |
| Current work recovery | Card "Reload rider work", body "Read work for the current authorised rider." PRIMARY "Try again", small "Read recovery" caption. Orange BOARD note "Reload only / no automatic task replay". No accept offer, resume proof, reconfirm delivery, online state, location or task-count value. |

Gaps and preserved boundaries:

- Retain the existing route-pop, offer cleanup and tracking stop when work binding ends; these are current behaviors, not new guarantees.
- Provider suppression of shared errors does not automatically suppress an awaited screen result; verify route, rider, task and episode around screen feedback.
- Proof recovery owner is not explicitly stored in the inspected PendingProof schema. No automatic cross-account proof resume or deletion guarantee in boards.
- A session change is not a delivered/completed/released outcome and does not cancel server step execution.
- Retry current work reads only; auth approval, offline status and assignment state remain separate.

Source anchors:

- [auth_provider.dart](../../apps/delivery/lib/providers/auth_provider.dart)
- [app.dart](../../apps/delivery/lib/app/app.dart)
- [order_provider.dart](../../apps/delivery/lib/providers/order_provider.dart)
- [active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)
- [proof_photo_recovery.dart](../../apps/delivery/lib/delivery/proof_photo_recovery.dart)

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

**Current implementation snapshot:** EmployeeAuthProvider hides non-owned projection, renews session/profile reads, clears approval on owner binding and revokes old auth commands, including later auth events for the same UID. Employee app gate requires role plus approval. PayoutAccountScreen captures payload and awaits requestEmployeePayoutChange/cancelEmployeePayoutChange but inspected feedback/finally checks mounted only. Its optional employeeUid/current UID determines displayed streams; no explicit auth epoch/route ticket is captured in these handlers. This is a presentation review gap, not proof a server permits editing someone else’s payout destination. No sensitive payout disk-draft persistence is evidenced here.

**Target:** Separate identity/account transitions from associate access and payout review. Hide previous associate settings immediately. Old request replies cannot show Submitted/Cancelled under a new session; reopen only current authorised payout settings and read actual request state before any repeat mutation. Do not transfer sensitive unsubmitted payout input between accounts.

**Domain design:** Premium royal-blue account transitions, indigo review-outcome guidance, pearl/slate payout-settings placeholders and restrained readable notices.

| Panel | Specimen |
| --- | --- |
| Associate account transition | Card "Updating associate account", indeterminate spinner and "Checking the current associate account." Empty settings-row skeletons. Indigo BOARD notes "Previous associate details hidden" and "Review access before opening workspace". No code, jurisdiction, commission or payout value. |
| Sign-in required | Card "Sign in as an associate", lock icon and "Sign in again. Associate access will be checked before continuing." royal-blue PRIMARY "Sign in again". Indigo BOARD annotation "Confirmed session end / approval remains separate". No fee, earnings promise or automatic workspace activation. |
| Late review boundary | Neutral card "Current payout settings", EMPTY setting-row skeletons, no bank/UPI/account values. Indigo BOARD diagram "Earlier review-request reply" arrow crossed at "Not applied to this account view". Note "No old-session Submitted or Cancelled notice" and "Request outcome is checked separately". No Approved/paid badge or repeat submit. |
| Current settings recovery | Card "Open current payout settings", body "View settings for the signed-in associate." PRIMARY "View payout settings", small "Read and navigation recovery" caption. Indigo BOARD note "Check request state before another submission". No request-created/approved/cancelled badge, stored draft, bank detail, monetary value or Submit again control. |

Gaps and preserved boundaries:

- Extend mounted checks with current associate, auth episode, intended payout entity and route before feedback or navigation.
- Submitting changes is not approval, settlement or payment; C18 pending-review gate remains separate.
- Unknown request outcome must be read before repeat submit/cancel; no automatic resubmission after sign-in.
- Discard sensitive input on account change under a deliberate policy; do not invent encrypted disk recovery or Save draft guarantees.
- Optional employeeUid preview/deep-link context never overrides caller authorization; validate current permitted record before showing settings.

Source anchors:

- [auth_provider.dart](../../apps/employee/lib/providers/auth_provider.dart)
- [app.dart](../../apps/employee/lib/app/app.dart)
- [payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart)
- [payout_request_screen.dart](../../apps/employee/lib/screens/wallet/payout_request_screen.dart)

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

**Current implementation snapshot:** AdminAuthProvider owns user projection/profile reads and exposes sessionVersion/isSessionCurrent; owner binding clears user/error and renews read/epoch. Settings logout captures provider identity, owner, epoch and current route before confirmation, dispatch and navigation; account credential form also owns its opening session. SupportCaseDetailScreen._call captures no explicit auth episode/route/case ticket: success/error, activity refresh and busy cleanup are gated by mounted. CurrentUID is captured for page context. Backend still authenticates callable permissions; mounted-only UI feedback is not proof of unauthorized server writes.

**Target:** Keep existing settings ownership as a model, extend support action feedback to current admin session and current case. Hide old operator context during role checks. A late case response cannot notify or refresh a replacement case; reload only the current authorised case and reconcile original action outcome before another mutation.

**Domain design:** Professional-blue administrator rebinding, cyan permission context, steel/slate case placeholders and precise read-versus-mutation controls.

| Panel | Specimen |
| --- | --- |
| Admin account transition | Card "Updating admin account", indeterminate spinner and "Checking the current account and admin role." Empty operational-row skeletons. Cyan BOARD note "Hide previous operator context" and "Access checked before case data". No name, case ID, role-approved badge or dashboard metrics. |
| Sign-in required | Card "Sign in to admin", lock icon, body "Sign in again. Admin access will be checked before continuing." professional-blue PRIMARY "Sign in again". Cyan BOARD note "Confirmed session end / not a failed access read". No invitation, approval queue, MFA, phone values or self-approval. |
| Late case boundary | Neutral card "Current case view", EMPTY case-row skeletons. Cyan BOARD diagram "Earlier case-action reply" arrow crossed at "Not applied to this case view". Notes "No old-session success notice" and "Server action may already have finished". No Case resolved, note content, assignee, old account or retry-action control. |
| Current case recovery | Card "Reload current case", body "Read the current case after admin access is confirmed." PRIMARY "Reload case", caption "Proposed read recovery". Cyan BOARD note "Read only / verify the earlier action separately". No Repeat action, resolve case, approve role, delete record, promised rollback or server-success tick. |

Gaps and preserved boundaries:

- Mounted alone does not establish current admin/case/route after account replacement; use sessionVersion and route/entity ticket.
- Suppress obsolete dialog results before dispatch as well as obsolete post-call results; action confirmation does not survive owner change.
- Settings logout already verifies current session and route; preserve that implementation rather than duplicate a generic helper.
- Case reload is a read; no retry mutation, role assignment, case resolution or success from old result.
- Failed role/profile read remains separate from confirmed session loss. No admin self-unlock or fabricated expired-session timer.

Source anchors:

- [auth_provider.dart](../../apps/admin/lib/providers/auth_provider.dart)
- [admin_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart)
- [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [app_router.dart](../../apps/admin/lib/app/app_router.dart)
- [auth_service.dart](../../packages/agrimore_services/lib/auth/auth_service.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Reuse and authority

Reuse existing owned-auth/session predicates, domain operation/journal identity and canonical feedback/modal/navigation equivalents. Do not create a second auth ownership helper when an equivalent can be extended. Historical emerald-only guidance and old component/adoption counts do not override C01 locked app identities or current source. C18 access/profile/approval semantics remain applicable after restoration. No new widget, helper, auth method or package folder implementation is delivered here.

## Future implementation verification

- Account changes while each awaited read/write/provider sign-in is delayed; sign-out, A-to-B-to-A and later same-UID auth event; stream error/done and disposal; canceled listener still delivering a queued callback. Only the valid new episode publishes data/loading/error.
- Route replaced while old dialog is open, entity changed within a still-mounted page, query changed, app background/resume, duplicate navigation taps. Stale dialog consent cannot initiate a mutation; old response cannot close/pop a new modal, show feedback or clear a newer spinner.
- Confirmed token/session expiry versus ordinary network outage, profile-read error, recent-login challenge, disabled account and approval restriction. Preserve supported sign-in methods and C18 access checks; no privileged-content flash.
- Marketplace: gateway callback after owner change; receipt read/acknowledgement; edited cart; original journal remains scoped. Stage-specific recovery does not duplicate charge/order or reveal former account content. RFQ/credit projection gates and screen-level late error ownership tested separately.
- Seller: overlapping product loads, canceled order listener, stock sheet account change and same-UID reauth. Preserve caller UID guards, inspect provider disposal/recreation and add episode scope where required. Read reload never repeats mutation or claims rollback.
- Delivery: auth/approval binding ends during task step/release; gate route cleanup and location/offer drop; provider shared result versus direct caller result. No different-rider task completion. Proof recovery is verified against original order/assignment, not assumed owner field or automatic resume.
- Associate: payout submit/cancel while signing out or viewing another permitted record; no stale Submitted/Cancelled/Paid notice, bank input or busy state. Current settings read cannot become automatic resubmission or approval.
- Admin: preserve owned settings logout/form flow; case action reply after admin/case/route change. No stale toast/tick/pop or role promotion; read current case only after actual admin access.
- Interrupted/lost mutation reply may already be committed. Verify action-specific request identity/status before replay. Ignoring UI callback is not a server cancellation protocol.
- Render all five apps light/dark, narrow/wide, keyboard/large text, reduced motion and actual TalkBack/VoiceOver transition announcements/focus. Raster proposals do not prove accessible or race-safe runtime behavior.
- Runtime source changes later require targeted meaningful tests and applicable app analyzers/emulator authorization checks. No live account, OTP, Firebase write, Flutter runtime/analyzer, emulator or security/accessibility certification occurred for these assets.

## Delivery scope and design review

27 new files: ten PNGs, five per-app README/prompts/manifest sets and two master documents. C01–C18 remain preserved. C19 is provisional, not owner-approved. User-requested exact image prompts are asset provenance, not exported implementation-worker prompts. Classifier: docs; voluntary UIUX/feedback design review covered identity consistency, current versus proposed scope, session-state wording, late-result/server-outcome boundaries, supported recovery and dark surfaces.

This task changes only design assets/docs; no runtime/auth/backend/pubspec/branch/index/commit/deployment work or other-chat interruption. Concurrent shared-checkout implementation is observed and preserved rather than reverted. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/providers/address_provider.dart, apps/marketplace/lib/providers/wishlist_provider.dart, packages/agrimore_services/lib/database/database_service.dart.

## Artifact verification evidence

The first post-packaging asset validation passed: 10 valid PNGs in 5 light/dark pairs, 27 declared new files, 10 exact generation prompts with input/output hashes, 86 local document links and all 837 earlier design files preserved byte-for-byte. Selected images were copied unchanged from built-in image_gen outputs; all ten were visually reviewed and no refinement was required. PNG dimensions/chunk CRCs, selected-source hashes and all C01 APPROVED_LOCKED references/token metadata were checked. Raster measurements, accessibility and race-safe runtime behavior are not certified by these checks.

Static inventory: 818 eligible source files / 271,801 lines at `785d7b91391079cc9fdb4cc275ae8caf2a64c934`. The first post-packaging check observed HEAD `066981a885caffbb917c102ef4d14de9fb64c9dc` on `agrimore/foundation-f3c-distance-delivery-pricing`. Concurrent source changes relative to inventory: `apps/marketplace/lib/providers/address_provider.dart`, `apps/marketplace/lib/providers/wishlist_provider.dart`, `packages/agrimore_services/lib/database/database_service.dart`. Additional source changes relative to the packaging baseline at this check: none in this snapshot. Platform configuration changes relative to inventory: none in this snapshot. These are measured snapshots of a shared checkout, not an assertion that other implementation work stopped. This task preserved that work and wrote only its declared design assets/docs.

C19 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION. C01–C18 remain preserved. Domain map distinguishes existing ownership checks, mitigating route/provider lifetimes and proposed gaps without claiming a verified cross-account exploit. No runtime auth/domain mutation/backend implementation, live calls, deployment, branch/index/commit action or other-chat interruption by this task.
