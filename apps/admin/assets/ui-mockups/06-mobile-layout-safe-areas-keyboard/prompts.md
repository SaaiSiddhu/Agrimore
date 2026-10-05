# Agrimore Admin — C06 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. C01 inputs are locked identity references. Fenced blocks preserve exact prompt text; omit the added separator newline when Original final newline is false.

## Light — initial generation

Prompt SHA-256: 0fa123a957814e9d5d7ad362972d3cd375699b3832b0eb895db7df4642dcd8b5. Original final newline: False.

```text
Create ONE premium light theme Storybook design-system board for Agrimore Admin, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Professional institutional blue with cyan and steel/slate support.
Authoritative color roles: {"primary":"#1D4F91","onPrimary":"#FFFFFF","support":"#087E8B","supportLabel":"Supporting cyan","canvas":"#F5F7FB","surface":"#FFFFFF","raised":"#F9FBFE","text":"#14243B","muted":"#5B6B82","border":"#D8E1EF","strongBorder":"#8C9DB5","selected":"#E8EFF8","focus":"#1D4F91"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E8F0FA","text":"#24528C"}]. Radius roles: {"Control":8,"Card":12,"Sheet / dialog":16}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use the approved light canvas with clean surface panels.

Heading: "Agrimore Admin" only, with a small "Light" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Compact mobile editor: "Edit product". Fields use exact readable text [["Product name","Fresh tomatoes"],["Category","Vegetables"],["Description","Packed daily."]]. Primary action "Save changes" and secondary action "Cancel".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Description" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 48px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Field gap | 12
Section gap | 24
Footer inset | 16
Footer vertical | 12
Action minimum | 48
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Keep editor sections inside one flexible scroll.
Reserve Save changes and Cancel below the form.
Stack actions when labels or text need more room.
Keep the focused field above the action footer.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
```

## Light — refinement 1

Prompt SHA-256: 1a2d93529ecb0b792b285f6a91b16ce6e6afc305a6dac8642101af86a768f7bf. Original final newline: False.

```text
Refine this existing C06 light board. Preserve the premium full-board structure, all heading/copy, exact six-row layout table and four keyboard/scroll rules. The second attached image is the approved C01 identity reference.
REPAIR mobile schematic comparison geometry: both CLOSED and OPEN viewport rectangles must have EXACTLY the same outer WIDTH and HEIGHT, with identical top and bottom baseline positions. Fit the system keyboard entirely INSIDE the open viewport's bottom part, reducing the internal scroll-body height; do not extend the total viewport to accommodate it. Keep the footer ABOVE the keyboard and the focused field/helper ABOVE the footer. Keep same header and font sizing in both states. Shrink the diagram keyboard band's footprint if needed; do not shrink text or minimum action target. Internal positions need not be pixel-scale specifications. Preserve generous whitespace and readable text.
Use the approved palette precisely as direction: {"primary":"#1D4F91","onPrimary":"#FFFFFF","support":"#087E8B","supportLabel":"Supporting cyan","canvas":"#F5F7FB","surface":"#FFFFFF","raised":"#F9FBFE","text":"#14243B","muted":"#5B6B82","border":"#D8E1EF","strongBorder":"#8C9DB5","selected":"#E8EFF8","focus":"#1D4F91"}. Solid primary actions use #1D4F91 with text #FFFFFF; no gradient. Focus outlines and diagram annotation accents use #1D4F91, not electric default blue. Supporting colors are secondary accents only.


Focus outline must be professional blue #1D4F91, not bright electric blue. Keep Save changes and Cancel in separate growing action rows as pictured.
Do not add navigation tabs, sidebar, hardware bezel, success statuses, extra rows or new layout numbers. Board title Agrimore Admin; light theme only.
```

## Dark — initial generation

Prompt SHA-256: 227d2e4c48ac9cda7d9594cad5f71ede038d47314817e50ab67eeef4df46d45b. Original final newline: False.

```text
Transform the FIRST attached C06 light board into its premium DARK companion. Keep the app-specific content, panels, field values, layout-role table and all four rules exactly matched to this selected C06 light board. The SECOND reference is the approved C01 DARK identity; its palette is authoritative.
Create ONE premium dark theme Storybook design-system board for Agrimore Admin, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Professional institutional blue with cyan and steel/slate support.
Authoritative color roles: {"primary":"#93B3EC","onPrimary":"#0D203E","support":"#7BCBD5","supportLabel":"Supporting cyan","canvas":"#080B10","surface":"#121922","raised":"#1D2837","text":"#F2F6FC","muted":"#B5C3D6","border":"#314157","strongBorder":"#74869E","selected":"#192E4A","focus":"#93B3EC"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#172A42","text":"#AFCCF6"}]. Radius roles: {"Control":8,"Card":12,"Sheet / dialog":16}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use a near-black canvas and dark-grey layered surfaces; no large white panels. Pale primary buttons need the dark onPrimary text.

Heading: "Agrimore Admin" only, with a small "Dark" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Compact mobile editor: "Edit product". Fields use exact readable text [["Product name","Fresh tomatoes"],["Category","Vegetables"],["Description","Packed daily."]]. Primary action "Save changes" and secondary action "Cancel".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Description" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 48px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Field gap | 12
Section gap | 24
Footer inset | 16
Footer vertical | 12
Action minimum | 48
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Keep editor sections inside one flexible scroll.
Reserve Save changes and Cancel below the form.
Stack actions when labels or text need more room.
Keep the focused field above the action footer.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
Additional pair-edit requirements: preserve the selected light board's story and anatomy. Change Light chip to Dark. Use BLACK/near-black overall canvas, layered dark-grey cards, high-contrast light text, muted secondary text. Neutral keyboard keys must be dark grey, never large bright white surfaces. Primary action background #93B3EC, action text #0D203E, focus outline #93B3EC. Solid fills without glow/gradients. No accidental white text on a pale action. 

Keep both comparison viewport top/bottom baselines aligned; keyboard belongs INSIDE the open viewport, footer above it, shortened scroll body above footer. All table values and copy stay unchanged.
```

