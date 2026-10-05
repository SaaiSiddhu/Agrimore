# Agrimore Seller — icons, labels and touch areas

**C04 · 2026-10-03 · PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** These two Storybook-style boards use the [approved C01 identity](../01-color-roles-theme-identity/README.md). C04 is ready for design review; it is not owner-locked or implemented in runtime.

Identity: Blue-teal; copper and cool neutrals. Icon direction: Retain the centralized SellerIcons Lucide outline family, 24-unit grid and nominal 2 px stroke at 24 px. Scale complete glyphs uniformly for 20 px controls; no mixed raw Material or FontAwesome control group.

| Icon or interaction role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Inventory control glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 48 |
| Adjacent target gap | 8 |

Anatomy: **20 glyph inside 48 target**, centered with 14 per side. Glyph bounds and interaction bounds are different. Independent actions remain separately named and their target areas must not overlap.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Edit stock | Edit stock for Fresh tomatoes | Enabled |
| Review quote | Review quote RFQ-2048 | Enabled |
| Filter | Filter catalogue | Enabled |

Accessible-name rows are documentation of proposed semantics, not executed screen-reader output. Actual semantics/hit areas and pixel-perfect color/icon rendering require later implementation verification. These are documentation assets and are not registered in pubspec.

- [Exact generation and refinement prompts](prompts.md)
- [Specifications and checksums](manifest.json)
- [Five-app gallery](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_BOARDS_2026-10-03.md)
- [Codebase domain mapping](../../../../../docs/design-system/ICONS_LABELS_TOUCH_AREAS_DOMAIN_MAP_2026-10-03.md)

## Light

![Agrimore Seller C04 light](agrimore-seller-icons-labels-touch-areas-light.png)

## Dark

![Agrimore Seller C04 dark](agrimore-seller-icons-labels-touch-areas-dark.png)
