# Agrimore Delivery — C23 help, support and legal information

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C23 owner approval is pending.

Field-readable black/white request support, burgundy safety separation, burnt-orange recovery/provenance notes and large clear controls.

[Ten-board gallery](../../../../../docs/design-system/HELP_SUPPORT_LEGAL_INFORMATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/HELP_SUPPORT_LEGAL_INFORMATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Help screen/home sheet expose delivery issue, earnings/payouts, account/documents topics, My requests, support call and separate emergency sheet. Profile has configured phone/email launcher with false/exception feedback. SubmitSupportRequestScreen validates message, optional uploaded photo and reuses widget-lifetime request ID; no related-order/statement picker ships. Request list persists server tickets, newest client sort, explicit loading/error/retry/empty; detail has Submitted/Seen/Closed and closure note. Backend permits registered suspended riders, server identity and idempotent existing-ticket return; existing ID replay does not compare changed payload. Client submit/upload uses mounted checks, not explicit owner/episode tickets. No legal entry found in inspected help/profile surfaces.

## Target direction

Preserve real support request/list/status flow and separate immediate-safety entry from routine support. Add ownership/payload-aware retry discipline and proposed legal entries tied to confirmed documents; no new chat, SLA or automatic emergency dispatch.

| Panel | Domain specimen |
| --- | --- |
| Rider support request | Card "Request support", category row "Delivery issue", EMPTY multiline field labelled "Message", SECONDARY "Add attachment"; DISABLED neutral "Submit request", explanation "Add a message before submitting". Orange BOARD note "Registered rider request / server acknowledgement". No attachment photograph/name, ID, related-record picker or success. |
| Request tracking vocabulary | Card "My support requests", generic request row "Delivery issue", EMPTY message skeleton, secondary "View request". Separate neutral legend labelled "Status vocabulary" with "Submitted", "Seen", "Closed" (NO ticks or progressing timeline). Orange BOARD note "Request state is not a delivery or payout outcome". No real status/date/ID/count/closure claim. |
| Routine and urgent help | Card "Contact support", SECONDARY "Open phone app" and "Open email app". Separate burgundy-outline row "Emergency help"; small "Routine support and urgent safety are separate". Orange BOARD note "Handoff does not alert anyone". No emergency number, call-connected/sent/location-shared claim or panic animation. |
| Rider legal information | Card "Legal information", two document rows "Terms and conditions" and "Privacy policy". Orange BOARD note "Proposed legal entry / confirm policy source". No external-versus-internal destination icon or body claim until source confirmed; no dates, consent, compliance, retention or insurance promise. |

Preservation and gaps:

- Widget-lifetime retry ID is not disk draft/queue. Backend existing-ID replay returns prior ticket without checking edited payload; changed request needs deliberate new-action policy.
- Attachment uploads happen on pick; remove UI does not prove server file deleted. Do not promise protected storage or automatic cleanup.
- Seen/Closed do not mean delivery completed, payout settled or incident resolved. Emergency dialer handoff is not location sharing/alert sent.
- Legal entries are proposed here; related record picker is not implemented and must not appear as live control.

## Light

![Agrimore Delivery C23 light](agrimore-delivery-help-support-legal-information-light.png)

## Dark

![Agrimore Delivery C23 dark](agrimore-delivery-help-support-legal-information-dark.png)

