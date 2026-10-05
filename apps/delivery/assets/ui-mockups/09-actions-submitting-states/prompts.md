# Agrimore Delivery — C09 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: b2138858ba1cc8255a5016fb0b9438e925804e1fe2be4192383b6a3101a7cc31. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Delivery, LIGHT theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Delivery" plus small "Light" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Black/white with burgundy and burnt orange support. Exact targets: {"primary":"#191919","onPrimary":"#FFFFFF","support":"#A94D24","supportLabel":"Burnt orange","canvas":"#F8F7F6","surface":"#FFFFFF","raised":"#FAF9F8","text":"#1C1C1C","muted":"#686260","border":"#DDD7D4","strongBorder":"#A49993","selected":"#F5E7EC","focus":"#A94D24","burgundy":"#7A2840"}. Status color pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FBEDE3","text":"#88451E"},{"role":"Error","container":"#F5E7EC","text":"#7A2840"},{"role":"Info","container":"#ECEAE8","text":"#59534F"}]. Inter weights 700/600/400 and type scale 32/24/20/17/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 8/12/18px. Quiet1px borders. Standard control MINIMUM height52px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Light means neutral bright canvas, white surfaces and understated border depth. Professional muted accents, not neon/electric blue.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. Delivery primary stays monochrome black/white. Burgundy secondary and burnt-orange Emergency only; no blue/green completion buttons.

DOMAIN SYSTEM: Black/white action hierarchy with restrained burgundy secondary controls and burnt-orange help accents; field-readable labels and strong neutral surfaces.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Field actions
Annotated variants: PRIMARY black/white filled 'Verify & complete'; SECONDARY neutral outline 'View map'; TERTIARY text 'Help'; separate burnt-orange small 'Emergency' text/glyph. Burgundy only a restrained secondary accent. Do not style completion in orange.

02 · Verification prerequisite
Disabled neutral 'Verify & complete'; helper 'Enter the full 6-digit code to continue.' Outline resolution 'Enter delivery code'. Separate caption 'Help remains available'. Do not print a real or invented six-digit code or claim proof photo is mandatory.

03 · Verifying delivery
Primary filled button with spinner and label 'Verifying…'; helper 'Wait for delivery confirmation.' Adjacent neutral 'Cancel' disabled. Small separate annotation 'Repeated taps blocked'. Tiny reduced-motion alternative static hourglass with same busy label; no Delivered checkmark.

04 · Separate recovery
Two clear independent recovery rows: first neutral/info 'Delivery status unclear' with outline action 'Check delivery status'; second warning 'Photo upload needs attention' with outline action 'Retry photo upload'. Caption 'Do not repeat completion for a photo retry'. Small flow 'Verify → Confirm → Upload photo'. These are illustrative independent states, no photo thumbnail, customer data or current success assertion.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
```

## Light — refinement 1

Prompt SHA-256: c6999b2f08fb1267716b214bf8133e4d5c1135d1045e68cbd02aaa23d9b391ec. Original final newline: False.

```text
Edit only the final stage label in panel 04 of this Agrimore Delivery C09 LIGHT board. Change the last flow box from 'Upload photo' to 'Optional photo'. Preserve all other text, panel structure, fonts, actions, colors, spacing, icons, footer and light-theme identity exactly. This single change clarifies that optional attachment upload is separate from server-confirmed completion. Do not add an OTP, actual delivery confirmation or additional success status.
```

## Dark — initial generation

Prompt SHA-256: 01c1b85eec9de3463640dfd1c02080b8955e35eb27b8170425ea154187d721a8. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Delivery, DARK theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Delivery" plus small "Dark" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Black/white with burgundy and burnt orange support. Exact targets: {"primary":"#F4F4F4","onPrimary":"#151515","support":"#ECA06D","supportLabel":"Burnt orange","canvas":"#090909","surface":"#151515","raised":"#222222","text":"#F5F3F2","muted":"#C3BAB7","border":"#3C3633","strongBorder":"#91857E","selected":"#3B2029","focus":"#ECA06D","burgundy":"#DCA0B1"}. Status color pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#342418","text":"#F0BE98"},{"role":"Error","container":"#3B2029","text":"#E3A8B9"},{"role":"Info","container":"#282523","text":"#D3C8C1"}]. Inter weights 700/600/400 and type scale 32/24/20/17/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 8/12/18px. Quiet1px borders. Standard control MINIMUM height52px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Dark means near-black canvas and dark-grey neutral cards everywhere. Pale primary accents and filled primary buttons have DARK onPrimary text/spinner, not white on pale fills. Never use light-mode saturated blue/cyan/green tiles on dark boards.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. Delivery primary stays monochrome black/white. Burgundy secondary and burnt-orange Emergency only; no blue/green completion buttons.

DOMAIN SYSTEM: Black/white action hierarchy with restrained burgundy secondary controls and burnt-orange help accents; field-readable labels and strong neutral surfaces.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Field actions
Annotated variants: PRIMARY black/white filled 'Verify & complete'; SECONDARY neutral outline 'View map'; TERTIARY text 'Help'; separate burnt-orange small 'Emergency' text/glyph. Burgundy only a restrained secondary accent. Do not style completion in orange.

02 · Verification prerequisite
Disabled neutral 'Verify & complete'; helper 'Enter the full 6-digit code to continue.' Outline resolution 'Enter delivery code'. Separate caption 'Help remains available'. Do not print a real or invented six-digit code or claim proof photo is mandatory.

03 · Verifying delivery
Primary filled button with spinner and label 'Verifying…'; helper 'Wait for delivery confirmation.' Adjacent neutral 'Cancel' disabled. Small separate annotation 'Repeated taps blocked'. Tiny reduced-motion alternative static hourglass with same busy label; no Delivered checkmark.

04 · Separate recovery
Two clear independent recovery rows: first neutral/info 'Delivery status unclear' with outline action 'Check delivery status'; second warning 'Photo upload needs attention' with outline action 'Retry photo upload'. Caption 'Do not repeat completion for a photo retry'. Small flow 'Verify → Confirm → Optional photo'. These are illustrative independent states, no photo thumbnail, customer data or current success assertion.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
PAIRED DARK BOARD: first image is the approved C01 DARK identity reference; second is selected C09 LIGHT layout/content reference. Preserve the selected light board's exact four-panel composition, copy, control arrangement, annotation roles and independent recovery scenarios. Recolor every surface and foreground to the stated DARK roles. Filled primary and busy primary MUST have pale primary backgrounds #F4F4F4 with dark text and spinner #151515. Secondary/text actions remain pale-primary on DARK neutral surfaces. Disabled controls remain dark-neutral and distinctly unavailable with readable muted labels. Helper and recovery panels must be dark INFO/WARNING containers, no bright light-theme blue/cyan/orange slabs. No invented success. Keep final flow stage label exactly 'Optional photo'; pale black/white primary, burgundy supporting and orange Emergency/photo-warning only.
```

