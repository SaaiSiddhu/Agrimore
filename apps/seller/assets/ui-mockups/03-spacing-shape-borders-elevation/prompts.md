# Agrimore Seller — C03 image generation prompts

Foundation: Spacing, shape, borders and elevation. Date: 2026-10-03.
Tool: **built-in image_gen**. Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. Owner approval has not been recorded for C03.

The corresponding [C01 lock](../01-color-roles-theme-identity/lock.json) supplies authoritative light/dark palettes, status colors, core spacing, radius arrays and border widths. Light uses the C01 light board as an identity reference. Dark uses the C01 dark board for skin and this app’s selected C03 light board for content/composition. Refinements below correct specific annotation or action-color mismatches; their exact input/output paths and hashes preserve provenance. Discarded drafts remain session artifacts, not selected app assets.

The prompts specify token values; raster generation is illustrative and cannot guarantee pixel-exact color or geometry. Use the manifest and domain map as implementation targets. No runtime tokens or screens were modified by this asset task.

## Light

Selected asset: [agrimore-seller-spacing-shape-borders-elevation-light.png](agrimore-seller-spacing-shape-borders-elevation-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-light.png` · SHA-256 `04d17f7ec077a040e8689bea57f1cc678d3b24ee0bd4a7f9be4717b5a848185c`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-9a6573d7-7f11-4c6d-8847-01c8ae3c3659.png` · SHA-256 `f471348087ecc56666e7ea5faf95b4d4bf091a1284444441d33d3b5220b2b405`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Seller, light theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 light board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Seller" and a small "Light" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Blue-teal, copper and cool neutrals. Palette tokens: primary: #0B6A80; onPrimary: #FFFFFF; support: #9B5E3D; canvas: #F5F8F9; surface: #FFFFFF; raised: #F9FCFD; text: #142A34; muted: #56717E; border: #D5E3E8; strongBorder: #879EAA; selected: #E5F2F5; focus: #0B6A80. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E6F3F7", "text": "#17647B"}]. Supporting accent is context, never a replacement for status semantics. Airy neutral canvas, clean white/near-white panels, quiet soft shadows. No full-color panel backgrounds, excessive shadows or low-contrast text.
Composition: Compact operational composition. A large annotated inventory ledger and a distinct copper-led RFQ editor occupy the main area; a narrow spacing-reference column sits beside them. Align table values and use restrained blue-teal controls. Copper must visibly label RFQ context and spacing guides. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Inventory rhythm". A bordered ledger with columns "Product", "Stock", "Unit price" and one row "Fresh tomatoes", "250 packs", "₹48.00". Dimension guides show "16 px card padding", "12 px cell padding" and "8 px row gap". Beneath, a copper heading "Quote workspace" above a compact editor with "Requested quantity", "20 packs", "Quote total", "₹960.00", and a blue-teal "Review quote" control. Mark "24 px section gap" between ledger and editor. A page-edge bracket labeled "16 px page inset". Do not turn the ledger into unrelated shadowed rows.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Inventory card padding | 16 px
Table cell padding | 12 px
Row content gap | 8 px
Section gap | 24 px
Minimum control height | 48 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 10 px", "Card — 14 px", "Sheet / dialog — 20 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #D5E3E8; strong stroke #879EAA; focus stroke #0B6A80. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Inventory ledger", "Quote editor", "Quote sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.
```
<!-- prompt:light-1:end -->

## Dark

Selected asset: [agrimore-seller-spacing-shape-borders-elevation-dark.png](agrimore-seller-spacing-shape-borders-elevation-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-dark.png` · SHA-256 `2608e9115e73f8ff7bf1a06e5921757fd488f0c4f3e0b6a219271b0e5d01de90`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/03-spacing-shape-borders-elevation/agrimore-seller-spacing-shape-borders-elevation-light.png` · SHA-256 `f471348087ecc56666e7ea5faf95b4d4bf091a1284444441d33d3b5220b2b405`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-f4e50244-922e-4845-a3fa-d18be5cc6cfd.png` · SHA-256 `43294683b2afb9283f124897a7189401b190a425b0ab0f0b8b085eb8ee7134b8`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Seller, dark theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 dark board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Seller" and a small "Dark" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Blue-teal, copper and cool neutrals. Palette tokens: primary: #70D0DF; onPrimary: #0B2831; support: #DAAE8C; canvas: #080C0F; surface: #11191E; raised: #1B262D; text: #F1F7FA; muted: #B5C9D1; border: #33464F; strongBorder: #7895A2; selected: #14313A; focus: #70D0DF. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#142D37", "text": "#9BD9E9"}]. Supporting accent is context, never a replacement for status semantics. Near-black canvas, true dark grey panels, excellent light-text contrast, no white panels, blue canvas, glow or colorful gradient. Depth comes primarily from distinct surface and raised tones plus crisp borders, as C01.
Composition: Compact operational composition. A large annotated inventory ledger and a distinct copper-led RFQ editor occupy the main area; a narrow spacing-reference column sits beside them. Align table values and use restrained blue-teal controls. Copper must visibly label RFQ context and spacing guides. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Inventory rhythm". A bordered ledger with columns "Product", "Stock", "Unit price" and one row "Fresh tomatoes", "250 packs", "₹48.00". Dimension guides show "16 px card padding", "12 px cell padding" and "8 px row gap". Beneath, a copper heading "Quote workspace" above a compact editor with "Requested quantity", "20 packs", "Quote total", "₹960.00", and a blue-teal "Review quote" control. Mark "24 px section gap" between ledger and editor. A page-edge bracket labeled "16 px page inset". Do not turn the ledger into unrelated shadowed rows.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Inventory card padding | 16 px
Table cell padding | 12 px
Row content gap | 8 px
Section gap | 24 px
Minimum control height | 48 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 10 px", "Card — 14 px", "Sheet / dialog — 20 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #33464F; strong stroke #7895A2; focus stroke #70D0DF. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Inventory ledger", "Quote editor", "Quote sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.

Pairing constraint: Input Image 2 is the SELECTED C03 LIGHT board for this SAME app, the authoritative CONTENT and COMPOSITION reference. Preserve its exact panel arrangement, all row counts, numeric labels, radius mappings, border widths, dimensional guides, specimen data and relative geometry. Convert it into the approved C01 dark skin from Image 1. Change the theme pill to "Dark", convert canvas/surface/raised/text/brand/support/status colors to the explicit dark tokens above. Do NOT copy old Color roles or Typography panels from Image 1. Do not redesign the light board or add unrelated panels. Use this app’s near-black canvas and dark grey surfaces with all content readable. 
```
<!-- prompt:dark-1:end -->

## Inherited token specifications

### Light — C01 owner-approved values

| Color role | Hex |
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

### Dark — C01 owner-approved values

| Color role | Hex |
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

### C03 domain role mapping — proposal

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Inventory card padding | 16 |
| Table cell padding | 12 |
| Row content gap | 8 |
| Section gap | 24 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius |
| --- | --- |
| Control | 10 |
| Card | 14 |
| Sheet / dialog | 20 |
