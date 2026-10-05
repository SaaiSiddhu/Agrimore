# Agrimore Admin — C09 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: 7a93f08cb862c52bcd8e03e0e129bfde317fbe43bc734401d7f24f3a8f723999. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Admin, LIGHT theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Admin" plus small "Light" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Professional institutional blue with cyan and steel/slate support. Exact targets: {"primary":"#1D4F91","onPrimary":"#FFFFFF","support":"#087E8B","supportLabel":"Supporting cyan","canvas":"#F5F7FB","surface":"#FFFFFF","raised":"#F9FBFE","text":"#14243B","muted":"#5B6B82","border":"#D8E1EF","strongBorder":"#8C9DB5","selected":"#E8EFF8","focus":"#1D4F91"}. Status color pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E8F0FA","text":"#24528C"}]. Inter weights 600/500/400 and type scale 32/24/18/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 8/12/16px. Quiet1px borders. Standard control MINIMUM height48px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Light means neutral bright canvas, white surfaces and understated border depth. Professional muted accents, not neon/electric blue.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. Professional institutional blue is muted navy/steel #1D4F91 light or pale #93B3EC dark, distinguish it from electric royal blue. Cyan support restrained.

DOMAIN SYSTEM: Professional muted institutional-blue action system with supporting cyan, steel borders and slate helper text; clear editor command hierarchy.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Editor commands
Annotated variants: PRIMARY muted professional-blue filled 'Save changes'; SECONDARY neutral outline 'Cancel'; TERTIARY blue text 'Preview'; DESTRUCTIVE outlined Error-colored 'Delete product'. Tiny cyan rule; no vivid electric cobalt. Caption 'One primary decision per editor'.

02 · Explain missing fields
Disabled neutral 'Add product' as policy specimen; helper 'Add required details, an image and delivery coverage.' Enabled outline 'Review required fields'. Caption 'Show field errors where they occur'. No filled-success or saved state.

03 · Saving changes
Filled primary button with spinner and exact label 'Saving changes…'; neighboring 'Cancel' disabled neutral; small separate outlined 'Delete product' also disabled neutral. Helper 'Wait for the save result.' Annotation 'Repeated taps blocked'. Tiny static-hourglass alternative with same busy label.

04 · Unknown save result
Information callout 'Save status unclear'; body 'Check Products before creating this record again.' Enabled outline 'Check Products'; text action 'Keep draft'. Small flow 'Edit → Save → Reconcile'; caption 'Confirm before destructive changes'. No fake Synced/Saved badge or success toast.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
```

## Dark — initial generation

Prompt SHA-256: 65da177e1e5cd912aae6b33ae451c3b76407c8d2ed013049564b8918c51382bb. Original final newline: False.

```text
Use case: ui-mockup. Create ONE premium Storybook-style design-system board for Agrimore Admin, DARK theme, C09 ACTIONS AND SUBMITTING STATES. Landscape 3:2, approximately1536×1024, polished legible typography, calm generous spacing. FULL BOARD with NO sidebar, navigation rail, browser chrome, device bezel, invented logo or generic dashboard. Top heading only "Agrimore Admin" plus small "Dark" chip. Under it: "Actions & submitting states"; subtitle "Variants, prerequisites, progress and safe repeat taps". Tiny footer "C09 · Design proposal · Illustrative states".

