# Agrimore Admin — C21 notifications, activity and destinations

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C21 owner approval is pending.

Professional-blue notification operations/history, cyan destination preview guidance, steel/slate immutable activity rows and restrained operational provenance labels.

[Ten-board gallery](../../../../../docs/design-system/NOTIFICATIONS_ACTIVITY_DESTINATIONS_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/NOTIFICATIONS_ACTIVITY_DESTINATIONS_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Admin /notifications routes to SendNotificationScreen: compose/order notification/history tabs, not a personal inbox. History streams notification_history ordered timestamp capped50; client logs after callable with server timestamp plus ISO client createdAt, catches history-log failure, and backend also logs sentAt/results. Fields/provenance differ; query timestamp may exclude sentAt-only rows. Current formatter uses relative age; future/missing times need handling. Support case activity is paginated append-only support_case_events ordered at with actor/date, not unread records. Callable successCount/failureCount are push transport outcomes, not viewed/read/record-business outcome. actionUrl accepts strings/internal normalization; shared external branch logs and returns rather than opening a browser.

## Target direction

Design Admin around outbound history and case activity, timestamp provenance, a clearly labelled recipient-state preview and safe destination review. Do not add Mark all read to the sending console or show recipients Read/Delivered from push success. Preview unread/read demonstrates recipient styling only; no real receipt or new admin personal inbox is asserted.

| Panel | Domain specimen |
| --- | --- |
| Outbound and case activity | Card "Notification history" with generic row "Notification record", outline history icon, EMPTY body skeletons and small type chip "General"; second slim row "Case activity" with EMPTY skeleton. Cyan BOARD notes "Outbound history / not a personal inbox" and "Activity entries are not mark-read controls". No unread badge on outbound record, sent/delivered/read recipient receipt or metrics. |
| Operational timestamp provenance | Card "Recorded time", exact fixed FORMAT EXAMPLE "18 Sep 2026 · 09:40"; secondary "Time unavailable". Cyan BOARD notes "Format example / use authoritative event time" and "History time is not a read receipt". No relative age, Just now, created success or invented operator. |
| Recipient state preview | CLEAR heading "Recipient preview only". Two compact synthetic preview rows "Notification" with EMPTY body skeleton: one blue dot, bold "Unread"; one normal "Read" and no dot. Cyan BOARD annotation "Styling preview / no recipient receipt". NO Mark all read, success tick, read statistics or claim admin observes actual recipient reads. |
| Destination review | Card "Review notification destination", outline link icon, neutral destination descriptor "Order details", PRIMARY "Review destination". Cyan BOARD notes "Proposed typed preview" and "Verify role, record and access before sending". No actual Send/Broadcast control, raw URL, target ID, user identity or external-launch guarantee. |

Preservation and gaps:

- Do not apply user inbox mark-read behavior to immutable support activity or outbound notification history.
- Transport accepted/success count is not recipient device display, human read or business success. History row existence does not prove all recipients received it.
- Client history logging can fail after send outcome; backend/client logging paths need consolidation/deduplication and consistent timestamp query before complete-history claims.
- Current relative age formatter can classify future values Just now; target explicit absolute-time provenance and missing-time treatment avoids invented urgency.
- Typed role-capable destination review is proposed; formatted actionUrl and dormant external logging branch do not guarantee a safe working destination.

## Light

![Agrimore Admin C21 light](agrimore-admin-notifications-activity-destinations-light.png)

## Dark

![Agrimore Admin C21 dark](agrimore-admin-notifications-activity-destinations-dark.png)

