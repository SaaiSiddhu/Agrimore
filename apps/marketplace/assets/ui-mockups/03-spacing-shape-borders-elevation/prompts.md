# Agrimore Marketplace — C03 image generation prompts

Foundation: Spacing, shape, borders and elevation. Date: 2026-10-03.
Tool: **built-in image_gen**. Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. Owner approval has not been recorded for C03.

The corresponding [C01 lock](../01-color-roles-theme-identity/lock.json) supplies authoritative light/dark palettes, status colors, core spacing, radius arrays and border widths. Light uses the C01 light board as an identity reference. Dark uses the C01 dark board for skin and this app’s selected C03 light board for content/composition. Refinements below correct specific annotation or action-color mismatches; their exact input/output paths and hashes preserve provenance. Discarded drafts remain session artifacts, not selected app assets.

The prompts specify token values; raster generation is illustrative and cannot guarantee pixel-exact color or geometry. Use the manifest and domain map as implementation targets. No runtime tokens or screens were modified by this asset task.

## Light

Selected asset: [agrimore-marketplace-spacing-shape-borders-elevation-light.png](agrimore-marketplace-spacing-shape-borders-elevation-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-light.png` · SHA-256 `cc568e8551edcfeb1e6358fa2bd83a3599636eba1102e8b115aa9247e3fefcda`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-1d8f7dfd-bee4-40be-b9bf-418bac7662ff.png` · SHA-256 `bf2140f8dcaa2aa4a9d668ca3ba2ca29c6024a5d138ff87b861ccdbe482d6a4c`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Marketplace, light theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 light board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Marketplace" and a small "Light" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Professional green, warm gold and natural stone. Palette tokens: primary: #087A4B; onPrimary: #FFFFFF; support: #9A6826; canvas: #F7F9F6; surface: #FFFFFF; raised: #FBFCF9; text: #1A2C21; muted: #5D7062; border: #DAE4DB; strongBorder: #91A594; selected: #E5F3E9; focus: #087A4B. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E7F2EC", "text": "#286B4D"}]. Supporting accent is context, never a replacement for status semantics. Airy neutral canvas, clean white/near-white panels, quiet soft shadows. No full-color panel backgrounds, excessive shadows or low-contrast text.
Composition: Airy shopping composition. A large annotated two-card product grid occupies the left half, a compact spacing reference occupies the right; a horizontal cart-summary specimen sits below the product grid. Warm gold is visible on pack context and measurement guides, with green for purchase actions. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Shopping rhythm". Two text-only product cards, each with "Fresh tomatoes", "1 kg pack", "₹48.00", and a green "Add to cart" control. Use fine dimension lines showing "16 px padding" inside one card, "12 px gap" between the two cards, and "24 px section gap" above a cart-summary strip labeled "Payable total" and "₹96.00". Avoid photos; show structural alignment and whitespace. One small page-edge bracket labeled "16 px page inset". Warm-gold "Pack details" heading and warm-gold measurement labels must be visible.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Product card padding | 16 px
Product grid gap | 12 px
Section gap | 24 px
Minimum control height | 48 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 12 px", "Card — 16 px", "Sheet / dialog — 24 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #DAE4DB; strong stroke #91A594; focus stroke #087A4B. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Cart row", "Product card", "Address sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.
```
<!-- prompt:light-1:end -->

## Dark

Selected asset: [agrimore-marketplace-spacing-shape-borders-elevation-dark.png](agrimore-marketplace-spacing-shape-borders-elevation-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-dark.png` · SHA-256 `63b4648caac7e8d4a4137aa41090bbc4bcc46a1727cf808379a1fba4ec87f4ca`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/03-spacing-shape-borders-elevation/agrimore-marketplace-spacing-shape-borders-elevation-light.png` · SHA-256 `bf2140f8dcaa2aa4a9d668ca3ba2ca29c6024a5d138ff87b861ccdbe482d6a4c`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-cd65b665-4bec-4a56-a9a4-d61a0f642c0b.png` · SHA-256 `65e68068baded1fa49150a08021d5a14eaa7d3e04ea442704cae3a8a1fbcb76b`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Marketplace, dark theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 dark board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Marketplace" and a small "Dark" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Professional green, warm gold and natural stone. Palette tokens: primary: #67D2A1; onPrimary: #0B291D; support: #DDB97A; canvas: #090C0A; surface: #141A16; raised: #1E2721; text: #F2F7F3; muted: #B9C9BD; border: #344338; strongBorder: #798F7E; selected: #163325; focus: #67D2A1. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#173126", "text": "#A1D8B9"}]. Supporting accent is context, never a replacement for status semantics. Near-black canvas, true dark grey panels, excellent light-text contrast, no white panels, blue canvas, glow or colorful gradient. Depth comes primarily from distinct surface and raised tones plus crisp borders, as C01.
Composition: Airy shopping composition. A large annotated two-card product grid occupies the left half, a compact spacing reference occupies the right; a horizontal cart-summary specimen sits below the product grid. Warm gold is visible on pack context and measurement guides, with green for purchase actions. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Shopping rhythm". Two text-only product cards, each with "Fresh tomatoes", "1 kg pack", "₹48.00", and a green "Add to cart" control. Use fine dimension lines showing "16 px padding" inside one card, "12 px gap" between the two cards, and "24 px section gap" above a cart-summary strip labeled "Payable total" and "₹96.00". Avoid photos; show structural alignment and whitespace. One small page-edge bracket labeled "16 px page inset". Warm-gold "Pack details" heading and warm-gold measurement labels must be visible.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Product card padding | 16 px
Product grid gap | 12 px
Section gap | 24 px
Minimum control height | 48 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 12 px", "Card — 16 px", "Sheet / dialog — 24 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #344338; strong stroke #798F7E; focus stroke #67D2A1. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Cart row", "Product card", "Address sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.

