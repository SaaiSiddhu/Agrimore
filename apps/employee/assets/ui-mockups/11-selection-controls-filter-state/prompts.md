# Agrimore Sales Associate — C11 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: becfdb5a91c8ab724d26529caa1573b9936739a8207544b4e73aaa92d382ecdd. Original final newline: False.

```text
Use case: ui-mockup. Create a premium full-canvas landscape Storybook design system board, 1536x1024. Heading "Agrimore Sales Associate", LIGHT theme chip, subtitle "Selection controls and filter state", small "C11 · Target design". Four numbered panels in balanced 2x2 grid, exceptionally clear English text, polished app-specific control anatomy. NO sidebar, phone frame, browser chrome, photography, logos or sprawling empty space.
Reference image 1 is the approved C01 LIGHT identity. Match its type character, colors, surfaces and supporting accents, not its original token content.
App identity: Premium royal blue with muted indigo, pearl and slate support..
Exact palette roles {"primary":"#2D56C4","onPrimary":"#FFFFFF","support":"#6950A2","supportLabel":"Supporting indigo","canvas":"#F7F8FC","surface":"#FFFFFF","raised":"#FBFCFF","text":"#192840","muted":"#61708B","border":"#DDE3F0","strongBorder":"#94A0B7","selected":"#EAF0FE","focus":"#2D56C4"}.
Status roles [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#EDF1FB","text":"#31549E"}]. Selection uses primary/selected roles, NOT success green or error styling. Apply dark onPrimary to pale filled controls. Focus visible and independent of selected.
Typography Inter weights 600/500/400 scale 34/24/18/16/14/12; spacing 4/8/12/16/24/32; Control/Card/Sheet radii 12/18/24; border 1px focus2px. Chips may be pill-shaped; comfortable 48px hit regions; labels wrap. No invented extra palette.
Distinct character: Premium royal-blue relationship and payout filters, indigo guidance and restrained pearl/slate control surfaces..
Panels:
1. "Preference and checkbox states" — Dark mode switch uses current board theme (OFF in LIGHT, ON in DARK), helper Applies immediately. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled with Unavailable helper. No new bulk-order functionality.
2. "One choice per group" — Order-mode chips All orders selected, B2B orders unselected, Retail orders unselected. Separate payout status radio group Requested selected, Paid / Settled unselected. Each group is independent and single choice; selection is filtering, not payout approval.
3. "Method and picker patterns" — Payout method segment Bank account selected, UPI unselected. Helper Method choice edits the form; Save commits. Small date picker field labelled Date picker · pattern reference with empty Choose a date, Cancel / Done. No account IDs, dates, numeric amounts or invented date-filter feature.
4. "Immediate filters, draft method" — Two clean mini-flows: Order chip → Filter list immediately; Method choice → Edit form → Save. Text Choosing a method does not approve an account. Neutral empty-state example No orders match this filter with Clear filter action. No fabricated records or counts.
CRITICAL: checkbox CHECKED shows a check; UNCHECKED empty square; MIXED dash; DISABLED muted with readable reason. Radio uses circle+dot, only one option selected per group. Switch knob position and On/Off text must agree. Checkmarks indicate selection only, never confirmed server success. Selected chips show check or clear shape cue; removable chips have explicit ×. Explain draft versus applied state clearly. Picker Cancel preserves old value. Keep choice groups separate. Generic atoms explicitly "Pattern reference"; do not imply nonexistent operational features.
Dark mode switch MUST be OFF to match theme.
Use calm pale canvas, white surfaces, high-contrast dark body text and app-specific primary controls.
Footer "C11 · Proposed system · Selection is not confirmation". No prices, balances, numeric monetary values, OTPs, IDs, personal data, fictitious result counts, guessed date values, fake saved state or fabricated backend guarantees. These are isolated illustrative control specimens, not a live screen. One complete board.
```

## Light — refinement 1

Prompt SHA-256: 95d6b8ef019b5d668af261d22bc7be0359a17d11c0162cbd800790a7a5980b52. Original final newline: False.

```text
Correct C11 LIGHT Sales Associate board, preserve all four panels, royal-blue/indigo/pearl identity and OFF Dark mode switch. Source has one COMBINED Paid / Settled filter, not separate Paid and Settled filters: Panel2 payout status radio group must have only TWO options Requested (selected) and Paid / Settled (unselected). Remove separate Paid and Settled controls and their descriptions. Bank account/UPI method segment remains draft form choice, not approved destination. Panel4 immediate order-chip example must show B2B orders selected leading to No orders match this filter; remove × from this SINGLE-choice chip (not a removable filter) and keep Clear filter action returning to All orders. Checkbox/date picker clearly Pattern reference. No invented payout options, financial outcomes, dates, amounts or sidebar.
```

## Dark — initial generation

Prompt SHA-256: 19dd3b23b131f04f02a5bc1aa08392ae226e83023bac65fa86f9c83b9221d869. Original final newline: False.

