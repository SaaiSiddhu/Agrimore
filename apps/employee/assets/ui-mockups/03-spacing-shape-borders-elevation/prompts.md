# Agrimore Sales Associate — C03 image generation prompts

Foundation: Spacing, shape, borders and elevation. Date: 2026-10-03.
Tool: **built-in image_gen**. Status: **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. Owner approval has not been recorded for C03.

The corresponding [C01 lock](../01-color-roles-theme-identity/lock.json) supplies authoritative light/dark palettes, status colors, core spacing, radius arrays and border widths. Light uses the C01 light board as an identity reference. Dark uses the C01 dark board for skin and this app’s selected C03 light board for content/composition. Refinements below correct specific annotation or action-color mismatches; their exact input/output paths and hashes preserve provenance. Discarded drafts remain session artifacts, not selected app assets.

The prompts specify token values; raster generation is illustrative and cannot guarantee pixel-exact color or geometry. Use the manifest and domain map as implementation targets. No runtime tokens or screens were modified by this asset task.

## Light

Selected asset: [agrimore-sales-associate-spacing-shape-borders-elevation-light.png](agrimore-sales-associate-spacing-shape-borders-elevation-light.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-light.png` · SHA-256 `5e40ab35853e74ff50cc1256d4445976f72d232fa3941b4393c073100e739e19`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-4cdc3848-2a38-4388-b143-e0764d059903.png` · SHA-256 `4378fdd643cdef9b666cc33062dd7e9e834e4629591c255d582b1370ad636a18`.

<!-- prompt:light-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Sales Associate, light theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 light board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Sales Associate" and a small "Light" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Premium royal blue, indigo and pearl/slate. Palette tokens: primary: #2D56C4; onPrimary: #FFFFFF; support: #6950A2; canvas: #F7F8FC; surface: #FFFFFF; raised: #FBFCFF; text: #192840; muted: #61708B; border: #DDE3F0; strongBorder: #94A0B7; selected: #EAF0FE; focus: #2D56C4. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#EDF1FB", "text": "#31549E"}]. Supporting accent is context, never a replacement for status semantics. Airy neutral canvas, clean white/near-white panels, quiet soft shadows. No full-color panel backgrounds, excessive shadows or low-contrast text.
Composition: Calm personal-finance composition. A generous balance group, a separately inset indigo pending-payout group and a commission record form the main vertical story; shape and spacing references sit alongside. Royal blue leads the balance and actions; indigo visibly leads payout context. Pearl/slate neutral surfaces, not a dense admin table. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Balance rhythm". A generously padded balance group reads "Available balance", "₹12,500.00" and a royal-blue "Review payout" control. Fine guides label "24 px hero padding" and "52 px min height". A separate indigo heading "Pending payout" with "₹2,000.00" appears below, separated by "24 px section gap". A flat commission record reads "Commission credited", "+₹125.00" and "2 Oct 2026", with "16 px record padding" and "12 px record gap" measurement guides. Page-edge bracket "16 px page inset". Pending payout is never visually merged into available balance.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Balance hero padding | 24 px
Record padding | 16 px
Record gap | 12 px
Section gap | 24 px
Minimum control height | 52 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 12 px", "Card — 18 px", "Sheet / dialog — 24 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #DDE3F0; strong stroke #94A0B7; focus stroke #2D56C4. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Commission row", "Balance group", "Payout sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.
```
<!-- prompt:light-1:end -->

## Dark

Selected asset: [agrimore-sales-associate-spacing-shape-borders-elevation-dark.png](agrimore-sales-associate-spacing-shape-borders-elevation-dark.png).

### Step 1 — initial

Input images, in tool order:

- Image 1: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/01-color-roles-theme-identity/agrimore-sales-associate-design-tokens-dark.png` · SHA-256 `579b82781b7cac9f889ec36a11448bab868333024ad3f7c037e14d1c3997ec62`
- Image 2: `/Users/saai_siddharth/Projects/Clients/Agrimore/apps/employee/assets/ui-mockups/03-spacing-shape-borders-elevation/agrimore-sales-associate-spacing-shape-borders-elevation-light.png` · SHA-256 `4378fdd643cdef9b666cc33062dd7e9e834e4629591c255d582b1370ad636a18`

