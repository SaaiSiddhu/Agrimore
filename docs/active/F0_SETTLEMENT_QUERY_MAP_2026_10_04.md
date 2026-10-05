# F0 settlement query map and bounded statement reads

Snapshot 2026-10-04T18:25:36.716042+00:00. 33 important query/read families across employee, seller, rider, admin and server transaction/scheduler paths. This is a semantic slice, not the completed 832-file codebase review. SINGLE AGENT; no workflow/delegation.

## Current statement change

The existing statement anchor is read first inside the same transaction. An existing part returns before account, partner or earnings reads. A new part queries the same rider’s unassigned earnings before the timestamp cutoff, orders oldest first and reads at most401 rows:400 selected plus one lookahead. Existing timestamp eligibility, local sort, exact paise validation, strict cutoff, cash netting, held destinations, idempotency,400 selected writes and50 parts remain. No settlement date or economic formula changes.

Original twelve-case actual Admin SDK baseline:3passed9failed. It read850 earnings for a400-line part,405 for equal-timestamp boundary selection,11 records instead of2 eligible timestamp records,3 earnings queries instead of1 on a multipart retry, and50 earnings queries for50 existing anchors. Fixed12/12 passed. A removed query limit caused2 failures; moving the anchor check back caused6 failures. Both mutations restored exact source bytes and rebuilt. Final compatible cohort95/95 terminal0: new14 (including two scheduler-core notice controls), DLVM1 ten, DLV4A23 and FOUNDATION16 balance48. `/tmp/agrimore-statement-bounds-exact-final.log` records the actual compiled helper/Admin SDK demo run and clean shutdown. Standard postcommit gate at313db577 completed terminal0/failed0 under official isolated Node22.23.3/npm10.9.9: Functions build, allfive analyzers0errors (delivery0diagnostics), six guards, three canonical checks and ledger0warnings. `/tmp/agrimore-statement-query-postcommit-gate.log`.

The fixture initially wrote to an incorrect cwd-relative path and did not exist; that first missing-module run is not a baseline. A later first fixed attempt failed ENOSPC before build/emulator startup; it is not a test result. Capacity recovered without deleting owner artifacts, and the fresh actual test passed. An optional legacy HTTP notice suite was mistakenly included in a Firestore-only run and failed because Auth9099 was absent: the money suites individually passed but that chain was terminal1. Its HTTP notice results are not claimed. Core weekly notice creation/retry controls are exercised separately in the compatible final cohort.

## Client and server query families

