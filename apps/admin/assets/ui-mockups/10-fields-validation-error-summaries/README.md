# Agrimore Admin — C10 fields, validation and error summaries

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 remains approved and locked.

Structured professional-blue editor, compact cyan section cues and tab-aware error routing.

[All ten boards](../../../../../docs/design-system/FIELDS_VALIDATION_ERROR_SUMMARIES_BOARDS_2026-10-03.md) · [Domain map](../../../../../docs/design-system/FIELDS_VALIDATION_ERROR_SUMMARIES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Product form uses custom styled TextFormField and dropdowns; validators require product name/category/location/description and parse price, with some generic Required/Invalid price messages. Editor save redirects basic-form failure to tab 0 and missing images to tab 1 with snackbar, rather than linking every failure to its control.

## Proposed direction

A cross-section error summary links text, dropdown and image-control failures; switch/reveal the target tab, await layout, then scroll/focus the exact invalid control with safe user-facing copy.

| Panel | Intent |
| --- | --- |
| Editor inputs | Fields Product name, Category dropdown, Sale price with ₹ prefix. Compact tabs Basic info, Images, Delivery. Visible labels and required markers. No sidebar. |
| Helpful inline errors | Product name empty: Enter a product name. Category unselected: Choose a category. Focus Product name; cyan only section guidance, errors use locked error colors. |
| Cross-section summary | Title Check product details. Exactly two linked items Basic info / Product name — Enter a product name; Basic info / Category — Choose a category. Additional small routing note Image errors open Images tab (not an active third error). |
| First invalid focus | Save product → Validate → Open Basic info → Focus Product name. Reveal the correct tab before focus. Include dropdowns and image controls. Preserve unsaved edits. |

Preservation and gaps:

- A parseable price is not necessarily valid for its domain; enforce authoritative constraints without invented limits.
- Offstage tab fields must not be focused before their tab is visible.
- Include category/image/coverage controls in the error model; do not implement text-only summary routing.

## Light

![Agrimore Admin C10 light](agrimore-admin-fields-validation-error-summaries-light.png)

## Dark

![Agrimore Admin C10 dark](agrimore-admin-fields-validation-error-summaries-dark.png)

