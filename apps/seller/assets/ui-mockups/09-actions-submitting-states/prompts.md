# Agrimore Seller — C09 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: 25d12b0e2394cd55e69abba0353472056ba9436a809f1280c300c78d1971d400. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Seller, LIGHT theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Seller" plus small "Light" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Blue-teal with warm copper and cool neutral support. Exact targets: {"primary":"#0B6A80","onPrimary":"#FFFFFF","support":"#9B5E3D","supportLabel":"Warm copper","canvas":"#F5F8F9","surface":"#FFFFFF","raised":"#F9FCFD","text":"#142A34","muted":"#56717E","border":"#D5E3E8","strongBorder":"#879EAA","selected":"#E5F2F5","focus":"#0B6A80"}. Status color pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E6F3F7","text":"#17647B"}]. Inter weights 600/500/400 and type scale 32/24/18/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 10/14/20px. Quiet1px borders. Standard control MINIMUM height48px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Light means neutral bright canvas, white surfaces and understated border depth. Professional muted accents, not neon/electric blue.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. 

DOMAIN SYSTEM: Blue-teal operational controls, copper non-status accents, cool-neutral prerequisite and work-in-progress surfaces.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Merchant actions
Annotated variants: PRIMARY filled blue-teal 'Save product'; SECONDARY outline 'Save as draft'; TERTIARY text 'Preview'; DESTRUCTIVE outlined Error-colored 'Delete product'. Small caption 'Draft saves without publishing'. Copper used only in a small accent rule.

02 · Publish requirements
Disabled neutral 'Publish product' SPECIMEN for a missing-field policy; helper 'Add price and delivery coverage to publish.' Enabled outline 'Review required fields'. Separate small note 'Draft needs a product name'. Do not show publishing as already completed.

03 · Saving the decision
Filled primary button with spinner and exact label 'Saving product…'; adjacent secondary 'Save as draft' disabled neutral. Helper 'Keep your changes while saving.' Separate annotation 'Repeated taps blocked'. Tiny reduced-motion alternative with static hourglass and the same busy label.

04 · Recover merchant work
Information callout 'Save status unclear'; body 'Check the catalogue before creating this product again.' Outline 'Check catalogue'; text action 'Keep editing'. Small flow 'Edit → Saving → Check catalogue'; caption 'Preserve the draft on failure'. No invented saved/published badge or success count.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
```

## Dark — initial generation

Prompt SHA-256: 4dbab79752c08c50e0ac35fd98532253ea03196f5d12ae47008aba4b03f86d33. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Seller, DARK theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Seller" plus small "Dark" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Blue-teal with warm copper and cool neutral support. Exact targets: {"primary":"#70D0DF","onPrimary":"#0B2831","support":"#DAAE8C","supportLabel":"Warm copper","canvas":"#080C0F","surface":"#11191E","raised":"#1B262D","text":"#F1F7FA","muted":"#B5C9D1","border":"#33464F","strongBorder":"#7895A2","selected":"#14313A","focus":"#70D0DF"}. Status color pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#142D37","text":"#9BD9E9"}]. Inter weights 600/500/400 and type scale 32/24/18/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 10/14/20px. Quiet1px borders. Standard control MINIMUM height48px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Dark means near-black canvas and dark-grey neutral cards everywhere. Pale primary accents and filled primary buttons have DARK onPrimary text/spinner, not white on pale fills. Never use light-mode saturated blue/cyan/green tiles on dark boards.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. 

DOMAIN SYSTEM: Blue-teal operational controls, copper non-status accents, cool-neutral prerequisite and work-in-progress surfaces.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Merchant actions
Annotated variants: PRIMARY filled blue-teal 'Save product'; SECONDARY outline 'Save as draft'; TERTIARY text 'Preview'; DESTRUCTIVE outlined Error-colored 'Delete product'. Small caption 'Draft saves without publishing'. Copper used only in a small accent rule.

02 · Publish requirements
Disabled neutral 'Publish product' SPECIMEN for a missing-field policy; helper 'Add price and delivery coverage to publish.' Enabled outline 'Review required fields'. Separate small note 'Draft needs a product name'. Do not show publishing as already completed.

03 · Saving the decision
Filled primary button with spinner and exact label 'Saving product…'; adjacent secondary 'Save as draft' disabled neutral. Helper 'Keep your changes while saving.' Separate annotation 'Repeated taps blocked'. Tiny reduced-motion alternative with static hourglass and the same busy label.

04 · Recover merchant work
Information callout 'Save status unclear'; body 'Check the catalogue before creating this product again.' Outline 'Check catalogue'; text action 'Keep editing'. Small flow 'Edit → Saving → Check catalogue'; caption 'Preserve the draft on failure'. No invented saved/published badge or success count.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
PAIRED DARK BOARD: first image is the approved C01 DARK identity reference; second is selected C09 LIGHT layout/content reference. Preserve the selected light board's exact four-panel composition, copy, control arrangement, annotation roles and independent recovery scenarios. Recolor every surface and foreground to the stated DARK roles. Filled primary and busy primary MUST have pale primary backgrounds #70D0DF with dark text and spinner #0B2831. Secondary/text actions remain pale-primary on DARK neutral surfaces. Disabled controls remain dark-neutral and distinctly unavailable with readable muted labels. Helper and recovery panels must be dark INFO/WARNING containers, no bright light-theme blue/cyan/orange slabs. No invented success. 
```