Input image 1 is the APPROVED C01 identity REFERENCE, not an edit target. Inherit its palette, typography, space and shape roles faithfully. Professional institutional blue with cyan and steel/slate support. Exact targets: {"primary":"#93B3EC","onPrimary":"#0D203E","support":"#7BCBD5","supportLabel":"Supporting cyan","canvas":"#080B10","surface":"#121922","raised":"#1D2837","text":"#F2F6FC","muted":"#B5C3D6","border":"#314157","strongBorder":"#74869E","selected":"#192E4A","focus":"#93B3EC"}. Status color pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#172A42","text":"#AFCCF6"}]. Inter weights 600/500/400 and type scale 32/24/18/16/14/12px. Spacing 4/8/12/16/24/32px; control/card/sheet radii 8/12/16px. Quiet1px borders. Standard control MINIMUM height48px, grow for wrapping labels. 48px minimum interaction targets. These are illustrative measurements, not pixel-scale screenshots.
Dark means near-black canvas and dark-grey neutral cards everywhere. Pale primary accents and filled primary buttons have DARK onPrimary text/spinner, not white on pale fills. Never use light-mode saturated blue/cyan/green tiles on dark boards.
Disabled controls use raised neutral background, muted readable text and border; NOT dark unreadable opacity or primary color fill. A busy primary remains distinctly in progress with its primary fill and onPrimary spinner/text, despite being non-interactive. Outlined/text buttons use PRIMARY text and an appropriate border, never white text on white surfaces. Destructive outline uses Error text/border, no invented red shade. Use Info/Warning pairs only for corresponding recovery callouts. Professional institutional blue is muted navy/steel #1D4F91 light or pale #93B3EC dark, distinguish it from electric royal blue. Cyan support restrained.

DOMAIN SYSTEM: Professional muted institutional-blue action system with supporting cyan, steel borders and slate helper text; clear editor command hierarchy.
Composition: four roomy specimen cards in a balanced2×2 grid; clear row labels and separate actual UI examples from small explanatory annotations. Each card has clear hierarchy and useful short readable copy. These are BUTTON AND SUBMISSION specimens, not whole app screens. Render all essential text accurately:
01 · Editor commands
Annotated variants: PRIMARY muted professional-blue filled 'Save changes'; SECONDARY neutral outline 'Cancel'; TERTIARY blue text 'Preview'; DESTRUCTIVE outlined Error-colored 'Delete product'. Tiny cyan rule; no vivid electric cobalt. Caption 'One primary decision per editor'.

02 · Explain missing fields
Disabled neutral 'Add product' as policy specimen; helper 'Add required details, an image and delivery coverage.' Enabled outline 'Review required fields'. Caption 'Show field errors where they occur'. No filled-success or saved state.

03 · Saving changes
Filled primary button with spinner and exact label 'Saving changes…'; neighboring 'Cancel' disabled neutral; small separate outlined 'Delete product' also disabled neutral. Helper 'Wait for the save result.' Annotation 'Repeated taps blocked'. Tiny static-hourglass alternative with same busy label.

04 · Unknown save result
Information callout 'Save status unclear'; body 'Check Products before creating this record again.' Enabled outline 'Check Products'; text action 'Keep draft'. Small flow 'Edit → Save → Reconcile'; caption 'Confirm before destructive changes'. No fake Synced/Saved badge or success toast.

Important: show independent scenarios as specimens, not contradictory simultaneous live states. Disabled explanations are always nearby readable text and have an enabled resolution action. Progress is indeterminate unless real measurable progress exists; no fake percentages. Small static hourglass alternative demonstrates reduced motion. Repeated-tap blocking is a TARGET CONTRACT, not a magical server guarantee. Unknown result recovery checks status before initiating another commitment; no instant retry that could duplicate payment, wallet debit or record creation. NO payment amounts, bank data, OTP digits, real IDs, invented counts, fake success, guaranteed transaction or completion celebration. Do not place internal implementation/code concepts inside product UI. Flow annotations may explain state relationships concisely. Keep label wrapping, consistent widths, carefully centered icons/spinners, app-specific palettes and editorial premium polish. Exact targets are documented; raster colors/geometry remain approximate.
PAIRED DARK BOARD: first image is the approved C01 DARK identity reference; second is selected C09 LIGHT layout/content reference. Preserve the selected light board's exact four-panel composition, copy, control arrangement, annotation roles and independent recovery scenarios. Recolor every surface and foreground to the stated DARK roles. Filled primary and busy primary MUST have pale primary backgrounds #93B3EC with dark text and spinner #0D203E. Secondary/text actions remain pale-primary on DARK neutral surfaces. Disabled controls remain dark-neutral and distinctly unavailable with readable muted labels. Helper and recovery panels must be dark INFO/WARNING containers, no bright light-theme blue/cyan/orange slabs. No invented success. Muted pale blue #93B3EC primary with #0D203E text, cyan #7BCBD5 accents only on dark support surfaces. Destructive entry #FFA39C outlined; busy disabled Delete stays neutral.
```

