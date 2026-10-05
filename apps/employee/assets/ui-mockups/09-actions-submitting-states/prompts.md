# Agrimore Sales Associate — C09 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: cda244d4db794007502cb5f4b6702e163f93636d135b2d4053bf01187fbcb263. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Sales Associate, LIGHT theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Sales Associate" plus small "Light" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Premium royal blue with muted indigo, pearl and slate support. Exact targets: {"primary":"#2D56C4","onPrimary":"#FFFFFF","support":"#6950A2","supportLabel":"Supporting indigo","canvas":"#F7F8FC","surface":"#FFFFFF","raised":"#FBFCFF","text":"#192840","muted":"#61708B","border":"#DDE3F0","strongBorder":"#94A0B7","selected":"#EAF0FE","focus":"#2D56C4"}. Status color pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#EDF1FB","text":"#31549E"}]. Inter weights 600/500/400 and type scale 34/24/18/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 12/18/24px. Quiet1px borders. Standard control MINIMUM height52px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Light means neutral bright canvas, white surfaces and understated border depth. Professional muted accents, not neon/electric blue.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. Royal-blue primary must be premium muted #2D56C4 in light, #96B4FF in dark, NOT electric #003DFF. Indigo is supporting only.

DOMAIN SYSTEM: Premium muted royal-blue commitment controls with supporting indigo, pearl/slate panels and restrained financial-status copy.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Reviewed commitment
Annotated variants: PRIMARY royal-blue filled 'Confirm & request payout'; SECONDARY royal-blue outline 'Review payout request'; TERTIARY text 'Change amount'. Tiny indigo rule. Caption 'Review amount and destination first'. No money values or transfer promise.

02 · Explain missing details
Disabled neutral 'Review payout request'; helper 'Add a payout account and enter an eligible amount.' Enabled outline 'Add payout account'. Small secondary note 'Amount must fit your available balance'. Do not show bank/UPI values.

03 · Submitting the request
Filled royal-blue primary with spinner and label 'Submitting request…'; muted helper 'Wait for the request result.' 'Change amount' is disabled neutral. Separate annotation 'Repeated taps blocked'. Tiny static-hourglass reduced-motion alternative. No progress percentage or bank-transfer animation.

04 · Reconcile before retry
Information callout 'Request status unclear'; body 'Check payout history before starting another request.' Enabled outline 'Check payout history'; caption 'Retry the same request when appropriate'. Small flow 'Review → Submit → Requested'; explicit note 'Requested is not settlement'. Requested is informational clock, no success check/paid badge. No account data, amount or guaranteed payout.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
```

## Dark — initial generation

Prompt SHA-256: 434273651922ea32de8ea7de9706f49aaeac4765645ac8e93f7417a062d32939. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Sales Associate, DARK theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Sales Associate" plus small "Dark" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Premium royal blue with muted indigo, pearl and slate support. Exact targets: {"primary":"#96B4FF","onPrimary":"#142241","support":"#C0ADE7","supportLabel":"Supporting indigo","canvas":"#090B11","surface":"#131722","raised":"#1E2533","text":"#F2F5FC","muted":"#B9C5DD","border":"#354259","strongBorder":"#8393B2","selected":"#1B2C50","focus":"#96B4FF"}. Status color pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#1A2B4C","text":"#B2C8FF"}]. Inter weights 600/500/400 and type scale 34/24/18/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 12/18/24px. Quiet1px borders. Standard control MINIMUM height52px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Dark means near-black canvas and dark-grey neutral cards everywhere. Pale primary accents and filled primary buttons have DARK onPrimary text/spinner, not white on pale fills. Never use light-mode saturated blue/cyan/green tiles on dark boards.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. Royal-blue primary must be premium muted #2D56C4 in light, #96B4FF in dark, NOT electric #003DFF. Indigo is supporting only.

DOMAIN SYSTEM: Premium muted royal-blue commitment controls with supporting indigo, pearl/slate panels and restrained financial-status copy.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Reviewed commitment
Annotated variants: PRIMARY royal-blue filled 'Confirm & request payout'; SECONDARY royal-blue outline 'Review payout request'; TERTIARY text 'Change amount'. Tiny indigo rule. Caption 'Review amount and destination first'. No money values or transfer promise.

02 · Explain missing details
Disabled neutral 'Review payout request'; helper 'Add a payout account and enter an eligible amount.' Enabled outline 'Add payout account'. Small secondary note 'Amount must fit your available balance'. Do not show bank/UPI values.

03 · Submitting the request
Filled royal-blue primary with spinner and label 'Submitting request…'; muted helper 'Wait for the request result.' 'Change amount' is disabled neutral. Separate annotation 'Repeated taps blocked'. Tiny static-hourglass reduced-motion alternative. No progress percentage or bank-transfer animation.

04 · Reconcile before retry
Information callout 'Request status unclear'; body 'Check payout history before starting another request.' Enabled outline 'Check payout history'; caption 'Retry the same request when appropriate'. Small flow 'Review → Submit → Requested'; explicit note 'Requested is not settlement'. Requested is informational clock, no success check/paid badge. No account data, amount or guaranteed payout.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
PAIRED DARK BOARD: first image is the approved C01 DARK identity reference; second is selected C09 LIGHT layout/content reference. Preserve the selected light board's exact four-panel composition, copy, control arrangement, annotation roles and independent recovery scenarios. Recolor every surface and foreground to the stated DARK roles. Filled primary and busy primary MUST have pale primary backgrounds #96B4FF with dark text and spinner #142241. Secondary/text actions remain pale-primary on DARK neutral surfaces. Disabled controls remain dark-neutral and distinctly unavailable with readable muted labels. Helper and recovery panels must be dark INFO/WARNING containers, no bright light-theme blue/cyan/orange slabs. No invented success. Requested is info/clock, not a green/paid result. Main primary pale #96B4FF with dark #142241 text. Indigo support #C0ADE7 on dark neutrals.
```