| Role | Family / source reference | Selection and bound | Important limit |
| --- | --- | --- | --- |
| rider | Rider unsettled earnings — `apps/delivery/lib/money/rider_money.dart:293` | riderId == captured rider; statementId == null; snapshots; sort in memory; **UNBOUNDED** | All unsettled rows, not just a page; immutable object owner is not complete Auth/session lifecycle proof. |
| rider | Rider account — `apps/delivery/lib/money/rider_money.dart:313` | doc(captured riderId); snapshots; ignore uncached absent result; **POINT** | Authoritative paise model; missing uncached document is not reported as confirmed zero cash. |
| rider | Rider payout history — `apps/delivery/lib/money/rider_money.dart:328` | riderId == captured rider; snapshots; sort createdAt in memory; **UNBOUNDED** | This method loads every statement; no server order/limit or history cursor. |
| rider | Latest rider bank request — `apps/delivery/lib/money/rider_money.dart:343` | riderId == captured rider; snapshots; sort all createdAt then first; **UNBOUNDED** | Latest-result rendering does not bound the database query. |
| rider | Statement delivery page — `apps/delivery/lib/money/rider_money.dart:435` | riderId == captured rider; statementId == selected statement; createdAt DESC; limit(pageSize); startAfterDocument(after); **CURSOR_PAGE_50_DEFAULT** | pageSize is caller-supplied; the method has no explicit maximum clamp. Default50; carry opaque snapshot cursor. |
| rider | Rider earning detail — `apps/delivery/lib/money/rider_money.dart:405` | rider_earnings/{orderId}; one get; **POINT** | Stored riderId is checked by the repository method; permission-denied/not-found become null. |
| rider | Rider payout detail — `apps/delivery/lib/money/rider_money.dart:419` | rider_payouts/{id}; one get; **POINT** | Stored riderId checked; one record is not historical enumeration. |
| seller | Seller withdrawals preview — `apps/seller/lib/screens/payments/wallet.dart:157` | sellerId == captured uid; createdAt DESC; limit20; snapshots; **FIXED_PREVIEW_20** | No cursor/load-more in this source; do not label complete withdrawal history. |
| seller | Seller pending payout change — `apps/seller/lib/screens/payments/wallet.dart:166` | sellerId == captured uid; status == pending; limit1; snapshots; **FIXED_1** | No ordering; server single-pending invariant is required. Not a complete pending-request audit. |
| seller | Seller payout list — `apps/seller/lib/screens/payments/payments_screen.dart:130` | sellerId == current user; createdAt DESC; limit200; snapshots; **FIXED_PREVIEW_200** | Statement rendering/totals are computed from this limited list, not all-time authoritative amounts. |
| employee | Employee wallet — `apps/employee/lib/screens/wallet/wallet_screen.dart:95` | doc(current uid); snapshots; **POINT** | Money stays in shared wallets, not the employee payout-change marker. |
| employee | Employee ledger prefix — `apps/employee/lib/screens/wallet/wallet_screen.dart:284` | userId == uid; createdAt DESC; limit(_pageSize); snapshots; **GROWING_PREFIX_20_STEP** | Load-more adds20 to one listener limit; not a snapshot cursor or fixed total cap. Status filters are applied client-side. |
| employee | Employee payout prefix — `apps/employee/lib/screens/wallet/payout_history_screen.dart:82` | employeeId == uid; createdAt DESC; limit(_pageSize); snapshots; **GROWING_PREFIX_20_STEP** | Load-more adds20 and rereads the prefix; status filtering is client-side. |
| employee | Employee payout detail — `apps/employee/lib/screens/wallet/payout_details_screen.dart:36` | doc(payoutId); one snapshot listener; **POINT** | Verify route identity/session ownership separately from owner-based rules. |
| employee | Employee payout account — `apps/employee/lib/screens/wallet/payout_account_screen.dart:216` | doc(current uid); snapshots; **POINT** | Source employee update payout-field protection differs from active rules; callable compatibility gate remains. |
| employee | Employee payout-change marker — `apps/employee/lib/screens/wallet/payout_account_screen.dart:253` | doc(current uid); snapshots; **POINT** | Private marker only, not balance; scoped source rule is absent in active snapshot. |
| admin | Admin employee payouts — `apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart:195` | createdAt DESC; snapshots; status filter in memory; **UNBOUNDED** | All employees/all payout history is loaded; no query limit/cursor. Local client-paid rule is removed while live compatibility declaration remains. |
| admin | Admin commission exceptions — `apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart:91` | createdAt DESC; limit200; snapshots; **FIXED_PREVIEW_200** | A preview only; complete finance exception audit needs paging/filters. |
| admin | Admin employee payout changes — `apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart:114` | status == pending; limit200; snapshots; **FIXED_200** | No explicit order; source-only scoped read declaration/callables need rollout. |
| admin | Admin seller payout rows — `apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart:97` | status == selected status; createdAt DESC; limit200; snapshots; **FIXED_PREVIEW_200** | Legacy admin-paid mutation exists; separate withdrawal/callable workflow must be reviewed. |
| admin | Admin seller withdrawals — `apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart:327` | status == selected status; limit300; snapshots; **FIXED_300** | No explicit server order/cursor; do not imply all requested withdrawals are visible. |
| admin | Admin seller payout changes — `apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart:416` | status == pending; limit200; snapshots; **FIXED_200** | No explicit server order/cursor; complete backlog visibility remains a requirement. |
| admin | Admin rider payout rows — `apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart:289` | status == selected status; limit300; snapshots; **FIXED_300** | Client sorts the limited subset; not a guaranteed most-recent300 or full pending backlog. |
| admin | Admin rider cash list — `apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart:478` | cashHeld > 0; cashHeld DESC; limit300; snapshots; **FIXED_300** | Query uses rupee display field; rendering prefers authoritative paise. Paise-only/stale-display coverage needs a projection audit. |
| admin | Admin rider bank changes — `apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart:604` | status == pending; limit200; snapshots; **FIXED_200** | No explicit server order/cursor; source/active read block token-equal, full Auth lifecycle not certified. |
| server | Weekly statement candidate earnings — `functions/src/delivery/riderMoney.ts:296` | riderId == rider; statementId == null; createdAt < cutoff Timestamp; createdAt ASC; limit401; transaction read; **FIXED_401** | New own ASC composite; existing-anchor retries return before this query. Existing millis eligibility filter/sort retained. |
| server | Weekly rider account enumeration — `functions/src/delivery/riderMoney.ts:360` | rider_accounts; all documents; then per-rider parts; **UNBOUNDED** | Global scheduler account enumeration remains unbounded; max50 parts/rider bounds writes/parts, not project-wide reads. |
| server | Rider pending payouts during bank change — `functions/src/delivery/riderMoney.ts:402` | riderId == rider; status == pending; transaction query; **UNBOUNDED** | Every returned payout can be updated in one transaction; large backlog write/read budget remains OPEN. |
| server | Rider held payouts during review — `functions/src/delivery/riderMoney.ts:431` | riderId == rider; status == on_hold; transaction query; **UNBOUNDED** | Every matching eligible hold can be released in one transaction; do not cap and silently release a subset. |
| server | Seller wallet summary pending rows — `functions/src/seller/sellerWallet.ts:173` | sellerId == seller; status == pending; get; filter maturity/withdrawal state in memory; **UNBOUNDED** | Summary combines pending rows, seller_wallets marker, payout destination and settings. Preview limits are not authoritative balances. |
| server | Seller withdrawal pending rows — `functions/src/seller/sellerWallet.ts:214` | sellerId == seller; status == pending; transaction query; filter maturity then select400; **UNBOUNDED** | 400 selected payout writes do not bound the query. Existing request replay reads query/destination/account before returning; separate follow-up. |
| server | Employee payout transaction — `functions/src/customer/requestEmployeePayout.ts:65` | wallets/{uid}; employee_payouts/{uid_requestId}; employees/{uid}; transaction point reads; **POINT_SET_3** | Authenticated approved employee; owner/amount-matching anchor; destination captured with balance in transaction. No collection enumeration. |
| server | Employee payout review transaction — `functions/src/customer/reviewEmployeePayout.ts:63` | employee_payouts/{payoutId}; rejection also wallets/{employeeId}; point reads; **POINT_SET** | Admin callable authority and once-only reversal are separate from local client read permissions; named handlers source-only in dated listing. |

