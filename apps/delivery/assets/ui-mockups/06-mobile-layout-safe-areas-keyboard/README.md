# Agrimore Delivery — C06 mobile layout, safe areas and keyboard

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** Approved C01 identity remains locked. Static review references; runtime behavior and asset registration are unchanged.

Identity: Black/white with burgundy and burnt orange support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-delivery-mobile-layout-safe-areas-keyboard-light.png) |
| Dark | [Open dark](agrimore-delivery-mobile-layout-safe-areas-keyboard-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_BOARDS_2026-10-03.md) · [Codebase/domain mapping](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

Frame: **Field-friendly task page**. Primary action: **Send request**. Focused field: **Message**. All example data is synthetic.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Field gap | 16 |
| Section gap | 24 |
| Footer inset | 16 |
| Footer vertical | 12 |
| Action minimum | 56 |

The support form and delivery-problem panel put submit actions inside scroll content. DeliveryBottomActionBar defines manual keyboard padding, but no call sites were found in the scanned source. Its adoption and the sticky support footer shown here are proposals. A resizing parent plus the helper's manual inset must not double-apply clearance.

- Use a large action reachable above the keyboard.
- Keep the message and its helper text visible.
- Separate map gestures from sheet scrolling.
- Use one owner for keyboard clearance.

The viewport diagrams illustrate body/keyboard allocation; they are not measured screenshots. Safe areas and keyboard sizes must come from the system. Controls can grow for large text. One keyboard-inset owner prevents double clearance.

## Light

![Agrimore Delivery C06 light mobile layout reference](agrimore-delivery-mobile-layout-safe-areas-keyboard-light.png)

## Dark

![Agrimore Delivery C06 dark mobile layout reference](agrimore-delivery-mobile-layout-safe-areas-keyboard-dark.png)

