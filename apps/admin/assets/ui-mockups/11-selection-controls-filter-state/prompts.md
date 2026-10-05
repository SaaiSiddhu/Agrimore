# Agrimore Admin — C11 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: a5ebf3e623cb8bff35ed974684fbbb2b388859302f93737c1ccc651da649d3a5. Original final newline: False.

```text
Use case: ui-mockup. Create a premium full-canvas landscape Storybook design system board, 1536x1024. Heading "Agrimore Admin", LIGHT theme chip, subtitle "Selection controls and filter state", small "C11 · Target design". Four numbered panels in balanced 2x2 grid, exceptionally clear English text, polished app-specific control anatomy. NO sidebar, phone frame, browser chrome, photography, logos or sprawling empty space.
Reference image 1 is the approved C01 LIGHT identity. Match its type character, colors, surfaces and supporting accents, not its original token content.
App identity: Professional institutional blue with cyan and steel/slate support..
Exact palette roles {"primary":"#1D4F91","onPrimary":"#FFFFFF","support":"#087E8B","supportLabel":"Supporting cyan","canvas":"#F5F7FB","surface":"#FFFFFF","raised":"#F9FBFE","text":"#14243B","muted":"#5B6B82","border":"#D8E1EF","strongBorder":"#8C9DB5","selected":"#E8EFF8","focus":"#1D4F91"}.
Status roles [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E8F0FA","text":"#24528C"}]. Selection uses primary/selected roles, NOT success green or error styling. Apply dark onPrimary to pale filled controls. Focus visible and independent of selected.
Typography Inter weights 600/500/400 scale 32/24/18/16/14/12; spacing 4/8/12/16/24/32; Control/Card/Sheet radii 8/12/16; border 1px focus2px. Chips may be pill-shaped; comfortable 48px hit regions; labels wrap. No invented extra palette.
Distinct character: Professional-blue dense review controls with cyan grouping, explicit row selection scope and mixed parent checkboxes..
Panels:
1. "Visible-row selection" — Proposed pattern: Select visible checkbox MIXED dash; two synthetic rows Record A checked, Record B unchecked. Caption Only visible eligible rows. Separate switch Product active ON, helper Editor draft — Save to commit. Do not show fake bulk actions or user data.
2. "Exclusive filters and radios" — User-filter chips All selected, Active unselected, Inactive unselected. Separate radio group Payout status: Pending / Requested selected, Paid unselected, Rejected unselected. One choice per group; not a mutation.
3. "Structured category picker" — Product category field Choose a category; open compact picker with Search categories and radio options Category A selected, Category B unselected. Synthetic labels. Caption Stable option IDs; preserve current value on cancel. No sidebar.
4. "Filter scope and selection" — Diagram Filter visible records → Review selected rows → Explicit action. Callout Mixed means some visible rows selected. Text Changing filters must reconcile selection. Clear selection text action. Separate editor Save / Cancel action specimens. No success message, permissions claims or real record counts.
CRITICAL: checkbox CHECKED shows a check; UNCHECKED empty square; MIXED dash; DISABLED muted with readable reason. Radio uses circle+dot, only one option selected per group. Switch knob position and On/Off text must agree. Checkmarks indicate selection only, never confirmed server success. Selected chips show check or clear shape cue; removable chips have explicit ×. Explain draft versus applied state clearly. Picker Cancel preserves old value. Keep choice groups separate. Generic atoms explicitly "Pattern reference"; do not imply nonexistent operational features.

Use calm pale canvas, white surfaces, high-contrast dark body text and app-specific primary controls.
Footer "C11 · Proposed system · Selection is not confirmation". No prices, balances, numeric monetary values, OTPs, IDs, personal data, fictitious result counts, guessed date values, fake saved state or fabricated backend guarantees. These are isolated illustrative control specimens, not a live screen. One complete board.
```

## Light — refinement 1

Prompt SHA-256: 70904b265ffc9132e5044cb535065cbc58ad7f761ac90f2a79afe7fd9c1ba788. Original final newline: False.

```text
Correct C11 LIGHT Admin board while preserving all four panels and professional institutional-blue/cyan C01 palette. Panel1 Select visible header mixed dash derives from EXACTLY two visible eligible rows: Record A checked, Record B unchecked. DELETE Record C entirely (a filtered-out record must not be drawn as visible eligible/selected). Add 'Proposed pattern' label to Select visible block. Panel2 payout status group has EXACTLY THREE options: 'Pending / Requested' selected, 'Paid' unselected, 'Rejected' unselected. Combine Pending and Requested into one option, no fourth state. Keep user filter All selected, category picker single choice, editor Product active draft ON with Save to commit. No bulk operation, no confirmed success check on flow Review selected rows (use neutral selection icon instead), no actual users, counts, hidden-row assumptions or sidebar.
```

## Dark — initial generation

Prompt SHA-256: b9296e790e412360f9a77949a73925054844436aefa34a0cc9c2c01196a2d7d5. Original final newline: False.

