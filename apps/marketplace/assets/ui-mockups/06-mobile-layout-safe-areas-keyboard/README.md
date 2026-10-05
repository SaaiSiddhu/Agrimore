# Agrimore Marketplace — C06 mobile layout, safe areas and keyboard

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** Approved C01 identity remains locked. Static review references; runtime behavior and asset registration are unchanged.

Identity: Professional green with warm gold and natural stone support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-marketplace-mobile-layout-safe-areas-keyboard-light.png) |
| Dark | [Open dark](agrimore-marketplace-mobile-layout-safe-areas-keyboard-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_BOARDS_2026-10-03.md) · [Codebase/domain mapping](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

Frame: **Scrollable task page**. Primary action: **Save address**. Focused field: **Pincode**. All example data is synthetic.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Field gap | 16 |
| Section gap | 24 |
| Footer inset | 16 |
| Footer vertical | 12 |
| Action minimum | 48 |

The checkout address screen positions a non-scrolling bottom form over a map, with a fixed map-control offset and a 42px save control. The address page below is a target proposal, not a claim that the current screen has been migrated.

- Keep address fields in one flexible scroll region.
- Reserve the footer outside the form scroll.
- Reveal the focused field and its validation text.
- Measure safe areas again when the keyboard changes.

The viewport diagrams illustrate body/keyboard allocation; they are not measured screenshots. Safe areas and keyboard sizes must come from the system. Controls can grow for large text. One keyboard-inset owner prevents double clearance.

## Light

![Agrimore Marketplace C06 light mobile layout reference](agrimore-marketplace-mobile-layout-safe-areas-keyboard-light.png)

## Dark

![Agrimore Marketplace C06 dark mobile layout reference](agrimore-marketplace-mobile-layout-safe-areas-keyboard-dark.png)

