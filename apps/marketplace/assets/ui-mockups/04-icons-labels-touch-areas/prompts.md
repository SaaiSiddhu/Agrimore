# Agrimore Marketplace — C04 image generation prompts

C04: Icons, labels and touch areas. Date: 2026-10-03. Tool: **built-in image_gen**.
Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. C04 owner approval is not recorded.

The [C01 v2 lock](../01-color-roles-theme-identity/lock.json) supplies approved palette, status colors, spacing scale, radii and border widths. All ten C01 images were inspected before generation. Light uses the corresponding C01 light skin reference. Dark uses C01 dark skin plus this app’s selected C04 light image for content and composition. Exact initial/refinement prompts and image inputs below preserve provenance. Discarded drafts remain session artifacts; only the selected pair is saved here.

These raster boards illustrate icon/label/target roles. Actual executable icon family fidelity, hit areas, accessible names/state and contrast require implementation and rendered testing. The label table is a proposed semantics mapping, not a screen-reader test result. Use manifest values for exact token/role implementation.

## Light

Selected asset: [agrimore-marketplace-icons-labels-touch-areas-light.png](agrimore-marketplace-icons-labels-touch-areas-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-light.png` · SHA-256 `cc568e8551edcfeb1e6358fa2bd83a3599636eba1102e8b115aa9247e3fefcda`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-a3309508-536a-495a-8aa6-6f1195fb2a48.png` · SHA-256 `c4ff6aad64b8a3a14d932086957b9e4cbfef99eb4fd7615baf09d2ea8ac74384`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Marketplace — light theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 light identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Professional green; warm gold and natural stone.
Header ONLY "Agrimore Marketplace" and "Light" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #087A4B; onPrimary #FFFFFF; support #9A6826; canvas #F7F9F6; surface #FFFFFF; raised #FBFCF9; text #1A2C21; muted #5D7062; border #DAE4DB; strongBorder #91A594; selected #E5F3E9; focus #087A4B. All FILLED primary action buttons use EXACTLY background #087A4B and text/embedded icons #FFFFFF. Neutral light canvas, clean white/near-white panels, excellent contrast and quiet elevation. Admin professional blue must not become electric/royal blue.
Family/style: Material outlined commerce icons, one consistent optical weight. Default outlines; a filled heart only for saved state, with text and semantic state. Do not mix FontAwesome and Material within a control group. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E7F2EC", "text": "#286B4D"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Airy commerce layout: an annotated Fresh tomatoes product/action specimen on the left; a wide accessible-label table on the right. A horizontal icon catalog on top; compact icon roles, target anatomy and states panels along the bottom. Warm-gold context heading "Shopping actions" and gold dimensional guides; green purchase and selected actions. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Search", "magnifying glass"], ["Filter", "sliders"], ["Cart", "shopping cart"], ["Wishlist", "heart"], ["Orders", "shopping bag"], ["Support", "headset"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Shopping actions" in warm gold. A text-only product group "Fresh tomatoes", "1 kg pack", "₹48.00" with a square heart-outline Save control and a separate filled green cart-icon button "Add to cart". Show a separate outline cart control with badge "2" and visible label "Cart". Annotate "24 px glyph", "48 × 48 px target" on the Save control, "8 px gap" BETWEEN controls and "8 px icon-label gap" on the labeled button. Avoid product photos. The target outline encloses the entire square interaction area, not just the heart. Use a 12 px control radius and 16 px card radius from C01.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Save | Save Fresh tomatoes | Not saved
Add to cart | Add Fresh tomatoes to cart | Enabled
Cart · 2 | Open cart, 2 items | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Shopping action glyph | 24 px
Navigation glyph | 24 px
Icon-only target | 48 px
Primary button min height | 48 px
Adjacent target gap | 8 px
Panel "Target anatomy": one enlarged heart outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "24 × 24 px glyph". A precise one-sided inset guide between inner and outer bounds reads "12 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 24 + 2 × 12. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same heart glyph inside equal comfortable targets with readable captions EXACTLY ["Save", "Focused", "Saved", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #087A4B; Selected uses #E5F3E9 container and #087A4B glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.
```
<!-- prompt:light-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-a3309508-536a-495a-8aa6-6f1195fb2a48.png` · SHA-256 `c4ff6aad64b8a3a14d932086957b9e4cbfef99eb4fd7615baf09d2ea8ac74384`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-light.png` · SHA-256 `cc568e8551edcfeb1e6358fa2bd83a3599636eba1102e8b115aa9247e3fefcda`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-4197bea9-b837-4f5c-acbe-e6af6dbcd82f.png` · SHA-256 `c5ea4d5ea4db65eec30e14509342c9eda7fe7a89176e31bcc5a5c93aa5333b61`.

<!-- prompt:light-2:begin -->
```text
Use case: ui-mockup. Edit Image 1, the new Agrimore Marketplace LIGHT C04 board; Image 2 is its approved C01 LIGHT skin reference. Correct ONLY the small "8 px icon-label gap" annotation beside/below the "Add to cart" labeled button. Remove that annotation’s measurement arrow/bracket/dotted extension lines because they currently point to the wrong boundary or glyph width. Keep a clear plain-text note "Icon-label gap: 8 px" immediately below or beside that button, with no dimensional arrow attached to it. Preserve actual separation of the button icon and text. Do not remove the actual button, icon, label or related app/quote context. Preserve ALL other dimension guides, target anatomy, all six icon/target roles, all three accessible-label rows, four action states, six domain icons, palette, full layout and typography. Keep glyph vs target dimensions unchanged. No new panel, no extra explanation, no identity change, no cropped labels.
```
<!-- prompt:light-2:end -->
### Step 3 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-4197bea9-b837-4f5c-acbe-e6af6dbcd82f.png` · SHA-256 `c5ea4d5ea4db65eec30e14509342c9eda7fe7a89176e31bcc5a5c93aa5333b61`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-light.png` · SHA-256 `cc568e8551edcfeb1e6358fa2bd83a3599636eba1102e8b115aa9247e3fefcda`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-c2ca664e-5382-4002-9507-89f4f7c81e87.png` · SHA-256 `979b3d7d5ebfd39cc61b9cda0b0b1dc0db833b6bf1b9c97306897787e437bccf`.

<!-- prompt:light-3:begin -->
```text
Use case: ui-mockup. Edit Image 1, the new Agrimore Marketplace LIGHT C04 board. Image 2 is the approved C01 light reference. Correct ONLY the local glyph annotation under the Save control in Shopping actions. Remove the small gold dashed rectangle that currently encloses the WORD "Save" as if that text were the glyph. Preserve the normal visible label "Save", the heart control, and its large outer "48 × 48 px target" dashed box. Keep "24 px glyph" as a plain text note below Save, with no small measurement box or guide around the word. The actual precise glyph-vs-target measurement remains in the unchanged Target anatomy panel, where 24 × 24 glyph is correctly inside 48 × 48 target. Preserve all remaining panels, values, accessible label rows, icons, spacing gap note, palette and layout exactly. Do not move or relabel the Target anatomy diagram, add new annotations, or alter the Add to cart button.
```
<!-- prompt:light-3:end -->

## Dark

Selected asset: [agrimore-marketplace-icons-labels-touch-areas-dark.png](agrimore-marketplace-icons-labels-touch-areas-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-dark.png` · SHA-256 `63b4648caac7e8d4a4137aa41090bbc4bcc46a1727cf808379a1fba4ec87f4ca`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/04-icons-labels-touch-areas/agrimore-marketplace-icons-labels-touch-areas-light.png` · SHA-256 `979b3d7d5ebfd39cc61b9cda0b0b1dc0db833b6bf1b9c97306897787e437bccf`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-48734a36-a8ad-4a33-8319-43362b788e42.png` · SHA-256 `b083b8144f1e382cadb6eab0b25c301e1690aba048e20346235274a38c52194c`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Create ONE landscape 16:10 high-resolution premium Storybook-style C04 design-system board for Agrimore Marketplace — dark theme. This is a new Icons, labels and touch areas reference board, not a swatch board or full application screenshot.
Input Image 1 is this app's APPROVED C01 dark identity reference. Preserve its palette, type personality, control/card radii, clean thin borders and restrained depth. Replace the old Color roles/Typography panels with C04 content only. Brand: Professional green; warm gold and natural stone.
Header ONLY "Agrimore Marketplace" and "Dark" theme pill; subtitle "Icons, labels & touch areas". No slogan, sidebar, navigation menu, browser/device frame, logo, photos, watermark or decorative illustration.
Palette: primary #67D2A1; onPrimary #0B291D; support #DDB97A; canvas #090C0A; surface #141A16; raised #1E2721; text #F2F7F3; muted #B9C9BD; border #344338; strongBorder #798F7E; selected #163325; focus #67D2A1. All FILLED primary action buttons use EXACTLY background #67D2A1 and text/embedded icons #0B291D. In particular dark mode primary labels are DARK on the light primary fill, not white. Use near-black canvas and genuinely dark grey surface/raised panels. No white content panels, electric blue/glow, bright background gradient or light-theme button fills.
Family/style: Material outlined commerce icons, one consistent optical weight. Default outlines; a filled heart only for saved state, with text and semantic state. Do not mix FontAwesome and Material within a control group. Show consistent simple recognizable UI glyphs with clean rounded joins and optical alignment; not emoji, clipart, brand marks, overly intricate line art or novelty pictograms. Every icon gets a readable text label. Supporting accent is secondary context, not a universal blue. Status colors, if used, only follow inherited pairs [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#173126", "text": "#A1D8B9"}]; selected/focus use selected/focus tokens, not Success green. An unrelated disabled control never uses Error red.
Composition: Airy commerce layout: an annotated Fresh tomatoes product/action specimen on the left; a wide accessible-label table on the right. A horizontal icon catalog on top; compact icon roles, target anatomy and states panels along the bottom. Warm-gold context heading "Shopping actions" and gold dimensional guides; green purchase and selected actions. Full uncropped image, crisp Inter UI typography, clear panel hierarchy, comfortable whitespace. Relative sizes convey logical UI px rather than literal raster px. Fit all the following panels without tiny type.
Panel "Domain icons": six consistent glyphs with these EXACT labels and meanings: [["Search", "magnifying glass"], ["Filter", "sliders"], ["Cart", "shopping cart"], ["Wishlist", "heart"], ["Orders", "shopping bag"], ["Support", "headset"]]. Draw one icon per label, equal optical grid and weight. Do not invent extra labels or omit icons. Noninteractive reference specimens, no badges here.
Panel "Interaction specimen": Panel heading "Shopping actions" in warm gold. A text-only product group "Fresh tomatoes", "1 kg pack", "₹48.00" with a square heart-outline Save control and a separate filled green cart-icon button "Add to cart". Show a separate outline cart control with badge "2" and visible label "Cart". Annotate "24 px glyph", "48 × 48 px target" on the Save control, "8 px gap" BETWEEN controls and "8 px icon-label gap" on the labeled button. Avoid product photos. The target outline encloses the entire square interaction area, not just the heart. Use a 12 px control radius and 16 px card radius from C01.
Panel "Accessible labels": EXACT three-column header "Visible label", "Accessible name", "State". EXACT rows:
Save | Save Fresh tomatoes | Not saved
Add to cart | Add Fresh tomatoes to cart | Enabled
Cart · 2 | Open cart, 2 items | Enabled
This table is a Storybook annotation of proposed semantics, not a claim of running screen-reader output. Accessible names do not say "button" or repeat the role. Names contain action and meaningful entity context; the State column is separate. Keep all three rows legible and wrap long names rather than shrink.
Panel "Icon & target roles": EXACT rows, all px:
Supporting glyph | 16 px
Shopping action glyph | 24 px
Navigation glyph | 24 px
Icon-only target | 48 px
Primary button min height | 48 px
Adjacent target gap | 8 px
Panel "Target anatomy": one enlarged heart outline glyph centered inside an OUTER square dashed measurement boundary labeled "48 × 48 px target". A smaller INNER dashed square bounds the glyph, labeled "24 × 24 px glyph". A precise one-sided inset guide between inner and outer bounds reads "12 px each side". The inner box is NOT an extra button. Outer boundary measures the full hit area; don't put both dimensions on the same box. Maintain proportional centered geometry, no overlaid text or overlapping hit regions. Include small rule "Glyph size ≠ touch target". 48 = 24 + 2 × 12. These inset values are calculated centering, not new layout-spacing tokens.
Panel "Action states": four samples of the same heart glyph inside equal comfortable targets with readable captions EXACTLY ["Save", "Focused", "Saved", "Unavailable"]. Default normal outline; Focused uses ONE reserved 2 px outline in #67D2A1; Selected uses #163325 container and #67D2A1 glyph, with a small separate check indicator plus state text; Unavailable is a muted disabled control with no focus outline or active styling. Do not show the Selected specimen as Success status, imply "Copied" success from a selected copy glyph, or conflate default/pending/disabled. All sample targets have equal bounds.
Footer rule ONLY "Name the action · Keep targets separate · Show state beyond color". Preserve all exact labels, IDs, Indian rupee symbols, values and measurements. Minimum controls may grow with long labels; show coherent type scale and visible target padding. Render full legible board with no clipped guides, contradictory dimensions, impossible anatomy, unreadable captions, duplicate panel titles, invented numbers or lorem ipsum.

STRICT THEME PAIR: Input Image 2 is the selected C04 LIGHT board for this SAME app, authoritative for CONTENT and COMPOSITION. Preserve its exact panel positions, six domain icons, six role rows, three accessible-name rows, full target-anatomy diagram/numerical equation, interaction labels, IDs/data and four state samples. Only convert its palette to the explicit approved DARK C01 tokens in Image 1. Do not copy old C01 panels. Keep plain-text "Icon-label gap: 8 px" notes from Image 2 where present, with NO measurement arrow, bracket or guide on that note. Do not reintroduce removed wrong guide boxes around text captions. The anatomy diagram measures actual glyph and full square target as separate bounds. DARK PRIMARY ACTION RULE: background #67D2A1; text AND embedded icon #0B291D. Use the exact light-brand-fill/dark-content appearance in Image 1 for any filled primary action, not dark saturated light-theme brand with white content. Dark selected states use #163325 surface, #67D2A1 glyph and a separate check/state caption; no green success badge in blue apps. Preserve supporting context color #DDB97A. Unavailable sample remains muted and distinguishable from enabled.
```
<!-- prompt:dark-1:end -->

## Inherited C01 theme values

### Light

| Role | Hex |
| --- | --- |
| primary | #087A4B |
| onPrimary | #FFFFFF |
| support | #9A6826 |
| supportLabel | Warm gold |
| canvas | #F7F9F6 |
| surface | #FFFFFF |
| raised | #FBFCF9 |
| text | #1A2C21 |
| muted | #5D7062 |
| border | #DAE4DB |
| strongBorder | #91A594 |
| selected | #E5F3E9 |
| focus | #087A4B |

| Status | Container | Text |
| --- | --- | --- |
| Success | #E7F5ED | #146C43 |
| Warning | #FFF4D6 | #805400 |
| Error | #FDECEA | #B42318 |
| Info | #E7F2EC | #286B4D |

### Dark

| Role | Hex |
| --- | --- |
| primary | #67D2A1 |
| onPrimary | #0B291D |
| support | #DDB97A |
| supportLabel | Warm gold |
| canvas | #090C0A |
| surface | #141A16 |
| raised | #1E2721 |
| text | #F2F7F3 |
| muted | #B9C9BD |
| border | #344338 |
| strongBorder | #798F7E |
| selected | #163325 |
| focus | #67D2A1 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #102C20 | #8DE0B0 |
| Warning | #302612 | #F1CE7B |
| Error | #341B1B | #FFA39C |
| Info | #173126 | #A1D8B9 |

## C04 domain specifications — proposal

Material outlined commerce icons, one consistent optical weight. Default outlines; a filled heart only for saved state, with text and semantic state. Do not mix FontAwesome and Material within a control group.

| Icon or target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Shopping action glyph | 24 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 48 |
| Adjacent target gap | 8 |

| Visible label | Accessible name | Separate state |
| --- | --- | --- |
| Save | Save Fresh tomatoes | Not saved |
| Add to cart | Add Fresh tomatoes to cart | Enabled |
| Cart · 2 | Open cart, 2 items | Enabled |

Target anatomy: 48 = 24 + 2 × 12. Calculated centering inset does not add a spacing token. Selected/action-state specimens are illustrative states, not proof of an operation completing.
