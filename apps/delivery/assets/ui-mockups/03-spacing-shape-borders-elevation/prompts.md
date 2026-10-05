# Agrimore Delivery — C03 image generation prompts

Foundation: Spacing, shape, borders and elevation. Date: 2026-10-03.
Tool: **built-in image_gen**. Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. Owner approval has not been recorded for C03.

The corresponding [C01 lock](../01-color-roles-theme-identity/lock.json) supplies authoritative light/dark palettes, status colors, core spacing, radius arrays and border widths. Light uses the C01 light board as an identity reference. Dark uses the C01 dark board for skin and this app’s selected C03 light board for content/composition. Refinements below correct specific annotation or action-color mismatches; their exact input/output paths and hashes preserve provenance. Discarded drafts remain session artifacts, not selected app assets.

The prompts specify token values; raster generation is illustrative and cannot guarantee pixel-exact color or geometry. Use the manifest and domain map as implementation targets. No runtime tokens or screens were modified by this asset task.

## Light

Selected asset: [agrimore-delivery-spacing-shape-borders-elevation-light.png](agrimore-delivery-spacing-shape-borders-elevation-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-light.png` · SHA-256 `2384d327a37606012a2f3dc2d9427b63447ce9be1ae6b121d1294cc62872e383`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-af6d1725-1915-42d1-89c0-56ee6101d1d1.png` · SHA-256 `e2745cc626a6baf7653904dabdb0977ce14c739d1421a645390baebd8299cc9a`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Delivery, light theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 light board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Delivery" and a small "Light" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Black/white, burgundy and burnt orange. Palette tokens: primary: #191919; onPrimary: #FFFFFF; support: #A94D24; canvas: #F8F7F6; surface: #FFFFFF; raised: #FAF9F8; text: #1C1C1C; muted: #686260; border: #DDD7D4; strongBorder: #A49993; selected: #F5E7EC; focus: #A94D24; burgundy: #7A2840. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FBEDE3", "text": "#88451E"}, {"role": "Error", "container": "#F5E7EC", "text": "#7A2840"}, {"role": "Info", "container": "#ECEAE8", "text": "#59534F"}]. Supporting accent is context, never a replacement for status semantics. Airy neutral canvas, clean white/near-white panels, quiet soft shadows. No full-color panel backgrounds, excessive shadows or low-contrast text.
Composition: Field-focused composition. A broad pickup-task specimen and cash context dominate, with a separate large action strip below; compact role panels sit to the right. High-contrast black/white actions, burgundy cash labels and burnt-orange dimension lines. It must feel glanceable, robust and operational, not a finance dashboard. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Task rhythm". A bordered task card reads "Next pickup", "Collect from seller", "2.4 km", "Pickup quantity", "20 packs". A distinct burgundy-labeled block reads "Cash to collect" and "₹960.00". Fine burnt-orange guides label "16 px card padding" and "16 px task gap". A black primary control with white text reads "View current job"; mark "56 px min height" and the clear space above it "24 px action separation". Page-edge bracket "16 px page inset". Also include readable line "Touch targets ≥ 48 px". In dark mode the primary control becomes off-white with dark text, as C01.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Task card padding | 16 px
Task gap | 16 px
Action separation | 24 px
Primary action min height | 56 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 8 px", "Card — 12 px", "Sheet / dialog — 18 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #DDD7D4; strong stroke #A49993; focus stroke #A94D24. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "History row", "Task card", "Route sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.
```
<!-- prompt:light-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-af6d1725-1915-42d1-89c0-56ee6101d1d1.png` · SHA-256 `e2745cc626a6baf7653904dabdb0977ce14c739d1421a645390baebd8299cc9a`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-light.png` · SHA-256 `2384d327a37606012a2f3dc2d9427b63447ce9be1ae6b121d1294cc62872e383`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-6bdcf2e1-b9dd-44a4-9ebe-9eb17c3ec63a.png` · SHA-256 `68b9e06930238db7a4a63ca419d7b42a9f2e85dba0af98e1cd520e128661f6d3`.

<!-- prompt:light-2:begin -->
```text
Use case: ui-mockup. Edit Image 1, the new Agrimore Delivery LIGHT C03 board, preserving its full layout, title, palette, all correct spacing tables, shapes, borders and depth roles. Image 2 is the approved C01 light identity reference. Correct ONE spatial annotation conflict: the vertical whitespace between the task card and the primary button is ONLY "24 px action separation". Remove the duplicate "16 px task gap" vertical arrow to the left of that same whitespace. Instead show "16 px task gap" as a small horizontal gap guide BETWEEN the pickup quantity group and the separate cash-to-collect block INSIDE the task card, making clear it describes separate task groups. Keep "16 px page inset" at the page edge, "16 px card padding" at the card inner edge, "56 px min height" on the button, all six Domain spacing rows and "Touch targets ≥ 48 px". Do not invent another value, duplicate a guide, crop any text, restyle the board or change the numerical captions. Refine with crisp well-spaced guides, burnt orange for measurements and burgundy cash context.
```
<!-- prompt:light-2:end -->

