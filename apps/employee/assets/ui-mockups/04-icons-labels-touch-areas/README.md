# Agrimore Sales Associate — icons, labels and touch areas

**C04 · 2026-10-03 · PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** These two Storybook-style boards use the [approved C01 identity](../01-color-roles-theme-identity/README.md). C04 is ready for design review; it is not owner-locked or implemented in runtime.

Identity: Premium royal blue; indigo and pearl/slate. Icon direction: Retain SaIcons Lucide outline with 16 supporting / 20 control / 24 navigation roles. Calm consistent outline finance/identity icons; royal-blue actions and distinct indigo payout context.

| Icon or interaction role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Code-action glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 52 |
| Adjacent target gap | 12 |

Anatomy: **20 glyph inside 48 target**, centered with 14 per side. Glyph bounds and interaction bounds are different. Independent actions remain separately named and their target areas must not overlap.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Copy code | Copy associate code AG-2048 | Enabled |
| Share code | Share associate code AG-2048 | Enabled |
| Review payout | Review payout request | Enabled |

Accessible-name rows are documentation of proposed semantics, not executed screen-reader output. Actual semantics/hit areas and pixel-perfect color/icon rendering require later implementation verification. These are documentation assets and are not registered in pubspec.

- [Exact generation and refinement prompts](prompts.md)
- [Specifications and checksums](manifest.json)
- [Five-app gallery](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_BOARDS_2026-10-03.md)
- [Codebase domain mapping](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_DOMAIN_MAP_2026-10-03.md)

## Light

![Agrimore Sales Associate C04 light](agrimore-sales-associate-icons-labels-touch-areas-light.png)

## Dark

![Agrimore Sales Associate C04 dark](agrimore-sales-associate-icons-labels-touch-areas-dark.png)