```text
Use case: ui-mockup. Create a premium full-canvas landscape Storybook design system board, 1536x1024. Heading "Agrimore Admin", DARK theme chip, subtitle "Selection controls and filter state", small "C11 · Target design". Four numbered panels in balanced 2x2 grid, exceptionally clear English text, polished app-specific control anatomy. NO sidebar, phone frame, browser chrome, photography, logos or sprawling empty space.
Reference image 1 is the approved C01 DARK identity. Match its type character, colors, surfaces and supporting accents, not its original token content.
App identity: Professional institutional blue with cyan and steel/slate support..
Exact palette roles {"primary":"#93B3EC","onPrimary":"#0D203E","support":"#7BCBD5","supportLabel":"Supporting cyan","canvas":"#080B10","surface":"#121922","raised":"#1D2837","text":"#F2F6FC","muted":"#B5C3D6","border":"#314157","strongBorder":"#74869E","selected":"#192E4A","focus":"#93B3EC"}.
Status roles [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#172A42","text":"#AFCCF6"}]. Selection uses primary/selected roles, NOT success green or error styling. Apply dark onPrimary to pale filled controls. Focus visible and independent of selected.
Typography Inter weights 600/500/400 scale 32/24/18/16/14/12; spacing 4/8/12/16/24/32; Control/Card/Sheet radii 8/12/16; border 1px focus2px. Chips may be pill-shaped; comfortable 48px hit regions; labels wrap. No invented extra palette.
Distinct character: Professional-blue dense review controls with cyan grouping, explicit row selection scope and mixed parent checkboxes..
Panels:
1. "Visible-row selection" — Proposed pattern: Select visible checkbox MIXED dash; two synthetic rows Record A checked, Record B unchecked. Caption Only visible eligible rows. Separate switch Product active ON, helper Editor draft — Save to commit. Do not show fake bulk actions or user data.
2. "Exclusive filters and radios" — User-filter chips All selected, Active unselected, Inactive unselected. Separate radio group Payout status: Pending / Requested selected, Paid unselected, Rejected unselected. One choice per group; not a mutation.
3. "Structured category picker" — Product category field Choose a category; open compact picker with Search categories and radio options Category A selected, Category B unselected. Synthetic labels. Caption Stable option IDs; preserve current value on cancel. No sidebar.
4. "Filter scope and selection" — Diagram Filter visible records → Review selected rows → Explicit action. Callout Mixed means some visible rows selected. Text Changing filters must reconcile selection. Clear selection text action. Separate editor Save / Cancel action specimens. No success message, permissions claims or real record counts.
CRITICAL: checkbox CHECKED shows a check; UNCHECKED empty square; MIXED dash; DISABLED muted with readable reason. Radio uses circle+dot, only one option selected per group. Switch knob position and On/Off text must agree. Checkmarks indicate selection only, never confirmed server success. Selected chips show check or clear shape cue; removable chips have explicit ×. Explain draft versus applied state clearly. Picker Cancel preserves old value. Keep choice groups separate. Generic atoms explicitly "Pattern reference"; do not imply nonexistent operational features.

Use near-black canvas and dark-grey neutral panels, subtle borders and pale app accents, no white panels or saturated navy slabs. Every pale primary-filled action/chip has dark onPrimary text.
Footer "C11 · Proposed system · Selection is not confirmation". No prices, balances, numeric monetary values, OTPs, IDs, personal data, fictitious result counts, guessed date values, fake saved state or fabricated backend guarantees. These are isolated illustrative control specimens, not a live screen. One complete board.
PAIR CONTRACT: Reference1 = authoritative C01 DARK identity. Reference2 = refined selected C11 LIGHT board, authoritative panel layout, state logic and copy. Match its content, control cardinality and premium hierarchy. Marketplace no marketing slogans, immediate sort separate from draft category/availability, shop Reset immediate. Seller store switch remains draft, blank calendar values. Delivery OFFLINE is availability only; never claim existing delivery updates unavailable; Cancel preserves applied filters and Reset now clears applied state. Sales Associate Dark mode MUST be ON with knob on right in this DARK board; only Requested and combined Paid / Settled options; no removable × on single-choice order chip. Admin ONLY Record A checked and Record B unchecked with mixed Select visible parent; combined Pending / Requested, Paid and Rejected group. Keep pattern-reference labels for proposed atoms. Near-black canvas, dark-grey surfaces, no white panels/saturated navy slabs. Pale filled primary controls/checkmarks/mixed dashes MUST use dark onPrimary foreground. No invented dates, numeric amounts, result counts, marketing or confirmed success. Include small C11 proposed footer.
```

## Dark — refinement 1

Prompt SHA-256: 0ed0558bf42f1072e2f86113a632aeb1dbf0ff533e0e0fbba988e2f64eec9af0. Original final newline: False.

```text
Targeted edit of this C11 DARK Admin image. Preserve EVERY panel, layout, labels, background and choice state. Change ONLY Product active ON switch styling: active TRACK exactly pale primary #93B3EC, knob on RIGHT exactly dark onPrimary #0D203E. Keep On text readable and dark slate surfaces. Do not use saturated light-theme blue track or white knob. All other controls and copy unchanged. C01 dark identity reference supplied second.
```

