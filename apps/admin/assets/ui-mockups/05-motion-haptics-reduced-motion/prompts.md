# Agrimore Admin — C05 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Generated using built-in image_gen. C01 inputs are identity references. Each fenced block preserves the exact original text; omit its added separator newline if Original final newline is false.

## Light — initial generation

Prompt SHA-256: eb6353c76bed940e25626eb399f21e36702c9de6a27822e5ee8f9a41e76643e8. Original final newline: True.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Admin — light theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 light theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Admin" and "Light" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Restrained operational desktop feedback; rows remain anchored, focus stable, no table slides or celebration. Cyan context, institutional blue actions distinct from royal blue. Inter 600/500/400.
Palette exact specification: {"primary":"#1D4F91","onPrimary":"#FFFFFF","support":"#087E8B","supportLabel":"Supporting cyan","canvas":"#F5F7FB","surface":"#FFFFFF","raised":"#F9FBFE","text":"#14243B","muted":"#5B6B82","border":"#D8E1EF","strongBorder":"#8C9DB5","selected":"#E8EFF8","focus":"#1D4F91"}.
Status colors exact pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E8F0FA","text":"#24528C"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #1D4F91 with text and embedded icons #FFFFFF; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #F5F7FB with dark-grey #FFFFFF/#F9FBFE panels, no pale large areas or neon/glow. Light canvas #F5F7FB, clean #FFFFFF cards. Supporting Supporting cyan #087E8B is secondary.
Inherited radii: {"Control":8,"Card":12,"Sheet / dialog":16}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: An operations query storyboard with compact stationary table snippets and a larger timing table. Cyan annotation accents, clear grid, comfortable controls and a quiet progress comparison below. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Hover / press | 80 ms
Row fade | 160 ms
Result reveal | 160 ms
Dialog enter | 240 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Application filter": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Seller applications · Pending". Ready has a filled primary button "Apply filter"; Pending has a neutral disabled/loading button labeled "Loading applications…" with a small ring snapshot; Confirmed has a static Success-colored check and label "List updated" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "A list refresh does not approve any application.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Loading applications…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Mobile selection | Optional selection click
Confirmed admin action | Optional light impact
Desktop or background refresh | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No row slide, chart sweep or pulse
Keep keyboard focus and table context
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.
```

## Light — refinement 1

Prompt SHA-256: 5150e4756cbfa8ee23e79c8f516689cb07584eff49f7786bafa965de9f6225a2. Original final newline: False.

```text
Use case: precise-object-edit. Input image 1 is the C05 board to refine. Input image 2 is the approved C01 light identity reference. Correct ONLY the Application filter storyboard controls and canonical identity: each of the three frames uses ONE filter field visibly labeled Pending, matching Seller applications · Pending. Replace All statuses with Pending, and remove all three Last 30 days fields entirely; use the freed whitespace quietly. Keep Ready/Apply filter, Pending/Loading applications… and Confirmed/List updated exactly. Filled Apply filter button and primary action accents use institutional blue #1D4F91, NOT royal/electric blue. Cyan #087E8B remains secondary. Preserve all other panels, durations, progress comparisons and labels. Premium Storybook board, full uncropped landscape image, no sidebar. This is a correction of a documentary design proposal, not a runtime screen. Keep everything else unchanged.
```

## Dark — initial generation

Prompt SHA-256: 57aacddf527ad963f45cd605cbac3e2d6277457fe0bf5a00416330bf116302e5. Original final newline: False.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Admin — dark theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 dark theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Admin" and "Dark" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Restrained operational desktop feedback; rows remain anchored, focus stable, no table slides or celebration. Cyan context, institutional blue actions distinct from royal blue. Inter 600/500/400.
Palette exact specification: {"primary":"#93B3EC","onPrimary":"#0D203E","support":"#7BCBD5","supportLabel":"Supporting cyan","canvas":"#080B10","surface":"#121922","raised":"#1D2837","text":"#F2F6FC","muted":"#B5C3D6","border":"#314157","strongBorder":"#74869E","selected":"#192E4A","focus":"#93B3EC"}.
Status colors exact pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#172A42","text":"#AFCCF6"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #93B3EC with text and embedded icons #0D203E; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #080B10 with dark-grey #121922/#1D2837 panels, no pale large areas or neon/glow. Light canvas #080B10, clean #121922 cards. Supporting Supporting cyan #7BCBD5 is secondary.
Inherited radii: {"Control":8,"Card":12,"Sheet / dialog":16}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: An operations query storyboard with compact stationary table snippets and a larger timing table. Cyan annotation accents, clear grid, comfortable controls and a quiet progress comparison below. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Hover / press | 80 ms
Row fade | 160 ms
Result reveal | 160 ms
Dialog enter | 240 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Application filter": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Seller applications · Pending". Ready has a filled primary button "Apply filter"; Pending has a neutral disabled/loading button labeled "Loading applications…" with a small ring snapshot; Confirmed has a static Success-colored check and label "List updated" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "A list refresh does not approve any application.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Loading applications…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Mobile selection | Optional selection click
Confirmed admin action | Optional light impact
Desktop or background refresh | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No row slide, chart sweep or pulse
Keep keyboard focus and table context
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.

Input image 2 is the selected C05 LIGHT board for this app: use its exact corrected panel structure, action/state copy, role table and haptic mapping as a content/layout reference. Change the entire board to Input image 1's APPROVED DARK palette. Remove every light canvas/card fill, retain black/dark-grey surfaces throughout. No product photos, prices except the specified associate amount, or extra stock data. Any curve drawing rises steeply then flattens, no S-curve. The storyboard has ONE Pending filter field per frame, no date-range field or All statuses. Buttons use the specified pale primary with DARK onPrimary text, never white on pale button. Keep Proposal status.
```

## Dark — refinement 1

Prompt SHA-256: e0709e9680ed49766a8a3257bed7ead7684226b6daa53a549e16d634344bca02. Original final newline: False.

```text
Use case: precise-object-edit. Image 1 is the C05 board to correct; Image 2 is the approved C01 dark identity reference. Change ONLY the Reduced motion On switch color treatment. Use a quiet approved selected container #192E4A, label and selected knob accent #93B3EC, with visible thin border #314157. Avoid bright turquoise fill and white text on pale cyan. Preserve the switch's On position, label and shape. Leave every other panel, color, duration and text unchanged. Full uncropped premium Storybook-style board, no sidebar. Keep everything else unchanged.
```

