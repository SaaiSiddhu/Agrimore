# Agrimore Admin — C06 mobile layout, safe areas and keyboard

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** Approved C01 identity remains locked. Static review references; runtime behavior and asset registration are unchanged.

Identity: Professional institutional blue with cyan and steel/slate support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-admin-mobile-layout-safe-areas-keyboard-light.png) |
| Dark | [Open dark](agrimore-admin-mobile-layout-safe-areas-keyboard-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_BOARDS_2026-10-03.md) · [Codebase/domain mapping](../../../../../docs/design-system/MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

Frame: **Compact mobile editor**. Primary action: **Save changes**. Focused field: **Description**. All example data is synthetic.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Field gap | 12 |
| Section gap | 24 |
| Footer inset | 16 |
| Footer vertical | 12 |
| Action minimum | 48 |

Product editing uses a Form/TabBarView and a bottomNavigationBar containing Cancel and Save changes. The footer is not explicitly keyboard-aware. Admin auth uses resizeToAvoidBottomInset:false and manual input clearance, so a blanket resize-true replacement is inappropriate. The board proposes a keyboard-safe mobile editor footer and locked token styling.

- Keep editor sections inside one flexible scroll.
- Reserve Save changes and Cancel below the form.
- Stack actions when labels or text need more room.
- Keep the focused field above the action footer.

The viewport diagrams illustrate body/keyboard allocation; they are not measured screenshots. Safe areas and keyboard sizes must come from the system. Controls can grow for large text. One keyboard-inset owner prevents double clearance.

## Light

![Agrimore Admin C06 light mobile layout reference](agrimore-admin-mobile-layout-safe-areas-keyboard-light.png)

## Dark

![Agrimore Admin C06 dark mobile layout reference](agrimore-admin-mobile-layout-safe-areas-keyboard-dark.png)

