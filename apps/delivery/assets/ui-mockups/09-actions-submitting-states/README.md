# Agrimore Delivery — C09 actions and submitting states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Black/white with burgundy and burnt orange support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-delivery-actions-submitting-states-light.png) |
| Dark | [Open dark](agrimore-delivery-actions-submitting-states-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

DeliveryButton supports primary, secondary, tonal, ghost and danger, disables callback on loading, and displays its supplied label with a spinner; loading text is limited to one ellipsized line. ActiveOrderScreen blocks footer actions with _isUpdating and opens a verification sheet for completion. _VerifySheet validates six-character code and disables submit/input while _submitting; _go has no early reentry return. confirmDelivery enforces assignment/status/OTP transactionally. Proof photo save happens after confirmation and can separately fail. confirmDelivery also returns alreadyDelivered for an assigned rider's repeat call after a confirmed delivery.

## Target direction

Keep delivery progress actions distinct from final verify-and-complete. Explain the verification prerequisite, keep Emergency/Help reachable, and preserve authoritative confirmation and independent proof-upload recovery. Never repeat completion because a later photo upload failed.

| Panel | Specimen intent |
| --- | --- |
| 01 · Field actions | Annotated variants: PRIMARY black/white filled 'Verify & complete'; SECONDARY neutral outline 'View map'; TERTIARY text 'Help'; separate burnt-orange small 'Emergency' text/glyph. Burgundy only a restrained secondary accent. Do not style completion in orange. |
| 02 · Verification prerequisite | Disabled neutral 'Verify & complete'; helper 'Enter the full 6-digit code to continue.' Outline resolution 'Enter delivery code'. Separate caption 'Help remains available'. Do not print a real or invented six-digit code or claim proof photo is mandatory. |
| 03 · Verifying delivery | Primary filled button with spinner and label 'Verifying…'; helper 'Wait for delivery confirmation.' Adjacent neutral 'Cancel' disabled. Small separate annotation 'Repeated taps blocked'. Tiny reduced-motion alternative static hourglass with same busy label; no Delivered checkmark. |
| 04 · Separate recovery | Two clear independent recovery rows: first neutral/info 'Delivery status unclear' with outline action 'Check delivery status'; second warning 'Photo upload needs attention' with outline action 'Retry photo upload'. Caption 'Do not repeat completion for a photo retry'. Small flow 'Verify → Confirm → Optional photo'. These are illustrative independent states, no photo thumbnail, customer data or current success assertion. |

Source gaps and preservation rules:

- Preserve the six-digit verification prerequisite and server assignment/state checks; the illustration's disabled-submit treatment is proposed, current sheet validates code on submit.
- Loading labels need wrapping and readable variant-specific progress contrast; current loading label has one-line ellipsis.
- Add early guards at controller/handler boundaries and robust cleanup; widget disabled state alone is insufficient.
- Proof upload is an independent operation after confirmed delivery and can fail. Never resubmit delivery merely to retry an attachment.
- Do not block Emergency/Help globally while a delivery operation submits; preserve 40px visual utility controls from earlier owner direction with proposed 48px hit regions.

Keep one primary commitment per decision. Every disabled state has readable adjacent reasoning and a reachable resolution. Busy actions retain a meaningful label, block callbacks and need an early handler guard; this is separate from server replay protection. Reconcile unknown outcomes before a new commitment, preserve user inputs and reuse logical request identity where supported. Minimum 48px hit regions and growing label height are proposed. Reduced motion uses a static progress symbol with the same label. Actual accessibility, keyboard/input methods, rapid tapping, retry and process-death recovery require later runtime verification.

## Light

![Agrimore Delivery C09 light](agrimore-delivery-actions-submitting-states-light.png)

## Dark

![Agrimore Delivery C09 dark](agrimore-delivery-actions-submitting-states-dark.png)

