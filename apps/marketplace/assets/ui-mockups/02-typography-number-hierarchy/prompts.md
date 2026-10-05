# Agrimore Marketplace — typography and number hierarchy prompts

C02 · v1 · Generated 2026-10-02 · **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**.

These two boards were generated with the built-in `image_gen` tool using the matching approved C01 boards as visual-system references. The new typography hierarchy awaits owner approval; the inherited C01 color decision remains approved/locked.

## Domain reading priority

Product name → selling price → pack specification → purchase quantity → payable total.

## Role specification

Inter is the visual family reference. Values below are logical UI pixels and font weights. The raster illustrates the roles; actual font resolution, scalable sizing and line-height behavior must be verified when implementing them in Flutter.

| Role | Size / line height | Weight | Specimen |
| --- | --- | --- | --- |
| Display | 36 / 44 | 700 | Fresh from the farm |
| Title | 26 / 34 | 600 | Shop fresh produce |
| Product | 20 / 28 | 600 | Fresh tomatoes |
| Body | 16 / 24 | 400 | Choose a pack for your household. |
| Label | 14 / 20 | 600 | Pack size |
| Caption | 12 / 18 | 400 | Price includes applicable taxes |
| Price | 32 / 40 | 700 | ₹48.00 |
| Quantity | 16 / 24 | 600 | 2 packs |

All monetary values, dates, counts and identifiers in these boards are fictional examples. Pack quantity is distinct from pack weight. Exact financial values retain Indian grouping and two decimals; explicit overview KPIs can use whole rupees. Tabular lining figures keep quantities, ledgers and updated numbers aligned.

## C01 continuity — inherited without changes

See the [approved C01 gallery](../01-color-roles-theme-identity/README.md) and [C01 lock](../01-color-roles-theme-identity/lock.json). These tables are copied exactly from that lock, including the four semantic status container/foreground pairs.

| Color role | Light | Dark |
| --- | --- | --- |
| primary | #087A4B | #67D2A1 |
| onPrimary | #FFFFFF | #0B291D |
| support | #9A6826 | #DDB97A |
| canvas | #F7F9F6 | #090C0A |
| surface | #FFFFFF | #141A16 |
| raised | #FBFCF9 | #1E2721 |
| text | #1A2C21 | #F2F7F3 |
| muted | #5D7062 | #B9C9BD |
| border | #DAE4DB | #344338 |
| strongBorder | #91A594 | #798F7E |
| selected | #E5F3E9 | #163325 |
| focus | #087A4B | #67D2A1 |

| Status | Light container / foreground | Dark container / foreground |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #E7F2EC / #286B4D | #173126 / #A1D8B9 |

Panels retain C01's surface/border/corner/shadow language. Dark generations use the same app's selected C02 light image for content/composition and its approved C01 dark image for color identity. Refinement history records the additional accent edits where used.

## Provenance

The prompts below preserve the original UTF-8 text. A newline is added before a closing Markdown fence only if required; prompt checksums cover the original text. [manifest.json](manifest.json) records image hashes, dimensions, references, exact C01 values, role definitions and initial-generation history. Historical generated-image filenames are provenance for outside-repository inputs; the two selected final PNGs live in this folder.

This is design-generation provenance, not an executable implementation-worker prompt. See the [five-app domain map](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_DOMAIN_MAP_2026-10-02.md) and [all ten final boards](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_BOARDS_2026-10-02.md).

## Light — exact final generation prompt

