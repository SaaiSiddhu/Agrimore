# Agrimore Sales Associate — C14 loading, empty, error and restricted states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C14 owner approval is pending.

Premium royal-blue relationship and attributed-order states, pearl/slate surfaces and restrained indigo context, with financial absence never fabricated as zero.

[Ten-board gallery](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

OrdersScreen filters a bounded newest-first attributed-order stream locally. Its initial no-data state returns SizedBox.shrink, while error output includes snap.error. No-match text differs from no-attributed-order copy, but loaded-prefix scope needs explicit guidance. PendingApprovalScreen provides support/sign-out; SuspendedScreen explains that new order attribution is paused and links HelpSupportScreen.

## Target direction

Make the currently blank initial load visible with a scoped skeleton. Separate successful empty attribution from a no-match in loaded orders. Replace raw exceptions with safe, scoped recovery. Pending review and suspended attribution remain distinct account states without earnings or approval guarantees.

| Panel | Domain specimen |
| --- | --- |
| Loading | Pearl/slate record skeleton with small relationship icon placeholder, text bars and no financial values. Heading "Loading attributed orders". Helper "Your records are being loaded". Small note "Refreshing keeps available rows". No balance, order count, percentage or commission amount. |
| Empty | Simple linked-record outline. Title "No attributed orders yet". Body "No orders are currently linked to your account." No forced commercial CTA. Separate indigo-accent inset labelled Filtered view: "No matches in loaded orders" with action "Clear filters". Caption "Load more only when more may exist". No fabricated payout balance. |
| Error | Safe error title "Orders unavailable". Body "We couldn’t load attributed orders. Try again." Primary royal-blue button "Retry" with small caption "Proposed reconnect action". Helper "Keep search and mode". No exception text, code, success, settlement or earnings implication. |
| Restricted | Two distinct cases. Pending: title "Application under review", helper "Approval is still pending", actions "Contact support" and "Sign out". Suspended: title "Account suspended", helper "New order attribution is paused", actions "Contact support" and "Sign out". No auto-approval, activation ETA, earning guarantee or reactivate control. |

Preservation and gaps:

- A filtered empty loaded prefix is not proof of no attributed orders elsewhere; Load more is conditional on the provider/stream evidence.
- Retry is a target reconnection affordance, not an existing dedicated retry handler in the inspected stream view.
- An unavailable order or payout read never implies zero earnings, lost commission, settlement or a change to attribution.
- Support and sign-out are supported. No invented reactivation, appeal submission, immediate active code or approval deadline.

## Light

![Agrimore Sales Associate C14 light](agrimore-sales-associate-loading-empty-error-restricted-states-light.png)

## Dark

![Agrimore Sales Associate C14 dark](agrimore-sales-associate-loading-empty-error-restricted-states-dark.png)

