# Agrimore Sales Associate — C06 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. C01 inputs are locked identity references. Fenced blocks preserve exact prompt text; omit the added separator newline when Original final newline is false.

## Light — initial generation

Prompt SHA-256: 1278f6661ef67d7f1b0638d2b6bfa17ae0b32037e90b7539964a748996d900a7. Original final newline: False.

```text
Create ONE premium light theme Storybook design-system board for Agrimore Sales Associate, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Premium royal blue with muted indigo, pearl and slate support.
Authoritative color roles: {"primary":"#2D56C4","onPrimary":"#FFFFFF","support":"#6950A2","supportLabel":"Supporting indigo","canvas":"#F7F8FC","surface":"#FFFFFF","raised":"#FBFCFF","text":"#192840","muted":"#61708B","border":"#DDE3F0","strongBorder":"#94A0B7","selected":"#EAF0FE","focus":"#2D56C4"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#EDF1FB","text":"#31549E"}]. Radius roles: {"Control":12,"Card":18,"Sheet / dialog":24}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use the approved light canvas with clean surface panels.

Heading: "Agrimore Sales Associate" only, with a small "Light" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Calm financial task page: "Request payout". Fields use exact readable text [["Destination","Payout account"],["Payout amount","₹2,400.00"]]. Primary action "Review payout request".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Payout amount" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 52px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 24
Field gap | 16
Section gap | 24
Footer inset | 24
Footer vertical | 16
Action minimum | 52
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Keep amount and eligibility guidance together.
Reserve the review action outside the scroll.
Reveal the amount field during numeric entry.
Let financial labels wrap at larger text sizes.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
```

## Light — refinement 1

Prompt SHA-256: 6dc0c43f03317cc3f7d96e4679e16c5728bf01072f8b5676709b61bdb6cf0b79. Original final newline: False.

```text
Refine this existing C06 light board. Preserve the premium full-board structure, all heading/copy, exact six-row layout table and four keyboard/scroll rules. The second attached image is the approved C01 identity reference.
REPAIR mobile schematic comparison geometry: both CLOSED and OPEN viewport rectangles must have EXACTLY the same outer WIDTH and HEIGHT, with identical top and bottom baseline positions. Fit the system keyboard entirely INSIDE the open viewport's bottom part, reducing the internal scroll-body height; do not extend the total viewport to accommodate it. Keep the footer ABOVE the keyboard and the focused field/helper ABOVE the footer. Keep same header and font sizing in both states. Shrink the diagram keyboard band's footprint if needed; do not shrink text or minimum action target. Internal positions need not be pixel-scale specifications. Preserve generous whitespace and readable text.
Use the approved palette precisely as direction: {"primary":"#2D56C4","onPrimary":"#FFFFFF","support":"#6950A2","supportLabel":"Supporting indigo","canvas":"#F7F8FC","surface":"#FFFFFF","raised":"#FBFCFF","text":"#192840","muted":"#61708B","border":"#DDE3F0","strongBorder":"#94A0B7","selected":"#EAF0FE","focus":"#2D56C4"}. Solid primary actions use #2D56C4 with text #FFFFFF; no gradient. Focus outlines and diagram annotation accents use #2D56C4, not electric default blue. Supporting colors are secondary accents only.

Replace BOTH helper messages beneath the payout amount with exactly "Review amount before requesting payout." Do not promise money transfer or successful payout. Keep action "Review payout request", amount ₹2,400.00 and premium royal blue #2D56C4, no electric blue.

Do not add navigation tabs, sidebar, hardware bezel, success statuses, extra rows or new layout numbers. Board title Agrimore Sales Associate; light theme only.
```

## Dark — initial generation

Prompt SHA-256: 24437b9ec31d2c09caba0e5f90194aea5169cc7be1853f79ca0062c400c12d4a. Original final newline: False.

```text
Transform the FIRST attached C06 light board into its premium DARK companion. Keep the app-specific content, panels, field values, layout-role table and all four rules exactly matched to this selected C06 light board. The SECOND reference is the approved C01 DARK identity; its palette is authoritative.
Create ONE premium dark theme Storybook design-system board for Agrimore Sales Associate, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Premium royal blue with muted indigo, pearl and slate support.
Authoritative color roles: {"primary":"#96B4FF","onPrimary":"#142241","support":"#C0ADE7","supportLabel":"Supporting indigo","canvas":"#090B11","surface":"#131722","raised":"#1E2533","text":"#F2F5FC","muted":"#B9C5DD","border":"#354259","strongBorder":"#8393B2","selected":"#1B2C50","focus":"#96B4FF"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#1A2B4C","text":"#B2C8FF"}]. Radius roles: {"Control":12,"Card":18,"Sheet / dialog":24}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use a near-black canvas and dark-grey layered surfaces; no large white panels. Pale primary buttons need the dark onPrimary text.

Heading: "Agrimore Sales Associate" only, with a small "Dark" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Calm financial task page: "Request payout". Fields use exact readable text [["Destination","Payout account"],["Payout amount","₹2,400.00"]]. Primary action "Review payout request".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Payout amount" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 52px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 24
Field gap | 16
Section gap | 24
Footer inset | 24
Footer vertical | 16
Action minimum | 52
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Keep amount and eligibility guidance together.
Reserve the review action outside the scroll.
Reveal the amount field during numeric entry.
Let financial labels wrap at larger text sizes.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
Additional pair-edit requirements: preserve the selected light board's story and anatomy. Change Light chip to Dark. Use BLACK/near-black overall canvas, layered dark-grey cards, high-contrast light text, muted secondary text. Neutral keyboard keys must be dark grey, never large bright white surfaces. Primary action background #96B4FF, action text #142241, focus outline #96B4FF. Solid fills without glow/gradients. No accidental white text on a pale action. 
Helper under BOTH payout amount fields is exactly "Review amount before requesting payout." No transfer promise.
Keep both comparison viewport top/bottom baselines aligned; keyboard belongs INSIDE the open viewport, footer above it, shortened scroll body above footer. All table values and copy stay unchanged.
```

