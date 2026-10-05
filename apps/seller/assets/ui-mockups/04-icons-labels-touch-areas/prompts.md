# Agrimore Seller — C04 image generation prompts

C04: Icons, labels and touch areas. Date: 2026-10-03. Tool: **built-in image_gen**.
Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. C04 owner approval is not recorded.

The [C01 v2 lock](../01-color-roles-theme-identity/lock.json) supplies approved palette, status colors, spacing scale, radii and border widths. All ten C01 images were inspected before generation. Light uses the corresponding C01 light skin reference. Dark uses C01 dark skin plus this app’s selected C04 light image for content and composition. Exact initial/refinement prompts and image inputs below preserve provenance. Discarded drafts remain session artifacts; only the selected pair is saved here.

These raster boards illustrate icon/label/target roles. Actual executable icon family fidelity, hit areas, accessible names/state and contrast require implementation and rendered testing. The label table is a proposed semantics mapping, not a screen-reader test result. Use manifest values for exact token/role implementation.

## Light

Selected asset: [agrimore-seller-icons-labels-touch-areas-light.png](agrimore-seller-icons-labels-touch-areas-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-light.png` · SHA-256 `04d17f7ec077a040e8689bea57f1cc678d3b24ee0bd4a7f9be4717b5a848185c`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-926b6b4a-6b70-4563-9d1d-9899bd6cae32.png` · SHA-256 `f33f0502dcb1d20732980aa3b71da5c545d10789f46addbb3f54eff86271b8ab`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Seller — light theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 light identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Blue-teal; copper and cool neutrals.
Header ONLY "Agrimore Seller" and "Light" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #0B6A80; onPrimary #FFFFFF; support #9B5E3D; canvas #F5F8F9; surface #FFFFFF; raised #F9FCFD; text #142A34; muted #56717E; border #D5E3E8; strongBorder #879EAA; selected #E5F2F5; focus #0B6A80. All FILLED primary action buttons use EXACTLY background #0B6A80 and text/embedded icons #FFFFFF. Neutral light canvas, clean white/near-white panels, excellent contrast and quiet elevation. Admin professional blue must not become electric/royal blue.
Family/style: Retain the centralized SellerIcons Lucide outline family, 24-unit grid and nominal 2 px stroke at 24 px. Scale complete glyphs uniformly for 20 px controls; no mixed raw Material or FontAwesome control group. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E6F3F7", "text": "#17647B"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Compact business layout: inventory record plus horizontal edit/filter toolbar and copper quote workspace on the left; accessible label table and icon roles on the right. Top domain icon catalog; bottom target-anatomy and state specimens. Blue-teal actions and copper section headings/guides; no shopping product-photo composition. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Catalogue", "package"], ["Orders", "shopping bag"], ["Quotes", "message with lines"], ["Payments", "credit card"], ["Stock", "stacked layers"], ["Edit", "pencil"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Inventory actions". A flat stock record reads "Fresh tomatoes" and "250 packs". Three separate square outline controls display a pencil, filter sliders and ellipsis, with visible labels "Edit stock", "Filter", "More". Annotate the pencil "20 px glyph" inside "48 × 48 px target" and mark "8 px gap" between targets. Under a copper heading "Quote actions", show one filled blue-teal message/file icon button "Review quote" and "RFQ-2048" as context. Mark "8 px icon-label gap" on the button. Use C01 control radius 10 and card radius 14. Do not suggest changing stock just by tapping the pencil; it opens the stock editor.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Edit stock | Edit stock for Fresh tomatoes | Enabled
Review quote | Review quote RFQ-2048 | Enabled
Filter | Filter catalogue | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Inventory control glyph | 20 px
Navigation glyph | 24 px
Icon-only target | 48 px
Primary button min height | 48 px
Adjacent target gap | 8 px
Panel "Target anatomy": one enlarged pencil outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "20 × 20 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 20 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same pencil glyph inside equal comfortable targets with readable captions EXACTLY ["Edit stock", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #0B6A80; Selected uses #E5F2F5 container and #0B6A80 glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.
```
<!-- prompt:light-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-926b6b4a-6b70-4563-9d1d-9899bd6cae32.png` · SHA-256 `f33f0502dcb1d20732980aa3b71da5c545d10789f46addbb3f54eff86271b8ab`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-light.png` · SHA-256 `04d17f7ec077a040e8689bea57f1cc678d3b24ee0bd4a7f9be4717b5a848185c`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-fc83888e-49a9-463e-b88c-02fd754da727.png` · SHA-256 `13747f7e7558224a62051e66ea64635338ea55160384f29c19b902a75af5992a`.

<!-- prompt:light-2:begin -->
```text
Use case: ui-mockup. Edit Image 1, the new Agrimore Seller LIGHT C04 board; Image 2 is its approved C01 LIGHT skin reference. Correct ONLY the small "8 px icon-label gap" annotation beside/below the "Review quote" labeled button. Remove that annotation’s measurement arrow/bracket/dotted extension lines because they currently point to the wrong boundary or glyph width. Keep a clear plain-text note "Icon-label gap: 8 px" immediately below or beside that button, with no dimensional arrow attached to it. Preserve actual separation of the button icon and text. Do not remove the actual button, icon, label or related app/quote context. Preserve ALL other dimension guides, target anatomy, all six icon/target roles, all three accessible-label rows, four action states, six domain icons, palette, full layout and typography. Keep glyph vs target dimensions unchanged. No new panel, no extra explanation, no identity change, no cropped labels.
```
<!-- prompt:light-2:end -->

## Dark

Selected asset: [agrimore-seller-icons-labels-touch-areas-dark.png](agrimore-seller-icons-labels-touch-areas-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-dark.png` · SHA-256 `2608e9115e73f8ff7bf1a06e5921757fd488f0c4f3e0b6a219271b0e5d01de90`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/04-icons-labels-touch-areas/agrimore-seller-icons-labels-touch-areas-light.png` · SHA-256 `13747f7e7558224a62051e66ea64635338ea55160384f29c19b902a75af5992a`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-672ab5d1-1bde-42e1-ac45-b33cb148494b.png` · SHA-256 `665410ef2bcd322bf1166dc53b725c50b67c06bdead659ad4a5f9d86138322dd`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Seller — dark theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 dark identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Blue-teal; copper and cool neutrals.
Header ONLY "Agrimore Seller" and "Dark" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #70D0DF; onPrimary #0B2831; support #DAAE8C; canvas #080C0F; surface #11191E; raised #1B262D; text #F1F7FA; muted #B5C9D1; border #33464F; strongBorder #7895A2; selected #14313A; focus #70D0DF. All FILLED primary action buttons use EXACTLY background #70D0DF and text/embedded icons #0B2831. In particular dark mode primary labels are DARK on the light primary fill, not white. Use near-black canvas and genuinely dark grey surface/raised panels. No white content panels, electric blue/glow, bright background gradient or light-theme button fills.
Family/style: Retain the centralized SellerIcons Lucide outline family, 24-unit grid and nominal 2 px stroke at 24 px. Scale complete glyphs uniformly for 20 px controls; no mixed raw Material or FontAwesome control group. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#142D37", "text": "#9BD9E9"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Compact business layout: inventory record plus horizontal edit/filter toolbar and copper quote workspace on the left; accessible label table and icon roles on the right. Top domain icon catalog; bottom target-anatomy and state specimens. Blue-teal actions and copper section headings/guides; no shopping product-photo composition. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Catalogue", "package"], ["Orders", "shopping bag"], ["Quotes", "message with lines"], ["Payments", "credit card"], ["Stock", "stacked layers"], ["Edit", "pencil"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Inventory actions". A flat stock record reads "Fresh tomatoes" and "250 packs". Three separate square outline controls display a pencil, filter sliders and ellipsis, with visible labels "Edit stock", "Filter", "More". Annotate the pencil "20 px glyph" inside "48 × 48 px target" and mark "8 px gap" between targets. Under a copper heading "Quote actions", show one filled blue-teal message/file icon button "Review quote" and "RFQ-2048" as context. Mark "8 px icon-label gap" on the button. Use C01 control radius 10 and card radius 14. Do not suggest changing stock just by tapping the pencil; it opens the stock editor.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Edit stock | Edit stock for Fresh tomatoes | Enabled
Review quote | Review quote RFQ-2048 | Enabled
Filter | Filter catalogue | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Inventory control glyph | 20 px
Navigation glyph | 24 px
Icon-only target | 48 px
Primary button min height | 48 px
Adjacent target gap | 8 px
Panel "Target anatomy": one enlarged pencil outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "20 × 20 px glyph". A precise one-sided inset guide between inner and outer bounds reads "14 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 20 + 2 × 14. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same pencil glyph inside equal comfortable targets with readable captions EXACTLY ["Edit stock", "Focused", "Selected", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #70D0DF; Selected uses #14313A container and #70D0DF glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.

STRICT THEME PAIR: Input Image 2 is the selected C04 LIGHT board for this SAME app, authoritative for CONTENT and COMPOSITION. Preserve its exact panel positions, six domain icons, six role rows, three accessible-name rows, full target-anatomy diagram/numerical equation, interaction labels, IDs/data and four state samples. Only convert its palette to the explicit approved DARK C01 tokens in Image 1. Do not copy old C01 panels. Keep plain-text "Icon-label gap: 8 px" notes from Image 2 where present, with NO measurement arrow, bracket or guide on that note. Do not reintroduce removed wrong guide boxes around text captions. The anatomy diagram measures actual glyph and full square target as separate bounds. DARK PRIMARY ACTION RULE: background #70D0DF; text AND embedded icon #0B2831. Use the exact light-brand-fill/dark-content appearance in Image 1 for any filled primary action, not dark saturated light-theme brand with white content. Dark selected states use #14313A surface, #70D0DF glyph and a separate check/state caption; no green success badge in blue apps. Preserve supporting context color #DAAE8C. Unavailable sample remains muted and distinguishable from enabled.
```
<!-- prompt:dark-1:end -->

## Inherited C01 theme values

### Light

| Role | Hex |
| --- | --- |
| primary | #0B6A80 |
| onPrimary | #FFFFFF |
| support | #9B5E3D |
| supportLabel | Warm copper |
| canvas | #F5F8F9 |
| surface | #FFFFFF |
| raised | #F9FCFD |
| text | #142A34 |
| muted | #56717E |
| border | #D5E3E8 |
| strongBorder | #879EAA |
| selected | #E5F2F5 |
| focus | #0B6A80 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #E7F5ED | #146C43 |
| Warning | #FFF4D6 | #805400 |
| Error | #FDECEA | #B42318 |
| Info | #E6F3F7 | #17647B |

### Dark

| Role | Hex |
| --- | --- |
| primary | #70D0DF |
| onPrimary | #0B2831 |
| support | #DAAE8C |
| supportLabel | Warm copper |
| canvas | #080C0F |
| surface | #11191E |
| raised | #1B262D |
| text | #F1F7FA |
| muted | #B5C9D1 |
| border | #33464F |
| strongBorder | #7895A2 |
| selected | #14313A |
| focus | #70D0DF |

| Status | Container | Text |
| --- | --- | --- |
| Success | #102C20 | #8DE0B0 |
| Warning | #302612 | #F1CE7B |
| Error | #341B1B | #FFA39C |
| Info | #142D37 | #9BD9E9 |

## C04 domain specifications — proposal

Retain the centralized SellerIcons Lucide outline family, 24-unit grid and nominal 2 px stroke at 24 px. Scale complete glyphs uniformly for 20 px controls; no mixed raw Material or FontAwesome control group.

| Icon or target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Inventory control glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 48 |
| Adjacent target gap | 8 |

| Visible label | Accessible name | Separate state |
| --- | --- | --- |
| Edit stock | Edit stock for Fresh tomatoes | Enabled |
| Review quote | Review quote RFQ-2048 | Enabled |
| Filter | Filter catalogue | Enabled |

Target anatomy: 48 = 20 + 2 × 14. Calculated centering inset does not add a spacing token. Selected/action-state specimens are illustrative states, not proof of an operation completing.
