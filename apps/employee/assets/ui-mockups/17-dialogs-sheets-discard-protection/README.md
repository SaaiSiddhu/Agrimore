# Agrimore Sales Associate — C17 dialogs, sheets and discard protection

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C17 owner approval is pending.

Premium royal-blue review-request sheets, indigo scope guidance and calm pearl/slate modal surfaces.

[Ten-board gallery](../../../../../docs/design-system/DIALOGS_SHEETS_DISCARD_PROTECTION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/DIALOGS_SHEETS_DISCARD_PROTECTION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

PayoutAccountScreen is a full page with Bank/UPI edit forms, validated controllers, requestEmployeePayoutChange and _isSaving loading buttons. No PopScope/dirty guard is present in the inspected file. Existing pending-change card has Cancel Request calling cancelEmployeePayoutChange directly and only reports cancellation after await. Submission awaits the request but current copy promises admin approval. Profile already uses shared DialogHelper for confirmations.

## Target direction

Illustrate a clearly proposed payout-detail sheet with protected unsubmitted edits and truthful submit-for-review lifecycle. Pending-review cancellation is a separate explicit server action, never a local discard or dialog close. Current details continue only if already configured.

| Panel | Domain specimen |
| --- | --- |
| Confirmation | Centered confirmation "Cancel review request?". Body "Withdraws the pending details change. Current details, if set, stay in use." OUTLINED royal-blue "Keep request" and OUTLINED semantic-danger "Cancel request". Indigo board note "Pending request only". No approval/rejection/paid state or automatic cancellation on dismiss. |
| Editable sheet | Bottom sheet "Edit payout details", small "Proposed sheet / Form excerpt", labelled close X. "Payout method" picker showing "Bank transfer" and empty "Account holder" field; annotation "Values omitted in this specimen". OUTLINED "Cancel" and royal-blue PRIMARY "Submit for review". Footer above labelled keyboard clearance. No names, bank/UPI/account numbers, amounts or claim this form excerpt contains all required fields. |
| Discard protection | Dialog "Discard payout edits?", body "Only unsubmitted edits will be removed." OUTLINED royal-blue "Keep editing" and OUTLINED danger "Discard edits". Indigo board note "Current details and pending requests stay unchanged". No server Cancel request in this local-discard specimen. |
| Submission recovery | Explicit separate "Pending variant" disabled outlined spinner "Submitting for review" and "Failed variant" safe notice "Submission unavailable", helper "Your edits are still here." Indigo annotation "Check request status before resubmitting". No Approved/paid badge, blind Retry or review promise. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Preservation and gaps:

- Sheet layout is a proposal; current payout editor is a page. Keep ownership/auth and existing form validations when adapting it.
- Add local dirty guard across every exit path; do not persist sensitive payout form values to disk by default.
- Cancel Request needs a proposed consequence confirmation, existing callable conditions and pending protection.
- Submission is not approved/effective/paid; unknown outcome is checked before repeat submission.
- Keep current-destination copy conditional for first-time setup; never fabricate details, balance or review date.

## Light

![Agrimore Sales Associate C17 light](agrimore-sales-associate-dialogs-sheets-discard-protection-light.png)

## Dark

![Agrimore Sales Associate C17 dark](agrimore-sales-associate-dialogs-sheets-discard-protection-dark.png)

