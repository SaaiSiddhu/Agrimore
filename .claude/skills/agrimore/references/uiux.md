# `uiux` lane — consistency across the five apps through `agrimore_ui` (OWNER_DECISION D-UIUX, 2026-09-04)

**Scope, stated honestly.** Agrimore has **no written design system, no token pipeline, no
accessibility gates, no Storybook, no brand constitution.** What exists is `packages/agrimore_ui`:
a theme (`AppTheme`, `AppColors`, `AppTextStyles`), responsive helpers, 15 common widgets and two
helpers. The owner chose (D-UIUX) that this lane enforces **consistency through that package**, not
an invented aesthetic. The lane therefore has three rules and one stop condition, and reports
everything else as observation. **Brand, marketing site, landing page and logo work are HOLD** — a
separate future decision; say so and stop if asked.

## 1. Hard rules

1. **Reuse before you build.** If `agrimore_ui` has an equivalent (§2), use it. **`ZERO_NEW_WIDGETS`
   is a stop condition**: a new widget that duplicates an `agrimore_ui` widget's purpose halts the
   phase and is reported; extending the shared widget (with a five-app analyze) is the path.
2. **Theme, not literals.** New code takes colour from `AppColors` and text style from
   `AppTextStyles`/`Theme.of(context)`; a new `Color(0x…)` where `AppColors` has the named colour is a
   finding. Dark mode is real in every app (`darkTheme` declared ×5) — verify both.
3. **Responsive through `agrimore_ui/responsive`** (`Breakpoints`, `ResponsiveHelper`, `SizeConfig`),
   mobile first; marketplace and admin ship web builds, so a screen is checked at a phone width and
   at a desktop width when it has a `web_*` variant.
4. Single agent. No design "explorations" that fan out; no subagents.

## 2. The canonical inventory (measured 2026-09-04 at `c8f6f30`; re-verify paths)

```
Themes       packages/agrimore_ui/lib/themes/app_theme.dart · app_colors.dart (primary 0xFF0D9B5C Emerald) · app_text_styles.dart
Responsive   packages/agrimore_ui/lib/responsive/{breakpoints,responsive,responsive_helper,size_config}.dart
Widgets      packages/agrimore_ui/lib/widgets/common/  custom_button · custom_text_field · custom_app_bar · custom_bottom_nav
             · custom_drawer · loading_indicator · loading_overlay · shimmer_loading · empty_state_widget · error_view
             · error_widget · rating_widget · badge_widget · search_bar_widget · network_image_widget · confirmation_dialog
             packages/agrimore_ui/lib/widgets/premium_splash_screen.dart · snackbar_helper.dart · dialog_helper.dart
Barrel       packages/agrimore_ui/lib/agrimore_ui.dart (re-exports agrimore_core; `hide ButtonType, CustomButton` on bottom nav)
Assets       packages/agrimore_ui/assets/icons/ (no associate icon — apps/employee's splash still uses admin_logo.png)
Fonts        NotoSans (marketplace, admin) · google_fonts + font_awesome_flutter ^11 (FaIconData, never < 11)
```

Adoption facts (files): marketplace imports `agrimore_ui` in 113, uses `AppColors` in 95, inline
`ThemeData(` in 2; admin 55 / 40 / 3 **and keeps a parallel theme set at `apps/admin/lib/app/themes/`
(`admin_colors.dart`, `admin_theme.dart`, `app_colors.dart`, `app_text_styles.dart`)**; seller 4 / 0 /
1 (inline theme in `app.dart`); delivery 2 / 0 / 1 (inline); employee 3 / 2 / 1 (inline). So: the
shared theme is canonical for marketplace; admin has a documented fork; seller/delivery/employee are
inline. **Do not "fix" that in a feature phase** — migrating an app's theme to `agrimore_ui` is its
own bounded phase with a visual before/after.

## 3. Workflow for any UI change

1. **Locate** the live files: which app, which theme it actually uses (`git grep -n "ThemeData("
   apps/<app>/lib/app/app.dart`), what `agrimore_ui` already provides (`git grep -n "<Widget>"`).
2. **Classify** the ask: verified defect, consistency gap, roadmap idea, or brand/marketing (HOLD).
3. **Compose** from the inventory; if a primitive is missing, stop and report (rule 1).
4. **Prove**: `flutter analyze` in the touched app (and all five if `packages/agrimore_ui` moved);
   run the screen — AVD `Pixel_8_API_35` via `flutter run`, or web via `.claude/launch.json`
   (`marketplace-web`, port 8090) in the browser preview — light AND dark; phone width, plus desktop
   for a `web_*` screen. Screens behind `AuthGuard` need a real OTP login against production and a
   real 2Factor credit: do not do that for a layout; mount the screen in a throwaway preview entry
   point with mock providers, screenshot, delete the entry point, and **say what was not seen**.
5. **Report** exact paths, commands, exit codes, screenshots' paths, and what you did not do.

## 4. Validation commands

```bash
(cd apps/<app> && flutter analyze)                                   # 0 errors; compare warnings/infos with the baseline
git diff <base>..HEAD -- 'apps/*/lib/**.dart' | grep -nE '^\+.*Color\(0x'          # new literals
git diff <base>..HEAD --name-only | grep -E 'packages/agrimore_ui/'   # → five-app analyze mandatory
git diff <base>..HEAD -- '*.dart' | grep -nE '^\+class \w+(Button|TextField|AppBar|Dialog|EmptyState|Loading)'   # duplicate-widget smell
```

## 5. Lane report

```
UIUX LANE — <phase>
Verdict: PASS | PASS_WITH_FINDINGS | BLOCKING | HOLD (brand/marketing)
Components used (path) · new widgets: 0 (or STOP with the duplicated agrimore_ui widget named)
Theme: app's actual theme source · new colour literals (path:line) · dark mode checked (yes/no)
Viewports checked: phone / desktop-web × light / dark — screenshot paths · not seen: …
Gates run: analyze per app (errors/warnings/infos) · five-app when agrimore_ui moved
Findings: severity · path:line · rule · fix
```

`BLOCKING` = a duplicate of an `agrimore_ui` widget, a shared-widget change without the five-app
analyze, a `font_awesome_flutter` downgrade below 11, a screen that cannot render in dark mode, or
brand/marketing work attempted under this lane.
