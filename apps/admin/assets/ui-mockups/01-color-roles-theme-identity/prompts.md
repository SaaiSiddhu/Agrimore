# Agrimore Admin — approved design-token prompts

Status: **APPROVED / LOCKED — v2**. Owner decision dated 2026-10-02.

Approval evidence: “Brooo perfect, fantastic,.. now lock all of these”. This approves the latest app-specific light/dark boards from this design session. These are design references; approval does not certify that the application code already implements the tokens.

## Identity

Professional institutional blue with cyan and steel/slate support.

Repository app: `apps/admin`. Supporting colors follow this app's identity. Functional status colors remain semantic, including success green where shown. Dark mode uses the approved near-black canvas and dark grey surfaces.

## Canonical color values

These values are preserved from the generation specification. Use these documented hexadecimal values when implementing tokens; the generated raster is the visual reference.

| Role | Light | Dark |
| --- | --- | --- |
| Primary | #1D4F91 | #93B3EC |
| On primary | #FFFFFF | #0D203E |
| Supporting accent | #087E8B | #7BCBD5 |
| Canvas | #F5F7FB | #080B10 |
| Surface | #FFFFFF | #121922 |
| Raised surface | #F9FBFE | #1D2837 |
| Text primary | #14243B | #F2F6FC |
| Text muted | #5B6B82 | #B5C3D6 |
| Border default | #D8E1EF | #314157 |
| Border strong | #8C9DB5 | #74869E |
| Selected container | #E8EFF8 | #192E4A |
| Focus | #1D4F91 | #93B3EC |

Supporting accent label: **Supporting cyan**.

| Status | Light container / text | Dark container / text |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #E8F0FA / #24528C | #172A42 / #AFCCF6 |

## Other board foundations

- Typeface reference: Inter; weights 600, 500, 400.
- Type scale: 32 / 24 / 18 / 16 / 14 / 12 px.
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 px.
- Radius: 8 / 12 / 16 px.
- Borders: default 1 px; strong 1 px; focus 2 px, with the corresponding palette roles above.
- Shadows: Flat / Soft / Raised as shown in the approved boards. Numeric shadow implementation remains to be specified.
- Presentation: one full-width Storybook-style board per theme, app-name heading and theme pill, no sidebar.

## Generation provenance and revision policy

Tool: built-in `image_gen`. Both originals were edits of earlier v1 reference boards, preserving each app's existing token-board layout. The original edit-prompt text below is retained verbatim. A separating newline is added before the closing Markdown fence when the original prompt has no final newline; the prompt checksum always covers the original text. Original newline presence is recorded in [lock.json](lock.json), alongside historical input filenames and checksums. V1 is superseded and is not included as an approved asset here.

For future edits, attach the corresponding approved PNG in this folder as the reference. Retain this pair and its checksums, and record an owner-approved successor in a new versioned location. Do not silently overwrite these approved files. `prompts.md` is design-generation provenance, not an executable phase or worker prompt.

The two files are byte-identical copies of the approved v2 outputs, each 1586 × 992 px. See the [gallery](README.md), [machine-readable lock](lock.json), and [five-app approval record](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Light — exact original generation prompt

Output: [agrimore-admin-design-tokens-light.png](agrimore-admin-design-tokens-light.png)

Image SHA-256: `fca2bb37fc479e39d3bdc3da8c45e5968af3840edf4ad66312e18a6860d4c1a4`

Prompt SHA-256 (original UTF-8 text): `b39eedb1297552a5b1708c8b65021abc8f13d32f0ba3559708c3372f6b469ad1`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Admin light Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: institutional professional blue, precise and restrained, cool cyan support, steel/slate neutrals; distinctly calmer and deeper than the Sales Associate royal blue
The header must contain ONLY "Agrimore Admin" and a small "Light" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #F5F7FB, panel surface #FFFFFF, raised surface #F9FBFE, text #14243B, muted text #5B6B82. Keep the full board premium airy white/off-white with crisp readable dark typography.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #1D4F91; "Supporting cyan" #087E8B; "Canvas" #F5F7FB; "Surface" #FFFFFF; "Raised" #F9FBFE; "Text primary" #14243B; "Text muted" #5B6B82; "Border" #D8E1EF. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Supporting cyan".
Solid primary sample button: #1D4F91 fill, #FFFFFF label. Secondary button uses restrained #D8E1EF or brand-outline border. "View details" uses #087E8B. Selected badge uses #E8EFF8 container and #1D4F91 readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #E7F5ED / #146C43; Warning #FFF4D6 / #805400; Error #FDECEA / #B42318; Info #E8F0FA / #24528C. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #D8E1EF; "Strong" 1px #8C9DB5; "Focus" 2px #1D4F91. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```

## Dark — exact original generation prompt

Output: [agrimore-admin-design-tokens-dark.png](agrimore-admin-design-tokens-dark.png)

Image SHA-256: `d232ad575ce49311efa785e4dfc2fc781c81d297184215e8f66979536f67041b`

Prompt SHA-256 (original UTF-8 text): `64d88a0e159ee5186009e999d201f6075805a38cad06cc2b2414fd2e7703f827`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Admin dark Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: institutional professional blue, precise and restrained, cool cyan support, steel/slate neutrals; distinctly calmer and deeper than the Sales Associate royal blue
The header must contain ONLY "Agrimore Admin" and a small "Dark" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #080B10, panel surface #121922, raised surface #1D2837, text #F2F6FC, muted text #B5C3D6. Keep the full board genuinely near-black and charcoal with readable off-white/light gray type; no white cards or bright full-canvas brand tint.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #93B3EC; "Supporting cyan" #7BCBD5; "Canvas" #080B10; "Surface" #121922; "Raised" #1D2837; "Text primary" #F2F6FC; "Text muted" #B5C3D6; "Border" #314157. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Supporting cyan".
Solid primary sample button: #93B3EC fill, #0D203E label. Secondary button uses restrained #314157 or brand-outline border. "View details" uses #7BCBD5. Selected badge uses #192E4A container and #93B3EC readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #102C20 / #8DE0B0; Warning #302612 / #F1CE7B; Error #341B1B / #FFA39C; Info #172A42 / #AFCCF6. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #314157; "Strong" 1px #74869E; "Focus" 2px #93B3EC. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```
