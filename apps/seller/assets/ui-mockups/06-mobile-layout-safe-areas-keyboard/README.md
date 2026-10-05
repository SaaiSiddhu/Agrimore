# Agrimore Seller — C06 mobile layout, safe areas and keyboard

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** Approved C01 identity remains locked. Static review references; runtime behavior and asset registration are unchanged.

Identity: Blue-teal with warm copper and cool neutral support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-seller-mobile-layout-safe-areas-keyboard-light.png) |
| Dark | [Open dark](agrimore-seller-mobile-layout-safe-areas-keyboard-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_BOARDS_2026-10-03.md) · [Codebase/domain mapping](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

Frame: **Bounded stock sheet**. Primary action: **Save stock**. Focused field: **Stock quantity**. All example data is synthetic.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Sheet inset | 24 |
| Field gap | 16 |
| Footer inset | 24 |
| Footer vertical | 12 |
| Action minimum | 48 |

SellerPage already separates scrolling content and its sticky footer. SellerSheetFrame has a flexible scrolling body, explicit viewInsets padding and a safe footer. The stock sheet uses an autofocus numeric input. Current sheet horizontal padding is 20px; the 24px role in this board is a proposed alignment with the locked spacing scale.

- Bound the sheet to the available height.
- Scroll the sheet body; reserve its footer.
- Apply the keyboard inset once at the sheet edge.
- Keep stock quantity visible during numeric entry.

The viewport diagrams illustrate body/keyboard allocation; they are not measured screenshots. Safe areas and keyboard sizes must come from the system. Controls can grow for large text. One keyboard-inset owner prevents double clearance.

## Light

![Agrimore Seller C06 light mobile layout reference](agrimore-seller-mobile-layout-safe-areas-keyboard-light.png)

## Dark

![Agrimore Seller C06 dark mobile layout reference](agrimore-seller-mobile-layout-safe-areas-keyboard-dark.png)

