# Agrimore Admin — C23 help, support and legal information

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C23 owner approval is pending.

Professional-blue operational support queue and case context, cyan internal-help/legal provenance and steel/slate audit rows.

[Ten-board gallery](../../../../../docs/design-system/HELP_SUPPORT_LEGAL_INFORMATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/HELP_SUPPORT_LEGAL_INFORMATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Real SupportQueueScreen filters all/status or mine (not composed mine+status) and opens/create cases; detail uses admin-only callables for assignment/status/note/resolve/reopen/link. Server optimistic version checks for changes, dedicated resolution summary, atomic command events, payload-aware idempotency for create/note; client caller mostly mounted/busy checks, raw callable messages remain. Settings help Email copied has no Clipboard call; Documentation only snackbar; Bug report submitted is unconditional success without submission. Settings legal dialog contains static unverified terms/privacy assurances. Rider-ticket admin management is a distinct operational record system, not identical support_cases status.

## Target direction

Design operational queue/case review separately from internal administrator help. Preserve real case records/audit mutations; propose genuine internal contact/guide actions and readable failure, and confirmed policy sources without fabricated bug submission.

| Panel | Domain specimen |
| --- | --- |
| Operational support queue | Card "Support queue", two filter chips "All" selected and "My cases" unselected, EMPTY neutral case rows, PRIMARY "Create case". Cyan BOARD note "Administrative cases / authorised access". No actor names, IDs, case count, customer contact or inbox receipt. |
| Case review and activity | Card "Case workspace", EMPTY case-title skeleton, SECONDARY "View case"; separate neutral legend labelled "Case status vocabulary": "Open", "In progress", "Waiting", "Resolved". Cyan BOARD note "Case resolution is not financial settlement". No current resolved checkmark, real note, audit timestamp, refund, payment action or rider-status substitution. |
| Genuine internal help | Card "Administrator help", SECONDARY "Open email app", neutral outline row "Administrator guide". Cyan BOARD note "Proposed genuine actions / settings placeholders today". No raw URL/email, Bug report submitted, copied/sent toast, live contact or guaranteed guide availability. |
| Administrative legal reference | Card "Legal reference", two document rows "Terms and conditions" and "Privacy policy". Cyan BOARD note "Confirm authoritative documents and version". No real legal clauses/date, compliance/encryption/sharing guarantee, accepted consent, fabricated external destination or legal-signoff badge. |

Preservation and gaps:

- Support-case resolution is workflow state, not refund, payout, delivery completion or recipient communication.
- Queue filter mine versus status is mutually selected; do not claim combined filter without implementation.
- Settings contact/documentation/bug actions are placeholders; target actions must open/copy/submit only when actually wired.
- Rider Submitted/Seen/Closed differs from admin Open/In progress/Waiting/Resolved; do not merge schemas or expose admin-only case notes to other apps.

## Light

![Agrimore Admin C23 light](agrimore-admin-help-support-legal-information-light.png)

## Dark

![Agrimore Admin C23 dark](agrimore-admin-help-support-legal-information-dark.png)

