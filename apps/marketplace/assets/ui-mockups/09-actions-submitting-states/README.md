# Agrimore Marketplace — C09 actions and submitting states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Professional green with warm gold and natural stone support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-marketplace-actions-submitting-states-light.png) |
| Dark | [Open dark](agrimore-marketplace-actions-submitting-states-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

CheckoutScreen requires a selected address and disables its footer while quoting delivery; its busy label is Calculating delivery. PaymentMethodScreen has an _isProcessing handler guard and a Processing label. Native MobileCheckoutFlow serializes work, acquires an owner-specific NativePaymentFlight, persists a request journal, and directs uncertain outcomes toward saved-checkout recovery. Shared CustomButton supports three variants but hardcodes white child text/spinner for all variants and has no loading text.

## Target direction

Separate browsing actions from checkout commitment. An address prerequisite has an adjacent explanation and an enabled resolution action. Use stage-specific progress labels; preserve checkout request/session recovery and never turn an ambiguous payment result into a fresh payment.

| Panel | Specimen intent |
| --- | --- |
| 01 · Commerce actions | Three distinct variants, annotated outside buttons: PRIMARY filled green button 'Continue to payment' with arrow; SECONDARY outline 'Change address'; TERTIARY green text action 'View cart'. Tiny warm-gold non-status divider. One primary per decision. |
| 02 · Explain prerequisites | Disabled neutral button 'Continue to payment'. Immediately below readable helper 'Select a delivery address to continue.' Enabled outlined resolution button 'Select address'. No fake chosen address or error toast. |
| 03 · Calculating delivery | Busy filled primary button with spinner and exact label 'Calculating delivery…'; helper 'Please wait while pricing is checked.' Small separate annotation 'Repeated taps blocked'. Small reduced-motion alternative with static hourglass and the same busy label. No percentage or success check. |
| 04 · Uncertain checkout | Information callout 'Checkout needs attention'; body 'Check your saved checkout before paying again.' Enabled outline 'Resume checkout'; main 'Pay' button is disabled neutral. Small flow: 'Ready → Processing → Check status', with caption 'Show success only after confirmation'. No amounts, gateway branding, payment success or placed-order claim. |

Source gaps and preservation rules:

- Shared CustomButton white child/spinner is unsuitable for outlined/text variants and pale dark-theme primary; future work should use variant-specific foreground roles and meaningful loading text.
- Checkout address prerequisite should retain an adjacent explanation and an enabled way to choose an address.
- Native checkout has durable recovery and session/flight guards; this does not establish the same behavior for all web/COD paths.
- Use friendly mapped errors; CheckoutScreen currently can surface callable messages. Preserve server-authoritative totals and current B2B validation.

Keep one primary commitment per decision. Every disabled state has readable adjacent reasoning and a reachable resolution. Busy actions retain a meaningful label, block callbacks and need an early handler guard; this is separate from server replay protection. Reconcile unknown outcomes before a new commitment, preserve user inputs and reuse logical request identity where supported. Minimum 48px hit regions and growing label height are proposed. Reduced motion uses a static progress symbol with the same label. Actual accessibility, keyboard/input methods, rapid tapping, retry and process-death recovery require later runtime verification.

## Light

![Agrimore Marketplace C09 light](agrimore-marketplace-actions-submitting-states-light.png)

## Dark

![Agrimore Marketplace C09 dark](agrimore-marketplace-actions-submitting-states-dark.png)

