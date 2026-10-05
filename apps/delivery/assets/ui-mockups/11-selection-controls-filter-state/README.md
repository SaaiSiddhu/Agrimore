# Agrimore Delivery — C11 selection controls and filter state

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 remains approved and locked.

Monochrome field controls, burgundy selected-container cues and burnt-orange focus with a compact history sheet.

[All ten boards](../../../../../docs/design-system/SELECTION_CONTROLS_FILTER_STATE_BOARDS_2026-10-03.md) · [Domain map](../../../../../docs/design-system/SELECTION_CONTROLS_FILTER_STATE_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Delivery history sheet stages date range and one status; Apply commits, dismissal discards draft, Reset clears committed filters immediately and closes. Custom dates use a date-range picker and block Apply until chosen. Availability pill exposes Online/Offline and a busy spinner. DeliveryChipRow uses filled brand choices; custom interactive chips need selected semantic verification.

## Proposed direction

Keep status mutually exclusive, dates staged, and Reset explicitly immediate. Make selection visible by symbol/border as well as color and preserve an announced availability busy state distinct from filter selection.

| Panel | Intent |
| --- | --- |
| Availability and checkbox atoms | Offline availability switch OFF with clear Offline text; alternate busy specimen Changing availability… static progress glyph and inert switch. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled. Do not introduce multi-status selection. |
| History selection | Radio status group All statuses selected; Delivered, Cancelled, Returned unselected, exactly one. Separate single-choice date chips This week selected, Last week unselected, Custom unselected. Selected fills black in light or white in dark, foreground inverse; burgundy secondary container accents, orange focus only. |
| Custom date picker | Custom range field empty Choose dates, calendar icon. Picker surface Select date range with Start date and End date empty fields and Cancel / Done. Disabled Apply filters with adjacent Choose start and end dates. No fabricated date values. |
| Apply, cancel and reset | Draft history filters panel. Primary Apply filters; secondary Cancel; explicit Reset now action. Diagram Draft → Apply → Applied filters. Text Cancel discards draft. Reset now clears applied filters and closes. No fake result count, no delivery success check. |

Preservation and gaps:

- Reset is an immediate committed clear; do not depict it as Clear draft.
- Do not invent live result-count badges; source intentionally uses Apply filters without a count.
- Checkbox atom examples are reference patterns, not multi-status history filters. The status group stays one choice.
- Custom control selection/keyboard focus and unavailable helper copy need runtime verification.
- DeliveryChipRow and DeliverySegmented pass button/label semantics to DeliveryInteractive, whose current wrapper has no selected parameter. Add explicit selected/group semantics as a future control extension; this asset task does not change runtime accessibility.

## Light

![Agrimore Delivery C11 light](agrimore-delivery-selection-controls-filter-state-light.png)

## Dark

![Agrimore Delivery C11 dark](agrimore-delivery-selection-controls-filter-state-dark.png)

