# Agrimore Admin — C03 image generation prompts

Foundation: Spacing, shape, borders and elevation. Date: 2026-10-03.
Tool: **built-in image_gen**. Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. Owner approval has not been recorded for C03.

The corresponding [C01 lock](../01-color-roles-theme-identity/lock.json) supplies authoritative light/dark palettes, status colors, core spacing, radius arrays and border widths. Light uses the C01 light board as an identity reference. Dark uses the C01 dark board for skin and this app’s selected C03 light board for content/composition. Refinements below correct specific annotation or action-color mismatches; their exact input/output paths and hashes preserve provenance. Discarded drafts remain session artifacts, not selected app assets.

The prompts specify token values; raster generation is illustrative and cannot guarantee pixel-exact color or geometry. Use the manifest and domain map as implementation targets. No runtime tokens or screens were modified by this asset task.

## Light

Selected asset: [agrimore-admin-spacing-shape-borders-elevation-light.png](agrimore-admin-spacing-shape-borders-elevation-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-light.png` · SHA-256 `fca2bb37fc479e39d3bdc3da8c45e5968af3840edf4ad66312e18a6860d4c1a4`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-0bb85163-5937-4525-898e-7e63b276881b.png` · SHA-256 `cea3151a662130f4e4e1fcbb09e44b938ad60abc8e2f62ac00b3e64fcb494d5f`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Admin, light theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 light board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Admin" and a small "Light" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Professional blue, cyan and steel/slate. Palette tokens: primary: #1D4F91; onPrimary: #FFFFFF; support: #087E8B; canvas: #F5F7FB; surface: #FFFFFF; raised: #F9FBFE; text: #14243B; muted: #5B6B82; border: #D8E1EF; strongBorder: #8C9DB5; selected: #E8EFF8; focus: #1D4F91. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E8F0FA", "text": "#24528C"}]. Supporting accent is context, never a replacement for status semantics. Airy neutral canvas, clean white/near-white panels, quiet soft shadows. No full-color panel backgrounds, excessive shadows or low-contrast text.
Composition: Structured administrative workstation composition. A wide annotated approval table dominates the left; a smaller review panel and cyan reference-heading occupy the right. Dense aligned rows, crisp 8 px controls, thin steel borders. Use professional blue actions and cyan comparison/measurement context, never storefront green. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Operations rhythm". A wide flat ledger with columns "Application", "Status", "Reference" and row "Seller application", "Pending review", "AGR-2048". Guides label "16 px panel padding", "12 px cell padding" and "16 px column gap". Below a separate review group labeled "Approval review" with the blue control "Review application"; mark "32 px section gap" between groups. A clearly cyan heading "Reference context" and cyan measurement labels. Page-edge bracket "24 px desktop inset". Interactive table rows remain at least 48 high and can grow; do not label a compact data gap as a touch-target height.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Desktop page inset | 24 px
Panel padding | 16 px
Table cell padding | 12 px
Column gap | 16 px
Section gap | 32 px
Minimum control height | 48 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 8 px", "Card — 12 px", "Sheet / dialog — 16 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #D8E1EF; strong stroke #8C9DB5; focus stroke #1D4F91. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Approval table", "Review panel", "Review dialog". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.
```
<!-- prompt:light-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-0bb85163-5937-4525-898e-7e63b276881b.png` · SHA-256 `cea3151a662130f4e4e1fcbb09e44b938ad60abc8e2f62ac00b3e64fcb494d5f`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-light.png` · SHA-256 `fca2bb37fc479e39d3bdc3da8c45e5968af3840edf4ad66312e18a6860d4c1a4`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-f9cc6a6e-67a5-4846-a512-3c964b9beffe.png` · SHA-256 `2bde2cf5f027777f6f273f94098543c2d833a91af42f77ad51f50df291444743`.

<!-- prompt:light-2:begin -->
```text
Use case: ui-mockup. Edit Image 1, the new Agrimore Admin LIGHT C03 board. Image 2 is the approved C01 light identity reference. Preserve all spatial numeric values, all panels, table values, role labels, main layout, header and pale steel/slate surfaces. Make ONLY these identity corrections: the "Review application" button must use professional institutional blue #1D4F91 with white text; the Focus outline must be exactly professional blue #1D4F91, 2 px, not bright royal/electric blue. Preserve its printed #1D4F91 caption. Preserve cyan #087E8B as supporting "Reference context" heading and guide color. In the Reference context panel remove the cyan status-like info icon and colored alert-container block; instead render its existing explanatory text as ordinary text on the white panel, with a subtle cyan underline or rule. This is contextual guidance, not an Info status. The sole Pending review warning chip retains C01 Warning #FFF4D6 background and #805400 text. No oversaturated blues, no additional status chips, no extra colors, no typography or geometry redesign, no cropped captions. Institutional blue should visibly differ from the Sales Associate royal blue.
```
<!-- prompt:light-2:end -->

## Dark

