# Agrimore Delivery — C17 dialogs, sheets and discard protection

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C17 owner approval is pending.

High-contrast black/white field sheets, burgundy local-discard warnings, burnt-orange task scope and large labelled controls.

[Ten-board gallery](../../../../../docs/design-system/DIALOGS_SHEETS_DISCARD_PROTECTION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/DIALOGS_SHEETS_DISCARD_PROTECTION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

DeliveryConfirmDialog returns result ?? false and has default dialog dismissal. Registration _confirmStartOver clears local draft/staged files only after explicit true; _checkForDraft instead clears draft for any false result, including dialog dismissal. ProblemReportSheet retains reason/note on failure, closes only after backend.report returns, blocks duplicate sends and reuses one request ID per sheet. Note TextField is not disabled during sending. Modal entry has default scrim/drag dismissal and no explicit dirty guard.

## Target direction

Separate local application draft reset from unsent delivery-report edits and submitted delivery work. Resume prompt dismissal keeps the saved draft; Start over is explicit consent. Report sheet protects dirty/pending state, freezes its submitted payload and reconciles uncertain outcome before reusing retry identity.

| Panel | Domain specimen |
| --- | --- |
| Confirmation | Centered danger dialog "Discard saved application?". Body "Clears the local draft and staged documents." Actions OUTLINED black/white "Keep draft" and OUTLINED burgundy "Start over". Burnt-orange board annotation "Local draft only". No withdrawal of a submitted application, submitted status, personal document image or real application ID. |
| Editable sheet | Bottom sheet "Report delivery problem", small "After-pickup form excerpt / Sample", labelled close X. Reason picker showing "Vehicle issue", empty "Notes" field, annotation "Values omitted in this specimen". OUTLINED "Cancel" and black/white PRIMARY "Send report". Footer above labelled keyboard clearance. No location, customer/address/phone, IDs or delivery outcome. |
| Discard protection | Dialog "Discard report edits?", body "Only your unsent report edits will be removed." OUTLINED black/white "Keep editing" and OUTLINED burgundy "Discard edits". Orange board note "Existing submitted reports stay unchanged". Do not confuse it with application reset, proof-photo recovery or delivery cancellation. |
| Submission recovery | Explicit independent "Pending variant" spinner disabled outlined "Sending report" and "Failed variant" burgundy notice "Report couldn’t be sent", helper "Your reason and notes are still here." Orange note "Check outcome before retry". No automatic Retry, new report IDs, success/delivered/payment badges or progress percentage. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Preservation and gaps:

- _checkForDraft treats false/null dismissal as Start over; target keeps draft on cancellation/back/scrim and asks explicitly before reset.
- Default confirm dialog return false is safe for explicit discard confirmation but not when a caller interprets false as consent to clear.
- Report note stays editable while location acquisition/submission runs; freeze captured payload while pending.
- No report dirty-route guard is evident; local discard never closes a submitted exception or reconfirms delivery.
- Retain existing same-request recovery identity; changed payload and unknown outcome need deliberate handling, not a blind new report.

## Light

![Agrimore Delivery C17 light](agrimore-delivery-dialogs-sheets-discard-protection-light.png)

## Dark

![Agrimore Delivery C17 dark](agrimore-delivery-dialogs-sheets-discard-protection-dark.png)