Output: [agrimore-marketplace-typography-number-hierarchy-light.png](agrimore-marketplace-typography-number-hierarchy-light.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `4a3cb78d1926423272ff4d779bad861ce84b23db7b93ace0cb58a658f7c0f5f9`

Prompt SHA-256 (original UTF-8): `58442db4ce466813d8d7428d82b065f60f747e08cbc318683534abc15418a61c`

```text
Input image 1: the attached APPROVED C01 Agrimore Marketplace light board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Marketplace, light theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Professional green; warm gold and natural stone support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #F7F9F6; panel surface #FFFFFF; raised surface #FBFCF9; primary text #1A2C21; secondary text #5D7062; border #DAE4DB; brand accent #087A4B; supporting accent #9A6826. All text must have excellent contrast. Use an airy light neutral canvas with clean white panels; readable dark text and restrained app-specific accents.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Marketplace" and a small "Light" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Airy shopping typography: broad specimen column and a generous product-price hierarchy panel, then a full-width cart-total strip. Product title and price dominate; gold stays a subtle supporting accent. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Display" | "36 / 44 · 700" | "Fresh from the farm"
"Title" | "26 / 34 · 600" | "Shop fresh produce"
"Product" | "20 / 28 · 600" | "Fresh tomatoes"
"Body" | "16 / 24 · 400" | "Choose a pack for your household."
"Label" | "14 / 20 · 600" | "Pack size"
"Caption" | "12 / 18 · 400" | "Price includes applicable taxes"
"Price" | "32 / 40 · 700" | "₹48.00"
"Quantity" | "16 / 24 · 600" | "2 packs"
Domain hierarchy: Product name → selling price → pack specification → purchase quantity → payable total.
Panel "Product price hierarchy": a text-only product specimen with "Fresh tomatoes", "1 kg pack", big green "₹48.00", smaller muted struck-through "₹60.00", and a quiet warm-gold "Save ₹12.00" label. A clearly subordinate line reads "per pack". Below it show "Quantity" with "2 packs" and "1 kg each". A final total row reads "Payable total" and "₹96.00". An independent miniature specimen reads "Bulk request" and "20 packs".
Panel "Number rules": "Indian grouping: ₹1,25,000.00"; "Pack count ≠ pack weight"; "Exact totals, clear units".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #FFFFFF; strongBorder #91A594; selected #E5F3E9; focus #087A4B. Border styling: default 1px #DAE4DB; strong 1px #91A594; focus 2px #087A4B. Radius references: 12 / 16 / 24 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #E7F5ED, foreground #146C43; Warning: container #FFF4D6, foreground #805400; Error: container #FDECEA, foreground #B42318; Info: container #E7F2EC, foreground #286B4D. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.
```

## Dark — exact final generation prompt

Output: [agrimore-marketplace-typography-number-hierarchy-dark.png](agrimore-marketplace-typography-number-hierarchy-dark.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `1d96f23f24c76b93529fddd699b37625dfdc54902a4fddaff5ee6ea118e1c646`

Prompt SHA-256 (original UTF-8): `a9a48b8b834acd1366ff6ac20b8da4b5d16a2806d79cff52d3dcced75096f42a`

```text
Input image 1: the attached APPROVED C01 Agrimore Marketplace dark board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Marketplace, dark theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Professional green; warm gold and natural stone support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #090C0A; panel surface #141A16; raised surface #1E2721; primary text #F2F7F3; secondary text #B9C9BD; border #344338; brand accent #67D2A1; supporting accent #DDB97A. All text must have excellent contrast. Use a genuinely near-black canvas and dark grey panels; do not turn dark mode into a white canvas, a blue background or a colorful gradient.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Marketplace" and a small "Dark" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Airy shopping typography: broad specimen column and a generous product-price hierarchy panel, then a full-width cart-total strip. Product title and price dominate; gold stays a subtle supporting accent. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Display" | "36 / 44 · 700" | "Fresh from the farm"
"Title" | "26 / 34 · 600" | "Shop fresh produce"
"Product" | "20 / 28 · 600" | "Fresh tomatoes"
"Body" | "16 / 24 · 400" | "Choose a pack for your household."
"Label" | "14 / 20 · 600" | "Pack size"
"Caption" | "12 / 18 · 400" | "Price includes applicable taxes"
"Price" | "32 / 40 · 700" | "₹48.00"
"Quantity" | "16 / 24 · 600" | "2 packs"
Domain hierarchy: Product name → selling price → pack specification → purchase quantity → payable total.
Panel "Product price hierarchy": a text-only product specimen with "Fresh tomatoes", "1 kg pack", big green "₹48.00", smaller muted struck-through "₹60.00", and a quiet warm-gold "Save ₹12.00" label. A clearly subordinate line reads "per pack". Below it show "Quantity" with "2 packs" and "1 kg each". A final total row reads "Payable total" and "₹96.00". An independent miniature specimen reads "Bulk request" and "20 packs".
Panel "Number rules": "Indian grouping: ₹1,25,000.00"; "Pack count ≠ pack weight"; "Exact totals, clear units".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #0B291D; strongBorder #798F7E; selected #163325; focus #67D2A1. Border styling: default 1px #344338; strong 1px #798F7E; focus 2px #67D2A1. Radius references: 12 / 16 / 24 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #102C20, foreground #8DE0B0; Warning: container #302612, foreground #F1CE7B; Error: container #341B1B, foreground #FFA39C; Info: container #173126, foreground #A1D8B9. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.

Input image 2: the NEW C02 light typography board for this same app. It is the edit target for CONTENT AND COMPOSITION. Preserve every C02 panel, row, specimen, numerical amount and domain hierarchy from image 2. Convert it to this app's dark theme using image 1's exact approved C01 dark palette, border/shadow/corner treatment and semantic status pairs. Change the header pill to "Dark". Do not copy the old C01 Color roles, Spacing, Radius or Shadows panels into C02. Keep all content from image 2 readable on dark surfaces.
```