Output: `/Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-3b0e9dc8-cdc0-4205-8fa7-cb741efeb832.png` · SHA-256 `cb516bc51d85a93671a73baccfcb0272cfdf9329cf1c80bda039a9e4d535bdf0`.

<!-- prompt:dark-1:begin -->
```text
Use case: ui-mockup. Asset type: C03 Spacing, shape, borders and elevation, premium Storybook-style design-system board for Agrimore Sales Associate, dark theme.
Generate ONE complete landscape 16:10 image, high resolution with crisp Inter UI typography and clean vector-like dimensional guides. Input Image 1 is this app's APPROVED C01 dark board, the authoritative identity/skin reference. Preserve its palette, supporting accent, surface hierarchy, type personality, spacing scale, radius values and border roles. Replace its old color/typography panels with this new C03 content. Do not reproduce the old color-swatches board. This is a design-system reference, not a full app screenshot.
Header: ONLY "Agrimore Sales Associate" and a small "Dark" theme pill; subtitle "Spacing, shape, borders & elevation". No slogan, sidebar, navigation, device frame, browser chrome, logo, watermark, photo or illustration.
Identity: Premium royal blue, indigo and pearl/slate. Palette tokens: primary: #96B4FF; onPrimary: #142241; support: #C0ADE7; canvas: #090B11; surface: #131722; raised: #1E2533; text: #F2F5FC; muted: #B9C5DD; border: #354259; strongBorder: #8393B2; selected: #1B2C50; focus: #96B4FF. Status colors if used must be exactly these inherited roles: [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#1A2B4C", "text": "#B2C8FF"}]. Supporting accent is context, never a replacement for status semantics. Near-black canvas, true dark grey panels, excellent light-text contrast, no white panels, blue canvas, glow or colorful gradient. Depth comes primarily from distinct surface and raised tones plus crisp borders, as C01.
Composition: Calm personal-finance composition. A generous balance group, a separately inset indigo pending-payout group and a commission record form the main vertical story; shape and spacing references sit alongside. Royal blue leads the balance and actions; indigo visibly leads payout context. Pearl/slate neutral surfaces, not a dense admin table. Full uncropped board with generous outer margins. All dimensions are logical UI px, not literal raster px; draw relative spacing proportions accurately. Measurement arrows must point to real whitespace/corner/border specimens, never obscure text.
Top compact panel "Spacing scale": SIX graduated spacing blocks labeled EXACTLY "4", "8", "12", "16", "24", "32", with a single "px" unit label. Keep labels distinct and ordered.
Main domain specimen: Panel heading "Balance rhythm". A generously padded balance group reads "Available balance", "₹12,500.00" and a royal-blue "Review payout" control. Fine guides label "24 px hero padding" and "52 px min height". A separate indigo heading "Pending payout" with "₹2,000.00" appears below, separated by "24 px section gap". A flat commission record reads "Commission credited", "+₹125.00" and "2 Oct 2026", with "16 px record padding" and "12 px record gap" measurement guides. Page-edge bracket "16 px page inset". Pending payout is never visually merged into available balance.
Panel "Domain spacing": exact reference rows below; numerical values are in px. Keep all rows readable, no omitted or duplicated rows:
Phone page inset | 16 px
Wide page inset | 24 px
Balance hero padding | 24 px
Record padding | 16 px
Record gap | 12 px
Section gap | 24 px
Minimum control height | 52 px
Bottom panel "Shape roles": three outlined form specimens with increasingly rounded corners labeled EXACTLY "Control — 12 px", "Card — 18 px", "Sheet / dialog — 24 px". Show those three distinct radii; don't substitute runtime legacy radii or pill shapes. Overlay shape may have only its top corners rounded for a sheet. Card padding and radius are different measurements.
Bottom panel "Border roles": three equal outline specimens. Labels EXACTLY "Default — 1 px", "Strong — 1 px", "Focus — 2 px". Default stroke #354259; strong stroke #8393B2; focus stroke #96B4FF. One outline per specimen; focus changes contrast/width without shifting the overall bounds. No thick double focus rings.
Bottom panel "Surface depth": three modest domain tiles labeled "Flat", "Soft", "Raised" and secondary labels respectively "Commission row", "Balance group", "Payout sheet". Flat is a bordered base surface with no shadow, Soft is a subtly lifted card, Raised is a clearly separate transient overlay. Match restrained C01 depth. In dark theme use its tonal panels and visible boundaries, no neon glows or white surfaces. Depth never stands in for approval, payment or delivery status.
Typography: Inter-style sans serif, natural sentence case, 400/500/600/700 as appropriate. Readable headings and body annotations. Preserve money glyphs and exact data; specimen values are fictional. All minimum control heights may grow with text, not fixed clipped heights. Exact spacing/radius/border numeric text is critical. No generic lorem ipsum, invented spacings, inconsistent radius captions, extra top-level panels, garbled numbers, tiny microtext or cropped corners.

Pairing constraint: Input Image 2 is the SELECTED C03 LIGHT board for this SAME app, the authoritative CONTENT and COMPOSITION reference. Preserve its exact panel arrangement, all row counts, numeric labels, radius mappings, border widths, dimensional guides, specimen data and relative geometry. Convert it into the approved C01 dark skin from Image 1. Change the theme pill to "Dark", convert canvas/surface/raised/text/brand/support/status colors to the explicit dark tokens above. Do NOT copy old Color roles or Typography panels from Image 1. Do not redesign the light board or add unrelated panels. Use this app’s near-black canvas and dark grey surfaces with all content readable. 
```
<!-- prompt:dark-1:end -->

