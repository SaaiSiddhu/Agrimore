# Agrimore Marketplace — C06 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Built-in image_gen. C01 inputs are locked identity references. Fenced blocks preserve exact prompt text; omit the added separator newline when Original final newline is false.

## Light — initial generation

Prompt SHA-256: 8fefd560dc4a40540fe64206d19bbed2774e8c11ee702566c279b78af4f81594. Original final newline: False.

```text
Create ONE premium light theme Storybook design-system board for Agrimore Marketplace, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Professional green with warm gold and natural stone support.
Authoritative color roles: {"primary":"#087A4B","onPrimary":"#FFFFFF","support":"#9A6826","supportLabel":"Warm gold","canvas":"#F7F9F6","surface":"#FFFFFF","raised":"#FBFCF9","text":"#1A2C21","muted":"#5D7062","border":"#DAE4DB","strongBorder":"#91A594","selected":"#E5F3E9","focus":"#087A4B"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E7F2EC","text":"#286B4D"}]. Radius roles: {"Control":12,"Card":16,"Sheet / dialog":24}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use the approved light canvas with clean surface panels.

Heading: "Agrimore Marketplace" only, with a small "Light" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Scrollable task page: "Delivery address". Fields use exact readable text [["House / building","12, Garden Street"],["Road / area","Market Road"],["Pincode","600001"]]. Primary action "Save address".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Pincode" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 48px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Field gap | 16
Section gap | 24
Footer inset | 16
Footer vertical | 12
Action minimum | 48
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Keep address fields in one flexible scroll region.
Reserve the footer outside the form scroll.
Reveal the focused field and its validation text.
Measure safe areas again when the keyboard changes.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
```

## Light — refinement 1

Prompt SHA-256: f0a16dd9a0a5392a540ff6d28d5c395526fdd0dce731177d00ee4829b55249d9. Original final newline: False.

```text
Refine this existing C06 light board. Preserve the premium full-board structure, all heading/copy, exact six-row layout table and four keyboard/scroll rules. The second attached image is the approved C01 identity reference.
REPAIR mobile schematic comparison geometry: both CLOSED and OPEN viewport rectangles must have EXACTLY the same outer WIDTH and HEIGHT, with identical top and bottom baseline positions. Fit the system keyboard entirely INSIDE the open viewport's bottom part, reducing the internal scroll-body height; do not extend the total viewport to accommodate it. Keep the footer ABOVE the keyboard and the focused field/helper ABOVE the footer. Keep same header and font sizing in both states. Shrink the diagram keyboard band's footprint if needed; do not shrink text or minimum action target. Internal positions need not be pixel-scale specifications. Preserve generous whitespace and readable text.
Use the approved palette precisely as direction: {"primary":"#087A4B","onPrimary":"#FFFFFF","support":"#9A6826","supportLabel":"Warm gold","canvas":"#F7F9F6","surface":"#FFFFFF","raised":"#FBFCF9","text":"#1A2C21","muted":"#5D7062","border":"#DAE4DB","strongBorder":"#91A594","selected":"#E5F3E9","focus":"#087A4B"}. Solid primary actions use #087A4B with text #FFFFFF; no gradient. Focus outlines and diagram annotation accents use #087A4B, not electric default blue. Supporting colors are secondary accents only.



Do not add navigation tabs, sidebar, hardware bezel, success statuses, extra rows or new layout numbers. Board title Agrimore Marketplace; light theme only.
```

## Dark — initial generation

Prompt SHA-256: 6732b23c556dab0f3375ff00d0d1cf8c2d2b94f7dbd60bd8ed7069f971bc895d. Original final newline: False.

