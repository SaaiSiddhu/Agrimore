# Agrimore Delivery — C21 notifications, activity and destinations

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C21 owner approval is pending.

High-contrast black/white rider inbox, burgundy attention markers, burnt-orange destination/time guidance and large comfortable field controls.

[Ten-board gallery](../../../../../docs/design-system/NOTIFICATIONS_ACTIVITY_DESTINATIONS_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/NOTIFICATIONS_ACTIVITY_DESTINATIONS_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

RiderNotice parses explicit known notice types and identifiers; inbox has unread semantic dot, type icons, All/Unread filters and local Today/Earlier grouping from valid createdAt (missing time -> Earlier). latest stream capped at 50; unreadCount capped at 50 with saturation text. markAllRead queries unread true beyond displayed slice then writes chunked batches; duplicate-tap busy guard and success/error toast after operation await. Single mark failure visible, row tap starts markRead separately from navigation. Delivery/statement destinations are loaded by ID before navigation; failed load stays inbox with error, missing entity unavailable. Specific support/bank/identity/document/incident destination routes preserve their supplied IDs. Known legacy document/bank fallbacks differ from missing incident/identity IDs.

## Target direction

Preserve real per-type destinations and full-query mark-read behavior. Show field-readable unread/read, valid local time versus missing time, busy/confirmed/failure read feedback and a destination unavailable state. Reading a delivery notice never accepts an offer, advances a step or proves delivery completed.

| Panel | Domain specimen |
| --- | --- |
| Rider notice hierarchy | Two synthetic notice rows titled "Delivery update", package outline icons and EMPTY body skeletons. First bold plus burgundy dot and explicit "Unread", second normal "Read" no dot. Compact nonnumeric chips "All" and "Unread". Orange BOARD note "Reading does not advance a task". No task ID, assignment count or delivery-completed icon. |
| Local notice time | Card "Notice time", exact fixed FORMAT EXAMPLE "18 Sep 2026, 9:40 AM"; smaller "Time unavailable". Orange BOARD notes "Format example / not live activity" and "Use local date only when known". No ETA, countdown or guessed Today section. |
| Inbox read feedback | Three SMALL independent states: DISABLED neutral "Marking as read…" and indeterminate spinner; confirmed inline "Read status updated"; failed "Could not finish updating read status" with SECONDARY "Try again". Orange BOARD note "Query scope / partial failure stays recoverable". No emptied inbox, count, deleted notice or universal all-caught-up claim. |
| Delivery destination recovery | Card "Delivery unavailable", outline package icon, body "This delivery cannot be opened right now." PRIMARY "Back to inbox", black light / off-white with dark text dark. Orange BOARD notes "Recheck current access and record" and "No task action from a notice". No accept offer, start route, proof replay, Delivered tick or raw ID. |

Preservation and gaps:

- Capped unread badge is saturated, not exact global count; failures/loading are not zero. Mark-all query is a snapshot, not a guarantee notices arriving later are already read.
- Chunked batches can partially commit before failure; show incomplete update and refresh/reconcile rather than roll back all or claim all success.
- Destination payload is not authority; current auth, rider binding, current entity and permissions must still be checked after awaits as C19.
- Legacy fallback is domain-specific: document current view and old bank Earnings are evidenced; no guessed incident or identity record.
- Missing timestamp grouped Earlier today is current source behavior, but target missing-time explanation should not certify it predates today.

## Light

![Agrimore Delivery C21 light](agrimore-delivery-notifications-activity-destinations-light.png)

## Dark

![Agrimore Delivery C21 dark](agrimore-delivery-notifications-activity-destinations-dark.png)

