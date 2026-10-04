# F0 active rules and recovery parity — 2026-10-04

Read-only observation window: 2026-10-04T17:58:24.216Z to 2026-10-04T17:59:51.660Z. Source comparison at `6cb92cc8`. Execution mode: SINGLE AGENT; no delegation or workflow. This is a dated source/live comparison, not release approval.

All requests were metadata/rules GETs through the installed Firebase CLI authentication/API libraries. No production documents, cloud writes, deployments, provider transactions, signing or device runs occurred. Rule contents remain in temporary files; the companion JSON contains hashes, line references and structural differences.

## Fresh observations

| Area | Observed result | Meaning |
| --- | --- | --- |
| Active Firestore release | Retrieved successfully; last update 2026-09-24T13:42:30.170045Z; differs from current local source | Local rules fixes are not evidence of live enforcement. |
| Active Storage release | Retrieved successfully; last update 2026-09-24T13:42:29.249053Z; differs from current local source | Newly declared source paths need owner rollout and compatible clients. |
| Composite index states | Initial GET and bounded retry failed HTTP 500 | Current READY/build/error states remain UNKNOWN. No empty index listing or readiness result was obtained. |
| Default database settings | Initial GET and bounded retry failed HTTP 500 | Do not refresh PITR/delete-protection/retention claims from the older successful snapshot. |
| Backups | Successful wildcard-location GET; zero entries, one complete page | No listed backup was available in this read. Export files elsewhere were not inventoried. |
| Default database backup schedules | Successful GET; zero entries, one complete page | No schedule was listed; no restore/replay was performed. |

The older endpoint/index report lists 58 live composite shapes, 75 committed and 78 working shapes. Its 17 committed and 3 owner working missing-live additions remain historical shape evidence. The current owner index file still matches that report's SHA256. Today's failed index reads do not confirm those counts or readiness.

The 2026-10-03 successful database read reported PITR disabled, a 3600-second version-retention period and delete protection disabled. Those settings remain dated evidence; today’s settings are unknown. Current empty backup/schedule results leave backup/restore, RPO/RTO and isolated replay acceptance OPEN. No configuration was enabled.

## Structural coverage

The comparison extracts scoped `match` and `function` blocks, removes comments and hashes token sequences while preserving quoted strings and wildcard names. It checks braces and unique scoped keys. Parent hashes include nested blocks. This distinguishes body changes from comments/formatting, but does not prove semantic equivalence, query authorization or absence of overlapping grants.

| Rules | Current source blocks | Active blocks | Token-equal | Token-different | Source-only | Live-only |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Firestore | 185 | 166 | 153 | 9 | 23 | 4 |
| Storage | 36 | 29 | 28 | 1 | 7 | 0 |

Firestore’s nine differences include the root and parent product block, so they are not nine independent policy changes. Storage’s only token-different existing block is the root: all 28 existing child/helper blocks are token-equal; its source changes add seven declarations. Raw whole-file hashes still differ.

## Critical boundary comparison

| Boundary | Active declaration | Current local declaration / release dependency |
| --- | --- | --- |
| Addresses | Owner read/create/update/delete; update checks existing owner | Source adds admin reads and retains the existing owner on update. The newer ownership invariant is not present in active rules. |
| Order ratings | No atomic rating helper or scoped order-review create block | Source binds customer rating and immutable review through `getAfter`, and protects ratings from fulfilment/claim updates. A collection-group review read block already exists in both; scoped-block absence alone does not mean every review read is denied. |
| Rider status | Assigned rider may write allowed forward delivery statuses, including delivered, through four live-only rank helpers | Source uses `riderCannotChangeStatus` and callable-owned transitions. The known compatible-client/OTP-lock release gate remains necessary; static declarations are not a fresh live bypass or installed-client test. |
| Employee payout outcome | Admin can mark an open payout paid with the existing constrained field set | Source denies client payout updates and relies on named payout paid/rejected callables. Verify named deployed handlers and admin client compatibility before owner rules rollout. |
| Employee payout account fields | Owner update checks approval/commission and onboarding fields | Source additionally protects payout account fields and adds payout-change request/private marker paths. Source-only enforcement must not be described as active review protection. |
| Product review votes/photos | Author edits retain existing ownership/rating checks | Source adds actor-only vote validation, immutable server photo markers and activation-state restrictions. Photo rollout remains gated; no attestation/provider deployment claim. |

