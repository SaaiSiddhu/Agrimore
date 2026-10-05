# Agrimore Sales Associate — typography and number hierarchy prompts

C02 · v1 · Generated 2026-10-02 · **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**.

These two boards were generated with the built-in `image_gen` tool using the matching approved C01 boards as visual-system references. The new typography hierarchy awaits owner approval; the inherited C01 color decision remains approved/locked.

## Domain reading priority

Available balance → credited commission → payout status → attributed-order count → associate code.

## Role specification

Inter is the visual family reference. Values below are logical UI pixels and font weights. The raster illustrates the roles; actual font resolution, scalable sizing and line-height behavior must be verified when implementing them in Flutter.

| Role | Size / line height | Weight | Specimen |
| --- | --- | --- | --- |
| Balance | 34 / 42 | 600 | ₹12,500.00 |
| Title | 24 / 32 | 600 | Sales overview |
| Section | 18 / 26 | 600 | Your commissions |
| Body | 16 / 24 | 400 | Track credited commission and payouts. |
| Label | 14 / 20 | 500 | Available balance |
| Caption | 12 / 18 | 400 | Credited 2 Oct 2026 |
| Commission | 20 / 28 | 600 | ₹125.00 |
| Code | 18 / 26 | 600 | AG-2048 |

All monetary values, dates, counts and identifiers in these boards are fictional examples. Pack quantity is distinct from pack weight. Exact financial values retain Indian grouping and two decimals; explicit overview KPIs can use whole rupees. Tabular lining figures keep quantities, ledgers and updated numbers aligned.

## C01 continuity — inherited without changes

See the [approved C01 gallery](../01-color-roles-theme-identity/README.md) and [C01 lock](../01-color-roles-theme-identity/lock.json). These tables are copied exactly from that lock, including the four semantic status container/foreground pairs.

| Color role | Light | Dark |
| --- | --- | --- |
| primary | #2D56C4 | #96B4FF |
| onPrimary | #FFFFFF | #142241 |
| support | #6950A2 | #C0ADE7 |
| canvas | #F7F8FC | #090B11 |
| surface | #FFFFFF | #131722 |
| raised | #FBFCFF | #1E2533 |
| text | #192840 | #F2F5FC |
| muted | #61708B | #B9C5DD |
| border | #DDE3F0 | #354259 |
| strongBorder | #94A0B7 | #8393B2 |
| selected | #EAF0FE | #1B2C50 |
| focus | #2D56C4 | #96B4FF |

| Status | Light container / foreground | Dark container / foreground |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #EDF1FB / #31549E | #1A2B4C / #B2C8FF |

Panels retain C01's surface/border/corner/shadow language. Dark generations use the same app's selected C02 light image for content/composition and its approved C01 dark image for color identity. Refinement history records the additional accent edits where used.

## Provenance

The prompts below preserve the original UTF-8 text. A newline is added before a closing Markdown fence only if required; prompt checksums cover the original text. [manifest.json](manifest.json) records image hashes, dimensions, references, exact C01 values, role definitions and initial-generation history. Historical generated-image filenames are provenance for outside-repository inputs; the two selected final PNGs live in this folder.

This is design-generation provenance, not an executable implementation-worker prompt. See the [five-app domain map](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_DOMAIN_MAP_2026-10-02.md) and [all ten final boards](../../../../../docs/design-system/TYPOGRAPHY_NUMBER_HIERARCHY_BOARDS_2026-10-02.md).

## Light — exact final generation prompt

Output: [agrimore-sales-associate-typography-number-hierarchy-light.png](agrimore-sales-associate-typography-number-hierarchy-light.png). Dimensions: 1587 × 991 px.

PNG SHA-256: `1c4658ada5368255387e4cc7ca1518be6aa66c3d11b41fbde35657af38ccf434`

Prompt SHA-256 (original UTF-8): `114cc8c4fa2a5c10882da7fbd4adc5e3b11af210be803480b65490a35c43d0ee`

```text
Use case: ui-mockup. Precise small edit of the attached C02 Agrimore Sales Associate light typography board. Image 1 is the edit target; image 2 is the approved C01 light design-system reference.
Preserve every panel, content string, figure, numerical arithmetic, type-role annotation, heading, theme pill, typography, layout, canvas, surfaces, border and status chip. Change only the requested accent emphasis (and Admin's numeral-strip size if specified). No redesign, no new panels, no sidebar, no cropped content.
Recolor only the main available-balance amount ₹12,500.00 and +₹125.00 credited-commission amount to approved premium royal blue #2D56C4, replacing any brighter generic electric blue. Recolor "Lifetime commission" and "Pending payout" headings to the exact approved supporting indigo #6950A2. Retain their numerical amounts in approved text primary #192840. Keep pending payout and available balance separate. Do not recolor status semantics.
Exact immutable base roles: canvas #F7F8FC; surface #FFFFFF; raised #FBFCFF; text primary #192840; text muted #61708B; border #DDE3F0. Match the same exact app-specific palette from image 2. Preserve all four Success/Warning/Error/Info container and foreground colors. Keep the Agrimore Sales Associate heading and Light pill. All text must remain crisp and verbatim. Flat premium product UI reference, no gradients, glow, photographs, logos or watermark.
```