```text
Transform the FIRST attached C06 light board into its premium DARK companion. Keep the app-specific content, panels, field values, layout-role table and all four rules exactly matched to this selected C06 light board. The SECOND reference is the approved C01 DARK identity; its palette is authoritative.
Create ONE premium dark theme Storybook design-system board for Agrimore Marketplace, C06 Mobile layout, safe areas and keyboard. Landscape 1536x1024 style, crisp polished typography, generous margins, no sidebar, no browser chrome, no device bezels, no photos. This is a proposed design specification, not a runtime screenshot.

REFERENCE: the attached approved C01 board defines this app's exact visual identity. Match its colors, Inter typography, component radii, borders and restrained elevation. Identity: Professional green with warm gold and natural stone support.
Authoritative color roles: {"primary":"#67D2A1","onPrimary":"#0B291D","support":"#DDB97A","supportLabel":"Warm gold","canvas":"#090C0A","surface":"#141A16","raised":"#1E2721","text":"#F2F7F3","muted":"#B9C9BD","border":"#344338","strongBorder":"#798F7E","selected":"#163325","focus":"#67D2A1"}.
Use only those brand colors for design accents. Status colors, if needed: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#173126","text":"#A1D8B9"}]. Radius roles: {"Control":12,"Card":16,"Sheet / dialog":24}; default border 1px, focus outline 2px. Do not invent an additional brand blue or green. Use a near-black canvas and dark-grey layered surfaces; no large white panels. Pale primary buttons need the dark onPrimary text.

Heading: "Agrimore Marketplace" only, with a small "Dark" chip. Subtitle: "Mobile layout, safe areas and keyboard". Small "C06 · Proposal" label.
Organize into a generous left two-thirds preview area and a right third with three stacked specimen cards. This is a full-width documentation board, not app navigation.
LEFT: two same-size upright MOBILE VIEWPORT SCHEMATICS (no hardware bezel), labelled "Keyboard closed" and "Keyboard open". Both display the same Scrollable task page: "Delivery address". Fields use exact readable text [["House / building","12, Garden Street"],["Road / area","Market Road"],["Pincode","600001"]]. Primary action "Save address".
Show a task page with a compact header, flexible scrolling form body and separate sticky action footer. No bottom navigation tabs on this task route.
CLOSED vertical anatomy: a subtle system top inset strip, header/title, scroll region with fields, sticky footer, system bottom inset strip.
OPEN vertical anatomy within the SAME overall viewport height: system top inset, header/title, a SHORTER flexible scrolling body keeping "Pincode" and short helper text visible, sticky footer immediately above the keyboard band, then a clearly bounded neutral system keyboard area at the bottom. Keyboard occupies the lower viewport; NEVER float the action below or inside the keyboard. Do not duplicate closed-state bottom padding above the keyboard. Add slim annotated arrows "Scroll region" and "Sticky action" beside appropriate boundaries. Label the keyboard band "System keyboard". Stylized unlabeled keys are fine, avoid fake keyboard slogans. No absolute device safe-area or keyboard heights. The focused field gets this app's approved focus outline. Content may scroll to reveal the focused field; do not squash text. Button minimum height 48px, allow growth for text. Diagrams are illustrative, not pixel-scale renderings.

RIGHT CARD 1 titled "Layout roles" contains this exact readable two-column table (units px):
Page inset | 16
Field gap | 16
Section gap | 24
Footer inset | 16
Footer vertical | 12
Action minimum | 48
RIGHT CARD 2 titled "Keyboard & scroll" contains these four concise lines:
Keep address fields in one flexible scroll region.
Reserve the footer outside the form scroll.
Reveal the focused field and its validation text.
Measure safe areas again when the keyboard changes.
RIGHT CARD 3 titled "Safe-area contract":
"Insets are system measured"
"Apply keyboard clearance once"
"Footer stays outside scroll"
"Large text can grow controls"
Small bottom note: "Light and dark share the same layout contract."
Keep hierarchy clear, all panels aligned, restrained dividers, high legibility. Include only requested copy; no developer paths, code, extra token swatches, fabricated backend statuses or success outcomes. Pair-matched structure, app-specific content and identity.
Additional pair-edit requirements: preserve the selected light board's story and anatomy. Change Light chip to Dark. Use BLACK/near-black overall canvas, layered dark-grey cards, high-contrast light text, muted secondary text. Neutral keyboard keys must be dark grey, never large bright white surfaces. Primary action background #67D2A1, action text #0B291D, focus outline #67D2A1. Solid fills without glow/gradients. No accidental white text on a pale action. 

Keep both comparison viewport top/bottom baselines aligned; keyboard belongs INSIDE the open viewport, footer above it, shortened scroll body above footer. All table values and copy stay unchanged.
```

