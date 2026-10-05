# Agrimore Delivery — C14 loading, empty, error and restricted states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C14 owner approval is pending.

High-contrast black/white field-use states with large controls, burgundy restrictions, burnt-orange connectivity cues and calm neutral cached-data guidance.

[Ten-board gallery](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

DeliveryLoadingList/DeliverySkeleton and DeliveryEmptyState/DeliveryErrorState already exist. ActiveWork explicitly models first load, ready/cache and failure with last-known orders. RiderDataError distinguishes permission, offline and unknown. Dashboard retains known orders and shows StaleDataBanner when cached or refresh fails. PendingApprovalScreen separates pending/rejected/suspended/deactivated; only pending/rejected may edit/resubmit.

## Target direction

Show first-load and a true successfully loaded empty active-work read independently of connectivity failure. Cached work remains visibly last-known, never an instruction to perform offline mutations. Account restriction gives supported support/edit/sign-out actions rather than retrying a forbidden operation.

| Panel | Domain specimen |
| --- | --- |
| Loading | Wide task skeleton with neutral icon block and text bars. Heading "Loading active work". Helper "Checking assigned orders". Thin neutral inset "Cached work / Last-known information" with text "Refresh unavailable"; note "Do not treat cached status as live". No map, address, task ID or fabricated job. |
| Empty | Minimal parcel outline. Title "No active assignments". Body "Your assigned-work list is empty." Outlined button "View history". Small burnt-orange caption "Only after a successful current read". Do not promise work will arrive, imply online status, or display Go online. |
| Error | Offline icon with title "Couldn’t connect". Body "Check your connection and try loading again." Large primary button "Retry". Separate small inset labelled Access error: "Can’t read orders" and text actions "Sign in again" and "Contact support". No generic Retry on the permission-error inset. |
| Restricted | Two distinct small cases. Pending review: "Application under review", helper "Work access waits for approval", button "Edit application". Suspended: "Account suspended", helper "An admin must restore work access", actions "Contact support" and "Sign out". Burgundy restricted accents; burnt-orange context. No approval time, automatic reinstatement or resubmit action on suspended case. |

Preservation and gaps:

- ActiveWork.isEmpty is loaded && orders.isEmpty even in failed state; consumers must prioritize error and cache evidence before true-empty copy.
- Current ActiveWorkError presents Retry even for mapped permission failure; target permission recovery differs from a connection retry.
- DeliverySkeleton respects reduced motion; the generic CircularProgressIndicator loading state has no dedicated reduced-motion branch in the inspected code.
- Pending/rejected edit or resubmit is supported. Suspended/deactivated do not get edit, resubmit, go-online, accept-order or self-unlock actions. No refresh-status endpoint is invented.

## Light

![Agrimore Delivery C14 light](agrimore-delivery-loading-empty-error-restricted-states-light.png)

## Dark

![Agrimore Delivery C14 dark](agrimore-delivery-loading-empty-error-restricted-states-dark.png)

