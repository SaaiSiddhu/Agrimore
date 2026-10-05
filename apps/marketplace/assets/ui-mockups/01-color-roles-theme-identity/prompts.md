# Agrimore Marketplace — approved design-token prompts

Status: **APPROVED / LOCKED — v2**. Owner decision dated 2026-10-02.

Approval evidence: “Brooo perfect, fantastic,.. now lock all of these”. This approves the latest app-specific light/dark boards from this design session. These are design references; approval does not certify that the application code already implements the tokens.

## Identity

Professional green with warm gold and natural stone support.

Repository app: `apps/marketplace`. Supporting colors follow this app's identity. Functional status colors remain semantic, including success green where shown. Dark mode uses the approved near-black canvas and dark grey surfaces.

## Canonical color values

These values are preserved from the generation specification. Use these documented hexadecimal values when implementing tokens; the generated raster is the visual reference.

| Role | Light | Dark |
| --- | --- | --- |
| Primary | #087A4B | #67D2A1 |
| On primary | #FFFFFF | #0B291D |
| Supporting accent | #9A6826 | #DDB97A |
| Canvas | #F7F9F6 | #090C0A |
| Surface | #FFFFFF | #141A16 |
| Raised surface | #FBFCF9 | #1E2721 |
| Text primary | #1A2C21 | #F2F7F3 |
| Text muted | #5D7062 | #B9C9BD |
| Border default | #DAE4DB | #344338 |
| Border strong | #91A594 | #798F7E |
| Selected container | #E5F3E9 | #163325 |
| Focus | #087A4B | #67D2A1 |

Supporting accent label: **Warm gold**.

| Status | Light container / text | Dark container / text |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #E7F2EC / #286B4D | #173126 / #A1D8B9 |

## Other board foundations

- Typeface reference: Inter; weights 700, 600, 400.
- Type scale: 36 / 26 / 20 / 16 / 14 / 12 px.
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 px.
- Radius: 12 / 16 / 24 px.
- Borders: default 1 px; strong 1 px; focus 2 px, with the corresponding palette roles above.
- Shadows: Flat / Soft / Raised as shown in the approved boards. Numeric shadow implementation remains to be specified.
- Presentation: one full-width Storybook-style board per theme, app-name heading and theme pill, no sidebar.

## Generation provenance and revision policy

Tool: built-in `image_gen`. Both originals were edits of earlier v1 reference boards, preserving each app's existing token-board layout. The original edit-prompt text below is retained verbatim. A separating newline is added before the closing Markdown fence when the original prompt has no final newline; the prompt checksum always covers the original text. Original newline presence is recorded in [lock.json](lock.json), alongside historical input filenames and checksums. V1 is superseded and is not included as an approved asset here.

For future edits, attach the corresponding approved PNG in this folder as the reference. Retain this pair and its checksums, and record an owner-approved successor in a new versioned location. Do not silently overwrite these approved files. `prompts.md` is design-generation provenance, not an executable phase or worker prompt.

The two files are byte-identical copies of the approved v2 outputs, each 1586 × 992 px. See the [gallery](README.md), [machine-readable lock](lock.json), and [five-app approval record](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Light — exact original generation prompt

Output: [agrimore-marketplace-design-tokens-light.png](agrimore-marketplace-design-tokens-light.png)

Image SHA-256: `cc568e8551edcfeb1e6358fa2bd83a3599636eba1102e8b115aa9247e3fefcda`

Prompt SHA-256 (original UTF-8 text): `0bc12b0c7adf8809494abb488aba83460ce3eee91fb9da37864b08fd685b30a2`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Marketplace light Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: professional premium forest/jade GREEN, warm muted gold support and natural stone neutrals; not blue, not neon, not lime
The header must contain ONLY "Agrimore Marketplace" and a small "Light" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #F7F9F6, panel surface #FFFFFF, raised surface #FBFCF9, text #1A2C21, muted text #5D7062. Keep the full board premium airy white/off-white with crisp readable dark typography.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #087A4B; "Warm gold" #9A6826; "Canvas" #F7F9F6; "Surface" #FFFFFF; "Raised" #FBFCF9; "Text primary" #1A2C21; "Text muted" #5D7062; "Border" #DAE4DB. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Warm gold".
Solid primary sample button: #087A4B fill, #FFFFFF label. Secondary button uses restrained #DAE4DB or brand-outline border. "View details" uses #9A6826. Selected badge uses #E5F3E9 container and #087A4B readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #E7F5ED / #146C43; Warning #FFF4D6 / #805400; Error #FDECEA / #B42318; Info #E7F2EC / #286B4D. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #DAE4DB; "Strong" 1px #91A594; "Focus" 2px #087A4B. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```

## Dark — exact original generation prompt

Output: [agrimore-marketplace-design-tokens-dark.png](agrimore-marketplace-design-tokens-dark.png)

Image SHA-256: `63b4648caac7e8d4a4137aa41090bbc4bcc46a1727cf808379a1fba4ec87f4ca`

Prompt SHA-256 (original UTF-8 text): `fdddf60178946caf762c94b4e6e5efc9c7610f44a17a49ebe5de7294a05f833c`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Marketplace dark Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: professional premium forest/jade GREEN, warm muted gold support and natural stone neutrals; not blue, not neon, not lime
The header must contain ONLY "Agrimore Marketplace" and a small "Dark" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #090C0A, panel surface #141A16, raised surface #1E2721, text #F2F7F3, muted text #B9C9BD. Keep the full board genuinely near-black and charcoal with readable off-white/light gray type; no white cards or bright full-canvas brand tint.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #67D2A1; "Warm gold" #DDB97A; "Canvas" #090C0A; "Surface" #141A16; "Raised" #1E2721; "Text primary" #F2F7F3; "Text muted" #B9C9BD; "Border" #344338. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Warm gold".
Solid primary sample button: #67D2A1 fill, #0B291D label. Secondary button uses restrained #344338 or brand-outline border. "View details" uses #DDB97A. Selected badge uses #163325 container and #67D2A1 readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #102C20 / #8DE0B0; Warning #302612 / #F1CE7B; Error #341B1B / #FFA39C; Info #173126 / #A1D8B9. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #344338; "Strong" 1px #798F7E; "Focus" 2px #67D2A1. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```
