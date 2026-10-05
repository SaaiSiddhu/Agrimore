# Agrimore Marketplace — C05 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Generated using built-in image_gen. C01 inputs are identity references. Each fenced block preserves the exact original text; omit its added separator newline if Original final newline is false.

## Light — initial generation

Prompt SHA-256: ee74a5f4ebde498da1a908d6f42a0989dc60289a3b7564ea8d69f9a1214d0b62. Original final newline: True.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Marketplace — light theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 light theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Marketplace" and "Light" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Responsive shopping feedback; gentle contained fades, no playful bounce or flying-cart effect. Inter 700/600/400.
Palette exact specification: {"primary":"#087A4B","onPrimary":"#FFFFFF","support":"#9A6826","supportLabel":"Warm gold","canvas":"#F7F9F6","surface":"#FFFFFF","raised":"#FBFCF9","text":"#1A2C21","muted":"#5D7062","border":"#DAE4DB","strongBorder":"#91A594","selected":"#E5F3E9","focus":"#087A4B"}.
Status colors exact pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E7F2EC","text":"#286B4D"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #087A4B with text and embedded icons #FFFFFF; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #F7F9F6 with dark-grey #FFFFFF/#FBFCF9 panels, no pale large areas or neon/glow. Light canvas #F7F9F6, clean #FFFFFF cards. Supporting Warm gold #9A6826 is secondary.
Inherited radii: {"Control":12,"Card":16,"Sheet / dialog":24}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: A broad three-state product/action storyboard above; timing tokens and loading comparison below; haptics and reduced-motion policy in the final row. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 100 ms
Content fade | 180 ms
Result reveal | 280 ms
Sheet enter | 320 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Add to cart": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Fresh tomatoes · 1 kg". Ready has a filled primary button "Add to cart"; Pending has a neutral disabled/loading button labeled "Adding item…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Added to cart" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Show confirmation after the cart update succeeds.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Adding item…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Quantity change | Selection click
Cart update confirmed | Optional light impact
Loading or refresh | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No confetti, pulse, slide or zoom
Keep tracking updates; snap marker
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.
```

## Light — refinement 1

Prompt SHA-256: ec9ed20ed5ace240e2e8056108b80f0a84b60123ea8aa33dba50669f68d4a059. Original final newline: False.

```text
Use case: precise-object-edit. Input image 1 is the C05 board to refine. Input image 2 is the approved C01 light identity reference. Change ONLY the Add to cart storyboard's product content: remove all three tomato photos, remove every invented ₹12.00 price and every In stock line. Replace the photo space with a quiet outline shopping-bag icon or whitespace. Each frame must keep ONLY exact entity Fresh tomatoes · 1 kg and the existing action/result label. Do not add a price, stock label or new data. Preserve all other panels, text, durations, geometry and colors. Premium Storybook board, full uncropped landscape image, no sidebar. This is a correction of a documentary design proposal, not a runtime screen. Keep everything else unchanged.
```

## Dark — initial generation

Prompt SHA-256: 9edc30ed8b9bde61ae89471709b4b718ccecccef58b09e1a7dcd7939f15c01a8. Original final newline: False.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Marketplace — dark theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 dark theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Marketplace" and "Dark" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Responsive shopping feedback; gentle contained fades, no playful bounce or flying-cart effect. Inter 700/600/400.
Palette exact specification: {"primary":"#67D2A1","onPrimary":"#0B291D","support":"#DDB97A","supportLabel":"Warm gold","canvas":"#090C0A","surface":"#141A16","raised":"#1E2721","text":"#F2F7F3","muted":"#B9C9BD","border":"#344338","strongBorder":"#798F7E","selected":"#163325","focus":"#67D2A1"}.
Status colors exact pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#173126","text":"#A1D8B9"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #67D2A1 with text and embedded icons #0B291D; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #090C0A with dark-grey #141A16/#1E2721 panels, no pale large areas or neon/glow. Light canvas #090C0A, clean #141A16 cards. Supporting Warm gold #DDB97A is secondary.
Inherited radii: {"Control":12,"Card":16,"Sheet / dialog":24}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: A broad three-state product/action storyboard above; timing tokens and loading comparison below; haptics and reduced-motion policy in the final row. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 100 ms
Content fade | 180 ms
Result reveal | 280 ms
Sheet enter | 320 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Add to cart": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Fresh tomatoes · 1 kg". Ready has a filled primary button "Add to cart"; Pending has a neutral disabled/loading button labeled "Adding item…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Added to cart" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Show confirmation after the cart update succeeds.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Adding item…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Quantity change | Selection click
Cart update confirmed | Optional light impact
Loading or refresh | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No confetti, pulse, slide or zoom
Keep tracking updates; snap marker
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.

Input image 2 is the selected C05 LIGHT board for this app: use its exact corrected panel structure, action/state copy, role table and haptic mapping as a content/layout reference. Change the entire board to Input image 1's APPROVED DARK palette. Remove every light canvas/card fill, retain black/dark-grey surfaces throughout. No product photos, prices except the specified associate amount, or extra stock data. Any curve drawing rises steeply then flattens, no S-curve.  Buttons use the specified pale primary with DARK onPrimary text, never white on pale button. Keep Proposal status.
```

## Dark — refinement 1

Prompt SHA-256: e925b602a777dd74af6c27203a6fc651f02b1acb09dbcf81748a97776ab0b86a. Original final newline: False.

```text
Use case: precise-object-edit. Image 1 is the C05 board to correct; Image 2 is the approved C01 dark identity reference. Change ONLY the curve diagram below Motion roles. Draw a single monotonic ease-out curve that rises steeply at Start and smoothly flattens to End. It must NEVER bend downward or overshoot the End value. Keep Start, End, Visual duration only and existing ease-out caption. Preserve all other panels, text, durations and canonical palette. Full uncropped premium Storybook-style board, no sidebar. Keep everything else unchanged.
```

