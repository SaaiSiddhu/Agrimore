# Agrimore Sales Associate — C04 image generation prompts

C04: Icons, labels and touch areas. Date: 2026-10-03. Tool: **built-in image_gen**.
Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. C04 owner approval is not recorded.

The [C01 v2 lock](../01-color-roles-theme-identity/lock.json) supplies approved palette, status colors, spacing scale, radii and border widths. All ten C01 images were inspected before generation. Light uses the corresponding C01 light skin reference. Dark uses C01 dark skin plus this app’s selected C04 light image for content and composition. Exact initial/refinement prompts and image inputs below preserve provenance. Discarded drafts remain session artifacts; only the selected pair is saved here.

These raster boards illustrate icon/label/target roles. Actual executable icon family fidelity, hit areas, accessible names/state and contrast require implementation and rendered testing. The label table is a proposed semantics mapping, not a screen-reader test result. Use manifest values for exact token/role implementation.

## Light

Selected asset: [agrimore-sales-associate-icons-labels-touch-areas-light.png](agrimore-sales-associate-icons-labels-touch-areas-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-light.png` · SHA-256 `5e40ab35853e74ff50cc1256d4445976f72d232fa3941b4393c073100e739e19`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-f511699d-3562-40c1-a401-df772d005990.png` · SHA-256 `076ec41b0461427484a11532be4325ea8c456d43fcb78443be10d425fcc5d175`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Sales Associate — light theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 light identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Premium royal blue; indigo and pearl/slate.
Header ONLY "Agrimore Sales Associate" and "Light" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #2D56C4; onPrimary #FFFFFF; support #6950A2; canvas #F7F8FC; surface #FFFFFF; raised #FBFCFF; text #192840; muted #61708B; border #DDE3F0; strongBorder #94A0B7; selected #EAF0FE; focus #2D56C4. All FILLED primary action buttons use EXACTLY background #2D56C4 and text/embedded icons #FFFFFF. Neutral light canvas, clean white/near-white panels, excellent contrast and quiet elevation. Admin professional blue must not become electric/royal blue.
Family/style: Retain SaIcons Lucide outline with 16 supporting / 20 control / 24 navigation roles. Calm consistent outline finance/identity icons; royal-blue actions and distinct indigo payout context. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#EDF1FB", "text": "#31549E"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Calm personal-finance composition: a generous associate code card and paired copy/share controls on the left; a separate indigo payout section below. Accessible-name mapping and compact icon role reference on the right; icon catalog on top and target/state specimens beneath. Royal blue controls; indigo payout heading and dimensional accents. No inventory table. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Wallet", "wallet"], ["Orders", "shopping bag"], ["Copy code", "two overlapping squares"], ["Share code", "three-node share"], ["Notifications", "bell"], ["Profile", "user"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Code actions". A neutral card reads "Associate code" and "AG-2048" with separate copy and share outline controls, visible labels "Copy code" and "Share code". Annotate "20 px glyph", "48 × 48 px target" on the copy control and "12 px gap" between controls. A separate indigo heading "Payout actions" above a royal-blue filled wallet-icon button "Review payout". Mark "52 px min height" and "8 px icon-label gap". Do not label a payout as paid or approved. Use C01 control radius 12 and card radius 18.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Copy code | Copy associate code AG-2048 | Enabled
Share code | Share associate code AG-2048 | Enabled
Review payout | Review payout request | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Code-action glyph | 20 px
Navigation glyph | 24 px
Icon-only target | 48 px
Primary button min height | 52 px
Adjacent target gap | 12 px
Panel "Target anatomy": one enlarged copy outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "20 × 20 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 20 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same copy glyph inside equal comfortable targets with readable captions EXACTLY ["Copy code", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #2D56C4; Selected uses #EAF0FE container and #2D56C4 glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.
```
<!-- prompt:light-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-f511699d-3562-40c1-a401-df772d005990.png` · SHA-256 `076ec41b0461427484a11532be4325ea8c456d43fcb78443be10d425fcc5d175`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-light.png` · SHA-256 `5e40ab35853e74ff50cc1256d4445976f72d232fa3941b4393c073100e739e19`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-b336f779-e89d-477b-95f6-e0478dab402e.png` · SHA-256 `e63f6579a9d3982fc79d6e4fe4c83e1fd17f5eaabaed98d7e60dc6cdd8d2d654`.

<!-- prompt:light-2:begin -->
```text
Use case: ui-mockup. Edit Image 1, the new Agrimore Sales Associate LIGHT C04 board; Image 2 is its approved C01 LIGHT skin reference. Correct ONLY the small "8 px icon-label gap" annotation beside/below the "Review payout" labeled button. Remove that annotation’s measurement arrow/bracket/dotted extension lines because they currently point to the wrong boundary or glyph width. Keep a clear plain-text note "Icon-label gap: 8 px" immediately below or beside that button, with no dimensional arrow attached to it. Preserve actual separation of the button icon and text. Do not remove the actual button, icon, label or related app/quote context. Preserve ALL other dimension guides, target anatomy, all six icon/target roles, all three accessible-label rows, four action states, six domain icons, palette, full layout and typography. Keep glyph vs target dimensions unchanged. No new panel, no extra explanation, no identity change, no cropped labels.
```
<!-- prompt:light-2:end -->

## Dark

Selected asset: [agrimore-sales-associate-icons-labels-touch-areas-dark.png](agrimore-sales-associate-icons-labels-touch-areas-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-dark.png` · SHA-256 `579b82781b7cac9f889ec36a11448bab868333024ad3f7c037e14d1c3997ec62`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/04-icons-labels-touch-areas/agrimore-sales-associate-icons-labels-touch-areas-light.png` · SHA-256 `e63f6579a9d3982fc79d6e4fe4c83e1fd17f5eaabaed98d7e60dc6cdd8d2d654`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-34cfa8ad-2856-4b09-9d9c-5d180dc37f66.png` · SHA-256 `9f5d33731248f9807747d678a8e353ed4cd5889cdfe0d432b678cfefd931f1f2`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Sales Associate — dark theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 dark identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Premium royal blue; indigo and pearl/slate.
Header ONLY "Agrimore Sales Associate" and "Dark" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #96B4FF; onPrimary #142241; support #C0ADE7; canvas #090B11; surface #131722; raised #1E2533; text #F2F5FC; muted #B9C5DD; border #354259; strongBorder #8393B2; selected #1B2C50; focus #96B4FF. All FILLED primary action buttons use EXACTLY background #96B4FF and text/embedded icons #142241. In particular dark mode primary labels are DARK on the light primary fill, not white. Use near-black canvas and genuinely dark grey surface/raised panels. No white content panels, electric blue/glow, bright background gradient or light-theme button fills.
Family/style: Retain SaIcons Lucide outline with 16 supporting / 20 control / 24 navigation roles. Calm consistent outline finance/identity icons; royal-blue actions and distinct indigo payout context. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#1A2B4C", "text": "#B2C8FF"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Calm personal-finance composition: a generous associate code card and paired copy/share controls on the left; a separate indigo payout section below. Accessible-name mapping and compact icon role reference on the right; icon catalog on top and target/state specimens beneath. Royal blue controls; indigo payout heading and dimensional accents. No inventory table. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Wallet", "wallet"], ["Orders", "shopping bag"], ["Copy code", "two overlapping squares"], ["Share code", "three-node share"], ["Notifications", "bell"], ["Profile", "user"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Code actions". A neutral card reads "Associate code" and "AG-2048" with separate copy and share outline controls, visible labels "Copy code" and "Share code". Annotate "20 px glyph", "48 × 48 px target" on the copy control and "12 px gap" between controls. A separate indigo heading "Payout actions" above a royal-blue filled wallet-icon button "Review payout". Mark "52 px min height" and "8 px icon-label gap". Do not label a payout as paid or approved. Use C01 control radius 12 and card radius 18.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Copy code | Copy associate code AG-2048 | Enabled
Share code | Share associate code AG-2048 | Enabled
Review payout | Review payout request | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Code-action glyph | 20 px
Navigation glyph | 24 px
Icon-only target | 48 px
Primary button min height | 52 px
Adjacent target gap | 12 px
Panel "Target anatomy": one enlarged copy outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "20 × 20 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 20 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same copy glyph inside equal comfortable targets with readable captions EXACTLY ["Copy code", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #96B4FF; Selected uses #1B2C50 container and #96B4FF glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.

STRICT THEME PAIR: Input Image 2 is the selected C04 LIGHT board for this SAME app, authoritative for CONTENT and COMPOSITION. Preserve its exact panel positions, six domain icons, six role rows, three accessible-name rows, full target-anatomy diagram/numerical equation, interaction labels, IDs/data and four state samples. Only convert its palette to the explicit approved DARK C01 tokens in Image 1. Do not copy old C01 panels. Keep plain-text "Icon-label gap: 8 px" notes from Image 2 where present, with NO measurement arrow, bracket or guide on that note. Do not reintroduce removed wrong guide boxes around text captions. The anatomy diagram measures actual glyph and full square target as separate bounds. DARK PRIMARY ACTION RULE: background #96B4FF; text AND embedded icon #142241. Use the exact light-brand-fill/dark-content appearance in Image 1 for any filled primary action, not dark saturated light-theme brand with white content. Dark selected states use #1B2C50 surface, #96B4FF glyph and a separate check/state caption; no green success badge in blue apps. Preserve supporting context color #C0ADE7. Unavailable sample remains muted and distinguishable from enabled.
```
<!-- prompt:dark-1:end -->

## Inherited C01 theme values

### Light

| Role | Hex |
| --- | --- |
| primary | #2D56C4 |
| onPrimary | #FFFFFF |
| support | #6950A2 |
| supportLabel | Supporting indigo |
| canvas | #F7F8FC |
| surface | #FFFFFF |
| raised | #FBFCFF |
| text | #192840 |
| muted | #61708B |
| border | #DDE3F0 |
| strongBorder | #94A0B7 |
| selected | #EAF0FE |
| focus | #2D56C4 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #E7F5ED | #146C43 |
| Warning | #FFF4D6 | #805400 |
| Error | #FDECEA | #B42318 |
| Info | #EDF1FB | #31549E |

### Dark

| Role | Hex |
| --- | --- |
| primary | #96B4FF |
| onPrimary | #142241 |
| support | #C0ADE7 |
| supportLabel | Supporting indigo |
| canvas | #090B11 |
| surface | #131722 |
| raised | #1E2533 |
| text | #F2F5FC |
| muted | #B9C5DD |
| border | #354259 |
| strongBorder | #8393B2 |
| selected | #1B2C50 |
| focus | #96B4FF |

| Status | Container | Text |
| --- | --- | --- |
| Success | #102C20 | #8DE0B0 |
| Warning | #302612 | #F1CE7B |
| Error | #341B1B | #FFA39C |
| Info | #1A2B4C | #B2C8FF |

## C04 domain specifications — proposal

Retain SaIcons Lucide outline with 16 supporting / 20 control / 24 navigation roles. Calm consistent outline finance/identity icons; royal-blue actions and distinct indigo payout context.

| Icon or target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Code-action glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 52 |
| Adjacent target gap | 12 |

| Visible label | Accessible name | Separate state |
| --- | --- | --- |
| Copy code | Copy associate code AG-2048 | Enabled |
| Share code | Share associate code AG-2048 | Enabled |
| Review payout | Review payout request | Enabled |

Target anatomy: 48 = 20 + 2 × 14. Calculated centering inset does not add a spacing token. Selected/action-state specimens are illustrative states, not proof of an operation completing.