Pairing constraint: Input Image 2 is the SELECTED C03 LIGHT board for this SAME app, the authoritative CONTENT and COMPOSITION reference. Preserve its exact panel arrangement, all row counts, numeric labels, radius mappings, border widths, dimensional guides, specimen data and relative geometry. Convert it into the approved C01 dark skin from Image 1. Change the theme pill to "Dark", convert canvas/surface/raised/text/brand/support/status colors to the explicit dark tokens above. Do NOT copy old Color roles or Typography panels from Image 1. Do not redesign the light board or add unrelated panels. Use this app’s near-black canvas and dark grey surfaces with all content readable. 
```
<!-- prompt:dark-1:end -->
### Step 2 — targeted_refinement

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-cd65b665-4bec-4a56-a9a4-d61a0f642c0b.png` · SHA-256 `65e68068baded1fa49150a08021d5a14eaa7d3e04ea442704cae3a8a1fbcb76b`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/marketplace/assets/ui-mockups/01-color-roles-theme-identity/agrimore-marketplace-design-tokens-dark.png` · SHA-256 `63b4648caac7e8d4a4137aa41090bbc4bcc46a1727cf808379a1fba4ec87f4ca`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-6af8995b-14d8-4cfc-a427-7b7ed8ffee58.png` · SHA-256 `d455d08b6a77f5ef818490b17c9449947bfddcc516609698ffe543dd97d1955f`.

<!-- prompt:dark-2:begin -->
```text
Use case: ui-mockup. Image 1 is the new Agrimore Marketplace DARK C03 board, the edit target. Image 2 is its APPROVED C01 DARK board, the authoritative palette reference. Change ONLY the TWO "Add to cart" controls inside the product cards. Their fills must be the approved dark primary mint-green #67D2A1, solid and flat, and their text and cart icons must be the approved very-dark onPrimary #0B291D. Remove the dark-green fill, white label and bright outlined treatment on those two controls. They must visually match the filled mint-green dark action in Image 2. Preserve EVERYTHING ELSE: exact geometry, panel arrangement, all text including every number, spacing scale, Domain spacing rows, Shape roles, Border roles, Surface depth, dark canvas/panels, dimension guides and theme pill. Do not regenerate or recolor other content, add panels, change financial figures, crop edges or copy old C01 panels. Crisp high-resolution typography and boundaries.
```
<!-- prompt:dark-2:end -->

## Inherited token specifications

### Light — C01 owner-approved values

| Color role | Hex |
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

### Dark — C01 owner-approved values

| Color role | Hex |
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

### C03 domain role mapping — proposal

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Product card padding | 16 |
| Product grid gap | 12 |
| Section gap | 24 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius |
| --- | --- |
| Control | 12 |
| Card | 16 |
| Sheet / dialog | 24 |
