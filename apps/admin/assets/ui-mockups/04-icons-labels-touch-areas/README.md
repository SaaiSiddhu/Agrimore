# Agrimore Admin — icons, labels and touch areas

**C04 · 2026-10-03 · PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** These two Storybook-style boards use the [approved C01 identity](../01-color-roles-theme-identity/README.md). C04 is ready for design review; it is not owner-locked or implemented in runtime.

Identity: Professional blue; cyan and steel/slate. Icon direction: Professional Material outlined operations icons, consistent optical weight. 20 px table actions with 24 navigation; centralize semantic aliases in a later migration rather than mix decorative families or replace domain symbols arbitrarily.

| Icon or interaction role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Table-action glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Interactive row min height | 48 |
| Adjacent target gap | 8 |

Anatomy: **20 glyph inside 48 target**, centered with 14 per side. Glyph bounds and interaction bounds are different. Independent actions remain separately named and their target areas must not overlap.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Filter | Filter seller applications | Enabled |
| Refresh | Refresh application list | Enabled |
| Review | Review seller application AGR-2048 | Enabled |

Accessible-name rows are documentation of proposed semantics, not executed screen-reader output. Actual semantics/hit areas and pixel-perfect color/icon rendering require later implementation verification. These are documentation assets and are not registered in pubspec.

- [Exact generation and refinement prompts](prompts.md)
- [Specifications and checksums](manifest.json)
- [Five-app gallery](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_BOARDS_2026-10-03.md)
- [Codebase domain mapping](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_DOMAIN_MAP_2026-10-03.md)

## Light

![Agrimore Admin C04 light](agrimore-admin-icons-labels-touch-areas-light.png)

## Dark

![Agrimore Admin C04 dark](agrimore-admin-icons-labels-touch-areas-dark.png)
