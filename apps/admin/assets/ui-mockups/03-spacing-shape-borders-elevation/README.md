# Agrimore Admin — spacing, shape, borders and elevation

**C03 · 2026-10-03 · PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** These two app-specific Storybook boards use the [approved C01 identity](../01-color-roles-theme-identity/README.md). They are ready for design review; C03 is not owner-locked or implemented in runtime code.

Identity: Professional blue, cyan and steel/slate.

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Desktop page inset | 24 |
| Panel padding | 16 |
| Table cell padding | 12 |
| Column gap | 16 |
| Section gap | 32 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius mapped by C03 |
| --- | --- |
| Control | 8 |
| Card | 12 |
| Sheet / dialog | 16 |

Borders: Default 1 px, Strong 1 px, Focus 2 px, using this app’s C01 theme colors. Flat → Approval table; Soft → Review panel; Raised → Review dialog.

Minimum controls can grow with text. System/keyboard insets are additive; the board measurements are logical UI roles, not literal raster pixels. Raster colors are illustrative; use the inherited values in [manifest.json](manifest.json) for implementation. These images are documentation assets and are not registered in pubspec.

- [Exact generation and refinement prompts](prompts.md)
- [Specifications and checksums](manifest.json)
- [Five-app gallery](../../../../../docs/design-system/SPACING_SHAPE_BORDERS_ELEVATION_BOARDS_2026-10-03.md)
- [Codebase domain mapping](../../../../../docs/design-system/SPACING_SHAPE_BORDERS_ELEVATION_DOMAIN_MAP_2026-10-03.md)

## Light

![Agrimore Admin C03 light](agrimore-admin-spacing-shape-borders-elevation-light.png)

## Dark

![Agrimore Admin C03 dark](agrimore-admin-spacing-shape-borders-elevation-dark.png)
