# Agrimore Delivery — typography and number hierarchy prompts

C02 · v1 · Generated 2026-10-02 · **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**.

These two boards were generated with the built-in `image_gen` tool using the matching approved C01 boards as visual-system references. The new typography hierarchy awaits owner approval; the inherited C01 color decision remains approved/locked.

## Domain reading priority

Offer/task timing → pickup/drop distance and address → cash to collect → item count → reference metadata.

## Role specification

Inter is the visual family reference. Values below are logical UI pixels and font weights. The raster illustrates the roles; actual font resolution, scalable sizing and line-height behavior must be verified when implementing them in Flutter.

| Role | Size / line height | Weight | Specimen |
| --- | --- | --- | --- |
| Countdown | 40 / 48 | 700 | 00:24 |
| Title | 24 / 32 | 700 | Next pickup |
| Task | 20 / 28 | 600 | Collect from seller |
| Body | 17 / 26 | 400 | Check the pack count at pickup. |
| Label | 14 / 20 | 600 | Cash to collect |
| Caption | 12 / 18 | 400 | Order reference |
| Cash | 32 / 40 | 700 | ₹960.00 |
| Distance | 28 / 36 | 700 | 2.4 km |

All monetary values, dates, counts and identifiers in these boards are fictional examples. Pack quantity is distinct from pack weight. Exact financial values retain Indian grouping and two decimals; explicit overview KPIs can use whole rupees. Tabular lining figures keep quantities, ledgers and updated numbers aligned.

## C01 continuity — inherited without changes

See the [approved C01 gallery](../01-color-roles-theme-identity/README.md) and [C01 lock](../01-color-roles-theme-identity/lock.json). These tables are copied exactly from that lock, including the four semantic status container/foreground pairs.

| Color role | Light | Dark |
| --- | --- | --- |
| primary | #191919 | #F4F4F4 |
| onPrimary | #FFFFFF | #151515 |
| support | #A94D24 | #ECA06D |
| canvas | #F8F7F6 | #090909 |
| surface | #FFFFFF | #151515 |
| raised | #FAF9F8 | #222222 |
| text | #1C1C1C | #F5F3F2 |
| muted | #686260 | #C3BAB7 |
| border | #DDD7D4 | #3C3633 |
| strongBorder | #A49993 | #91857E |
| selected | #F5E7EC | #3B2029 |
| focus | #A94D24 | #ECA06D |
| burgundy | #7A2840 | #DCA0B1 |

| Status | Light container / foreground | Dark container / foreground |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FBEDE3 / #88451E | #342418 / #F0BE98 |
| Error | #F5E7EC / #7A2840 | #3B2029 / #E3A8B9 |
| Info | #ECEAE8 / #59534F | #282523 / #D3C8C1 |

Panels retain C01's surface/border/corner/shadow language. Dark generations use the same app's selected C02 light image for content/composition and its approved C01 dark image for color identity. Refinement history records the additional accent edits where used.

## Provenance

The prompts below preserve the original UTF-8 text. A newline is added before a closing Markdown fence only if required; prompt checksums cover the original text. [manifest.json](manifest.json) records image hashes, dimensions, references, exact C01 values, role definitions and initial-generation history. Historical generated-image filenames are provenance for outside-repository inputs; the two selected final PNGs live in this folder.

This is design-generation provenance, not an executable implementation-worker prompt. See the [five-app domain map](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_DOMAIN_MAP_2026-10-02.md) and [all ten final boards](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_BOARDS_2026-10-02.md).

## Light — exact final generation prompt

