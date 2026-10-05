# Agrimore Admin — C04 image generation prompts

C04: Icons, labels and touch areas. Date: 2026-10-03. Tool: **built-in image_gen**.
Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. C04 owner approval is not recorded.

The [C01 v2 lock](../01-color-roles-theme-identity/lock.json) supplies approved palette, status colors, spacing scale, radii and border widths. All ten C01 images were inspected before generation. Light uses the corresponding C01 light skin reference. Dark uses C01 dark skin plus this app’s selected C04 light image for content and composition. Exact initial/refinement prompts and image inputs below preserve provenance. Discarded drafts remain session artifacts; only the selected pair is saved here.

These raster boards illustrate icon/label/target roles. Actual executable icon family fidelity, hit areas, accessible names/state and contrast require implementation and rendered testing. The label table is a proposed semantics mapping, not a screen-reader test result. Use manifest values for exact token/role implementation.

## Light

Selected asset: [agrimore-admin-icons-labels-touch-areas-light.png](agrimore-admin-icons-labels-touch-areas-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-light.png` · SHA-256 `fca2bb37fc479e39d3bdc3da8c45e5968af3840edf4ad66312e18a6860d4c1a4`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-cea28255-b3c0-42ba-9605-15627b6ba2ff.png` · SHA-256 `b1a87ac23ba8e7b6527c5e5fe91a094387532190b0e3e2500459e7e94ce7d871`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Admin — light theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 light identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Professional blue; cyan and steel/slate.
Header ONLY "Agrimore Admin" and "Light" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #1D4F91; onPrimary #FFFFFF; support #087E8B; canvas #F5F7FB; surface #FFFFFF; raised #F9FBFE; text #14243B; muted #5B6B82; border #D8E1EF; strongBorder #8C9DB5; selected #E8EFF8; focus #1D4F91. All FILLED primary action buttons use EXACTLY background #1D4F91 and text/embedded icons #FFFFFF. Neutral light canvas, clean white/near-white panels, excellent contrast and quiet elevation. Admin professional blue must not become electric/royal blue.
Family/style: Professional Material outlined operations icons, consistent optical weight. 20 px table actions with 24 navigation; centralize semantic aliases in a later migration rather than mix decorative families or replace domain symbols arbitrarily. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E8F0FA", "text": "#24528C"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Structured workstation layout: an application list/action row dominates the left; cyan context/label-mapping and icon role panels sit on the right. Top six-glyph catalog; bottom 48 px target anatomy and focused/selected/disabled samples. Compact optical glyphs with comfortable full hit areas. Professional blue must remain distinctly muted from Sales Associate royal blue. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Approvals", "shield with check"], ["Filter", "sliders"], ["Refresh", "circular arrow"], ["Finance", "receipt"], ["Users", "people"], ["Audit", "document with list"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Application actions". Show a flat record "Seller application" and "AGR-2048" with a blue shield/check outline icon button labeled "Review". Above the record, two separate square filter and refresh controls with visible labels "Filter", "Refresh". Annotate "20 px glyph", "48 × 48 px target" on Filter, "8 px gap" between targets, and "48 px row min height" on the record. Under a cyan heading "Contextual action names" show a small plain-text reference "Review opens application details". It is ordinary context, not an Info status alert. Use C01 control radius 8 and panel radius 12. No approve checkmark action masquerading as a generic Review shortcut.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Filter | Filter seller applications | Enabled
Refresh | Refresh application list | Enabled
Review | Review seller application AGR-2048 | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Table-action glyph | 20 px
Navigation glyph | 24 px
Icon-only target | 48 px
Interactive row min height | 48 px
Adjacent target gap | 8 px
Panel "Target anatomy": one enlarged sliders outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "20 × 20 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 20 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same sliders glyph inside equal comfortable targets with readable captions EXACTLY ["Filter", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #1D4F91; Selected uses #E8EFF8 container and #1D4F91 glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.
```
<!-- prompt:light-1:end -->

## Dark

Selected asset: [agrimore-admin-icons-labels-touch-areas-dark.png](agrimore-admin-icons-labels-touch-areas-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-dark.png` · SHA-256 `d232ad575ce49311efa785e4dfc2fc781c81d297184215e8f66979536f67041b`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/04-icons-labels-touch-areas/agrimore-admin-icons-labels-touch-areas-light.png` · SHA-256 `b1a87ac23ba8e7b6527c5e5fe91a094387532190b0e3e2500459e7e94ce7d871`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-04ec875b-aa87-4f62-b9fc-8f2618f95d16.png` · SHA-256 `bbf6a5c3e4723034a82843ecb7d72112b9e722ac463338f4ba86f8541f84383b`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Admin — dark theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 dark identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Professional blue; cyan and steel/slate.
Header ONLY "Agrimore Admin" and "Dark" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #93B3EC; onPrimary #0D203E; support #7BCBD5; canvas #080B10; surface #121922; raised #1D2837; text #F2F6FC; muted #B5C3D6; border #314157; strongBorder #74869E; selected #192E4A; focus #93B3EC. All FILLED primary action buttons use EXACTLY background #93B3EC and text/embedded icons #0D203E. In particular dark mode primary labels are DARK on the light primary fill, not white. Use near-black canvas and genuinely dark grey surface/raised panels. No white content panels, electric blue/glow, bright background gradient or light-theme button fills.
Family/style: Professional Material outlined operations icons, consistent optical weight. 20 px table actions with 24 navigation; centralize semantic aliases in a later migration rather than mix decorative families or replace domain symbols arbitrarily. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#172A42", "text": "#AFCCF6"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Structured workstation layout: an application list/action row dominates the left; cyan context/label-mapping and icon role panels sit on the right. Top six-glyph catalog; bottom 48 px target anatomy and focused/selected/disabled samples. Compact optical glyphs with comfortable full hit areas. Professional blue must remain distinctly muted from Sales Associate royal blue. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Approvals", "shield with check"], ["Filter", "sliders"], ["Refresh", "circular arrow"], ["Finance", "receipt"], ["Users", "people"], ["Audit", "document with list"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Application actions". Show a flat record "Seller application" and "AGR-2048" with a blue shield/check outline icon button labeled "Review". Above the record, two separate square filter and refresh controls with visible labels "Filter", "Refresh". Annotate "20 px glyph", "48 × 48 px target" on Filter, "8 px gap" between targets, and "48 px row min height" on the record. Under a cyan heading "Contextual action names" show a small plain-text reference "Review opens application details". It is ordinary context, not an Info status alert. Use C01 control radius 8 and panel radius 12. No approve checkmark action masquerading as a generic Review shortcut.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Filter | Filter seller applications | Enabled
Refresh | Refresh application list | Enabled
Review | Review seller application AGR-2048 | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Table-action glyph | 20 px
Navigation glyph | 24 px
Icon-only target | 48 px
Interactive row min height | 48 px
Adjacent target gap | 8 px
Panel "Target anatomy": one enlarged sliders outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "20 × 20 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 20 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same sliders glyph inside equal comfortable targets with readable captions EXACTLY ["Filter", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #93B3EC; Selected uses #192E4A container and #93B3EC glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.

STRICT THEME PAIR: Input Image 2 is the selected C04 LIGHT board for this SAME app, authoritative for CONTENT and COMPOSITION. Preserve its exact panel positions, six domain icons, six role rows, three accessible-name rows, full target-anatomy diagram/numerical equation, interaction labels, IDs/data and four state samples. Only convert its palette to the explicit approved DARK C01 tokens in Image 1. Do not copy old C01 panels. Keep plain-text "Icon-label gap: 8 px" notes from Image 2 where present, with NO measurement arrow, bracket or guide on that note. Do not reintroduce removed wrong guide boxes around text captions. The anatomy diagram measures actual glyph and full square target as separate bounds. DARK PRIMARY ACTION RULE: background #93B3EC; text AND embedded icon #0D203E. Use the exact light-brand-fill/dark-content appearance in Image 1 for any filled primary action, not dark saturated light-theme brand with white content. Dark selected states use #192E4A surface, #93B3EC glyph and a separate check/state caption; no green success badge in blue apps. Preserve supporting context color #7BCBD5. Unavailable sample remains muted and distinguishable from enabled.
```
<!-- prompt:dark-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-04ec875b-aa87-4f62-b9fc-8f2618f95d16.png` · SHA-256 `bbf6a5c3e4723034a82843ecb7d72112b9e722ac463338f4ba86f8541f84383b`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-dark.png` · SHA-256 `d232ad575ce49311efa785e4dfc2fc781c81d297184215e8f66979536f67041b`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-7a13ea32-7ddf-4f46-a821-5a1874308265.png` · SHA-256 `09c3c4e8e610a8998b625124ab64fd357b7637fe745404c1f792988015b22507`.

<!-- prompt:dark-2:begin -->
```text
Use case: ui-mockup. Edit Image 1, the Agrimore Admin DARK C04 board; Image 2 is the APPROVED C01 DARK identity reference. Make only these small dark-theme annotation/contrast corrections: in Action states beneath Unavailable keep "Disabled state" but REMOVE the stale light-theme hex caption "#5B6B82". Do not replace it with a newly invented disabled token: C01 does not define a separate disabled hex role. The disabled filter glyph stays visibly muted. In the pale-blue filled Review button in Application actions, use a simple shield-check OUTLINE glyph in dark onPrimary #0D203E, matching the dark Review text; remove the blue filled shield/white check treatment. Button fill remains #93B3EC. Preserve everything else: all six catalog icons, layout, icon-role values, three accessible-label rows, numerical target diagram/equation, state shapes, cyan context, focus #93B3EC and selected #192E4A captions, identity, heading, guides and footer. Do not recreate old C01 panels or change any wording, spacing, figures or other colors. Full uncropped board.
```
<!-- prompt:dark-2:end -->

## Inherited C01 theme values

### Light

| Role | Hex |
| --- | --- |
| primary | #1D4F91 |
| onPrimary | #FFFFFF |
| support | #087E8B |
| supportLabel | Supporting cyan |
| canvas | #F5F7FB |
| surface | #FFFFFF |
| raised | #F9FBFE |
| text | #14243B |
| muted | #5B6B82 |
| border | #D8E1EF |
| strongBorder | #8C9DB5 |
| selected | #E8EFF8 |
| focus | #1D4F91 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #E7F5ED | #146C43 |
| Warning | #FFF4D6 | #805400 |
| Error | #FDECEA | #B42318 |
| Info | #E8F0FA | #24528C |

### Dark

| Role | Hex |
| --- | --- |
| primary | #93B3EC |
| onPrimary | #0D203E |
| support | #7BCBD5 |
| supportLabel | Supporting cyan |
| canvas | #080B10 |
| surface | #121922 |
| raised | #1D2837 |
| text | #F2F6FC |
| muted | #B5C3D6 |
| border | #314157 |
| strongBorder | #74869E |
| selected | #192E4A |
| focus | #93B3EC |

| Status | Container | Text |
| --- | --- | --- |
| Success | #102C20 | #8DE0B0 |
| Warning | #302612 | #F1CE7B |
| Error | #341B1B | #FFA39C |
| Info | #172A42 | #AFCCF6 |

## C04 domain specifications — proposal

Professional Material outlined operations icons, consistent optical weight. 20 px table actions with 24 navigation; centralize semantic aliases in a later migration rather than mix decorative families or replace domain symbols arbitrarily.

| Icon or target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Table-action glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Interactive row min height | 48 |
| Adjacent target gap | 8 |

| Visible label | Accessible name | Separate state |
| --- | --- | --- |
| Filter | Filter seller applications | Enabled |
| Refresh | Refresh application list | Enabled |
| Review | Review seller application AGR-2048 | Enabled |

Target anatomy: 48 = 20 + 2 × 14. Calculated centering inset does not add a spacing token. Selected/action-state specimens are illustrative states, not proof of an operation completing.
