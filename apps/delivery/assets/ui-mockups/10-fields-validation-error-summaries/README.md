# Agrimore Delivery — C10 fields, validation and error summaries

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 remains approved and locked.

High-contrast monochrome verification sheet, burgundy error states and burnt-orange focus.

[All ten boards](../../../../../docs/design-system/FIELDS_VALIDATION_ERROR_SUMMARIES_BOARDS_2026-10-03.md) · [Domain map](../../../../../docs/design-system/FIELDS_VALIDATION_ERROR_SUMMARIES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

DeliveryTextField forwards labels, validators and focus nodes. Active-order verify sheet uses DeliveryOtpField with six cells, digit semantic labels, inline error and disabled while submitting; incomplete code sets an error and returned server errors stay in the open sheet.

## Proposed direction

Treat six visible code cells as one logical input, focus its actual editable control on validation failure and distinguish incomplete input from server rejection without announcing every digit.

| Panel | Intent |
| --- | --- |
| Verification input | Single group Delivery code with six EMPTY square cells. Helper Enter the 6-digit delivery code. One logical accessible input. Black primary Verify delivery, never orange primary. |
| Helpful inline errors | Same six EMPTY cells and burgundy inline error Enter the complete 6-digit code. Separate server-error specimen Code not accepted. Check and try again. No digits or success tick. |
| Focused error summary | Title Check delivery code. One linked item Delivery code — Enter the complete 6-digit code. Single-field sheet uses a compact summary, no fake second error. |
| First invalid focus | Verify delivery → Validate format → Reveal code input → Focus. Server checks follow valid input. Keep sheet open on rejection. Proof photo is separate. |

Preservation and gaps:

- A six-digit format is not verification; only the server can confirm completion.
- Never display OTP digits, sensitive logs or assumed successful handover.
- Keep verification errors separate from optional proof-photo upload retry and rate-limit guidance.

## Light

![Agrimore Delivery C10 light](agrimore-delivery-fields-validation-error-summaries-light.png)

## Dark

![Agrimore Delivery C10 dark](agrimore-delivery-fields-validation-error-summaries-dark.png)