Output: [agrimore-delivery-typography-number-hierarchy-light.png](agrimore-delivery-typography-number-hierarchy-light.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `39a92e38539679d481d6b995c7296209def7be051e0a793be1696109f01fd6ee`

Prompt SHA-256 (original UTF-8): `9d9a61cfbe0c898f7cac1224e1afa3f0cb12a4c33da5a622bfddbf520eba14c3`

```text
Input image 1: the attached APPROVED C01 Agrimore Delivery light board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Delivery, light theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Black/white; burgundy and burnt orange support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #F8F7F6; panel surface #FFFFFF; raised surface #FAF9F8; primary text #1C1C1C; secondary text #686260; border #DDD7D4; brand accent #191919; supporting accent #A94D24; burgundy #7A2840. All text must have excellent contrast. Use an airy light neutral canvas with clean white panels; readable dark text and restrained app-specific accents.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Delivery" and a small "Light" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Bold glanceable field typography: a dominant live-offer countdown specimen and distance/cash stack, with a tighter role-reference panel beside it. Wide separation around operational numbers. High-contrast black/white dominates; burgundy labels cash/context and orange labels time/route emphasis. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Countdown" | "40 / 48 · 700" | "00:24"
"Title" | "24 / 32 · 700" | "Next pickup"
"Task" | "20 / 28 · 600" | "Collect from seller"
"Body" | "17 / 26 · 400" | "Check the pack count at pickup."
"Label" | "14 / 20 · 600" | "Cash to collect"
"Caption" | "12 / 18 · 400" | "Order reference"
"Cash" | "32 / 40 · 700" | "₹960.00"
"Distance" | "28 / 36 · 700" | "2.4 km"
Domain hierarchy: Offer/task timing → pickup/drop distance and address → cash to collect → item count → reference metadata.
Panel "Operational numbers": explicitly label the big tabular "00:24" as "Offer expires in". Another block labeled "Pickup distance" reads "2.4 km". A distinct cash specimen reads "Cash to collect" and "₹960.00"; keep the exact paise visible. A final quantity line reads "Pickup quantity" and "20 packs". Do not conflate cash collection with personal earnings.
Panel "Field readability": "Next pickup"; "Check the pack count at pickup."; "Order reference"; "AGR-2048". Critical task instructions and cash labels are readable at 14 or 17, never tiny metadata.
Panel "Number rules": "Stable countdown digits"; "Always show distance units"; "Cash collection ≠ earnings".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #FFFFFF; strongBorder #A49993; selected #F5E7EC; focus #A94D24. Border styling: default 1px #DDD7D4; strong 1px #A49993; focus 2px #A94D24. Radius references: 8 / 12 / 18 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #E7F5ED, foreground #146C43; Warning: container #FBEDE3, foreground #88451E; Error: container #F5E7EC, foreground #7A2840; Info: container #ECEAE8, foreground #59534F. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.
```

## Dark — exact final generation prompt

Output: [agrimore-delivery-typography-number-hierarchy-dark.png](agrimore-delivery-typography-number-hierarchy-dark.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `380906f17bdbf8f78bb76567b3c4d46f857e848f7b3cae255fb0d4ef50ee512e`

Prompt SHA-256 (original UTF-8): `94fb97e4d495904f695f6b853e5b9418b400dab7cf6deefc29d55c91f50f3a24`

```text
Input image 1: the attached APPROVED C01 Agrimore Delivery dark board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Delivery, dark theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Black/white; burgundy and burnt orange support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #090909; panel surface #151515; raised surface #222222; primary text #F5F3F2; secondary text #C3BAB7; border #3C3633; brand accent #F4F4F4; supporting accent #ECA06D; burgundy #DCA0B1. All text must have excellent contrast. Use a genuinely near-black canvas and dark grey panels; do not turn dark mode into a white canvas, a blue background or a colorful gradient.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Delivery" and a small "Dark" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Bold glanceable field typography: a dominant live-offer countdown specimen and distance/cash stack, with a tighter role-reference panel beside it. Wide separation around operational numbers. High-contrast black/white dominates; burgundy labels cash/context and orange labels time/route emphasis. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Countdown" | "40 / 48 · 700" | "00:24"
"Title" | "24 / 32 · 700" | "Next pickup"
"Task" | "20 / 28 · 600" | "Collect from seller"
"Body" | "17 / 26 · 400" | "Check the pack count at pickup."
"Label" | "14 / 20 · 600" | "Cash to collect"
"Caption" | "12 / 18 · 400" | "Order reference"
"Cash" | "32 / 40 · 700" | "₹960.00"
"Distance" | "28 / 36 · 700" | "2.4 km"
Domain hierarchy: Offer/task timing → pickup/drop distance and address → cash to collect → item count → reference metadata.
Panel "Operational numbers": explicitly label the big tabular "00:24" as "Offer expires in". Another block labeled "Pickup distance" reads "2.4 km". A distinct cash specimen reads "Cash to collect" and "₹960.00"; keep the exact paise visible. A final quantity line reads "Pickup quantity" and "20 packs". Do not conflate cash collection with personal earnings.
Panel "Field readability": "Next pickup"; "Check the pack count at pickup."; "Order reference"; "AGR-2048". Critical task instructions and cash labels are readable at 14 or 17, never tiny metadata.
Panel "Number rules": "Stable countdown digits"; "Always show distance units"; "Cash collection ≠ earnings".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #151515; strongBorder #91857E; selected #3B2029; focus #ECA06D. Border styling: default 1px #3C3633; strong 1px #91857E; focus 2px #ECA06D. Radius references: 8 / 12 / 18 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #102C20, foreground #8DE0B0; Warning: container #342418, foreground #F0BE98; Error: container #3B2029, foreground #E3A8B9; Info: container #282523, foreground #D3C8C1. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.

Input image 2: the NEW C02 light typography board for this same app. It is the edit target for CONTENT AND COMPOSITION. Preserve every C02 panel, row, specimen, numerical amount and domain hierarchy from image 2. Convert it to this app's dark theme using image 1's exact approved C01 dark palette, border/shadow/corner treatment and semantic status pairs. Change the header pill to "Dark". Do not copy the old C01 Color roles, Spacing, Radius or Shadows panels into C02. Keep all content from image 2 readable on dark surfaces.
```
