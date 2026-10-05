# Agrimore Admin — C16 feedback surfaces and announcements

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C16 owner approval is pending.

Professional-blue operational feedback, cyan context cues and dense steel/slate information surfaces.

[Ten-board gallery](../../../../../docs/design-system/FEEDBACK_SURFACES_ANNOUNCEMENTS_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/FEEDBACK_SURFACES_ANNOUNCEMENTS_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SupportCaseDetail _call waits for the callable before success and refreshes activity. FirebaseFunctionsException feedback can expose e.message; generic catch is safe. Finance reconciliation already persists scan coverage and an incomplete warning with reasons, separate from findings. Shared SnackbarHelper handles status/custom/action/loading; some paths queue bars, loading uses a 365-day duration requiring explicit hide/clear.

## Target direction

Concise confirmed case-action toast, safe inline scoped action failure, and persistent incomplete-scan warning. A toast never certifies case resolution or complete finance coverage. Prioritize actionable feedback, prevent stale/queued repeats, and distinguish urgent errors from routine polite updates.

| Panel | Domain specimen |
| --- | --- |
| Transient toast | Compact neutral professional-blue toast "Case updated" with success icon. Caption "Sample confirmed action". Cyan board note "Confirmed case action only". No Resolved/Approved/paid inference or Undo. |
| Inline notice | Inline safe error "Case update failed", body "Review the case before submitting again." Small labelled context "Support case / Sample". Cyan note "Other sections remain available". No stack trace, server message, case IDs or blind Retry. |
| Persistent banner | Persistent warning "Scan coverage incomplete", body "Some records were not checked. Review the covered scope." Small cyan context "Read-only reconciliation". No dismiss X or invented action button; the surrounding view owns coverage details. No All clear, scanned counts, timestamps or fake full coverage. |
| Accessible updates | Explicit "Announcement design" section. Speaker icon and quote "Case updated". Rules "One confirmed update", "Keep operator focus", "Prioritize blocking errors". Cyan supporting note "Coalesce repeated notices". No automatic assertive readout for every banner. |

Preservation and gaps:

- Map callable exceptions to safe operator-facing reasons; do not expose raw server messages.
- Incomplete scan must remain visible alongside findings; no All clear or zero findings inferred from incomplete coverage.
- Shared helper lifecycle needs timeout/cancel/unmount policy instead of immortal progress snackbar.
- No blind replay of administrative mutations, fictional Undo, or assertion that case action certifies money.

## Light

![Agrimore Admin C16 light](agrimore-admin-feedback-surfaces-announcements-light.png)

## Dark

![Agrimore Admin C16 dark](agrimore-admin-feedback-surfaces-announcements-dark.png)