## Inherited token specifications

### Light — C01 owner-approved values

| Color role | Hex |
| --- | --- |
| primary | #2D56C4 |
| onPrimary | #FFFFFF |
| support | #6950A2 |
| supportLabel | Supporting indigo |
| canvas | #F7F8FC |
| surface | #FFFFFF |
| raised | #FBFCFF |
| text | #192840 |
| muted | #61708B |
| border | #DDE3F0 |
| strongBorder | #94A0B7 |
| selected | #EAF0FE |
| focus | #2D56C4 |

| Status | Container | Text |
| --- | --- | --- |
| Success | #E7F5ED | #146C43 |
| Warning | #FFF4D6 | #805400 |
| Error | #FDECEA | #B42318 |
| Info | #EDF1FB | #31549E |

### Dark — C01 owner-approved values

| Color role | Hex |
| --- | --- |
| primary | #96B4FF |
| onPrimary | #142241 |
| support | #C0ADE7 |
| supportLabel | Supporting indigo |
| canvas | #090B11 |
| surface | #131722 |
| raised | #1E2533 |
| text | #F2F5FC |
| muted | #B9C5DD |
| border | #354259 |
| strongBorder | #8393B2 |
| selected | #1B2C50 |
| focus | #96B4FF |

| Status | Container | Text |
| --- | --- | --- |
| Success | #102C20 | #8DE0B0 |
| Warning | #302612 | #F1CE7B |
| Error | #341B1B | #FFA39C |
| Info | #1A2B4C | #B2C8FF |

### C03 domain role mapping — proposal

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Balance hero padding | 24 |
| Record padding | 16 |
| Record gap | 12 |
| Section gap | 24 |
| Minimum control height | 52 |

| Shape role | Approved C01 radius |
| --- | --- |
| Control | 12 |
| Card | 18 |
| Sheet / dialog | 24 |
