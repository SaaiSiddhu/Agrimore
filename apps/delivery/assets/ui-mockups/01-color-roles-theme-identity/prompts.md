# Agrimore Delivery — approved design-token prompts

Status: **APPROVED / LOCKED — v2**. Owner decision dated 2026-10-02.

Approval evidence: “Brooo perfect, fantastic,.. now lock all of these”. This approves the latest app-specific light/dark boards from this design session. These are design references; approval does not certify that the application code already implements the tokens.

## Identity

Black/white with burgundy and burnt orange support.

Repository app: `apps/delivery`. Supporting colors follow this app's identity. Functional status colors remain semantic, including success green where shown. Dark mode uses the approved near-black canvas and dark grey surfaces.

## Canonical color values

These values are preserved from the generation specification. Use these documented hexadecimal values when implementing tokens; the generated raster is the visual reference.

| Role | Light | Dark |
| --- | --- | --- |
| Primary | #191919 | #F4F4F4 |
| On primary | #FFFFFF | #151515 |
| Supporting accent | #A94D24 | #ECA06D |
| Canvas | #F8F7F6 | #090909 |
| Surface | #FFFFFF | #151515 |
| Raised surface | #FAF9F8 | #222222 |
| Text primary | #1C1C1C | #F5F3F2 |
| Text muted | #686260 | #C3BAB7 |
| Border default | #DDD7D4 | #3C3633 |
| Border strong | #A49993 | #91857E |
| Selected container | #F5E7EC | #3B2029 |
| Focus | #A94D24 | #ECA06D |
| Burgundy accent | #7A2840 | #DCA0B1 |

Supporting accent label: **Burnt orange**.

| Status | Light container / text | Dark container / text |
| --- | --- | --- |
| Success | #E7F5ED / #146C43 | #102C20 / #8DE0B0 |
| Warning | #FBEDE3 / #88451E | #342418 / #F0BE98 |
| Error | #F5E7EC / #7A2840 | #3B2029 / #E3A8B9 |
| Info | #ECEAE8 / #59534F | #282523 / #D3C8C1 |

## Other board foundations

- Typeface reference: Inter; weights 700, 600, 400.
- Type scale: 32 / 24 / 20 / 17 / 14 / 12 px.
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 px.
- Radius: 8 / 12 / 18 px.
- Borders: default 1 px; strong 1 px; focus 2 px, with the corresponding palette roles above.
- Shadows: Flat / Soft / Raised as shown in the approved boards. Numeric shadow implementation remains to be specified.
- Presentation: one full-width Storybook-style board per theme, app-name heading and theme pill, no sidebar.

## Generation provenance and revision policy

Tool: built-in `image_gen`. Both originals were edits of earlier v1 reference boards, preserving each app's existing token-board layout. The original edit-prompt text below is retained verbatim. A separating newline is added before the closing Markdown fence when the original prompt has no final newline; the prompt checksum always covers the original text. Original newline presence is recorded in [lock.json](lock.json), alongside historical input filenames and checksums. V1 is superseded and is not included as an approved asset here.

For future edits, attach the corresponding approved PNG in this folder as the reference. Retain this pair and its checksums, and record an owner-approved successor in a new versioned location. Do not silently overwrite these approved files. `prompts.md` is design-generation provenance, not an executable phase or worker prompt.

