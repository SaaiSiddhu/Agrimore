# Agrimore Sales Associate — C16 feedback surfaces and announcements

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C16 owner approval is pending.

Premium royal-blue relationship and payout-review feedback, indigo pending context with pearl/slate surfaces.

[Ten-board gallery](../../../../../docs/design-system/FEEDBACK_SURFACES_ANNOUNCEMENTS_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/FEEDBACK_SURFACES_ANNOUNCEMENTS_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

PayoutAccountScreen awaits requestEmployeePayoutChange before its submitted-for-review snackbar; wallet payoutChangePending replaces the form with a persistent pending card and existing Cancel Request handler. Current success wording says an admin will approve it, although review may reject. Notification batch success waits for commit but failure embeds $e. HelpSupportScreen announces copied immediately without awaiting Clipboard.setData.

## Target direction

Truthful submission toast, safe local refusal/failure notices and a persistent review banner. Submission is not approval, an effective payout destination or money paid. Retain existing supported cancel-request behavior with pending protection; cancel is a mutation, not dismiss.

| Panel | Domain specimen |
| --- | --- |
| Transient toast | Royal-blue neutral-surface floating toast "Payout details submitted for review", small receipt/check icon. Caption "Sample confirmed submission". Indigo note "Submitted does not mean approved". No Paid badge or promise. |
| Inline notice | Safe error notice "Request couldn’t be submitted", body "Review your details before trying again." Empty field labelled "Payout method" with no account/UPI/bank values. Note "Keep entered details". No unconditional Retry or raw exception. |
| Persistent banner | Indigo context banner "Payout details awaiting review", body "Current payout details, if set, still apply until approval." OUTLINED royal-blue action "Cancel request". Board annotation "Explicit cancellation / not dismiss". No approve control, guaranteed date or false balance. |
| Accessible updates | Explicit "Announcement design" section. Quoted text "Request submitted for review" with speaker icon. Rules "Announce once", "Keep focus in context", "Do not announce approval". Indigo supporting note "Review state stays visible". |

Preservation and gaps:

- Replace approval promise with pending-review wording; approval/rejection remain independent confirmed outcomes.
- Map notification/other exceptions to safe copy; no raw platform strings or account details.
- Clipboard success must follow completed write rather than fire immediately.
- Cancel Request requires its existing backend checks and busy state; announcement coalescing and focus restoration are proposed.
- Pending-review copy covers both replacement and first-time payout setup: an existing destination continues only if one was already configured.

## Light

![Agrimore Sales Associate C16 light](agrimore-sales-associate-feedback-surfaces-announcements-light.png)

## Dark

![Agrimore Sales Associate C16 dark](agrimore-sales-associate-feedback-surfaces-announcements-dark.png)

