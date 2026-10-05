# Agrimore Marketplace — C09 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: c8cd6dfab80ac3fb0ab7508ff35bb90c2369c1508792b13c92664afdf710c909. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Marketplace, LIGHT theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Marketplace" plus small "Light" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Professional green with warm gold and natural stone support. Exact targets: {"primary":"#087A4B","onPrimary":"#FFFFFF","support":"#9A6826","supportLabel":"Warm gold","canvas":"#F7F9F6","surface":"#FFFFFF","raised":"#FBFCF9","text":"#1A2C21","muted":"#5D7062","border":"#DAE4DB","strongBorder":"#91A594","selected":"#E5F3E9","focus":"#087A4B"}. Status color pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E7F2EC","text":"#286B4D"}]. Inter weights 700/600/400 and type scale 36/26/20/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 12/16/24px. Quiet1px borders. Standard control MINIMUM height54px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Light means neutral bright canvas, white surfaces and understated border depth. Professional muted accents, not neon/electric blue.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. 

DOMAIN SYSTEM: Professional green shopping actions with warm-gold secondary accents, natural-stone helper surfaces and reassuring plain copy.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Commerce actions
Three distinct variants, annotated outside buttons: PRIMARY filled green button 'Continue to payment' with arrow; SECONDARY outline 'Change address'; TERTIARY green text action 'View cart'. Tiny warm-gold non-status divider. One primary per decision.

02 · Explain prerequisites
Disabled neutral button 'Continue to payment'. Immediately below readable helper 'Select a delivery address to continue.' Enabled outlined resolution button 'Select address'. No fake chosen address or error toast.

03 · Calculating delivery
Busy filled primary button with spinner and exact label 'Calculating delivery…'; helper 'Please wait while pricing is checked.' Small separate annotation 'Repeated taps blocked'. Small reduced-motion alternative with static hourglass and the same busy label. No percentage or success check.

04 · Uncertain checkout
Information callout 'Checkout needs attention'; body 'Check your saved checkout before paying again.' Enabled outline 'Resume checkout'; main 'Pay' button is disabled neutral. Small flow: 'Ready → Processing → Check status', with caption 'Show success only after confirmation'. No amounts, gateway branding, payment success or placed-order claim.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
```

## Dark — initial generation

Prompt SHA-256: 3ef4beb1304e5c3e29a50df7e1814db4a0352641d6157ddef51e720d3200f298. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Marketplace, DARK theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Marketplace" plus small "Dark" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Professional green with warm gold and natural stone support. Exact targets: {"primary":"#67D2A1","onPrimary":"#0B291D","support":"#DDB97A","supportLabel":"Warm gold","canvas":"#090C0A","surface":"#141A16","raised":"#1E2721","text":"#F2F7F3","muted":"#B9C9BD","border":"#344338","strongBorder":"#798F7E","selected":"#163325","focus":"#67D2A1"}. Status color pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#173126","text":"#A1D8B9"}]. Inter weights 700/600/400 and type scale 36/26/20/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 12/16/24px. Quiet1px borders. Standard control MINIMUM height54px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Dark means near-black canvas and dark-grey neutral cards everywhere. Pale primary accents and filled primary buttons have DARK onPrimary text/spinner, not white on pale fills. Never use light-mode saturated blue/cyan/green tiles on dark boards.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. 

DOMAIN SYSTEM: Professional green shopping actions with warm-gold secondary accents, natural-stone helper surfaces and reassuring plain copy.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Commerce actions
Three distinct variants, annotated outside buttons: PRIMARY filled green button 'Continue to payment' with arrow; SECONDARY outline 'Change address'; TERTIARY green text action 'View cart'. Tiny warm-gold non-status divider. One primary per decision.

02 · Explain prerequisites
Disabled neutral button 'Continue to payment'. Immediately below readable helper 'Select a delivery address to continue.' Enabled outlined resolution button 'Select address'. No fake chosen address or error toast.

03 · Calculating delivery
Busy filled primary button with spinner and exact label 'Calculating delivery…'; helper 'Please wait while pricing is checked.' Small separate annotation 'Repeated taps blocked'. Small reduced-motion alternative with static hourglass and the same busy label. No percentage or success check.

04 · Uncertain checkout
Information callout 'Checkout needs attention'; body 'Check your saved checkout before paying again.' Enabled outline 'Resume checkout'; main 'Pay' button is disabled neutral. Small flow: 'Ready → Processing → Check status', with caption 'Show success only after confirmation'. No amounts, gateway branding, payment success or placed-order claim.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
PAIRED DARK BOARD: first image is the approved C01 DARK identity reference; second is selected C09 LIGHT layout/content reference. Preserve the selected light board's exact four-panel composition, copy, control arrangement, annotation roles and independent recovery scenarios. Recolor every surface and foreground to the stated DARK roles. Filled primary and busy primary MUST have pale primary backgrounds #67D2A1 with dark text and spinner #0B291D. Secondary/text actions remain pale-primary on DARK neutral surfaces. Disabled controls remain dark-neutral and distinctly unavailable with readable muted labels. Helper and recovery panels must be dark INFO/WARNING containers, no bright light-theme blue/cyan/orange slabs. No invented success. 
```

