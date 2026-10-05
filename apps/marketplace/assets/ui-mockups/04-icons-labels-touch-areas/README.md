# Agrimore Marketplace — icons, labels and touch areas

**C04 · 2026-10-03 · PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** These two Storybook-style boards use the [approved C01 identity](../01-color-roles-theme-identity/README.md). C04 is ready for design review; it is not owner-locked or implemented in runtime.

Identity: Professional green; warm gold and natural stone. Icon direction: Material outlined commerce icons, one consistent optical weight. Default outlines; a filled heart only for saved state, with text and semantic state. Do not mix FontAwesome and Material within a control group.

| Icon or interaction role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Shopping action glyph | 24 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 48 |
| Adjacent target gap | 8 |

Anatomy: **24 glyph inside 48 target**, centered with 12 per side. Glyph bounds and interaction bounds are different. Independent actions remain separately named and their target areas must not overlap.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Save | Save Fresh tomatoes | Not saved |
| Add to cart | Add Fresh tomatoes to cart | Enabled |
| Cart · 2 | Open cart, 2 items | Enabled |

Accessible-name rows are documentation of proposed semantics, not executed screen-reader output. Actual semantics/hit areas and pixel-perfect color/icon rendering require later implementation verification. These are documentation assets and are not registered in pubspec.

- [Exact generation and refinement prompts](prompts.md)
- [Specifications and checksums](manifest.json)
- [Five-app gallery](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_BOARDS_2026-10-03.md)
- [Codebase domain mapping](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_DOMAIN_MAP_2026-10-03.md)

## Light

![Agrimore Marketplace C04 light](agrimore-marketplace-icons-labels-touch-areas-light.png)

## Dark

![Agrimore Marketplace C04 dark](agrimore-marketplace-icons-labels-touch-areas-dark.png)
