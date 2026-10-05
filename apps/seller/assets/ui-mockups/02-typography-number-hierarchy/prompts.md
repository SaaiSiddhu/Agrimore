# Agrimore Seller — typography and number hierarchy prompts

C02 · v1 · Generated 2026-10-02 · **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**.

These two boards were generated with the built-in `image_gen` tool using the matching approved C01 boards as visual-system references. The new typography hierarchy awaits owner approval; the inherited C01 color decision remains approved/locked.

## Domain reading priority

Business revenue → workload → stock quantity → unit price/MOQ → quote or invoice total.

## Role specification

Inter is the visual family reference. Values below are logical UI pixels and font weights. The raster illustrates the roles; actual font resolution, scalable sizing and line-height behavior must be verified when implementing them in Flutter.

| Role | Size / line height | Weight | Specimen |
| --- | --- | --- | --- |
| Revenue | 32 / 40 | 600 | ₹1,25,000 |
| Title | 24 / 32 | 600 | Seller overview |
| Section | 18 / 26 | 600 | Inventory & quotes |
| Body | 16 / 24 | 400 | Review stock before confirming a quote. |
| Label | 14 / 20 | 500 | Available stock |
| Caption | 12 / 16 | 400 | Updated 2 Oct 2026 |
| Unit price | 18 / 24 | 600 | ₹48.00 / pack |
| Quantity | 16 / 24 | 600 | 250 packs |

All monetary values, dates, counts and identifiers in these boards are fictional examples. Pack quantity is distinct from pack weight. Exact financial values retain Indian grouping and two decimals; explicit overview KPIs can use whole rupees. Tabular lining figures keep quantities, ledgers and updated numbers aligned.

## C01 continuity — inherited without changes

See the [approved C01 gallery](../01-color-roles-theme-identity/README.md) and [C01 lock](../01-color-roles-theme-identity/lock.json). These tables are copied exactly from that lock, including the four semantic status container/foreground pairs.

| Color role | Light | Dark |
| --- | --- | --- |
| primary | #0B6A80 | #70D0DF |
| onPrimary | #FFFFFF | #0B2831 |
| support | #9B5E3D | #DAAE8C |
| canvas | #F5F8F9 | #080C0F |
| surface | #FFFFFF | #11191E |
| raised | #F9FCFD | #1B262D |
| text | #142A34 | #F1F7FA |
| muted | #56717E | #B5C9D1 |
| border | #D5E3E8 | #33464F |
| strongBorder | #879EAA | #7895A2 |
| selected | #E5F2F5 | #14313A |
| focus | #0B6A80 | #70D0DF |

| Status | Light container / foreground | Dark container / foreground |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #E6F3F7 / #17647B | #142D37 / #9BD9E9 |

Panels retain C01's surface/border/corner/shadow language. Dark generations use the same app's selected C02 light image for content/composition and its approved C01 dark image for color identity. Refinement history records the additional accent edits where used.

## Provenance

The prompts below preserve the original UTF-8 text. A newline is added before a closing Markdown fence only if required; prompt checksums cover the original text. [manifest.json](manifest.json) records image hashes, dimensions, references, exact C01 values, role definitions and initial-generation history. Historical generated-image filenames are provenance for outside-repository inputs; the two selected final PNGs live in this folder.

This is design-generation provenance, not an executable implementation-worker prompt. See the [five-app domain map](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_DOMAIN_MAP_2026-10-02.md) and [all ten final boards](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_BOARDS_2026-10-02.md).

## Light — exact final generation prompt