Selected asset: [agrimore-admin-spacing-shape-borders-elevation-dark.png](agrimore-admin-spacing-shape-borders-elevation-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-dark.png` · SHA-256 `d232ad575ce49311efa785e4dfc2fc781c81d297184215e8f66979536f67041b`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/03-spacing-shape-borders-elevation/agrimore-admin-spacing-shape-borders-elevation-light.png` · SHA-256 `2bde2cf5f027777f6f273f94098543c2d833a91af42f77ad51f50df291444743`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-09e5391a-91c9-4996-852c-008300e828d6.png` · SHA-256 `3a88249d8064b0f1e63388ecc449baa1288d661cb8149c991f189d72b444f0ef`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Admin, dark theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 dark board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Admin" and a small "Dark" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Professional blue, cyan and steel/slate. Palette tokens: primary: #93B3EC; onPrimary: #0D203E; support: #7BCBD5; canvas: #080B10; surface: #121922; raised: #1D2837; text: #F2F6FC; muted: #B5C3D6; border: #314157; strongBorder: #74869E; selected: #192E4A; focus: #93B3EC. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#172A42", "text": "#AFCCF6"}]. Supporting accent is context, never a replacement for status semantics. Near-black canvas, true dark grey panels, excellent light-text contrast, no white panels, blue canvas, glow or colorful gradient. Depth comes primarily from distinct surface and raised tones plus crisp borders, as C01.
Composition: Structured administrative workstation composition. A wide annotated approval table dominates the left; a smaller review panel and cyan reference-heading occupy the right. Dense aligned rows, crisp 8 px controls, thin steel borders. Use professional blue actions and cyan comparison/measurement context, never storefront green. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Operations rhythm". A wide flat ledger with columns "Application", "Status", "Reference" and row "Seller application", "Pending review", "AGR-2048". Guides label "16 px panel padding", "12 px cell padding" and "16 px column gap". Below a separate review group labeled "Approval review" with the blue control "Review application"; mark "32 px section gap" between groups. A clearly cyan heading "Reference context" and cyan measurement labels. Page-edge bracket "24 px desktop inset". Interactive table rows remain at least 48 high and can grow; do not label a compact data gap as a touch-target height.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Desktop page inset | 24 px
Panel padding | 16 px
Table cell padding | 12 px
Column gap | 16 px
Section gap | 32 px
Minimum control height | 48 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 8 px", "Card — 12 px", "Sheet / dialog — 16 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #314157; strong stroke #74869E; focus stroke #93B3EC. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Approval table", "Review panel", "Review dialog". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.

Pairing constraint: Input Image 2 is the SELECTED C03 LIGHT board for this SAME app, the authoritative CONTENT and COMPOSITION reference. Preserve its exact panel arrangement, all row counts, numeric labels, radius mappings, border widths, dimensional guides, specimen data and relative geometry. Convert it into the approved C01 dark skin from Image 1. Change the theme pill to "Dark", convert canvas/surface/raised/text/brand/support/status colors to the explicit dark tokens above. Do NOT copy old Color roles or Typography panels from Image 1. Do not redesign the light board or add unrelated panels. Use this app’s near-black canvas and dark grey surfaces with all content readable.  The Reference context panel is ordinary contextual text with a cyan rule, no invented cyan Info alert. Pending review uses the C01 Warning dark pair, not cyan. Action and focus use the approved muted professional blue, never electric blue.
```
<!-- prompt:dark-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-09e5391a-91c9-4996-852c-008300e828d6.png` · SHA-256 `3a88249d8064b0f1e63388ecc449baa1288d661cb8149c991f189d72b444f0ef`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/admin/assets/ui-mockups/01-color-roles-theme-identity/agrimore-admin-design-tokens-dark.png` · SHA-256 `d232ad575ce49311efa785e4dfc2fc781c81d297184215e8f66979536f67041b`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-59c204e0-3155-4825-892c-aa28853586d2.png` · SHA-256 `629b86436781e5f34ad3fbe3830f32f9ace78f7b663562f423830e7a1218836a`.

<!-- prompt:dark-2:begin -->
```text
Use case: ui-mockup. Image 1 is the new Agrimore Admin DARK C03 board, the edit target. Image 2 is its APPROVED C01 DARK board, the authoritative palette reference. Change ONLY the "Review application" control in Approval review. Its fill must be the approved muted pale professional blue #93B3EC, solid and flat; its text must be the approved dark onPrimary #0D203E. Remove the medium-blue fill and white label. Match the filled pale-blue dark action in Image 2. Preserve the correct blue focus outline, cyan context, steel/slate panels and warning chip. Preserve EVERYTHING ELSE: exact geometry, panel arrangement, all text including every number, spacing scale, Domain spacing rows, Shape roles, Border roles, Surface depth, dark canvas/panels, dimension guides and theme pill. Do not regenerate or recolor other content, add panels, change financial figures, crop edges or copy old C01 panels. Crisp high-resolution typography and boundaries.
```
<!-- prompt:dark-2:end -->

## Inherited token specifications

### Light — C01 owner-approved values

| Color role | Hex |
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

### Dark — C01 owner-approved values

| Color role | Hex |
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

### C03 domain role mapping — proposal

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Desktop page inset | 24 |
| Panel padding | 16 |
| Table cell padding | 12 |
| Column gap | 16 |
| Section gap | 32 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius |
| --- | --- |
| Control | 8 |
| Card | 12 |
| Sheet / dialog | 16 |
