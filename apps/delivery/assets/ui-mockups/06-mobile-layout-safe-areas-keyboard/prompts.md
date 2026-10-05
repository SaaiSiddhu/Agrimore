# Agrimore Delivery — C06 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. C01 inputs are locked identity references. Fenced blocks preserve exact prompt text; omit the added separator newline when Original final newline is false.

## Light — initial generation

Prompt SHA-256: cdce3dcd00a0116ab6531deb6c6511485a51d7253ba5462e08edf002190c39e9. Original final newline: False.

```text
Create ONE premium light theme Storybook design-system board for Agrimore Delivery, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Black/white with burgundy and burnt orange support.
Authoritative color roles: {"primary":"#191919","onPrimary":"#FFFFFF","support":"#A94D24","supportLabel":"Burnt orange","canvas":"#F8F7F6","surface":"#FFFFFF","raised":"#FAF9F8","text":"#1C1C1C","muted":"#686260","border":"#DDD7D4","strongBorder":"#A49993","selected":"#F5E7EC","focus":"#A94D24","burgundy":"#7A2840"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FBEDE3","text":"#88451E"},{"role":"Error","container":"#F5E7EC","text":"#7A2840"},{"role":"Info","container":"#ECEAE8","text":"#59534F"}]. Radius roles: {"Control":8,"Card":12,"Sheet / dialog":18}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use the approved light canvas with clean surface panels.

Heading: "Agrimore Delivery" only, with a small "Light" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Field-friendly task page: "Support request". Fields use exact readable text [["Category","Delivery"],["Subject","Pickup support"],["Message","Need help with pickup."]]. Primary action "Send request".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Message" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 56px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Field gap | 16
Section gap | 24
Footer inset | 16
Footer vertical | 12
Action minimum | 56
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Use a large action reachable above the keyboard.
Keep the message and its helper text visible.
Separate map gestures from sheet scrolling.
Use one owner for keyboard clearance.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
```

## Light — refinement 1

Prompt SHA-256: 6e1c92acd3edd4f53c4473395b7b55f0c3772d822b89015ebebb0e15566c5d20. Original final newline: False.

```text
Refine this existing C06 light board. Preserve the premium full-board structure, all heading/copy, exact six-row layout table and four keyboard/scroll rules. The second attached image is the approved C01 identity reference.
REPAIR mobile schematic comparison geometry: both CLOSED and OPEN viewport rectangles must have EXACTLY the same outer WIDTH and HEIGHT, with identical top and bottom baseline positions. Fit the system keyboard entirely INSIDE the open viewport's bottom part, reducing the internal scroll-body height; do not extend the total viewport to accommodate it. Keep the footer ABOVE the keyboard and the focused field/helper ABOVE the footer. Keep same header and font sizing in both states. Shrink the diagram keyboard band's footprint if needed; do not shrink text or minimum action target. Internal positions need not be pixel-scale specifications. Preserve generous whitespace and readable text.
Use the approved palette precisely as direction: {"primary":"#191919","onPrimary":"#FFFFFF","support":"#A94D24","supportLabel":"Burnt orange","canvas":"#F8F7F6","surface":"#FFFFFF","raised":"#FAF9F8","text":"#1C1C1C","muted":"#686260","border":"#DDD7D4","strongBorder":"#A49993","selected":"#F5E7EC","focus":"#A94D24","burgundy":"#7A2840"}. Solid primary actions use #191919 with text #FFFFFF; no gradient. Focus outlines and diagram annotation accents use #A94D24, not electric default blue. Supporting colors are secondary accents only.
CRITICAL: change BOTH Send request buttons to neutral black #191919 with white #FFFFFF text. Burnt orange remains only the focus outline/accent; burgundy is secondary, not the main action.


Do not add navigation tabs, sidebar, hardware bezel, success statuses, extra rows or new layout numbers. Board title Agrimore Delivery; light theme only.
```

## Light — refinement 2

Prompt SHA-256: aad3d8ea806f4d19e321b4eca743fba86831bea6c1de95fbe81dc3a6adb817ee. Original final newline: False.

```text
Refine this Agrimore Delivery LIGHT C06 board with one localized geometry edit. Preserve all text, panels, typography and colors; neutral black #191919 Send request buttons with white labels stay unchanged.
The LEFT closed-keyboard viewport is shorter than the right. Extend ONLY the LEFT viewport downward so its bottom edge is exactly horizontally aligned with the RIGHT keyboard-open viewport bottom edge. Move the left footer (Send request), its annotation and bottom safe-inset band downward together. Lengthen the blank portion of the left scroll body above that footer to absorb the additional height. Preserve all LEFT input positions, sizes and text. Preserve the entire RIGHT viewport unchanged, including its keyboard and its button above the keyboard. Both top and bottom viewport baselines must now align. Do not invent extra content, enlarge a safe-area band or change any text. All other board content unchanged.
```

## Dark — initial generation

Prompt SHA-256: da152d19a578976e58bf10ecfd1f8648d6955034ec8299e2696081f57565b360. Original final newline: False.

```text
Transform the FIRST attached C06 light board into its premium DARK companion. Keep the app-specific content, panels, field values, layout-role table and all four rules exactly matched to this selected C06 light board. The SECOND reference is the approved C01 DARK identity; its palette is authoritative.
Create ONE premium dark theme Storybook design-system board for Agrimore Delivery, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Black/white with burgundy and burnt orange support.
Authoritative color roles: {"primary":"#F4F4F4","onPrimary":"#151515","support":"#ECA06D","supportLabel":"Burnt orange","canvas":"#090909","surface":"#151515","raised":"#222222","text":"#F5F3F2","muted":"#C3BAB7","border":"#3C3633","strongBorder":"#91857E","selected":"#3B2029","focus":"#ECA06D","burgundy":"#DCA0B1"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#342418","text":"#F0BE98"},{"role":"Error","container":"#3B2029","text":"#E3A8B9"},{"role":"Info","container":"#282523","text":"#D3C8C1"}]. Radius roles: {"Control":8,"Card":12,"Sheet / dialog":18}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use a near-black canvas and dark-grey layered surfaces; no large white panels. Pale primary buttons need the dark onPrimary text.

Heading: "Agrimore Delivery" only, with a small "Dark" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Field-friendly task page: "Support request". Fields use exact readable text [["Category","Delivery"],["Subject","Pickup support"],["Message","Need help with pickup."]]. Primary action "Send request".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Message" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 56px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Field gap | 16
Section gap | 24
Footer inset | 16
Footer vertical | 12
Action minimum | 56
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Use a large action reachable above the keyboard.
Keep the message and its helper text visible.
Separate map gestures from sheet scrolling.
Use one owner for keyboard clearance.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
Additional pair-edit requirements: preserve the selected light board's story and anatomy. Change Light chip to Dark. Use BLACK/near-black overall canvas, layered dark-grey cards, high-contrast light text, muted secondary text. Neutral keyboard keys must be dark grey, never large bright white surfaces. Primary action background #F4F4F4, action text #151515, focus outline #ECA06D. Solid fills without glow/gradients. No accidental white text on a pale action. Both Send request actions are #F4F4F4 with #151515 text; burnt orange #ECA06D is only focus/support.

Keep both comparison viewport top/bottom baselines aligned; keyboard belongs INSIDE the open viewport, footer above it, shortened scroll body above footer. All table values and copy stay unchanged.
```