```text
Use case: ui-mockup. Create a premium full-canvas landscape Storybook design system board, 1536x1024. Heading "Agrimore Sales Associate", DARK theme chip, subtitle "Selection controls and filter state", small "C11 · Target design". Four numbered panels in balanced 2x2 grid, exceptionally clear English text, polished app-specific control anatomy. NO sidebar, phone frame, browser chrome, photography, logos or sprawling empty space.
Reference image 1 is the approved C01 DARK identity. Match its type character, colors, surfaces and supporting accents, not its original token content.
App identity: Premium royal blue with muted indigo, pearl and slate support..
Exact palette roles {"primary":"#96B4FF","onPrimary":"#142241","support":"#C0ADE7","supportLabel":"Supporting indigo","canvas":"#090B11","surface":"#131722","raised":"#1E2533","text":"#F2F5FC","muted":"#B9C5DD","border":"#354259","strongBorder":"#8393B2","selected":"#1B2C50","focus":"#96B4FF"}.
Status roles [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#1A2B4C","text":"#B2C8FF"}]. Selection uses primary/selected roles, NOT success green or error styling. Apply dark onPrimary to pale filled controls. Focus visible and independent of selected.
Typography Inter weights 600/500/400 scale 34/24/18/16/14/12; spacing 4/8/12/16/24/32; Control/Card/Sheet radii 12/18/24; border 1px focus2px. Chips may be pill-shaped; comfortable 48px hit regions; labels wrap. No invented extra palette.
Distinct character: Premium royal-blue relationship and payout filters, indigo guidance and restrained pearl/slate control surfaces..
Panels:
1. "Preference and checkbox states" — Dark mode switch uses current board theme (OFF in LIGHT, ON in DARK), helper Applies immediately. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled with Unavailable helper. No new bulk-order functionality.
2. "One choice per group" — Order-mode chips All orders selected, B2B orders unselected, Retail orders unselected. Separate payout status radio group Requested selected, Paid / Settled unselected. Each group is independent and single choice; selection is filtering, not payout approval.
3. "Method and picker patterns" — Payout method segment Bank account selected, UPI unselected. Helper Method choice edits the form; Save commits. Small date picker field labelled Date picker · pattern reference with empty Choose a date, Cancel / Done. No account IDs, dates, numeric amounts or invented date-filter feature.
4. "Immediate filters, draft method" — Two clean mini-flows: Order chip → Filter list immediately; Method choice → Edit form → Save. Text Choosing a method does not approve an account. Neutral empty-state example No orders match this filter with Clear filter action. No fabricated records or counts.
CRITICAL: checkbox CHECKED shows a check; UNCHECKED empty square; MIXED dash; DISABLED muted with readable reason. Radio uses circle+dot, only one option selected per group. Switch knob position and On/Off text must agree. Checkmarks indicate selection only, never confirmed server success. Selected chips show check or clear shape cue; removable chips have explicit ×. Explain draft versus applied state clearly. Picker Cancel preserves old value. Keep choice groups separate. Generic atoms explicitly "Pattern reference"; do not imply nonexistent operational features.
Dark mode switch MUST be ON to match theme.
Use near-black canvas and dark-grey neutral panels, subtle borders and pale app accents, no white panels or saturated navy slabs. Every pale primary-filled action/chip has dark onPrimary text.
Footer "C11 · Proposed system · Selection is not confirmation". No prices, balances, numeric monetary values, OTPs, IDs, personal data, fictitious result counts, guessed date values, fake saved state or fabricated backend guarantees. These are isolated illustrative control specimens, not a live screen. One complete board.
PAIR CONTRACT: Reference1 = authoritative C01 DARK identity. Reference2 = refined selected C11 LIGHT board, authoritative panel layout, state logic and copy. Match its content, control cardinality and premium hierarchy. Marketplace no marketing slogans, immediate sort separate from draft category/availability, shop Reset immediate. Seller store switch remains draft, blank calendar values. Delivery OFFLINE is availability only; never claim existing delivery updates unavailable; Cancel preserves applied filters and Reset now clears applied state. Sales Associate Dark mode MUST be ON with knob on right in this DARK board; only Requested and combined Paid / Settled options; no removable × on single-choice order chip. Admin ONLY Record A checked and Record B unchecked with mixed Select visible parent; combined Pending / Requested, Paid and Rejected group. Keep pattern-reference labels for proposed atoms. Near-black canvas, dark-grey surfaces, no white panels/saturated navy slabs. Pale filled primary controls/checkmarks/mixed dashes MUST use dark onPrimary foreground. No invented dates, numeric amounts, result counts, marketing or confirmed success. Include small C11 proposed footer.
```

## Dark — refinement 1

Prompt SHA-256: 62fb89d4dd85f9bad920fd516fc535847c3b754c8acb610d6000016fd2990b82. Original final newline: False.

```text
Targeted edit of C11 DARK Sales Associate image. Preserve EVERY panel, layout, labels, controls and dark neutral surfaces. Change ONLY Dark mode ON switch: track exactly primary #96B4FF, knob on RIGHT exactly dark onPrimary #142241, not white. Keep On state and all payout/method/checkbox patterns unchanged. C01 dark identity reference supplied second.
```

