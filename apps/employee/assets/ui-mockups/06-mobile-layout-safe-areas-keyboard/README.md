# Agrimore Sales Associate — C06 mobile layout, safe areas and keyboard

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** Approved C01 identity remains locked. Static review references; runtime behavior and asset registration are unchanged.

Identity: Premium royal blue with muted indigo, pearl and slate support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-sales-associate-mobile-layout-safe-areas-keyboard-light.png) |
| Dark | [Open dark](agrimore-sales-associate-mobile-layout-safe-areas-keyboard-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_BOARDS_2026-10-03.md) · [Codebase/domain mapping](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

Frame: **Calm financial task page**. Primary action: **Review payout request**. Focused field: **Payout amount**. All example data is synthetic.

| Target role | px |
| --- | --- |
| Page inset | 24 |
| Field gap | 16 |
| Section gap | 24 |
| Footer inset | 24 |
| Footer vertical | 16 |
| Action minimum | 52 |

The payout request screen uses a 16px-padded scrollable form and a review button inside the content. Review remains gated by account, balance and amount validation. The board proposes a separate sticky review footer and 24px page inset; it does not submit a payout or imply payment completion.

- Keep amount and eligibility guidance together.
- Reserve the review action outside the scroll.
- Reveal the amount field during numeric entry.
- Let financial labels wrap at larger text sizes.

The viewport diagrams illustrate body/keyboard allocation; they are not measured screenshots. Safe areas and keyboard sizes must come from the system. Controls can grow for large text. One keyboard-inset owner prevents double clearance.

## Light

![Agrimore Sales Associate C06 light mobile layout reference](agrimore-sales-associate-mobile-layout-safe-areas-keyboard-light.png)

## Dark

![Agrimore Sales Associate C06 dark mobile layout reference](agrimore-sales-associate-mobile-layout-safe-areas-keyboard-dark.png)