Output: [agrimore-seller-typography-number-hierarchy-light.png](agrimore-seller-typography-number-hierarchy-light.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `2224c5735aadbc3311ce0a4bf426e544b08c116da9783fcb5253bad5812668c8`

Prompt SHA-256 (original UTF-8): `94ad89542bad4b3059f7f7ab7c103d5ca304d20d743699f6760eeb35d260e2ee`

```text
Use case: ui-mockup. Precise small edit of the attached C02 Agrimore Seller light typography board. Image 1 is the edit target; image 2 is the approved C01 light design-system reference.
Preserve every panel, content string, figure, numerical arithmetic, type-role annotation, heading, theme pill, typography, layout, canvas, surfaces, border and status chip. Change only the requested accent emphasis (and Admin's numeral-strip size if specified). No redesign, no new panels, no sidebar, no cropped content.
Recolor only the "Gross sales" hero amount ₹1,25,000 to the approved primary blue-teal #0B6A80. Recolor the "Quote hierarchy" heading and "MOQ 20 packs" caption to the approved supporting copper #9B5E3D. Keep every other money/stock figure in the approved text colors. The copper must be visibly present, restrained, with no newly invented hue. Do not recolor status semantics.
Exact immutable base roles: canvas #F5F8F9; surface #FFFFFF; raised #F9FCFD; text primary #142A34; text muted #56717E; border #D5E3E8. Match the same exact app-specific palette from image 2. Preserve all four Success/Warning/Error/Info container and foreground colors. Keep the Agrimore Seller heading and Light pill. All text must remain crisp and verbatim. Flat premium product UI reference, no gradients, glow, photographs, logos or watermark.
```

### Light initial-generation prompt 1

The selected final image refines this earlier draft; this draft is not a final deliverable.

Historical input: `exec-92e3f587-aeeb-44e9-aae8-a2b92a127ad3.png`, SHA-256 `4f726f8ae04c85a9f6ccddedd1ce7f3981a04954cb9047644795fa26439db636`.

```text
Input image 1: the attached APPROVED C01 Agrimore Seller light board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Seller, light theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Blue-teal; copper and cool neutral support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #F5F8F9; panel surface #FFFFFF; raised surface #F9FCFD; primary text #142A34; secondary text #56717E; border #D5E3E8; brand accent #0B6A80; supporting accent #9B5E3D. All text must have excellent contrast. Use an airy light neutral canvas with clean white panels; readable dark text and restrained app-specific accents.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Seller" and a small "Light" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Restrained business typography: compact specimen column, large revenue specimen beside an inventory list, then a horizontal RFQ arithmetic block. The appearance is operational and blue-teal, with copper for secondary stock/quote emphasis. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Revenue" | "32 / 40 · 600" | "₹1,25,000"
"Title" | "24 / 32 · 600" | "Seller overview"
"Section" | "18 / 26 · 600" | "Inventory & quotes"
"Body" | "16 / 24 · 400" | "Review stock before confirming a quote."
"Label" | "14 / 20 · 500" | "Available stock"
"Caption" | "12 / 16 · 400" | "Updated 2 Oct 2026"
"Unit price" | "18 / 24 · 600" | "₹48.00 / pack"
"Quantity" | "16 / 24 · 600" | "250 packs"
Domain hierarchy: Business revenue → workload → stock quantity → unit price/MOQ → quote or invoice total.
Panel "Business numbers": "Gross sales" above a large "₹1,25,000", with smaller "Today" and a separate workload count "24 orders". Under this show a compact text-only inventory row "Fresh tomatoes", "1 kg pack", "Stock", "250 packs", "Unit price", "₹48.00". Keep numerical columns right-aligned.
Panel "Quote hierarchy": "Requested quantity" with "20 packs", "Price per pack" with "₹48.00", and "Quote total" with "₹960.00". Show the exact arithmetic line "20 × ₹48.00 = ₹960.00". Below it, an independently labeled minimum quantity reads "MOQ 20 packs".
Panel "Number rules": "Whole-rupee KPIs"; "Two decimals on invoices"; "Tabular stock & price columns".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #FFFFFF; strongBorder #879EAA; selected #E5F2F5; focus #0B6A80. Border styling: default 1px #D5E3E8; strong 1px #879EAA; focus 2px #0B6A80. Radius references: 10 / 14 / 20 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #E7F5ED, foreground #146C43; Warning: container #FFF4D6, foreground #805400; Error: container #FDECEA, foreground #B42318; Info: container #E6F3F7, foreground #17647B. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.
```

## Dark — exact final generation prompt

Output: [agrimore-seller-typography-number-hierarchy-dark.png](agrimore-seller-typography-number-hierarchy-dark.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `1ad8d35b1e1623913ab9dcc50337b80f864ddb5db4d0fcf56f9a24dca5ae96a4`

Prompt SHA-256 (original UTF-8): `434a7a67f9f9961e0fd037babdff79e2f7013b1504d2bc5b5b2537b30ba9a5d3`

```text
Input image 1: the attached APPROVED C01 Agrimore Seller dark board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Seller, dark theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Blue-teal; copper and cool neutral support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #080C0F; panel surface #11191E; raised surface #1B262D; primary text #F1F7FA; secondary text #B5C9D1; border #33464F; brand accent #70D0DF; supporting accent #DAAE8C. All text must have excellent contrast. Use a genuinely near-black canvas and dark grey panels; do not turn dark mode into a white canvas, a blue background or a colorful gradient.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Seller" and a small "Dark" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Restrained business typography: compact specimen column, large revenue specimen beside an inventory list, then a horizontal RFQ arithmetic block. The appearance is operational and blue-teal, with copper for secondary stock/quote emphasis. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Revenue" | "32 / 40 · 600" | "₹1,25,000"
"Title" | "24 / 32 · 600" | "Seller overview"
"Section" | "18 / 26 · 600" | "Inventory & quotes"
"Body" | "16 / 24 · 400" | "Review stock before confirming a quote."
"Label" | "14 / 20 · 500" | "Available stock"
"Caption" | "12 / 16 · 400" | "Updated 2 Oct 2026"
"Unit price" | "18 / 24 · 600" | "₹48.00 / pack"
"Quantity" | "16 / 24 · 600" | "250 packs"
Domain hierarchy: Business revenue → workload → stock quantity → unit price/MOQ → quote or invoice total.
Panel "Business numbers": "Gross sales" above a large "₹1,25,000", with smaller "Today" and a separate workload count "24 orders". Under this show a compact text-only inventory row "Fresh tomatoes", "1 kg pack", "Stock", "250 packs", "Unit price", "₹48.00". Keep numerical columns right-aligned.
Panel "Quote hierarchy": "Requested quantity" with "20 packs", "Price per pack" with "₹48.00", and "Quote total" with "₹960.00". Show the exact arithmetic line "20 × ₹48.00 = ₹960.00". Below it, an independently labeled minimum quantity reads "MOQ 20 packs".
Panel "Number rules": "Whole-rupee KPIs"; "Two decimals on invoices"; "Tabular stock & price columns".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #0B2831; strongBorder #7895A2; selected #14313A; focus #70D0DF. Border styling: default 1px #33464F; strong 1px #7895A2; focus 2px #70D0DF. Radius references: 10 / 14 / 20 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #102C20, foreground #8DE0B0; Warning: container #302612, foreground #F1CE7B; Error: container #341B1B, foreground #FFA39C; Info: container #142D37, foreground #9BD9E9. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.

Input image 2: the NEW C02 light typography board for this same app. It is the edit target for CONTENT AND COMPOSITION. Preserve every C02 panel, row, specimen, numerical amount and domain hierarchy from image 2. Convert it to this app's dark theme using image 1's exact approved C01 dark palette, border/shadow/corner treatment and semantic status pairs. Change the header pill to "Dark". Do not copy the old C01 Color roles, Spacing, Radius or Shadows panels into C02. Keep all content from image 2 readable on dark surfaces.
```
