# Agrimore Seller — C10 fields, validation and error summaries

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 remains approved and locked.

Compact blue-teal product editor with copper section cues, units and draft-aware requirements.

[All ten boards](../../../../../docs/design-system/FIELDS_VALIDATION_ERROR_SUMMARIES_BOARDS_2026-10-03.md) · [Domain map](../../../../../docs/design-system/FIELDS_VALIDATION_ERROR_SUMMARIES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SellerTextField/Dropdown register focus handles in SellerFormScope; summary links focus by label and first-invalid sorts rendered visual positions. Product publish schedules focus after validation; draft only requires name. Stock helper preserves malformed/missing raw stock as unknown.

## Proposed direction

Extend the existing field/scope system with stable field identifiers, explicit numeric/unit rules and summary links that also reveal collapsed or offstage sections.

| Panel | Intent |
| --- | --- |
| Product inputs | Fields Product name, Sale price with ₹ prefix and helper Set a valid sale price, Stock quantity with units suffix and helper Use a whole-unit count. Copper chip Draft has fewer requirements. |
| Helpful inline errors | Product name empty: Enter a product name. Stock quantity empty: Enter a whole-unit stock count. Show first focused Product name. No fake monetary values. |
| Publish summary | Title Check before publishing. Exactly two linked errors: Product name — Enter a product name; Stock quantity — Enter a whole-unit stock count. Secondary text Your draft is preserved. |
| First invalid focus | Publish → Validate → Reveal Product name → Focus. Draft and publish use different rules. Missing stock stays unknown. Reuse existing field scope. |

Preservation and gaps:

- Retain draft versus publish requirements instead of enforcing all publish checks on drafts.
- Label-based focus can collide; stable field IDs are a target improvement, not current implementation.
- Audit numeric parsing independently: several editor validators only check nonempty; unknown stock must not silently become zero.

## Light

![Agrimore Seller C10 light](agrimore-seller-fields-validation-error-summaries-light.png)

## Dark

![Agrimore Seller C10 dark](agrimore-seller-fields-validation-error-summaries-dark.png)

