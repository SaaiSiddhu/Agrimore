# Agrimore Delivery — C04 image generation prompts

C04: Icons, labels and touch areas. Date: 2026-10-03. Tool: **built-in image_gen**.
Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. C04 owner approval is not recorded.

The [C01 v2 lock](../01-color-roles-theme-identity/lock.json) supplies approved palette, status colors, spacing scale, radii and border widths. All ten C01 images were inspected before generation. Light uses the corresponding C01 light skin reference. Dark uses C01 dark skin plus this app’s selected C04 light image for content and composition. Exact initial/refinement prompts and image inputs below preserve provenance. Discarded drafts remain session artifacts; only the selected pair is saved here.

These raster boards illustrate icon/label/target roles. Actual executable icon family fidelity, hit areas, accessible names/state and contrast require implementation and rendered testing. The label table is a proposed semantics mapping, not a screen-reader test result. Use manifest values for exact token/role implementation.

## Light

Selected asset: [agrimore-delivery-icons-labels-touch-areas-light.png](agrimore-delivery-icons-labels-touch-areas-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-light.png` · SHA-256 `2384d327a37606012a2f3dc2d9427b63447ce9be1ae6b121d1294cc62872e383`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-2b869169-178a-409b-aac4-5fd90b1f820f.png` · SHA-256 `ec48df6bf16159be1465a1dc142c3875463be82610b4117d61bb796bb44aa3b2`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Delivery — light theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 light identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Black/white; burgundy and burnt orange.
Header ONLY "Agrimore Delivery" and "Light" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #191919; onPrimary #FFFFFF; support #A94D24; canvas #F8F7F6; surface #FFFFFF; raised #FAF9F8; text #1C1C1C; muted #686260; border #DDD7D4; strongBorder #A49993; selected #F5E7EC; focus #A94D24; burgundy #7A2840. All FILLED primary action buttons use EXACTLY background #191919 and text/embedded icons #FFFFFF. Neutral light canvas, clean white/near-white panels, excellent contrast and quiet elevation. Admin professional blue must not become electric/royal blue.
Family/style: Retain centralized DeliveryIcons Lucide outline and the existing house600 home exception. Regular glyphs 20/24; propose 28 px for critical field-task controls, scaling the same family uniformly rather than inventing heavier random strokes. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FBEDE3", "text": "#88451E"}, {"role": "Error", "container": "#F5E7EC", "text": "#7A2840"}, {"role": "Info", "container": "#ECEAE8", "text": "#59534F"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Glanceable field operations layout: large pickup task strip and three widely separated labeled field controls dominate the center-left; cash context is a quiet burgundy section, not a navigation action. Icon catalog on top; large target anatomy, label map and state samples in clean side/bottom panels. Black/white dominates, burgundy context, orange dimensional/focus guides. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Pickup", "storefront"], ["Route", "route with endpoints"], ["Call", "phone handset"], ["Proof", "camera"], ["Cash", "banknote"], ["Support", "headset"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Field actions" with "Next pickup" and "2.4 km". Show THREE separate rounded-square field controls: route icon with visible "Route", phone handset with "Call seller", camera with "Add proof". Each has a "56 × 56 px target", 28 px glyph, and "16 px gap" between target boundaries. Annotate ONE enlarged phone control only, not all three. Under them a burgundy context line reads "Cash to collect" and "₹960.00"; this money context is not a button. Include one wide primary button "View current job" with a package outline icon and "56 px min height", plus "8 px icon-label gap". Use 8 px control radius and 12 px task card radius. Burnt orange guides and focus; normal control icons use readable black/white.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Route | Open pickup route | Enabled
Call seller | Call pickup seller | Enabled
Add proof | Add pickup proof photo | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Standard control glyph | 24 px
Field action glyph | 28 px
Standard target | 48 px
Field action target | 56 px
Adjacent field gap | 16 px
Panel "Target anatomy": one enlarged phone handset outline glyph centered inside an OUTER square dashed measurement boundary labeled "56 × 56 px target". A smaller INNER dashed square bounds the glyph, labeled "28 × 28 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 56 = 28 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same phone handset glyph inside equal comfortable targets with readable captions EXACTLY ["Call seller", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #A94D24; Selected uses #F5E7EC container and #191919 glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.
```
<!-- prompt:light-1:end -->

## Dark

Selected asset: [agrimore-delivery-icons-labels-touch-areas-dark.png](agrimore-delivery-icons-labels-touch-areas-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-dark.png` · SHA-256 `745bda063c678184a1c0dc206bab60f45c659f08e0a5824a95fc19e4171385c4`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/04-icons-labels-touch-areas/agrimore-delivery-icons-labels-touch-areas-light.png` · SHA-256 `ec48df6bf16159be1465a1dc142c3875463be82610b4117d61bb796bb44aa3b2`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-e5abcc85-7eeb-43b7-8235-f3359aeda2ca.png` · SHA-256 `7fdb1df747debc044d8ce9be6c4ff4dd94b7b86cb84cfc6d01d290a238fb391c`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Delivery — dark theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 dark identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Black/white; burgundy and burnt orange.
Header ONLY "Agrimore Delivery" and "Dark" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #F4F4F4; onPrimary #151515; support #ECA06D; canvas #090909; surface #151515; raised #222222; text #F5F3F2; muted #C3BAB7; border #3C3633; strongBorder #91857E; selected #3B2029; focus #ECA06D; burgundy #DCA0B1. All FILLED primary action buttons use EXACTLY background #F4F4F4 and text/embedded icons #151515. In particular dark mode primary labels are DARK on the light primary fill, not white. Use near-black canvas and genuinely dark grey surface/raised panels. No white content panels, electric blue/glow, bright background gradient or light-theme button fills.
Family/style: Retain centralized DeliveryIcons Lucide outline and the existing house600 home exception. Regular glyphs 20/24; propose 28 px for critical field-task controls, scaling the same family uniformly rather than inventing heavier random strokes. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#342418", "text": "#F0BE98"}, {"role": "Error", "container": "#3B2029", "text": "#E3A8B9"}, {"role": "Info", "container": "#282523", "text": "#D3C8C1"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Glanceable field operations layout: large pickup task strip and three widely separated labeled field controls dominate the center-left; cash context is a quiet burgundy section, not a navigation action. Icon catalog on top; large target anatomy, label map and state samples in clean side/bottom panels. Black/white dominates, burgundy context, orange dimensional/focus guides. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Pickup", "storefront"], ["Route", "route with endpoints"], ["Call", "phone handset"], ["Proof", "camera"], ["Cash", "banknote"], ["Support", "headset"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Field actions" with "Next pickup" and "2.4 km". Show THREE separate rounded-square field controls: route icon with visible "Route", phone handset with "Call seller", camera with "Add proof". Each has a "56 × 56 px target", 28 px glyph, and "16 px gap" between target boundaries. Annotate ONE enlarged phone control only, not all three. Under them a burgundy context line reads "Cash to collect" and "₹960.00"; this money context is not a button. Include one wide primary button "View current job" with a package outline icon and "56 px min height", plus "8 px icon-label gap". Use 8 px control radius and 12 px task card radius. Burnt orange guides and focus; normal control icons use readable black/white.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Route | Open pickup route | Enabled
Call seller | Call pickup seller | Enabled
Add proof | Add pickup proof photo | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Standard control glyph | 24 px
Field action glyph | 28 px
Standard target | 48 px
Field action target | 56 px
Adjacent field gap | 16 px
Panel "Target anatomy": one enlarged phone handset outline glyph centered inside an OUTER square dashed measurement boundary labeled "56 × 56 px target". A smaller INNER dashed square bounds the glyph, labeled "28 × 28 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 56 = 28 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same phone handset glyph inside equal comfortable targets with readable captions EXACTLY ["Call seller", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #ECA06D; Selected uses #3B2029 container and #F4F4F4 glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.

STRICT THEME PAIR: Input Image 2 is the selected C04 LIGHT board for this SAME app, authoritative for CONTENT and COMPOSITION. Preserve its exact panel positions, six domain icons, six role rows, three accessible-name rows, full target-anatomy diagram/numerical equation, interaction labels, IDs/data and four state samples. Only convert its palette to the explicit approved DARK C01 tokens in Image 1. Do not copy old C01 panels. Keep plain-text "Icon-label gap: 8 px" notes from Image 2 where present, with NO measurement arrow, bracket or guide on that note. Do not reintroduce removed wrong guide boxes around text captions. The anatomy diagram measures actual glyph and full square target as separate bounds. DARK PRIMARY ACTION RULE: background #F4F4F4; text AND embedded icon #151515. Use the exact light-brand-fill/dark-content appearance in Image 1 for any filled primary action, not dark saturated light-theme brand with white content. Dark selected states use #3B2029 surface, #F4F4F4 glyph and a separate check/state caption; no green success badge in blue apps. Preserve supporting context color #ECA06D. Unavailable sample remains muted and distinguishable from enabled.
```
<!-- prompt:dark-1:end -->

## Inherited C01 theme values

### Light

| Role | Hex |
| --- | --- |
| primary | #191919 |
| onPrimary | #FFFFFF |
| support | #A94D24 |
| supportLabel | Burnt orange |
| canvas | #F8F7F6 |
| surface | #FFFFFF |
| raised | #FAF9F8 |
| text | #1C1C1C |
| muted | #686260 |
| border | #DDD7D4 |
| strongBorder | #A49993 |
| selected | #F5E7EC |
| focus | #A94D24 |
| burgundy | #7A2840 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #E7F5ED | #146C43 |
| Warning | #FBEDE3 | #88451E |
| Error | #F5E7EC | #7A2840 |
| Info | #ECEAE8 | #59534F |

### Dark

| Role | Hex |
| --- | --- |
| primary | #F4F4F4 |
| onPrimary | #151515 |
| support | #ECA06D |
| supportLabel | Burnt orange |
| canvas | #090909 |
| surface | #151515 |
| raised | #222222 |
| text | #F5F3F2 |
| muted | #C3BAB7 |
| border | #3C3633 |
| strongBorder | #91857E |
| selected | #3B2029 |
| focus | #ECA06D |
| burgundy | #DCA0B1 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #102C20 | #8DE0B0 |
| Warning | #342418 | #F0BE98 |
| Error | #3B2029 | #E3A8B9 |
| Info | #282523 | #D3C8C1 |

## C04 domain specifications — proposal

Retain centralized DeliveryIcons Lucide outline and the existing house600 home exception. Regular glyphs 20/24; propose 28 px for critical field-task controls, scaling the same family uniformly rather than inventing heavier random strokes.

| Icon or target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Standard control glyph | 24 |
| Field action glyph | 28 |
| Standard target | 48 |
| Field action target | 56 |
| Adjacent field gap | 16 |

| Visible label | Accessible name | Separate state |
| --- | --- | --- |
| Route | Open pickup route | Enabled |
| Call seller | Call pickup seller | Enabled |
| Add proof | Add pickup proof photo | Enabled |

Target anatomy: 56 = 28 + 2 × 14. Calculated centering inset does not add a spacing token. Selected/action-state specimens are illustrative states, not proof of an operation completing.
