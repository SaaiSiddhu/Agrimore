# Agrimore Delivery — C11 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: 061caeda01aabcf66d41fb252cca0eb6d8697c8efa046db7fbd26bf4ffc8a869. Original final newline: False.

```text
Use case: ui-mockup. Create a premium full-canvas landscape Storybook design system board, 1536x1024. Heading "Agrimore Delivery", LIGHT theme chip, subtitle "Selection controls and filter state", small "C11 · Target design". Four numbered panels in balanced 2x2 grid, exceptionally clear English text, polished app-specific control anatomy. NO sidebar, phone frame, browser chrome, photography, logos or sprawling empty space.
Reference image 1 is the approved C01 LIGHT identity. Match its type character, colors, surfaces and supporting accents, not its original token content.
App identity: Black/white with burgundy and burnt orange support..
Exact palette roles {"primary":"#191919","onPrimary":"#FFFFFF","support":"#A94D24","supportLabel":"Burnt orange","canvas":"#F8F7F6","surface":"#FFFFFF","raised":"#FAF9F8","text":"#1C1C1C","muted":"#686260","border":"#DDD7D4","strongBorder":"#A49993","selected":"#F5E7EC","focus":"#A94D24","burgundy":"#7A2840"}.
Status roles [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FBEDE3","text":"#88451E"},{"role":"Error","container":"#F5E7EC","text":"#7A2840"},{"role":"Info","container":"#ECEAE8","text":"#59534F"}]. Selection uses primary/selected roles, NOT success green or error styling. Apply dark onPrimary to pale filled controls. Focus visible and independent of selected.
Typography Inter weights 700/600/400 scale 32/24/20/17/14/12; spacing 4/8/12/16/24/32; Control/Card/Sheet radii 8/12/18; border 1px focus2px. Chips may be pill-shaped; comfortable 48px hit regions; labels wrap. No invented extra palette.
Distinct character: Monochrome field controls, burgundy selected-container cues and burnt-orange focus with a compact history sheet..
Panels:
1. "Availability and checkbox atoms" — Offline availability switch OFF with clear Offline text; alternate busy specimen Changing availability… static progress glyph and inert switch. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled. Do not introduce multi-status selection.
2. "History selection" — Radio status group All statuses selected; Delivered, Cancelled, Returned unselected, exactly one. Separate single-choice date chips This week selected, Last week unselected, Custom unselected. Selected fills black in light or white in dark, foreground inverse; burgundy secondary container accents, orange focus only.
3. "Custom date picker" — Custom range field empty Choose dates, calendar icon. Picker surface Select date range with Start date and End date empty fields and Cancel / Done. Disabled Apply filters with adjacent Choose start and end dates. No fabricated date values.
4. "Apply, cancel and reset" — Draft history filters panel. Primary Apply filters; secondary Cancel; explicit Reset now action. Diagram Draft → Apply → Applied filters. Text Cancel discards draft. Reset now clears applied filters and closes. No fake result count, no delivery success check.
CRITICAL: checkbox CHECKED shows a check; UNCHECKED empty square; MIXED dash; DISABLED muted with readable reason. Radio uses circle+dot, only one option selected per group. Switch knob position and On/Off text must agree. Checkmarks indicate selection only, never confirmed server success. Selected chips show check or clear shape cue; removable chips have explicit ×. Explain draft versus applied state clearly. Picker Cancel preserves old value. Keep choice groups separate. Generic atoms explicitly "Pattern reference"; do not imply nonexistent operational features.

Use calm pale canvas, white surfaces, high-contrast dark body text and app-specific primary controls.
Footer "C11 · Proposed system · Selection is not confirmation". No prices, balances, numeric monetary values, OTPs, IDs, personal data, fictitious result counts, guessed date values, fake saved state or fabricated backend guarantees. These are isolated illustrative control specimens, not a live screen. One complete board.
```

## Light — refinement 1

Prompt SHA-256: 24bf2ea6c566074820a863630c9ffca44a724eb263e61712d62a17a580af3ca0. Original final newline: False.

```text
Correct C11 LIGHT Delivery board, keep four panels and C01 black/white with burgundy/orange identity. Critical: offline availability does NOT imply existing deliveries cannot be updated. Replace 'When offline, deliveries cannot be updated' and 'Delivery updates are unavailable while offline' with neutral 'Availability preference' and 'Offline'. Keep Offline switch OFF; separate busy Changing availability state only disables availability switch during its own update. Panel4 applied filters text must say 'Applied filters remain until you apply changes or Reset now' — Cancel never clears or changes applied filters. Keep exactly one history status, custom range Apply disabled helper, Reset now clears committed filters and closes, Cancel discards draft. Checkbox states explicitly Pattern reference and not multi-status functionality. No invented offline limitations, result counts or server guarantees.
```

## Dark — initial generation