### Light initial-generation prompt 1

The selected final image refines this earlier draft; this draft is not a final deliverable.

Historical input: `exec-c22cc10c-2703-45a7-bb4c-edea7d24348f.png`, SHA-256 `500bac802f2ba09a2d65898c9140d2ef6b6535b46184cb6064d364cba54da810`.

```text
Input image 1: the attached APPROVED C01 Agrimore Sales Associate light board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Sales Associate, light theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Premium royal blue; indigo and pearl/slate support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #F7F8FC; panel surface #FFFFFF; raised surface #FBFCFF; primary text #192840; secondary text #61708B; border #DDE3F0; brand accent #2D56C4; supporting accent #6950A2. All text must have excellent contrast. Use an airy light neutral canvas with clean white panels; readable dark text and restrained app-specific accents.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Sales Associate" and a small "Light" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Calm premium financial typography: a generous royal-blue balance specimen, separate quieter indigo payout/lifetime specimens, a commission record and code/count specimen. It should feel personal and focused, with pearl/slate surfaces rather than an administrative ledger or a storefront. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Balance" | "34 / 42 · 600" | "₹12,500.00"
"Title" | "24 / 32 · 600" | "Sales overview"
"Section" | "18 / 26 · 600" | "Your commissions"
"Body" | "16 / 24 · 400" | "Track credited commission and payouts."
"Label" | "14 / 20 · 500" | "Available balance"
"Caption" | "12 / 18 · 400" | "Credited 2 Oct 2026"
"Commission" | "20 / 28 · 600" | "₹125.00"
"Code" | "18 / 26 · 600" | "AG-2048"
Domain hierarchy: Available balance → credited commission → payout status → attributed-order count → associate code.
Panel "Money hierarchy": a large "Available balance" with "₹12,500.00". Separate secondary specimens read "Lifetime commission" and "₹48,250.00", then "Pending payout" and "₹2,000.00". Show a commission record "Commission credited" with "+₹125.00" and "2 Oct 2026". Do not imply these balances are arithmetically equivalent or that pending payout is spendable balance.
Panel "Counts & identity": "Attributed orders" with "24", and "Associate code" with "AG-2048". This code is an identifier with clear glyphs, not a money figure or a phone number.
Panel "Number rules": "Two-decimal money"; "Pending ≠ available"; "Distinct code & count roles".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #FFFFFF; strongBorder #94A0B7; selected #EAF0FE; focus #2D56C4. Border styling: default 1px #DDE3F0; strong 1px #94A0B7; focus 2px #2D56C4. Radius references: 12 / 18 / 24 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #E7F5ED, foreground #146C43; Warning: container #FFF4D6, foreground #805400; Error: container #FDECEA, foreground #B42318; Info: container #EDF1FB, foreground #31549E. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.
```

## Dark — exact final generation prompt

Output: [agrimore-sales-associate-typography-number-hierarchy-dark.png](agrimore-sales-associate-typography-number-hierarchy-dark.png). Dimensions: 1586 × 992 px.

PNG SHA-256: `5b33c1ca5ef6a8ead7d1dc9e83d0c081236c11d66c885554e6566a067303b818`

Prompt SHA-256 (original UTF-8): `06c9f7ccc68e100846a0fa3ee8868c5b237c2e81e20ec8f72409f1061e6e7cdf`

