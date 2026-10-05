# Agrimore Admin — C05 motion, haptics and reduced motion

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C05 is a review proposal; approved C01 identity remains locked. These are still reference images, not runtime changes.

Identity: Professional blue; cyan and steel/slate.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-admin-motion-haptics-reduced-motion-light.png) |
| Dark | [Open dark](agrimore-admin-motion-haptics-reduced-motion-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/MOTION_HAPTICS_REDUCED_MOTION_BOARDS_2026-10-03.md) · [Codebase/domain mapping](../../../../../docs/design-system/MOTION_HAPTICS_REDUCED_MOTION_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

| Visual role | Duration (ms) |
| --- | --- |
| Hover / press | 80 |
| Row fade | 160 |
| Result reveal | 160 |
| Dialog enter | 240 |
| Reduced motion | 0 |

Curve: ease-out · cubic(0.2, 0, 0, 1). **0 ms applies to visual effects only**. Keep real timers, visible pending state and actual outcome. Haptics are optional, device supported and user enabled; haptic and reduced-motion preferences are separate.

## Light

![Agrimore Admin C05 light motion reference](agrimore-admin-motion-haptics-reduced-motion-light.png)

## Dark

![Agrimore Admin C05 dark motion reference](agrimore-admin-motion-haptics-reduced-motion-dark.png)

Numeric/hex targets are exact specifications; raster boards and curve sketches are approximate. No executable animation, measured device haptics or runtime accessibility certification is included.
