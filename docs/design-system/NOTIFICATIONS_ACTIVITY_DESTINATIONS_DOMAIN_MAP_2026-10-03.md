# Agrimore — C21 notifications, activity and destinations: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C21 is not owner-approved; this deliverable is assets/docs only.

[Ten-board gallery](NOTIFICATIONS_ACTIVITY_DESTINATIONS_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: 066981a885caffbb917c102ef4d14de9fb64c9dc. 818 eligible files / 272064 source lines across five app lib trees, three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files were excluded. Files were indexed/hashed and searched for read state, mark-read actions, timestamp fields, destinations, push taps and activity history. Focused semantic reads covered all four personal inboxes and badge queries, Delivery typed models/targets/grouping/source, Marketplace FCM tap handlers, Seller parser/formatting, Associate app unknown-route gate, Admin sender/history/case activity, shared notification service/model, notification writers and owner read-field rules. This is broad static inventory plus focused review, not semantic certification of every line or rendered screen.

Marker totals include comments/call sites and other domain timestamps, not unique notification components or defect counts. All five apps do not consume the shared NotificationModel: inspected inboxes have local map/model conventions. A matching route string does not prove the app implements that destination. Shared-checkout implementation may advance source or HEAD during this design task. Rules were read as context, not tested or security-certified.

| Scope | read_state | mark_read | timestamp | destination | push_tap | activity |
| --- | --- | --- | --- | --- | --- | --- |
| admin | 0 | 0 | 153 | 25 | 0 | 12 |
| delivery | 46 | 12 | 84 | 29 | 0 | 1 |
| employee | 8 | 2 | 37 | 2 | 0 | 0 |
| marketplace | 6 | 0 | 118 | 1 | 4 | 3 |
| seller | 27 | 8 | 94 | 15 | 0 | 5 |
| functions | 6 | 0 | 133 | 30 | 0 | 9 |
| agrimore_core | 10 | 0 | 314 | 10 | 0 | 0 |
| agrimore_services | 2 | 0 | 40 | 29 | 6 | 0 |
| agrimore_ui | 0 | 0 | 1 | 0 | 0 | 0 |

## Shared target notification contract

1. Read/unread is notification attention state, not order approval, payment settlement, task completion, deletion or recipient delivery proof.
2. Normalize documented writer schemas deliberately across unread/read/legacy isRead and existing title/body/message/actionUrl locations. Badge/query interpretation must match rows; owner rules permit only approved read fields.
3. Unknown badge/read load is not zero/caught up. Bound/capped counts need honest saturation; operation scope must say loaded, query snapshot or whole supported domain.
4. Mark-read has pending, acknowledged and failed/partial states; guard duplicate taps and keep notice readable. Announce confirmed read status only after the supported write completes; pending local projection is not server acknowledgement.
5. Reading/opening a notice and destination navigation are separate outcomes. Mark-read failure cannot fabricate navigation failure or business failure; destination failure cannot fabricate unread restoration.
6. Mark-all scope must be real: Seller loaded slice differs from Delivery server query and Associate read==false legacy compatibility. New notices during the action remain separate; partial batch completion is recoverable.
7. Show timestamps only from valid source fields with defined timezone and meaning. Missing/null/invalid/pending/future values cannot become Just now/Today. Event time, recorded time, transport time and readAt are distinct.
8. Board timestamp examples are fixed synthetic format specimens, not live events. Relative age requires actual valid time and clock; include an absolute accessible alternative for future implementation.
9. Payload links are untrusted routing hints, not access grants. Allowlist by app/role, validate identifiers, reread current authorised entity and preserve account/session/entity/route ownership from C19.
10. Missing/deleted/reassigned/forbidden/unsupported target and network-read failure require distinct safe explanations/actions. Domain legacy fallbacks must be evidenced; do not guess latest record.
11. Deduplicate foreground/local push/background/cold-start/inbox routing and wait for current navigator/auth/access readiness without indefinite old-session navigation.
12. Admin outbound history/case events have no personal unread state or recipient read receipts here. Recipient previews are clearly labelled, and push transport success is not observed/read delivery.
13. Reuse existing inbox models, formatters, typed destinations, auth predicates and feedback/navigation equivalents; no generic handler that weakens access or invents an app route.
14. Accessible labels express unread/read beyond color, comfortable full-row targets and labelled mark-read actions; preserve focus/list position and support text scaling/reduced motion. Runtime AT/contrast/routing verification remains future work.

## Five domain systems

| App | Unread / attention source | Time and read operation | Destination boundary |
| --- | --- | --- | --- |
| Marketplace | unread==true from fetched inbox; local list count | Timestamp only; no inbox row mark-read currently | Separate push handlers route order/product/offer; inbox row destination is proposed |
| Seller | InboxEntry normalizes unread/read/isRead, badge query unread only capped100 | IST grouping plus SellerFormat dateTime; loaded-slice mark-all; individual failure log-only | Exact relative order/rfq/payout parser; missing loaded order goes Orders; unknown no target |
| Delivery | Typed RiderNotice, unread/read; badge saturated at50; semantic dot | Local grouping/time; mark-all queries unread beyond displayed slice and chunks writes | Fresh by-ID delivery/statement reads; exact support/bank/identity/document/incident paths and specific legacy fallback |
| Sales Associate | Rows read!=true unread; bell/bulk query read==false excludes missing fields | Date-only formatter; tapped write not awaited; bulk lacks busy guard | Row does not navigate; shared named route falls to app AuthGate, not exact record detail |
| Admin | Outbound history and case activity have no personal unread state | notification_history timestamp/sentAt; support_case_events at; no read operation for these journals | Typed destination preview proposed; no recipient read receipt or working external opener asserted |

## Read schema and action scope

| Observed convention | Current inconsistency | Target requirement |
| --- | --- | --- |
| unread=true writers | Marketplace/Seller/Delivery queries recognize it; Associate read==false query misses absent read field | Choose compatible row/query model and migration strategy; do not simply flip every legacy field |
| read=true / false readers | Associate rows regard absent read as unread but query needs explicit false | Row, presence badge and mark-all eligible query must agree |
| Legacy isRead | Seller normalizes it; shared NotificationModel reads only isRead; owner rules do not permit changing it | Normalize reads deliberately; write only permitted unread/read/readAt without weakening rules |
| Marketplace local fetched list | No read mutation or row destination; read failure can show caught-up empty | Add explicit failure, owner generation, acknowledged read feedback and typed row routing |
| Seller Mark all read | Loaded newest100 entries only; not whole historical inbox | Show Mark shown as read until actual wider query exists; no hidden older inbox guarantee |
| Delivery Mark all read | Queries unread entries beyond newest50, chunks400 writes | Success for operation snapshot only; recover partial write failure and later-arriving notices separately |
| Associate Mark all read | Queries read==false then one batch; no action busy guard in inspected code | Resolve legacy compatibility/scalability and add duplicate guard/partial failure/owner feedback |
| Tap marking and open | Seller/Delivery start read mark separately from destination; Associate only marking | State the policy explicitly; read state and navigation success are independent outcomes |
| Admin history and activity | No unread semantics; transport result may be logged in more than one path | Keep append-only activity/history separate from recipient preview and personal read controls |

## Timestamp policy and specimens

All displayed dates on these boards are fixed synthetic format examples, not real notification events. The examples deliberately have no names, identifiers, balances, counts or live age. Unread/read and confirmed/failed examples are independent Storybook states, not real operations performed by this task.

| App | Observed formatter/source | C21 illustration / proposed rule |
| --- | --- | --- |
| Marketplace | Raw day/month/year hour:minute from createdAt Timestamp; no explicit timezone policy in method | 18 Sep 2026 · 09:40 labelled Format example; unknown Time unavailable; canonical formatted hierarchy proposed |
| Seller | SellerFormat dateTime d MMM y, h:mm a; grouping via IST day key | 18 Sep 2026, 9:40 AM; valid timestamp only; align display/group timezone in implementation |
| Delivery | DeliveryFormat dateTime plus toLocal; missing grouping falls Earlier | 18 Sep 2026, 9:40 AM; Time unavailable when absent; avoid presenting missing date as proven older |
| Sales Associate | SaFormatters d MMM yyyy without clock time | 18 Sep 2026 date only; Date unavailable when absent; no invented clock time |
| Admin | History relative age from timestamp/sentAt; case at displayed as date | 18 Sep 2026 · 09:40 absolute example proposed; authoritative event time distinct from receipt; invalid/future/pending values explicit |

Current createdAt, recordedAt, sentAt, client ISO-createdAt, readAt and support event at have distinct meaning. Arrival/event time must not be replaced by current device time. Relative labels need a valid timestamp, appropriate timezone, clock refresh and an accessible absolute alternative. Pending server timestamps, future skew and ordering of missing fields require real data tests. No date shown here certifies freshness or receipt.

## Destination handling

| Condition | UI target | Authority / operation boundary |
| --- | --- | --- |
| Known destination and valid entity | Label appropriate View order / View quote / typed detail | Current account/role/access and actual record, not payload title/body |
| Record deleted, reassigned or inaccessible | Readable unavailable explanation and safe inbox/list return | No guessed latest record or exposed foreign context |
| Read failed while resolving target | Keep notice and offer domain read recovery | Do not call missing/forbidden when network result is unknown |
| Legacy missing identifiers | Only evidenced domain fallback | Delivery old bank Earnings and document current view differ from unsupported identity/incident target |
| Unknown type/link or unsupported role route | Readable notice, no false action affordance | App-specific allowlist; not generic pushNamed success |
| Notification clicked before auth/navigator ready | Deferred current-session route with deduplication | No stale queued tap across account change or infinite retry loop |
| Tap marks notice but detail cannot open | Separate read status and target error | Read does not imply task/order/payment success or erase notice |
| External link | Only explicit supported safe capability | Shared external branch currently logs/returns; no working browser launch is claimed |
| Admin typed preview before send | Review role-capable destination without sending | Preview is proposed; no live broadcast, recipient receipt or grant of access |
| Read confirmation | Announce only acknowledged operation scope | No All caught up if query is bounded, partial, legacy-incompatible or new notices arrive |

## Verified gaps and preserved implementation

| Area | Current evidence | Target / limitation |
| --- | --- | --- |
| Marketplace inbox | One-shot get; no row onTap/write; catch only clears loading; setState not episode guarded | Canonical rows/error state and owner-scoped update/routing are proposals; preserve separate push fallback paths |
| Read schema | Writers use unread and legacy isRead; Associate reader/query read convention differs; shared model expects Timestamp | Deliberate compatibility/migration and null-safe parsing; no blanket shared-model substitution |
| Seller scope/parser | markAllRead(all) receives bounded list; InboxLink parses exact two relative path parts; individual write error log-only | Truthful shown-scope label; per-row failure/busy; consistent allowed slash normalization |
| Delivery existing strengths | Typed IDs/type icons, All/Unread, local grouping, broader mark query, busy guard and acknowledgement feedback | Retain existing source/targets; add partial outcome/owner checks and truthful missing-time presentation |
| Delivery destinations | Delivery/statement loaded by supplied ID; failures/unavailable handled; known domain-specific legacy fallback | Payload is not authorization; existing mounted checks and gate lifecycle do not replace explicit C19 ticket verification |
| Associate lists/actions | Rows read!=true, badge/bulk query read==false, tap fire-and-forget, raw-error surfaces | Fix query/schema mismatch and human-readable acknowledged update; no invented exact destination |
| Associate route fallback | navigatorKey wired; no named detail route table; onUnknownRoute returns AuthGate | Safe auth-shell fallback is not the intended record; typed app destinations are target work |
| Admin history/activity | Sender/history console, case event list; backend/client history fields differ; transport counters displayed | No personal inbox/read receipts; consolidate provenance/logging before complete/delivered claims |
| Shared navigation | actionUrl generic routing and delayed retries; external URL branch logs/returns | Reuse allowed route capabilities but scope/deduplicate by current session; no blanket external link guarantee |
| Owner rules | Owners can update only unread/read/readAt for notification docs | Keep content immutable for recipient; no weakening permissions to accommodate legacy isRead write |

## Agrimore Marketplace

**Current implementation snapshot:** Inbox does a one-shot users/uid/notifications get ordered by createdAt; unread requires unread==true, time renders only a Timestamp. Rows have no mark-read or destination handler. Fetch error only clears loading, which can show the empty/caught-up state; inspected fetch setState lacks mounted/session-generation guards. Separate FCM tap code routes typed order/product/offer and safe missing-ID lists/main; shared local tap handling uses actionUrl. These push handlers are not the inbox row implementation.

**Target:** Add explicit readable unread/read row variants, provenance-aware time, owner-scoped mark-read feedback and safe inbox destination handling. Proposed row navigation can use existing order routes after current access/entity checks; a notification is not an authoritative order/payment result.

**Domain design:** Professional-green shopper notice rows, warm-gold timestamp/destination guidance, natural-stone surfaces and generous calm notification spacing.

| Panel | Specimen |
| --- | --- |
| Shopper notice hierarchy | Two synthetic notice rows titled "Order update", EMPTY muted body skeletons: first bold with green dot and explicit "Unread" label, second normal weight with "Read" label and no dot. No outcome, ID, count, money or record status. Gold BOARD note "Unread is not an order status". No navigation sidebar. |
| Notice time provenance | Card "Notification time", clock icon, exact fixed FORMAT EXAMPLE "18 Sep 2026 · 09:40"; second smaller row "Time unavailable". Gold BOARD notes "Format example / not live activity" and "Missing time is not Just now". No age/countdown/Today tag. |
| Proposed mark-read feedback | Three separate SMALL feedback specimens labelled "Updating", "Confirmed", "Failed": Updating has indeterminate spinner and DISABLED neutral "Marking as read…"; Confirmed has readable inline "Marked as read"; Failed has "Could not update read status" and SECONDARY "Try again". Gold BOARD annotation "Proposed / confirmation after write succeeds". Read status alone is confirmed, no order/payment success. |
| Order destination handling | Card "Open related order", outline order icon, EMPTY record context skeleton, PRIMARY "View order". Gold BOARD notes "Proposed inbox destination" and "Check current account and order access". Smaller muted line "Missing link: open Orders". No raw URL, order ID, completed order or claim payload grants access. |

Gaps and preserved boundaries:

- Keep error separate from caught up; unknown count is not zero. One-shot local list count is not a live global unread total.
- Inbox mark-read and row destinations are target implementation, not existing features. Do not confuse working push tap code with working inbox rows.
- Normalize writer/read conventions deliberately; Firestore owner updates permit unread/read/readAt, not arbitrary isRead mutations.
- Keep safe missing-order/product ID fallbacks and add typed routing/deduplication across foreground, background, cold start and inbox; no indefinite delayed navigation across auth changes.
- Proposed date format improves existing raw numeric date/time; no missing timestamp becomes Just now/Today.

Source anchors:

- [notifications_screen.dart](../../apps/marketplace/lib/screens/user/notifications/notifications_screen.dart)
- [main.dart](../../apps/marketplace/lib/main.dart)
- [routes.dart](../../apps/marketplace/lib/app/routes.dart)
- [notification_service.dart](../../packages/agrimore_services/lib/notifications/notification_service.dart)
- [notification_model.dart](../../packages/agrimore_core/lib/models/notification_model.dart)
- [orderNotifications.ts](../../functions/src/customer/orderNotifications.ts)
- [firestore.rules](../../firestore.rules)

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

**Current implementation snapshot:** Seller inbox normalizes unread/read/isRead legacy variants in InboxEntry, groups by IST calendar day and renders SellerFormat.dateTime. Bell queries unread==true capped at 100, while inbox rows normalize more conventions. Loaded list capped at 100; mark-all batches loaded unread entries, not full unseen inbox. Individual markRead catches/logs failure only; bulk failure uses action banner, no busy guard in inspected method. Tap marks read without awaiting and opens existing order if loaded else Orders tab, RFQ by ID, or Payments tab; InboxLink exact two-segment parser accepts order/rfq/payout only without leading slash normalization.

**Target:** Keep category/row hierarchy and current navigation, add explicit individual/bulk operation feedback and truthful Mark shown as read scope until backend-wide action exists. Unknown/legacy payload gets a safe non-actionable notice rather than a guessed record; current merchant/entity access still required.

**Domain design:** Compact blue-teal merchant inbox rows, copper chronology/read-scope annotations, cool-neutral grouped records and precise order/quote destinations.

| Panel | Specimen |
| --- | --- |
| Merchant unread and read | Two synthetic rows titled "Quote update", EMPTY body skeletons, quote outline icons. First has teal dot, bold title and explicit "Unread"; second normal "Read", no dot. Small nonnumeric category chips "Orders" and "Quotes", no counts. Copper BOARD note "Read state does not delete the notice". |
| Merchant notice timestamps | Card "Notice time", exact fixed FORMAT EXAMPLE "18 Sep 2026, 9:40 AM", secondary "Time unavailable". Copper BOARD notes "Format example / not live activity" and "Group only from a valid timestamp". No fabricated Today label, age or live clock. |
| Loaded-scope read feedback | Three SMALL independent read-state feedback specimens: DISABLED neutral "Marking shown as read…" with indeterminate spinner; inline confirmation "Shown notices marked as read"; failure "Could not update read status" and SECONDARY "Try again". Copper BOARD annotation "Loaded notices only / confirm after write". No All caught up, cleared count or hidden older notices assertion. |
| Order and quote destinations | Card "Related quote", outline quote icon and EMPTY record context, PRIMARY "View quote". Copper BOARD notes "Known quote link only" and "Missing order: open Orders". Small muted "Unknown link: keep notice readable". No quote ID, order value, offer accepted or read-receipt claim. |

Gaps and preserved boundaries:

- Badge query and normalized legacy row interpretation can disagree; unify deliberately before claiming precise unread totals.
- Existing mark-all is limited to loaded entries; label the displayed scope or implement an explicitly tested whole-inbox operation.
- Individual read failure is currently log-only; propose visible retry and busy guard, not false success. Read marking does not delete row.
- IST Today grouping and dateTime local display need consistent timezone policy, midnight tests and invalid/future timestamps. Missing timestamp is not inferred current.
- Parser two-segment relative links can disagree with leading-slash payloads; map only allowed destinations, no generic external launcher.

Source anchors:

- [inbox_rules.dart](../../apps/seller/lib/screens/notifications/inbox_rules.dart)
- [notifications_screen.dart](../../apps/seller/lib/screens/notifications/notifications_screen.dart)
- [home_stats.dart](../../apps/seller/lib/screens/home/home_stats.dart)
- [seller_format.dart](../../apps/seller/lib/design_system/format/seller_format.dart)
- [seller_rfq_detail_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart)
- [orderNotifications.ts](../../functions/src/customer/orderNotifications.ts)

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

**Current implementation snapshot:** RiderNotice parses explicit known notice types and identifiers; inbox has unread semantic dot, type icons, All/Unread filters and local Today/Earlier grouping from valid createdAt (missing time -> Earlier). latest stream capped at 50; unreadCount capped at 50 with saturation text. markAllRead queries unread true beyond displayed slice then writes chunked batches; duplicate-tap busy guard and success/error toast after operation await. Single mark failure visible, row tap starts markRead separately from navigation. Delivery/statement destinations are loaded by ID before navigation; failed load stays inbox with error, missing entity unavailable. Specific support/bank/identity/document/incident destination routes preserve their supplied IDs. Known legacy document/bank fallbacks differ from missing incident/identity IDs.

**Target:** Preserve real per-type destinations and full-query mark-read behavior. Show field-readable unread/read, valid local time versus missing time, busy/confirmed/failure read feedback and a destination unavailable state. Reading a delivery notice never accepts an offer, advances a step or proves delivery completed.

**Domain design:** High-contrast black/white rider inbox, burgundy attention markers, burnt-orange destination/time guidance and large comfortable field controls.

| Panel | Specimen |
| --- | --- |
| Rider notice hierarchy | Two synthetic notice rows titled "Delivery update", package outline icons and EMPTY body skeletons. First bold plus burgundy dot and explicit "Unread", second normal "Read" no dot. Compact nonnumeric chips "All" and "Unread". Orange BOARD note "Reading does not advance a task". No task ID, assignment count or delivery-completed icon. |
| Local notice time | Card "Notice time", exact fixed FORMAT EXAMPLE "18 Sep 2026, 9:40 AM"; smaller "Time unavailable". Orange BOARD notes "Format example / not live activity" and "Use local date only when known". No ETA, countdown or guessed Today section. |
| Inbox read feedback | Three SMALL independent states: DISABLED neutral "Marking as read…" and indeterminate spinner; confirmed inline "Read status updated"; failed "Could not finish updating read status" with SECONDARY "Try again". Orange BOARD note "Query scope / partial failure stays recoverable". No emptied inbox, count, deleted notice or universal all-caught-up claim. |
| Delivery destination recovery | Card "Delivery unavailable", outline package icon, body "This delivery cannot be opened right now." PRIMARY "Back to inbox", black light / off-white with dark text dark. Orange BOARD notes "Recheck current access and record" and "No task action from a notice". No accept offer, start route, proof replay, Delivered tick or raw ID. |

Gaps and preserved boundaries:

- Capped unread badge is saturated, not exact global count; failures/loading are not zero. Mark-all query is a snapshot, not a guarantee notices arriving later are already read.
- Chunked batches can partially commit before failure; show incomplete update and refresh/reconcile rather than roll back all or claim all success.
- Destination payload is not authority; current auth, rider binding, current entity and permissions must still be checked after awaits as C19.
- Legacy fallback is domain-specific: document current view and old bank Earnings are evidenced; no guessed incident or identity record.
- Missing timestamp grouped Earlier today is current source behavior, but target missing-time explanation should not certify it predates today.

Source anchors:

- [rider_inbox.dart](../../apps/delivery/lib/inbox/rider_inbox.dart)
- [inbox_screen.dart](../../apps/delivery/lib/screens/inbox/inbox_screen.dart)
- [delivery_shell.dart](../../apps/delivery/lib/app/delivery_shell.dart)
- [delivery_format.dart](../../apps/delivery/lib/design_system/format/delivery_format.dart)
- [riderNotices.ts](../../functions/src/delivery/riderNotices.ts)

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

**Current implementation snapshot:** Associate inbox streams latest 50 rows, treats only read==true as read, otherwise unread. Individual tap updates read:true without awaited error feedback or row navigation. Mark-all queries read==false, commits batch, shows success or raw-error snackbar; no duplicate-tap guard in inspected StatelessWidget action. Bell queries read==false limit1 for presence, which omits missing-read rows that inbox considers unread. Display date uses SaFormatters.formatDate without time. Shared notification initialization has named routing but app has no named detail route map; onUnknownRoute returns AuthGate, so exact push notice destinations are not implemented merely by wiring navigatorKey.

**Target:** Use explicit unread/read and date-only provenance, normalize legacy fields/badge query deliberately, add safe mark-read feedback with owner/route guards, and propose typed read-only destinations. Missing/unsupported related activity retains notice and offers Back to notifications; do not pretend shared pushNamed already opens a payout/order detail.

**Domain design:** Premium royal-blue associate notice rows, indigo read-status/time provenance guidance, pearl/slate surfaces and restrained attributed-activity navigation.

| Panel | Specimen |
| --- | --- |
| Associate unread and read | Two synthetic rows titled "Attributed order update", bell outline icons and EMPTY body skeletons. First royal-blue dot, bold title and explicit "Unread"; second normal "Read" with no dot. Indigo BOARD note "Read state is not payout status". No earnings, balance, account value or count. |
| Date-only notice hierarchy | Card "Notice date", exact fixed FORMAT EXAMPLE "18 Sep 2026"; secondary "Date unavailable". Indigo BOARD notes "Date-only format example" and "Do not invent a time". No clock time, age, Today, approval timer or payout date promise. |
| Proposed read-status feedback | Three SMALL independent states: DISABLED neutral "Marking as read…" and indeterminate spinner; confirmed inline "Marked as read"; failure "Could not update read status" with SECONDARY "Try again". Indigo BOARD note "Proposed guard / confirm after write". No Paid/settled/approved badge, erased list or all-history guarantee. |
| Related activity fallback | Card "Related activity unavailable", body "The related record cannot be opened from this notice." PRIMARY "Back to notifications". Indigo BOARD notes "Typed destinations proposed" and "Keep the notice readable". No View payout button implying implemented direct navigation, raw URL, record ID or fallback approval. |

Gaps and preserved boundaries:

- Read==false query excludes missing-read docs even though inbox displays them unread; no precise count/caught-up claim until schema/query compatibility is fixed.
- Mark-all unbounded read==false batch needs scalability, operation snapshot and partial failure policy; no generic all-history success from loaded list or bad query.
- Single tap has no visible write failure; propose guarded feedback. Raw errors in list/bulk action need human-readable sentences.
- Current formatter supplies date only; do not fabricate a clock time or substitute now when createdAt is absent.
- Exact named detail destinations need app-specific allowlisted routing; AuthGate fallback protects shell access but does not prove the intended record opened.

Source anchors:

- [notifications_screen.dart](../../apps/employee/lib/screens/notifications/notifications_screen.dart)
- [dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)
- [sa_formatters.dart](../../apps/employee/lib/utils/sa_formatters.dart)
- [app.dart](../../apps/employee/lib/app/app.dart)
- [main.dart](../../apps/employee/lib/main.dart)
- [notification_service.dart](../../packages/agrimore_services/lib/notifications/notification_service.dart)

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

**Current implementation snapshot:** Admin /notifications routes to SendNotificationScreen: compose/order notification/history tabs, not a personal inbox. History streams notification_history ordered timestamp capped50; client logs after callable with server timestamp plus ISO client createdAt, catches history-log failure, and backend also logs sentAt/results. Fields/provenance differ; query timestamp may exclude sentAt-only rows. Current formatter uses relative age; future/missing times need handling. Support case activity is paginated append-only support_case_events ordered at with actor/date, not unread records. Callable successCount/failureCount are push transport outcomes, not viewed/read/record-business outcome. actionUrl accepts strings/internal normalization; shared external branch logs and returns rather than opening a browser.

**Target:** Design Admin around outbound history and case activity, timestamp provenance, a clearly labelled recipient-state preview and safe destination review. Do not add Mark all read to the sending console or show recipients Read/Delivered from push success. Preview unread/read demonstrates recipient styling only; no real receipt or new admin personal inbox is asserted.

**Domain design:** Professional-blue notification operations/history, cyan destination preview guidance, steel/slate immutable activity rows and restrained operational provenance labels.

| Panel | Specimen |
| --- | --- |
| Outbound and case activity | Card "Notification history" with generic row "Notification record", outline history icon, EMPTY body skeletons and small type chip "General"; second slim row "Case activity" with EMPTY skeleton. Cyan BOARD notes "Outbound history / not a personal inbox" and "Activity entries are not mark-read controls". No unread badge on outbound record, sent/delivered/read recipient receipt or metrics. |
| Operational timestamp provenance | Card "Recorded time", exact fixed FORMAT EXAMPLE "18 Sep 2026 · 09:40"; secondary "Time unavailable". Cyan BOARD notes "Format example / use authoritative event time" and "History time is not a read receipt". No relative age, Just now, created success or invented operator. |
| Recipient state preview | CLEAR heading "Recipient preview only". Two compact synthetic preview rows "Notification" with EMPTY body skeleton: one blue dot, bold "Unread"; one normal "Read" and no dot. Cyan BOARD annotation "Styling preview / no recipient receipt". NO Mark all read, success tick, read statistics or claim admin observes actual recipient reads. |
| Destination review | Card "Review notification destination", outline link icon, neutral destination descriptor "Order details", PRIMARY "Review destination". Cyan BOARD notes "Proposed typed preview" and "Verify role, record and access before sending". No actual Send/Broadcast control, raw URL, target ID, user identity or external-launch guarantee. |

Gaps and preserved boundaries:

- Do not apply user inbox mark-read behavior to immutable support activity or outbound notification history.
- Transport accepted/success count is not recipient device display, human read or business success. History row existence does not prove all recipients received it.
- Client history logging can fail after send outcome; backend/client logging paths need consolidation/deduplication and consistent timestamp query before complete-history claims.
- Current relative age formatter can classify future values Just now; target explicit absolute-time provenance and missing-time treatment avoids invented urgency.
- Typed role-capable destination review is proposed; formatted actionUrl and dormant external logging branch do not guarantee a safe working destination.

Source anchors:

- [send_notification_screen.dart](../../apps/admin/lib/screens/admin/notifications/send_notification_screen.dart)
- [app_router.dart](../../apps/admin/lib/app/app_router.dart)
- [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [notifications.ts](../../functions/src/admin/notifications.ts)
- [notification_service.dart](../../packages/agrimore_services/lib/notifications/notification_service.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Reuse and authority

Reuse domain inbox models, type icons, formatters, source interfaces, current app routes, auth predicates and canonical feedback equivalents. C01 locked colors/type/spacing/radii override historical emerald-only notes. C16 feedback, C18 access, C19 session ownership and C20 freshness remain separate applicable foundations. No new widget, shared notification manager, field migration, route map or runtime implementation is delivered here. Exact requested image prompts are asset provenance, not exported implementation-worker prompts.

## Future implementation verification

- Fixtures for unread/read/isRead present, absent, conflicting and malformed; actual writer payloads; null/pending/invalid/future timestamps. Row, bell, filter and mark operation eligible query agree and content remains immutable under owner rules.
- Bounded counters, loading/errors, saturated badges, new notices arriving during mark-all, loaded-only scope and historical notices outside first slice. Unknown is not zero/caught up; partial batch failure retains truthful state and recoverable retry.
- Busy duplicate taps, per-row update failure, pending offline write/acknowledgement, delayed stream metadata, success announcement after actual acknowledgement. Confirmed read is not record success/deletion; preserve list position/focus.
- Local/IST midnight, timezone/DST where applicable, large and future clock skew, relative label refresh/absolute accessible alternative, absent date grouping and timestamp source meaning. No missing date becomes Just now.
- Cold start/background/foreground/local tap/inbox path deduplication, navigator/auth ready, signed-out/pending/restricted access, account change after queued tap and after detail await. C19 owner/episode/entity/route tickets prevent old destination/feedback in replacement session.
- Valid known route, leading/trailing slashes, encoded/malformed identifiers, unknown type, absent link, external URL, role-inappropriate route, deleted/reassigned/inaccessible entity and network failure. No blind generic route, guessed latest record or action performed from payload.
- Marketplace: actual inbox row write/routing/error versus separate FCM paths; safe missing-order/product fallback and generic source fields. Seller: legacy row/badge mismatch, capped loaded-scope mark and RFQ/payment/order fallback/parser behavior.
- Delivery: query beyond displayed slice, chunked partial update and new notices; exact delivery/statement/support/bank/identity/document/incident entity, terminal/history versus active and domain-specific legacy fallback. No offer acceptance/step/proof action by notice tap.
- Associate: missing read query mismatch, bulk scale/busy, single update feedback and route fallback. Exact attributed-order/payout destinations need app-specific implementation; AuthGate is not a record detail. No earnings/payment success from notice state.
- Admin: sender callable transport partial outcome, client history write failure after successful send, backend/client provenance and duplicated logs, timestamp versus sentAt query consistency; case events remain append-only and no fake read/delivery analytics. Preview validation never sends a real notification.
- Render all five light/dark systems at narrow/wide widths with text scaling, readable unread labels beyond color, labelled row/button targets, focus/announcements, reduced motion and real TalkBack/VoiceOver. Raster proposals do not certify contrast, accessibility, routing or security.
- Later runtime edits require targeted meaningful tests and applicable app analyzers. No live push/send, Firestore mark-read, Flutter runtime/analyzer/emulator or security/accessibility certification was performed for these design assets.

## Delivery scope and design review

27 new files: ten PNGs, five per-app README/prompts/manifest sets and two master documents. C01–C20 and existing C16 remain preserved. C21 is provisional, not owner-approved. Classifier: docs; voluntary UIUX/feedback design review covers locked identity, attention/business-state distinction, timestamp provenance, truthful update scope and app-specific destinations/preview limitations.

This task writes only its design assets/docs. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption was performed by this task. Shared-checkout implementation changes are observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset verification — first post-packaging snapshot

PASS: ten PNGs / five light–dark pairs; PNG headers, dimensions and chunk CRCs; selected-output byte hashes; eleven exact prompt blocks covering ten initial generations plus Delivery light timestamp refinement; all input/output provenance hashes; C01 APPROVED_LOCKED reference hashes and token metadata; 88 local document links; exactly 27 declared new repository files. All 891 earlier design files matched their pre-task hashes, including existing C16 and C01–C20.

Static inventory: 818 eligible source files / 272,064 lines at HEAD 066981a885caffbb917c102ef4d14de9fb64c9dc. First post-packaging check observed HEAD 3698e5df739a794d4d86d019451cc483849f2958 on branch agrimore/foundation-f3c-distance-delivery-pricing. That concurrent HEAD advance was preserved. No eligible baseline source hash changes were observed between inventory and packaging or between packaging and that check; ten inspected platform configuration hashes matched. This is a bounded observation, not a claim that the shared checkout will remain unchanged.

All ten selected outputs were reviewed through native image previews for explicit unread/read attention labels, synthetic time/missing-time hierarchy, independent read-update feedback, scope and destination limits, Admin preview-only distinction, app identity and dark inverse labels. Delivery light was refined to separate known-time and missing-time rows, then used as the dark composition reference. Illustrative confirmation applies only to read status, not a live operation or business outcome. No live notification was sent or marked read.

Verification covered assets/docs only. Exact token metadata and image integrity do not certify pixel-exact palette, runtime routing/recovery, security or accessibility. This task wrote its 27 declared files and did not stage, commit, change runtime code, deploy or interrupt another chat.