The existing task live-point declarations and core role helper blocks are token-equal in this snapshot. This does not certify full Auth lifecycle, server-owned writer behavior, query shape compatibility or deployed callable bodies.

## Source-only declarations

Exact scoped keys and source/active line references are in the companion JSON. The following list includes helper declarations and private deny blocks; it is a coverage list, not a list of missing permissions. Unmatched paths remain subject to all overlapping grants and default-deny behavior.

**Firestore:**

- `/databases/{database}/documents::ownerCannotSetPayoutFields` — source line 1233 (function).
- `/databases/{database}/documents::ownerOrderRatingChangeIsValid` — source line 561 (function).
- `/databases/{database}/documents::reviewSelfVoteOnly` — source line 410 (function).
- `/databases/{database}/documents::reviewVotesInitiallyEmpty` — source line 404 (function).
- `/databases/{database}/documents::reviewVotesValid` — source line 393 (function).
- `/databases/{database}/documents::riderCannotChangeStatus` — source line 727 (function).
- `/databases/{database}/documents/benefit_accrual_cursors/{period}` — source line 12 (match).
- `/databases/{database}/documents/checkout_requests/{requestId}` — source line 2487 (match).
- `/databases/{database}/documents/document_review_submissions/{submissionId}` — source line 2238 (match).
- `/databases/{database}/documents/employee_payout_change_requests/{requestId}` — source line 1294 (match).
- `/databases/{database}/documents/employee_wallets/{employeeId}` — source line 1298 (match).
- `/databases/{database}/documents/orders/{orderId}/reviews/{reviewId}` — source line 826 (match).
- `/databases/{database}/documents/payment_reconciliation_cursors/{cursorId}` — source line 2480 (match).
- `/databases/{database}/documents/product_credit_expiry_cursors/{cursorId}` — source line 10 (match).
- `/databases/{database}/documents/review_photo_drafts/{draftId}` — source line 6 (match).
- `/databases/{database}/documents/review_photo_rpc_limits/{limitId}` — source line 8 (match).
- `/databases/{database}/documents/review_photo_upload_limits/{ownerId}` — source line 7 (match).
- `/databases/{database}/documents/rider_identity_change_requests/{requestId}` — source line 2229 (match).
- `/databases/{database}/documents/rider_support_tickets/{ticketId}` — source line 2204 (match).
- `/databases/{database}/documents/support_case_events/{eventId}` — source line 2523 (match).
- `/databases/{database}/documents/support_case_evidence/{evidenceId}` — source line 2532 (match).
- `/databases/{database}/documents/support_case_notes/{noteId}` — source line 2519 (match).
- `/databases/{database}/documents/support_cases/{caseId}` — source line 2515 (match).

**Storage:**

- `/b/{bucket}/o::isImageOrPdf` — source line 376 (function).
- `/b/{bucket}/o/categories/{folder}/{fileName}` — source line 154 (match).
- `/b/{bucket}/o/delivery_document_submissions/{userId}/{submissionId}` — source line 292 (match).
- `/b/{bucket}/o/section_banners/{fileName}` — source line 166 (match).
- `/b/{bucket}/o/sponsored_banners/{fileName}` — source line 178 (match).
- `/b/{bucket}/o/support_attachments/{riderId}/{fileName}` — source line 345 (match).
- `/b/{bucket}/o/support_case_evidence/{caseId}/{fileName}` — source line 380 (match).

## Release and verification boundary

Owner-operated release planning must reconcile compatible clients, named callables, required indexes and whole-rule-file changes. No deployment command is executed by this report. In particular, keep direct-status lock and payout callable migration dependent on installed-client/deployed-handler evidence; keep redemption/photo gates until their own acceptance succeeds. Preserve the owner working index additions and the six historically live-only Functions.

The fresh rules hashes match the earlier active hashes, while local source has continued to advance. This establishes a dated enforcement gap, not an outage, compromise or blanket statement about all active security. Full semantic important-query/dependency coverage, managed runtime/body parity, index readiness, backup/restore and connected mobile release acceptance remain OPEN.

Validation: both active file hashes and current local hashes independently recomputed; scoped keys/braces/count totals checked; owner index bytes preserved; GET request inventory retained. Source inventory and standard postcommit gate pending. No synthetic test is substituted for cloud/device evidence.
