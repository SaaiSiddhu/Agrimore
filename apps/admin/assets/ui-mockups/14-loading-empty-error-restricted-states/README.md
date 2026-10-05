# Agrimore Admin — C14 loading, empty, error and restricted states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C14 owner approval is pending.

Dense professional-blue operational states with steel/slate record skeletons, cyan read-scope guidance and precise authorization boundaries.

[Ten-board gallery](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

ProductManagementScreen displays loading before an empty-product branch and has query-sensitive empty copy; its inspected list branch has no explicit product-load error state. SellerProductApprovalScreen separates stream error/no-data/empty but interpolates snapshot.error and update exceptions into UI. The approval collection shows all seller products rather than a verified pending-only queue. AuthScreen and app router enforce admin access and show a safe access-denied message.

## Target direction

Provide a compact operational read-state family that never turns a failed read into an empty queue. Existing catalogue and seller-product review contexts remain distinct. Admin access denial directs to an authorized sign-in path without granting roles or exposing operational data.

| Panel | Domain specimen |
| --- | --- |
| Loading | Dense neutral table/record-row skeleton. Heading "Loading catalogue records". Helper "Keep available rows during refresh". Small cyan guidance "Refresh status stays visible". No fake table values, identifiers, selection totals or backend status. |
| Empty | Compact catalogue outline. Title "No catalogue products". Body "No products are available in this view." Secondary button "Add product". Separate thin inset labelled Filtered catalogue: "No matching loaded records" with action "Clear filters". Never "No pending approvals" or a completed-review claim. |
| Error | Operational error panel title "Catalogue unavailable". Body "Records couldn’t be loaded. Try the read again." Filled professional-blue "Retry" action. Small note "Keep query and filters". Separate quiet line "Retained records: last-known" and "Guard actions that need current data". No data details or fictional result count. |
| Restricted | Shield/lock outline. Title "Admin access unavailable". Body "This account cannot access the admin app." Primary button "Return to sign in". Small helper "Use an authorized admin account". No Request access, Grant role, approve, retry bypass or operational record exposure. |

Preservation and gaps:

- Do not call the seller-product screen an empty pending queue: the current query reads all products and filters sellerId, without a pending-status predicate.
- Add a mapped load-error branch to catalogue management; avoid reporting catalogue absence after a provider failure.
- Raw stream/update exceptions require safe user copy and scoped telemetry; repeated retry must not duplicate mutations or lose selections.
- Proposed retry/read refresh and retained-data guards require future wiring. Access denied is not solved by retry, request-role automation or bypassing authorization.

## Light

![Agrimore Admin C14 light](agrimore-admin-loading-empty-error-restricted-states-light.png)

## Dark

![Agrimore Admin C14 dark](agrimore-admin-loading-empty-error-restricted-states-dark.png)