## Dark

Selected asset: [agrimore-delivery-spacing-shape-borders-elevation-dark.png](agrimore-delivery-spacing-shape-borders-elevation-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/01-color-roles-theme-identity/agrimore-delivery-design-tokens-dark.png` · SHA-256 `745bda063c678184a1c0dc206bab60f45c659f08e0a5824a95fc19e4171385c4`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/delivery/assets/ui-mockups/03-spacing-shape-borders-elevation/agrimore-delivery-spacing-shape-borders-elevation-light.png` · SHA-256 `68b9e06930238db7a4a63ca419d7b42a9f2e85dba0af98e1cd520e128661f6d3`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-3acb7807-e89d-4fb5-b941-f5087ffa771e.png` · SHA-256 `085a42e5f2253440e80605fdc19e9b2bd3fa4d52c9ec1e0db70670eb44337ebb`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Delivery, dark theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 dark board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Delivery" and a small "Dark" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Black/white, burgundy and burnt orange. Palette tokens: primary: #F4F4F4; onPrimary: #151515; support: #ECA06D; canvas: #090909; surface: #151515; raised: #222222; text: #F5F3F2; muted: #C3BAB7; border: #3C3633; strongBorder: #91857E; selected: #3B2029; focus: #ECA06D; burgundy: #DCA0B1. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#342418", "text": "#F0BE98"}, {"role": "Error", "container": "#3B2029", "text": "#E3A8B9"}, {"role": "Info", "container": "#282523", "text": "#D3C8C1"}]. Supporting accent is context, never a replacement for status semantics. Near-black canvas, true dark grey panels, excellent light-text contrast, no white panels, blue canvas, glow or colorful gradient. Depth comes primarily from distinct surface and raised tones plus crisp borders, as C01.
Composition: Field-focused composition. A broad pickup-task specimen and cash context dominate, with a separate large action strip below; compact role panels sit to the right. High-contrast black/white actions, burgundy cash labels and burnt-orange dimension lines. It must feel glanceable, robust and operational, not a finance dashboard. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Task rhythm". A bordered task card reads "Next pickup", "Collect from seller", "2.4 km", "Pickup quantity", "20 packs". A distinct burgundy-labeled block reads "Cash to collect" and "₹960.00". Fine burnt-orange guides label "16 px card padding" and "16 px task gap". A black primary control with white text reads "View current job"; mark "56 px min height" and the clear space above it "24 px action separation". Page-edge bracket "16 px page inset". Also include readable line "Touch targets ≥ 48 px". In dark mode the primary control becomes off-white with dark text, as C01.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Task card padding | 16 px
Task gap | 16 px
Action separation | 24 px
Primary action min height | 56 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 8 px", "Card — 12 px", "Sheet / dialog — 18 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #3C3633; strong stroke #91857E; focus stroke #ECA06D. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "History row", "Task card", "Route sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.

Pairing constraint: Input Image 2 is the SELECTED C03 LIGHT board for this SAME app, the authoritative CONTENT and COMPOSITION reference. Preserve its exact panel arrangement, all row counts, numeric labels, radius mappings, border widths, dimensional guides, specimen data and relative geometry. Convert it into the approved C01 dark skin from Image 1. Change the theme pill to "Dark", convert canvas/surface/raised/text/brand/support/status colors to the explicit dark tokens above. Do NOT copy old Color roles or Typography panels from Image 1. Do not redesign the light board or add unrelated panels. Use this app’s near-black canvas and dark grey surfaces with all content readable.  Keep the 16 px task-gap horizontal guide BETWEEN pickup quantity and cash block, and the sole 24 px action-separation vertical guide between task card and button. Do not reintroduce duplicate conflicting gap guides.
```
<!-- prompt:dark-1:end -->

## Inherited token specifications

### Light — C01 owner-approved values

| Color role | Hex |
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

### Dark — C01 owner-approved values

| Color role | Hex |
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

### C03 domain role mapping — proposal

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Task card padding | 16 |
| Task gap | 16 |
| Action separation | 24 |
| Primary action min height | 56 |

| Shape role | Approved C01 radius |
| --- | --- |
| Control | 8 |
| Card | 12 |
| Sheet / dialog | 18 |
