# Agrimore Sales Associate — C09 actions and submitting states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Premium royal blue with muted indigo, pearl and slate support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-sales-associate-actions-submitting-states-light.png) |
| Dark | [Open dark](agrimore-sales-associate-actions-submitting-states-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

SaLoadingButton supports primary/outlined, 52px minimum, loading text and _isEnabled gating. PayoutRequestScreen requires a destination account and a positive amount within available balance before Review Payout Request. PayoutReviewScreen uses an early _isSubmitting guard and one request ID per review-screen lifetime; backend requestEmployeePayout uses actor-scoped transactional replay and amount mismatch checks. Review button does not supply a distinct loadingText; Back in the AppBar is not disabled while submitting. Error copy may include callable/raw exception text.

## Target direction

Review amount/destination before committing the payout request. Explain missing prerequisites next to the disabled review action. Say Submitting request rather than transferring/paid; preserve the same logical request for an uncertain retry and report Requested separately from settlement.

| Panel | Specimen intent |
| --- | --- |
| 01 · Reviewed commitment | Annotated variants: PRIMARY royal-blue filled 'Confirm & request payout'; SECONDARY royal-blue outline 'Review payout request'; TERTIARY text 'Change amount'. Tiny indigo rule. Caption 'Review amount and destination first'. No money values or transfer promise. |
| 02 · Explain missing details | Disabled neutral 'Review payout request'; helper 'Add a payout account and enter an eligible amount.' Enabled outline 'Add payout account'. Small secondary note 'Amount must fit your available balance'. Do not show bank/UPI values. |
| 03 · Submitting the request | Filled royal-blue primary with spinner and label 'Submitting request…'; muted helper 'Wait for the request result.' 'Change amount' is disabled neutral. Separate annotation 'Repeated taps blocked'. Tiny static-hourglass reduced-motion alternative. No progress percentage or bank-transfer animation. |
| 04 · Reconcile before retry | Information callout 'Request status unclear'; body 'Check payout history before starting another request.' Enabled outline 'Check payout history'; caption 'Retry the same request when appropriate'. Small flow 'Review → Submit → Requested'; explicit note 'Requested is not settlement'. Requested is informational clock, no success check/paid badge. No account data, amount or guaranteed payout. |

Source gaps and preservation rules:

- Keep SaLoadingButton and its minimum height/variant bindings; add stage-specific loadingText at payout review.
- One request ID survives retries only for the review screen's lifetime; navigation/process death persistence is a distinct unresolved design/implementation concern.
- AppBar Back remains available during submission; future handling should prevent accidental new requests while preserving a recoverable route, rather than merely disabling every way out.
- Backend replay protections are verified source facts, not deployed/exercised runtime guarantees.
- Map raw error text to safe, actionable copy; Requested means a request exists and is distinct from bank settlement.

Keep one primary commitment per decision. Every disabled state has readable adjacent reasoning and a reachable resolution. Busy actions retain a meaningful label, block callbacks and need an early handler guard; this is separate from server replay protection. Reconcile unknown outcomes before a new commitment, preserve user inputs and reuse logical request identity where supported. Minimum 48px hit regions and growing label height are proposed. Reduced motion uses a static progress symbol with the same label. Actual accessibility, keyboard/input methods, rapid tapping, retry and process-death recovery require later runtime verification.

## Light

![Agrimore Sales Associate C09 light](agrimore-sales-associate-actions-submitting-states-light.png)

## Dark

![Agrimore Sales Associate C09 dark](agrimore-sales-associate-actions-submitting-states-dark.png)