Prompt SHA-256: 5140de21faa4a01e6e184c136043c216d16236378b887de12d88476250b84ce8. Original final newline: False.

```text
Use case: ui-mockup. Create a premium full-canvas landscape Storybook design system board, 1536x1024. Heading "Agrimore Delivery", DARK theme chip, subtitle "Selection controls and filter state", small "C11 · Target design". Four numbered panels in balanced 2x2 grid, exceptionally clear English text, polished app-specific control anatomy. NO sidebar, phone frame, browser chrome, photography, logos or sprawling empty space.
Reference image 1 is the approved C01 DARK identity. Match its type character, colors, surfaces and supporting accents, not its original token content.
App identity: Black/white with burgundy and burnt orange support..
Exact palette roles {"primary":"#F4F4F4","onPrimary":"#151515","support":"#ECA06D","supportLabel":"Burnt orange","canvas":"#090909","surface":"#151515","raised":"#222222","text":"#F5F3F2","muted":"#C3BAB7","border":"#3C3633","strongBorder":"#91857E","selected":"#3B2029","focus":"#ECA06D","burgundy":"#DCA0B1"}.
Status roles [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#342418","text":"#F0BE98"},{"role":"Error","container":"#3B2029","text":"#E3A8B9"},{"role":"Info","container":"#282523","text":"#D3C8C1"}]. Selection uses primary/selected roles, NOT success green or error styling. Apply dark onPrimary to pale filled controls. Focus visible and independent of selected.
Typography Inter weights 700/600/400 scale 32/24/20/17/14/12; spacing 4/8/12/16/24/32; Control/Card/Sheet radii 8/12/18; border 1px focus2px. Chips may be pill-shaped; comfortable 48px hit regions; labels wrap. No invented extra palette.
Distinct character: Monochrome field controls, burgundy selected-container cues and burnt-orange focus with a compact history sheet..
Panels:
1. "Availability and checkbox atoms" — Offline availability switch OFF with clear Offline text; alternate busy specimen Changing availability… static progress glyph and inert switch. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled. Do not introduce multi-status selection.
2. "History selection" — Radio status group All statuses selected; Delivered, Cancelled, Returned unselected, exactly one. Separate single-choice date chips This week selected, Last week unselected, Custom unselected. Selected fills black in light or white in dark, foreground inverse; burgundy secondary container accents, orange focus only.
3. "Custom date picker" — Custom range field empty Choose dates, calendar icon. Picker surface Select date range with Start date and End date empty fields and Cancel / Done. Disabled Apply filters with adjacent Choose start and end dates. No fabricated date values.
4. "Apply, cancel and reset" — Draft history filters panel. Primary Apply filters; secondary Cancel; explicit Reset now action. Diagram Draft → Apply → Applied filters. Text Cancel discards draft. Reset now clears applied filters and closes. No fake result count, no delivery success check.
CRITICAL: checkbox CHECKED shows a check; UNCHECKED empty square; MIXED dash; DISABLED muted with readable reason. Radio uses circle+dot, only one option selected per group. Switch knob position and On/Off text must agree. Checkmarks indicate selection only, never confirmed server success. Selected chips show check or clear shape cue; removable chips have explicit ×. Explain draft versus applied state clearly. Picker Cancel preserves old value. Keep choice groups separate. Generic atoms explicitly "Pattern reference"; do not imply nonexistent operational features.

Use near-black canvas and dark-grey neutral panels, subtle borders and pale app accents, no white panels or saturated navy slabs. Every pale primary-filled action/chip has dark onPrimary text.
Footer "C11 · Proposed system · Selection is not confirmation". No prices, balances, numeric monetary values, OTPs, IDs, personal data, fictitious result counts, guessed date values, fake saved state or fabricated backend guarantees. These are isolated illustrative control specimens, not a live screen. One complete board.
PAIR CONTRACT: Reference1 = authoritative C01 DARK identity. Reference2 = refined selected C11 LIGHT board, authoritative panel layout, state logic and copy. Match its content, control cardinality and premium hierarchy. Marketplace no marketing slogans, immediate sort separate from draft category/availability, shop Reset immediate. Seller store switch remains draft, blank calendar values. Delivery OFFLINE is availability only; never claim existing delivery updates unavailable; Cancel preserves applied filters and Reset now clears applied state. Sales Associate Dark mode MUST be ON with knob on right in this DARK board; only Requested and combined Paid / Settled options; no removable × on single-choice order chip. Admin ONLY Record A checked and Record B unchecked with mixed Select visible parent; combined Pending / Requested, Paid and Rejected group. Keep pattern-reference labels for proposed atoms. Near-black canvas, dark-grey surfaces, no white panels/saturated navy slabs. Pale filled primary controls/checkmarks/mixed dashes MUST use dark onPrimary foreground. No invented dates, numeric amounts, result counts, marketing or confirmed success. Include small C11 proposed footer.
```

