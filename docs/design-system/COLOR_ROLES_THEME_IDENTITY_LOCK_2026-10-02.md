# Agrimore — color roles and theme identity approval

**Status: APPROVED / LOCKED · Version: v2 · Owner decision: 2026-10-02**

The owner approved the ten latest app-specific boards with: “Brooo perfect, fantastic,.. now lock all of these”. This record locks one light and one dark design-token board for each of the five apps. The earlier uniform-green v1 proposal is superseded.

## Approved references

| App | Identity | Approved images | Provenance |
| --- | --- | --- | --- |
| [Agrimore Admin](../../apps/admin/assets/ui-mockups/01-color-roles-theme-identity/README.md) | Professional institutional blue with cyan and steel/slate support. | [Light](../../apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-light.png) · [Dark](../../apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-dark.png) | [Prompts](../../apps/admin/assets/ui-mockups/01-color-roles-theme-identity/prompts.md) · [Lock](../../apps/admin/assets/ui-mockups/01-color-roles-theme-identity/lock.json) |
| [Agrimore Marketplace](../../apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/README.md) | Professional green with warm gold and natural stone support. | [Light](../../apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-light.png) · [Dark](../../apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-dark.png) | [Prompts](../../apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/prompts.md) · [Lock](../../apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/lock.json) |
| [Agrimore Seller](../../apps/seller/assets/ui-mockups/01-color-roles-theme-identity/README.md) | Blue-teal with warm copper and cool neutral support. | [Light](../../apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-light.png) · [Dark](../../apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-dark.png) | [Prompts](../../apps/seller/assets/ui-mockups/01-color-roles-theme-identity/prompts.md) · [Lock](../../apps/seller/assets/ui-mockups/01-color-roles-theme-identity/lock.json) |
| [Agrimore Sales Associate](../../apps/employee/assets/ui-mockups/01-color-roles-theme-identity/README.md) | Premium royal blue with muted indigo, pearl and slate support. | [Light](../../apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-light.png) · [Dark](../../apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-dark.png) | [Prompts](../../apps/employee/assets/ui-mockups/01-color-roles-theme-identity/prompts.md) · [Lock](../../apps/employee/assets/ui-mockups/01-color-roles-theme-identity/lock.json) |
| [Agrimore Delivery](../../apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/README.md) | Black/white with burgundy and burnt orange support. | [Light](../../apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-light.png) · [Dark](../../apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-dark.png) | [Prompts](../../apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/prompts.md) · [Lock](../../apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/lock.json) |

Sales Associate maps to the existing `apps/employee` directory. Image filenames use `sales-associate` to preserve the public app identity.

## Scope of approval

The approved visual foundation is **C01: Color roles and theme identity**, including the colors, typography, spacing, radius, borders and shadow specimens shown on these boards. Each app has its own brand and supporting colors. Dark mode uses near-black canvases and dark grey surfaces. Functional success, warning, error and information roles remain explicit in each app's `prompts.md` and `lock.json`.

The documented hexadecimal values are the canonical specification for future implementation; the generated PNGs provide the approved visual reference. Shadow appearance is approved as illustrated, while numeric shadow tokens remain to be defined during implementation. This record does not approve every screen or the remaining shared foundations, and does not claim that the current runtime UI already matches these boards.

## Asset organization and integrity

Each app stores this pair under `assets/ui-mockups/01-color-roles-theme-identity/`, alongside `README.md`, `prompts.md` and `lock.json`. Filenames follow `agrimore-<app>-design-tokens-<light|dark>.png`.

All ten images are byte-identical copies of the approved v2 generation outputs. Each lock records the image SHA-256, byte length, dimensions, exact-prompt SHA-256, original final-newline presence, historical edit-input checksum, palette and semantic status values. Original generation-prompt text is preserved verbatim in each app's `prompts.md`; a Markdown fence separator is added where required and excluded from the original-text checksum.

These are repository design-reference assets. Runtime asset registration and theme-code changes are separate implementation work. Existing mockups are preserved.

## Revision policy

Keep this approved pair intact. Any successor must preserve the five independent identities unless the owner approves a change, retain these historical boards, and record a new version with updated prompts and checksums. Locking means a documented, versioned design decision; it does not apply filesystem immutability.
