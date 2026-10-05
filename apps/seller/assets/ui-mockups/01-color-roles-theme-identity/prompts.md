# Agrimore Seller — approved design-token prompts

Status: **APPROVED / LOCKED — v2**. Owner decision dated 2026-10-02.

Approval evidence: “Brooo perfect, fantastic,.. now lock all of these”. This approves the latest app-specific light/dark boards from this design session. These are design references; approval does not certify that the application code already implements the tokens.

## Identity

Blue-teal with warm copper and cool neutral support.

Repository app: `apps/seller`. Supporting colors follow this app's identity. Functional status colors remain semantic, including success green where shown. Dark mode uses the approved near-black canvas and dark grey surfaces.

## Canonical color values

These values are preserved from the generation specification. Use these documented hexadecimal values when implementing tokens; the generated raster is the visual reference.

| Role | Light | Dark |
| --- | --- | --- |
| Primary | #0B6A80 | #70D0DF |
| On primary | #FFFFFF | #0B2831 |
| Supporting accent | #9B5E3D | #DAAE8C |
| Canvas | #F5F8F9 | #080C0F |
| Surface | #FFFFFF | #11191E |
| Raised surface | #F9FCFD | #1B262D |
| Text primary | #142A34 | #F1F7FA |
| Text muted | #56717E | #B5C9D1 |
| Border default | #D5E3E8 | #33464F |
| Border strong | #879EAA | #7895A2 |
| Selected container | #E5F2F5 | #14313A |
| Focus | #0B6A80 | #70D0DF |

Supporting accent label: **Warm copper**.

| Status | Light container / text | Dark container / text |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FFF4D6 / #805400 | #302612 / #F1CE7B |
| Error | #FDECEA / #B42318 | #341B1B / #FFA39C |
| Info | #E6F3F7 / #17647B | #142D37 / #9BD9E9 |

## Other board foundations

- Typeface reference: Inter; weights 600, 500, 400.
- Type scale: 32 / 24 / 18 / 16 / 14 / 12 px.
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 px.
- Radius: 10 / 14 / 20 px.
- Borders: default 1 px; strong 1 px; focus 2 px, with the corresponding palette roles above.
- Shadows: Flat / Soft / Raised as shown in the approved boards. Numeric shadow implementation remains to be specified.
- Presentation: one full-width Storybook-style board per theme, app-name heading and theme pill, no sidebar.

## Generation provenance and revision policy

Tool: built-in `image_gen`. Both originals were edits of earlier v1 reference boards, preserving each app's existing token-board layout. The original edit-prompt text below is retained verbatim. A separating newline is added before the closing Markdown fence when the original prompt has no final newline; the prompt checksum always covers the original text. Original newline presence is recorded in [lock.json](lock.json), alongside historical input filenames and checksums. V1 is superseded and is not included as an approved asset here.

For future edits, attach the corresponding approved PNG in this folder as the reference. Retain this pair and its checksums, and record an owner-approved successor in a new versioned location. Do not silently overwrite these approved files. `prompts.md` is design-generation provenance, not an executable phase or worker prompt.

The two files are byte-identical copies of the approved v2 outputs, each 1586 × 992 px. See the [gallery](README.md), [machine-readable lock](lock.json), and [five-app approval record](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Light — exact original generation prompt

Output: [agrimore-seller-design-tokens-light.png](agrimore-seller-design-tokens-light.png)

Image SHA-256: `04d17f7ec077a040e8689bea57f1cc678d3b24ee0bd4a7f9be4717b5a848185c`

Prompt SHA-256 (original UTF-8 text): `3550e85bbe551ca5aaf653e6d6d9eb1e85539498cc5037b9bfe8e9bdbd57f32d`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Seller light Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: BLUE-TEAL: a refined ocean/petrol blue with teal influence, more blue than green. Warm copper support and cool neutral surfaces. Not forest green and not royal blue.
The header must contain ONLY "Agrimore Seller" and a small "Light" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #F5F8F9, panel surface #FFFFFF, raised surface #F9FCFD, text #142A34, muted text #56717E. Keep the full board premium airy white/off-white with crisp readable dark typography.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #0B6A80; "Warm copper" #9B5E3D; "Canvas" #F5F8F9; "Surface" #FFFFFF; "Raised" #F9FCFD; "Text primary" #142A34; "Text muted" #56717E; "Border" #D5E3E8. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Warm copper".
Solid primary sample button: #0B6A80 fill, #FFFFFF label. Secondary button uses restrained #D5E3E8 or brand-outline border. "View details" uses #9B5E3D. Selected badge uses #E5F2F5 container and #0B6A80 readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #E7F5ED / #146C43; Warning #FFF4D6 / #805400; Error #FDECEA / #B42318; Info #E6F3F7 / #17647B. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #D5E3E8; "Strong" 1px #879EAA; "Focus" 2px #0B6A80. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```

## Dark — exact original generation prompt

Output: [agrimore-seller-design-tokens-dark.png](agrimore-seller-design-tokens-dark.png)

Image SHA-256: `2608e9115e73f8ff7bf1a06e5921757fd488f0c4f3e0b6a219271b0e5d01de90`

Prompt SHA-256 (original UTF-8 text): `e20b8b73c8d828cfd6821b21db861d4cd9b13879e424015d78d09dbdec85249d`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Seller dark Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: BLUE-TEAL: a refined ocean/petrol blue with teal influence, more blue than green. Warm copper support and cool neutral surfaces. Not forest green and not royal blue.
The header must contain ONLY "Agrimore Seller" and a small "Dark" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #080C0F, panel surface #11191E, raised surface #1B262D, text #F1F7FA, muted text #B5C9D1. Keep the full board genuinely near-black and charcoal with readable off-white/light gray type; no white cards or bright full-canvas brand tint.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #70D0DF; "Warm copper" #DAAE8C; "Canvas" #080C0F; "Surface" #11191E; "Raised" #1B262D; "Text primary" #F1F7FA; "Text muted" #B5C9D1; "Border" #33464F. Keep eight aligned swatches. The OLD label "Supporting blue" must be replaced with "Warm copper".
Solid primary sample button: #70D0DF fill, #0B2831 label. Secondary button uses restrained #33464F or brand-outline border. "View details" uses #DAAE8C. Selected badge uses #14313A container and #70D0DF readable foreground. 
"Status colors" specimens, exact matched container/text hex captions: Success #102C20 / #8DE0B0; Warning #302612 / #F1CE7B; Error #341B1B / #FFA39C; Info #142D37 / #9BD9E9. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #33464F; "Strong" 1px #7895A2; "Focus" 2px #70D0DF. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```
