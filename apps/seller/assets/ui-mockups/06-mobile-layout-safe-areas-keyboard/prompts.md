# Agrimore Seller — C06 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. C01 inputs are locked identity references. Fenced blocks preserve exact prompt text; omit the added separator newline when Original final newline is false.

## Light — initial generation

Prompt SHA-256: 7ec9fbb2fb183a2a3072093b5f864bb5d71b1ad23a5c1c61c17c5a56e3f1eafd. Original final newline: False.

```text
Create ONE premium light theme Storybook design-system board for Agrimore Seller, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Blue-teal with warm copper and cool neutral support.
Authoritative color roles: {"primary":"#0B6A80","onPrimary":"#FFFFFF","support":"#9B5E3D","supportLabel":"Warm copper","canvas":"#F5F8F9","surface":"#FFFFFF","raised":"#F9FCFD","text":"#142A34","muted":"#56717E","border":"#D5E3E8","strongBorder":"#879EAA","selected":"#E5F2F5","focus":"#0B6A80"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E6F3F7","text":"#17647B"}]. Radius roles: {"Control":10,"Card":14,"Sheet / dialog":20}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use the approved light canvas with clean surface panels.

Heading: "Agrimore Seller" only, with a small "Light" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Bounded stock sheet: "Edit stock". Fields use exact readable text [["Product","Fresh tomatoes"],["Stock quantity","250"]]. Primary action "Save stock".
Show a bounded bottom sheet over a subtle neutral backdrop inside each viewport. The sheet has a title, flexible scrolling body and separate footer, with radius 20. Opening the keyboard reduces available sheet space.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Stock quantity" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 48px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Sheet inset | 24
Field gap | 16
Footer inset | 24
Footer vertical | 12
Action minimum | 48
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Bound the sheet to the available height.
Scroll the sheet body; reserve its footer.
Apply the keyboard inset once at the sheet edge.
Keep stock quantity visible during numeric entry.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
```

## Light — refinement 1

Prompt SHA-256: a62023ffc6887df61c02cd83000abcecf09cd0e18e08db6da1488dac6fa2cdb7. Original final newline: False.

```text
Refine this existing C06 light board. Preserve the premium full-board structure, all heading/copy, exact six-row layout table and four keyboard/scroll rules. The second attached image is the approved C01 identity reference.
REPAIR mobile schematic comparison geometry: both CLOSED and OPEN viewport rectangles must have EXACTLY the same outer WIDTH and HEIGHT, with identical top and bottom baseline positions. Fit the system keyboard entirely INSIDE the open viewport's bottom part, reducing the internal scroll-body height; do not extend the total viewport to accommodate it. Keep the footer ABOVE the keyboard and the focused field/helper ABOVE the footer. Keep same header and font sizing in both states. Shrink the diagram keyboard band's footprint if needed; do not shrink text or minimum action target. Internal positions need not be pixel-scale specifications. Preserve generous whitespace and readable text.
Use the approved palette precisely as direction: {"primary":"#0B6A80","onPrimary":"#FFFFFF","support":"#9B5E3D","supportLabel":"Warm copper","canvas":"#F5F8F9","surface":"#FFFFFF","raised":"#F9FCFD","text":"#142A34","muted":"#56717E","border":"#D5E3E8","strongBorder":"#879EAA","selected":"#E5F2F5","focus":"#0B6A80"}. Solid primary actions use #0B6A80 with text #FFFFFF; no gradient. Focus outlines and diagram annotation accents use #0B6A80, not electric default blue. Supporting colors are secondary accents only.



Do not add navigation tabs, sidebar, hardware bezel, success statuses, extra rows or new layout numbers. Board title Agrimore Seller; light theme only.
```

## Dark — initial generation

Prompt SHA-256: 010573c165187aa5088c1c739cdd6198d728998670e1abf28ca7ae20a52871e4. Original final newline: False.

```text
Transform the FIRST attached C06 light board into its premium DARK companion. Keep the app-specific content, panels, field values, layout-role table and all four rules exactly matched to this selected C06 light board. The SECOND reference is the approved C01 DARK identity; its palette is authoritative.
Create ONE premium dark theme Storybook design-system board for Agrimore Seller, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Blue-teal with warm copper and cool neutral support.
Authoritative color roles: {"primary":"#70D0DF","onPrimary":"#0B2831","support":"#DAAE8C","supportLabel":"Warm copper","canvas":"#080C0F","surface":"#11191E","raised":"#1B262D","text":"#F1F7FA","muted":"#B5C9D1","border":"#33464F","strongBorder":"#7895A2","selected":"#14313A","focus":"#70D0DF"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#142D37","text":"#9BD9E9"}]. Radius roles: {"Control":10,"Card":14,"Sheet / dialog":20}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use a near-black canvas and dark-grey layered surfaces; no large white panels. Pale primary buttons need the dark onPrimary text.

Heading: "Agrimore Seller" only, with a small "Dark" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Bounded stock sheet: "Edit stock". Fields use exact readable text [["Product","Fresh tomatoes"],["Stock quantity","250"]]. Primary action "Save stock".
Show a bounded bottom sheet over a subtle neutral backdrop inside each viewport. The sheet has a title, flexible scrolling body and separate footer, with radius 20. Opening the keyboard reduces available sheet space.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Stock quantity" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 48px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Sheet inset | 24
Field gap | 16
Footer inset | 24
Footer vertical | 12
Action minimum | 48
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Bound the sheet to the available height.
Scroll the sheet body; reserve its footer.
Apply the keyboard inset once at the sheet edge.
Keep stock quantity visible during numeric entry.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
Additional pair-edit requirements: preserve the selected light board's story and anatomy. Change Light chip to Dark. Use BLACK/near-black overall canvas, layered dark-grey cards, high-contrast light text, muted secondary text. Neutral keyboard keys must be dark grey, never large bright white surfaces. Primary action background #70D0DF, action text #0B2831, focus outline #70D0DF. Solid fills without glow/gradients. No accidental white text on a pale action. 

Keep both comparison viewport top/bottom baselines aligned; keyboard belongs INSIDE the open viewport, footer above it, shortened scroll body above footer. All table values and copy stay unchanged.
```

