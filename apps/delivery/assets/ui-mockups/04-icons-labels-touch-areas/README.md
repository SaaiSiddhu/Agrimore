# Agrimore Delivery — icons, labels and touch areas

**C04 · 2026-10-03 · PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** These two Storybook-style boards use the [approved C01 identity](../01-color-roles-theme-identity/README.md). C04 is ready for design review; it is not owner-locked or implemented in runtime.

Identity: Black/white; burgundy and burnt orange. Icon direction: Retain centralized DeliveryIcons Lucide outline and the existing house600 home exception. Regular glyphs 20/24; propose 28 px for critical field-task controls, scaling the same family uniformly rather than inventing heavier random strokes.

| Icon or interaction role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Standard control glyph | 24 |
| Field action glyph | 28 |
| Standard target | 48 |
| Field action target | 56 |
| Adjacent field gap | 16 |

Anatomy: **28 glyph inside 56 target**, centered with 14 per side. Glyph bounds and interaction bounds are different. Independent actions remain separately named and their target areas must not overlap.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Route | Open pickup route | Enabled |
| Call seller | Call pickup seller | Enabled |
| Add proof | Add pickup proof photo | Enabled |

Accessible-name rows are documentation of proposed semantics, not executed screen-reader output. Actual semantics/hit areas and pixel-perfect color/icon rendering require later implementation verification. These are documentation assets and are not registered in pubspec.

- [Exact generation and refinement prompts](prompts.md)
- [Specifications and checksums](manifest.json)
- [Five-app gallery](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_BOARDS_2026-10-03.md)
- [Codebase domain mapping](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_DOMAIN_MAP_2026-10-03.md)

## Light

![Agrimore Delivery C04 light](agrimore-delivery-icons-labels-touch-areas-light.png)

## Dark

![Agrimore Delivery C04 dark](agrimore-delivery-icons-labels-touch-areas-dark.png)