## Index and rule dependencies

The new server query needs the explicit `rider_earnings` COLLECTION composite: `riderId ASC, statementId ASC, createdAt ASC`. Existing delivery statement-line history uses `createdAt DESC` and its separate existing composite. This one own ASC expansion is prepared against committed source:75→76 shapes. Working source78→79 retains exactly three owner additions. Original working bytes are recoverable by removing only the append insertion; the partial Git index blob must contain only committed-base plus this own expansion. No owner addition is staged or dispositioned by this phase.

Firebase documents that combining equality and range constraints needs a composite, and ordering filters out missing fields. The real emulator data-type/cutoff parity case covers timestamp, cutoff/future, missing/null/numeric/string/boolean/map/array dates, comparing selected IDs with the prior eligibility algorithm. This is synthetic data evidence, not a production legacy-data audit or live planner proof. [Firebase compound queries](https://firebase.google.com/docs/firestore/query-data/queries), [order and limit behavior](https://firebase.google.com/docs/firestore/query-data/order-limit-data).

Latest direct database/index-state reads failedHTTP500. All new/existing composite build readiness remains UNKNOWN. Owner handover: review an index manifest from the verified committed source and current live definitions before deploying required indexes; confirm READY and planner compatibility before the named `buildRiderStatements` function. Never deploy the owner working additions inadvertently. No deployment or cloud write is performed.

The fresh active-rule report establishes token-equal rider account/earnings/payout and seller payout declarations, but employee payout transitions and employee payout-account field guards differ from local source. Source-only employee marker/change declarations and named source-only paid/reject/change callables require compatible rollout. Token equality does not prove complete Auth lifecycle or authorization of arbitrary queries.

## Endpoint parity (dated)

| Endpoint | Name presence | Deployed body equality |
| --- | --- | --- |
| `buildRiderStatements` | matched-name | UNKNOWN_LIVE_STATE |
| `cancelEmployeePayoutChange` | source-only | NOT_APPLICABLE |
| `cancelSellerWithdrawal` | matched-name | UNKNOWN_LIVE_STATE |
| `markEmployeePayoutPaid` | source-only | NOT_APPLICABLE |
| `markRiderPayoutPaid` | source-only | NOT_APPLICABLE |
| `markSellerWithdrawalPaid` | matched-name | UNKNOWN_LIVE_STATE |
| `recordRiderCashDeposit` | matched-name | UNKNOWN_LIVE_STATE |
| `rejectEmployeePayout` | source-only | NOT_APPLICABLE |
| `rejectSellerWithdrawal` | matched-name | UNKNOWN_LIVE_STATE |
| `requestEmployeePayout` | matched-name | UNKNOWN_LIVE_STATE |
| `requestEmployeePayoutChange` | source-only | NOT_APPLICABLE |
| `requestRiderBankChange` | matched-name | UNKNOWN_LIVE_STATE |
| `requestSellerWithdrawal` | matched-name | UNKNOWN_LIVE_STATE |
| `reviewEmployeePayoutChange` | source-only | NOT_APPLICABLE |
| `reviewRiderBankChange` | matched-name | UNKNOWN_LIVE_STATE |
| `riderMoneySummary` | source-only | NOT_APPLICABLE |
| `sellerWalletSummary` | matched-name | UNKNOWN_LIVE_STATE |

No SDK name becomes deployed merely because its caller exists. In particular, `buildRiderStatements` is matched-name but its body is unknown in the dated report. This bounded implementation is source/local-emulator work until the owner runs the compatible named release.

## Remaining foundation work

Bounded statement candidate reads do not bound the global account enumeration, all parts across all riders, or the bank-change queries that may update every pending/on-hold payout. Seller summaries/withdrawal transactions still read all pending payout rows. Mobile/admin limits and growing prefixes are not complete histories or queues. Future paging must preserve complete financial selection, idempotent effects and owner isolation; adding a limit alone must not hide money/backlog entries.

Complete the remaining all-role semantic queries, delegated listeners, projection/ledger consistency, large-backlog transaction budgets, actual provider and connected device journeys, active rule/callable compatibility, READY indexes and recovery rehearsals. FullF0-F9 acceptance remains OPEN, Product Credit redemption stays gated, device/signing/release controls unchanged. No production document read, provider/payment action, live write, device run, signing, deployment, push or merge occurred.
