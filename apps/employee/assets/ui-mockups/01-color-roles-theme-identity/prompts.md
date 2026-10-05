# Agrimore Sales Associate — approved design-token prompts

Status: **APPROVED / LOCKED — v2**. Owner decision dated 2026-10-02.

Approval evidence: “Brooo perfect, fantastic,.. now lock all of these”. This approves the latest app-specific light/dark boards from this design session. These are design references; approval does not certify that the application code already implements the tokens.

## Identity

Premium royal blue with muted indigo, pearl and slate support.

Repository app: `apps/employee`. Supporting colors follow this app's identity. Functional status colors remain semantic, including success green where shown. Dark mode uses the approved near-black canvas and dark grey surfaces.

## Canonical color values

These values are preserved from the generation specification. Use these documented hexadecimal values when implementing tokens; the generated raster is the visual reference.

| Role | Light | Dark |
| --- | --- | --- |
| Primary | #2D56C4 | #96B4FF |
| On primary | #FFFFFF | #142241 |
| Supporting accent | #6950A2 | #C0ADE7 |
| Canvas | #F7F8FC | #090B11 |
| Surface | #FFFFFF | #131722 |
| Raised surface | #FBFCFF | #1E2533 |
| Text primary | #192840 | #F2F5FC |
| Text muted | #61708B | #B9C5DD |
| Border default | #DDE3F0 | #354259 |
| Border strong | #94A0B7 | #8393B2 |
| Selected container | #EAF0FE | #1B2C50 |
| Focus | #2D56C4 | #96B4FF |

Supporting accent label: **Supporting indigo**.

| Status | Light container / text | Dark container / text |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #EDF1FB / #31549E | #1A2B4C / #B2C8FF |

## Other board foundations

- Typeface reference: Inter; weights 600, 500, 400.
- Type scale: 34 / 24 / 18 / 16 / 14 / 12 px.
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 px.
- Radius: 12 / 18 / 24 px.
- Borders: default 1 px; strong 1 px; focus 2 px, with the corresponding palette roles above.
- Shadows: Flat / Soft / Raised as shown in the approved boards. Numeric shadow implementation remains to be specified.
- Presentation: one full-width Storybook-style board per theme, app-name heading and theme pill, no sidebar.

## Generation provenance and revision policy

Tool: built-in `image_gen`. Both originals were edits of earlier v1 reference boards, preserving each app's existing token-board layout. The original edit-prompt text below is retained verbatim. A separating newline is added before the closing Markdown fence when the original prompt has no final newline; the prompt checksum always covers the original text. Original newline presence is recorded in [lock.json](lock.json), alongside historical input filenames and checksums. V1 is superseded and is not included as an approved asset here.

For future edits, attach the corresponding approved PNG in this folder as the reference. Retain this pair and its checksums, and record an owner-approved successor in a new versioned location. Do not silently overwrite these approved files. `prompts.md` is design-generation provenance, not an executable phase or worker prompt.

The two files are byte-identical copies of the approved v2 outputs, each 1586 × 992 px. See the [gallery](README.md), [machine-readable lock](lock.json), and [five-app approval record](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Light — exact original generation prompt

Output: [agrimore-sales-associate-design-tokens-light.png](agrimore-sales-associate-design-tokens-light.png)

Image SHA-256: `5e40ab35853e74ff50cc1256d4445976f72d232fa3941b4393c073100e739e19`

Prompt SHA-256 (original UTF-8 text): `8a9907a71965513733b65ca2967061ef6f4c7fd68390295c19b58052d665dae3`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Sales Associate light Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: PREMIUM ROYAL BLUE, polished personal sales/commission workspace, muted indigo/lavender supporting accent and pearl/slate neutrals. Distinctly brighter and more personal than Admin's institutional blue.
The header must contain ONLY "Agrimore Sales Associate" and a small "Light" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #F7F8FC, panel surface #FFFFFF, raised surface #FBFCFF, text #192840, muted text #61708B. Keep the full board premium airy white/off-white with crisp readable dark typography.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #2D56C4; "Supporting indigo" #6950A2; "Canvas" #F7F8FC; "Surface" #FFFFFF; "Raised" #FBFCFF; "Text primary" #192840; "Text muted" #61708B; "Border" #DDE3F0. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Supporting indigo".
Solid primary sample button: #2D56C4 fill, #FFFFFF label. Secondary button uses restrained #DDE3F0 or brand-outline border. "View details" uses #6950A2. Selected badge uses #EAF0FE container and #2D56C4 readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #E7F5ED / #146C43; Warning #FFF4D6 / #805400; Error #FDECEA / #B42318; Info #EDF1FB / #31549E. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #DDE3F0; "Strong" 1px #94A0B7; "Focus" 2px #2D56C4. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```

## Dark — exact original generation prompt

Output: [agrimore-sales-associate-design-tokens-dark.png](agrimore-sales-associate-design-tokens-dark.png)

Image SHA-256: `579b82781b7cac9f889ec36a11448bab868333024ad3f7c037e14d1c3997ec62`

Prompt SHA-256 (original UTF-8 text): `e8cee7e5df4fc6c8b3deae06c11922c1cfeb82c1a6478477e53dc61cf43dcfdc`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Sales Associate dark Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: PREMIUM ROYAL BLUE, polished personal sales/commission workspace, muted indigo/lavender supporting accent and pearl/slate neutrals. Distinctly brighter and more personal than Admin's institutional blue.
The header must contain ONLY "Agrimore Sales Associate" and a small "Dark" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #090B11, panel surface #131722, raised surface #1E2533, text #F2F5FC, muted text #B9C5DD. Keep the full board genuinely near-black and charcoal with readable off-white/light gray type; no white cards or bright full-canvas brand tint.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #96B4FF; "Supporting indigo" #C0ADE7; "Canvas" #090B11; "Surface" #131722; "Raised" #1E2533; "Text primary" #F2F5FC; "Text muted" #B9C5DD; "Border" #354259. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Supporting indigo".
Solid primary sample button: #96B4FF fill, #142241 label. Secondary button uses restrained #354259 or brand-outline border. "View details" uses #C0ADE7. Selected badge uses #1B2C50 container and #96B4FF readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #102C20 / #8DE0B0; Warning #302612 / #F1CE7B; Error #341B1B / #FFA39C; Info #1A2B4C / #B2C8FF. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #354259; "Strong" 1px #8393B2; "Focus" 2px #96B4FF. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```