The two files are byte-identical copies of the approved v2 outputs, each 1586 × 992 px. See the [gallery](README.md), [machine-readable lock](lock.json), and [five-app approval record](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Light — exact original generation prompt

Output: [agrimore-delivery-design-tokens-light.png](agrimore-delivery-design-tokens-light.png)

Image SHA-256: `2384d327a37606012a2f3dc2d9427b63447ce9be1ae6b121d1294cc62872e383`

Prompt SHA-256 (original UTF-8 text): `96a4d1611d88b885f811df55fef335f7df818b5b35d16c745a4bef92a4c458b2`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Delivery light Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: BLACK / WHITE monochrome field-operations system with BURGUNDY and BURNT ORANGE supporting accents. Keep black or white as the primary action color, use burgundy for selected/review accents and burnt orange for useful emphasis. NO green primary and NO blue supporting theme.
The header must contain ONLY "Agrimore Delivery" and a small "Light" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #F8F7F6, panel surface #FFFFFF, raised surface #FAF9F8, text #1C1C1C, muted text #686260. Keep the full board premium airy white/off-white with crisp readable dark typography.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #191919; "Burnt orange" #A94D24; "Burgundy" #7A2840; "Canvas" #F8F7F6; "Surface" #FFFFFF; "Raised" #FAF9F8; "Text primary" #1C1C1C; "Text muted" #686260; "Border" #DDD7D4. Use nine aligned swatches in Delivery so both Burgundy and Burnt orange have their own labeled specimens. The OLD label "Supporting blue" must be replaced with "Burnt orange".
Solid primary sample button: #191919 fill, #FFFFFF label. Secondary button uses restrained #DDD7D4 or brand-outline border. "View details" uses #A94D24. Selected badge uses #F5E7EC container and #7A2840 readable foreground. Delivery secondary-outline or selected accent may use Burgundy; primary must remain black in light and white in dark. Do not turn the primary into burgundy or orange.
"Status colors" specimens, exact matched container/text hex captions: Success #E7F5ED / #146C43; Warning #FBEDE3 / #88451E; Error #F5E7EC / #7A2840; Info #ECEAE8 / #59534F. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #DDD7D4; "Strong" 1px #A49993; "Focus" 2px #A94D24. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```

## Dark — exact original generation prompt

Output: [agrimore-delivery-design-tokens-dark.png](agrimore-delivery-design-tokens-dark.png)

Image SHA-256: `745bda063c678184a1c0dc206bab60f45c659f08e0a5824a95fc19e4171385c4`

Prompt SHA-256 (original UTF-8 text): `0ebd257c12efc0f7ad564e38fbf751098d13a386bd09cd3fe87a8d014efe40ed`

```text
Use case: ui-mockup. EDIT TARGET: the attached existing Agrimore Delivery dark Storybook token board.
Make a precise premium palette correction. Preserve the existing full-width landscape editorial token-board layout, app heading, typography panel, application-specific sample action, spacing/radius values, border and shadow sections. This is the SAME app and SAME theme; do not switch theme or produce multiple boards.
NEW APP IDENTITY: BLACK / WHITE monochrome field-operations system with BURGUNDY and BURNT ORANGE supporting accents. Keep black or white as the primary action color, use burgundy for selected/review accents and burnt orange for useful emphasis. NO green primary and NO blue supporting theme.
The header must contain ONLY "Agrimore Delivery" and a small "Dark" theme pill. Remove any extra tagline or slogan. No sidebar, navigation menu, browser/device frame, logo, photograph or watermark.
Theme canvas must be #090909, panel surface #151515, raised surface #222222, text #F5F3F2, muted text #C3BAB7. Keep the full board genuinely near-black and charcoal with readable off-white/light gray type; no white cards or bright full-canvas brand tint.
Replace ALL old green/blue brand artifacts, swatches, buttons, selected badges, links, focus rings and hex captions with the new app-specific values. Keep functional success green only in the small Success specimen where appropriate, never as this app's primary unless this is Marketplace.
The full-width "Color roles" swatch strip must contain these exact labels and captions: "Primary" #F4F4F4; "Burnt orange" #ECA06D; "Burgundy" #DCA0B1; "Canvas" #090909; "Surface" #151515; "Raised" #222222; "Text primary" #F5F3F2; "Text muted" #C3BAB7; "Border" #3C3633. Use nine aligned swatches in Delivery so both Burgundy and Burnt orange have their own labeled specimens. The OLD label "Supporting blue" must be replaced with "Burnt orange".
Solid primary sample button: #F4F4F4 fill, #151515 label. Secondary button uses restrained #3C3633 or brand-outline border. "View details" uses #ECA06D. Selected badge uses #3B2029 container and #DCA0B1 readable foreground. Delivery secondary-outline or selected accent may use Burgundy; primary must remain black in light and white in dark. Do not turn the primary into burgundy or orange.
"Status colors" specimens, exact matched container/text hex captions: Success #102C20 / #8DE0B0; Warning #342418 / #F0BE98; Error #3B2029 / #E3A8B9; Info #282523 / #D3C8C1. Retain success, warning, error and info icons/text. Info follows this app's identity, not a universally copied blue.
Borders: "Default" 1px #3C3633; "Strong" 1px #91857E; "Focus" 2px #ECA06D. Recolor spacing/radius specimens subtly to harmonize with this app. Shadows remain calm low elevation and theme-appropriate; no glow.
Preserve precise readable wording in every panel, all typography/spacing/radius values, full uncropped board and generous margins. Exact app name, accurate hexadecimal captions and clear light/dark theme. Flat 2D shippable UI design-token reference, not an illustration. Avoid gradients, illegible microtext, extra invented text and remnants of the superseded uniform-green palette.
```