```text
Input image 1: the attached APPROVED C01 Agrimore Sales Associate dark board is the authoritative visual-system reference. Preserve this exact app/theme identity, canvas, panel/raised surface colors, primary/muted text colors, border colors, brand/support colors, header treatment, theme pill, quiet shadows and rounded-corner language. Replace the old Color roles, generic Typography, Surfaces & actions, Spacing, Radius, Borders and Shadows specimen sections with the new C02 typography/number content below. Do not reproduce a C01 color-swatches board. Use the specified C02 layout and domain examples while retaining the original design-system skin.
Use case: ui-mockup.
Asset type: C02 Typography and number hierarchy, premium Storybook-style design-system reference board for Agrimore Sales Associate, dark theme. Generate ONE complete image, landscape 16:10, high-resolution crisp product-design typography. This is a NEW typography board, not a color-swatches board or a whole app screenshot.
Brand identity: Premium royal blue; indigo and pearl/slate support. This app must have its own domain-specific type hierarchy and specimen composition; do not copy another Agrimore app's system.
Locked palette: canvas #090B11; panel surface #131722; raised surface #1E2533; primary text #F2F5FC; secondary text #B9C5DD; border #354259; brand accent #96B4FF; supporting accent #C0ADE7. All text must have excellent contrast. Use a genuinely near-black canvas and dark grey panels; do not turn dark mode into a white canvas, a blue background or a colorful gradient.
Typeface: precise Inter-style sans serif, real professional UI typography. Roles differ by domain, not by random novelty fonts. Weights 400/500/600/700 where specified. Tabular, lining numerals for money, quantities, counts, timers and IDs; stable-width digits and correct rupee glyph. No decorative serif, stencil, handwritten or futuristic font.
Header: ONLY the app name "Agrimore Sales Associate" and a small "Dark" theme pill. A subordinate section label "Typography & number hierarchy" may appear beneath it. No tagline or slogan.
Composition: Calm premium financial typography: a generous royal-blue balance specimen, separate quieter indigo payout/lifetime specimens, a commission record and code/count specimen. It should feel personal and focused, with pearl/slate surfaces rather than an administrative ledger or a storefront. Generous margins, thin restrained borders, quiet elevation, highly legible labels. Make the two themes share this app's role values, content and composition. No sidebar, navigation menu, device frame, browser chrome, logo, watermark, photography or illustration.
Panel "Type roles": columns "Role", "Size / line · weight", and "Specimen". The numeric annotations describe logical UI pixels and font weights. Render specimen words with the correct relative sizes and weights. Exact rows:
"Balance" | "34 / 42 · 600" | "₹12,500.00"
"Title" | "24 / 32 · 600" | "Sales overview"
"Section" | "18 / 26 · 600" | "Your commissions"
"Body" | "16 / 24 · 400" | "Track credited commission and payouts."
"Label" | "14 / 20 · 500" | "Available balance"
"Caption" | "12 / 18 · 400" | "Credited 2 Oct 2026"
"Commission" | "20 / 28 · 600" | "₹125.00"
"Code" | "18 / 26 · 600" | "AG-2048"
Domain hierarchy: Available balance → credited commission → payout status → attributed-order count → associate code.
Panel "Money hierarchy": a large "Available balance" with "₹12,500.00". Separate secondary specimens read "Lifetime commission" and "₹48,250.00", then "Pending payout" and "₹2,000.00". Show a commission record "Commission credited" with "+₹125.00" and "2 Oct 2026". Do not imply these balances are arithmetically equivalent or that pending payout is spendable balance.
Panel "Counts & identity": "Attributed orders" with "24", and "Associate code" with "AG-2048". This code is an identifier with clear glyphs, not a money figure or a phone number.
Panel "Number rules": "Two-decimal money"; "Pending ≠ available"; "Distinct code & count roles".
Bottom micro-specimen: "0123456789  ₹  %  kg  L  km" with the label "Tabular numerals". Use readable caption size, not tiny microtext. Keep body copy natural, sentence case and clearly secondary to titles and operational amounts. Keep units visually attached to their value while giving the numeric value emphasis. Financial columns align to the right; names align to the left. Count and weight are different quantities. Price and cash figures are fictional specimen data, not live application data.
Text accuracy: copy every quoted heading, specimen, amount, decimal, Indian comma grouping and unit exactly. Render ₹ correctly, not $ or an invented glyph. Maintain clear numerical hierarchy, generous reading space and a full uncropped board. No extra invented panels, generic lorem ipsum, green brand remnants in blue apps, universal supporting blue, gradients, glows, low-contrast captions or illegible text.
C01 additional immutable color roles: onPrimary #142241; strongBorder #8393B2; selected #1B2C50; focus #96B4FF. Border styling: default 1px #354259; strong 1px #8393B2; focus 2px #96B4FF. Radius references: 12 / 18 / 24 px; spacing rhythm: 4 / 8 / 12 / 16 / 24 / 32 px. Match the original calm shadow appearance, do not introduce glowing elevation.
Semantic status typography must use ONLY the original C01 role pairs: Success: container #102C20, foreground #8DE0B0; Warning: container #302612, foreground #F1CE7B; Error: container #341B1B, foreground #FFA39C; Info: container #1A2B4C, foreground #B2C8FF. Add a small four-chip line labeled "State labels" with "Success", "Warning", "Error", "Info"; each chip uses its corresponding exact container/foreground pair and a small status symbol. Do not use success green as Seller/Admin/Associate's brand accent, or recolor warnings to their supporting copper/cyan/indigo. Do not confuse Delivery's neutral Info with a blue badge. This strip demonstrates label legibility, not a new status-color system.

Input image 2: the NEW C02 light typography board for this same app. It is the edit target for CONTENT AND COMPOSITION. Preserve every C02 panel, row, specimen, numerical amount and domain hierarchy from image 2. Convert it to this app's dark theme using image 1's exact approved C01 dark palette, border/shadow/corner treatment and semantic status pairs. Change the header pill to "Dark". Do not copy the old C01 Color roles, Spacing, Radius or Shadows panels into C02. Keep all content from image 2 readable on dark surfaces.
```
