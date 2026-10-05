# Agrimore Delivery — C05 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Generated using built-in image_gen. C01 inputs are identity references. Each fenced block preserves the exact original text; omit its added separator newline if Original final newline is false.

## Light — initial generation

Prompt SHA-256: a25156049ebb97e9f5c38bf1660d0ba854b151cfe3db8391a3ad20ed4885a630. Original final newline: True.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Delivery — light theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 light theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Delivery" and "Light" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Direct field-task feedback, larger stable actions, no zoom on critical tasks. Burnt orange timing guides, burgundy proof context; neutral primary actions. Inter 700/600/400.
Palette exact specification: {"primary":"#191919","onPrimary":"#FFFFFF","support":"#A94D24","supportLabel":"Burnt orange","canvas":"#F8F7F6","surface":"#FFFFFF","raised":"#FAF9F8","text":"#1C1C1C","muted":"#686260","border":"#DDD7D4","strongBorder":"#A49993","selected":"#F5E7EC","focus":"#A94D24","burgundy":"#7A2840"}.
Status colors exact pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FBEDE3","text":"#88451E"},{"role":"Error","container":"#F5E7EC","text":"#7A2840"},{"role":"Info","container":"#ECEAE8","text":"#59534F"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #191919 with text and embedded icons #FFFFFF; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #F8F7F6 with dark-grey #FFFFFF/#FAF9F8 panels, no pale large areas or neon/glow. Light canvas #F8F7F6, clean #FFFFFF cards. Supporting Burnt orange #A94D24; burgundy #7A2840 is secondary.
Inherited radii: {"Control":8,"Card":12,"Sheet / dialog":18}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: A wide three-frame proof-transfer strip with large controls; black/white action specimens, burgundy task context and burnt orange timing accents. Separate loading, haptics and safety-oriented reduced-motion panels. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 120 ms
Panel fade | 200 ms
Result reveal | 200 ms
Sheet enter | 320 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Proof upload": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Order ORD-2048 · Proof photo". Ready has a filled primary button "Upload proof"; Pending has a neutral disabled/loading button labeled "Uploading proof…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Proof received" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Proof received does not mean delivery completed.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Uploading proof…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Task selected | Optional light impact
Proof receipt confirmed | Optional medium impact
GPS or upload retry | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No pulse, camera fly-in or zoom
Keep offer timer and GPS updates
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.
```

## Light — refinement 1

Prompt SHA-256: ba2574b9df718810e14dfbb61359dc44f667542030360ef7647d477d1b55af79. Original final newline: False.

```text
Use case: precise-object-edit. Image 1 is the C05 board to correct; Image 2 is the approved C01 light identity reference. Change ONLY decorative state colors in the Reduced motion panel. The On pill must use selected container #F5E7EC, with burgundy text #7A2840, NOT Success green. The crossed-circle beside No pulse, camera fly-in or zoom must use #A94D24 burnt orange or #686260 neutral, NOT bright red. Leave the real Proof received Success-green confirmation unchanged. Preserve all wording, panels, duration values, geometry and all other colors. Full uncropped premium Storybook-style board, no sidebar. Keep everything else unchanged.
```

## Dark — initial generation

Prompt SHA-256: 3572f05cd09a77d0bad6cffbb152b60bc5c36c0535a5e563a3118d8d3e01d3aa. Original final newline: False.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Delivery — dark theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 dark theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Delivery" and "Dark" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Direct field-task feedback, larger stable actions, no zoom on critical tasks. Burnt orange timing guides, burgundy proof context; neutral primary actions. Inter 700/600/400.
Palette exact specification: {"primary":"#F4F4F4","onPrimary":"#151515","support":"#ECA06D","supportLabel":"Burnt orange","canvas":"#090909","surface":"#151515","raised":"#222222","text":"#F5F3F2","muted":"#C3BAB7","border":"#3C3633","strongBorder":"#91857E","selected":"#3B2029","focus":"#ECA06D","burgundy":"#DCA0B1"}.
Status colors exact pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#342418","text":"#F0BE98"},{"role":"Error","container":"#3B2029","text":"#E3A8B9"},{"role":"Info","container":"#282523","text":"#D3C8C1"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #F4F4F4 with text and embedded icons #151515; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #090909 with dark-grey #151515/#222222 panels, no pale large areas or neon/glow. Light canvas #090909, clean #151515 cards. Supporting Burnt orange #ECA06D; burgundy #DCA0B1 is secondary.
Inherited radii: {"Control":8,"Card":12,"Sheet / dialog":18}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: A wide three-frame proof-transfer strip with large controls; black/white action specimens, burgundy task context and burnt orange timing accents. Separate loading, haptics and safety-oriented reduced-motion panels. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 120 ms
Panel fade | 200 ms
Result reveal | 200 ms
Sheet enter | 320 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Proof upload": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Order ORD-2048 · Proof photo". Ready has a filled primary button "Upload proof"; Pending has a neutral disabled/loading button labeled "Uploading proof…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Proof received" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Proof received does not mean delivery completed.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Uploading proof…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Task selected | Optional light impact
Proof receipt confirmed | Optional medium impact
GPS or upload retry | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No pulse, camera fly-in or zoom
Keep offer timer and GPS updates
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.

Input image 2 is the selected C05 LIGHT board for this app: use its exact corrected panel structure, action/state copy, role table and haptic mapping as a content/layout reference. Change the entire board to Input image 1's APPROVED DARK palette. Remove every light canvas/card fill, retain black/dark-grey surfaces throughout. No product photos, prices except the specified associate amount, or extra stock data. Any curve drawing rises steeply then flattens, no S-curve.  Buttons use the specified pale primary with DARK onPrimary text, never white on pale button. Keep Proposal status.
```

## Dark — refinement 1

Prompt SHA-256: 2950ca15cb7113b81ef1d8a7ed7b7420bc8ce235cefdcdde9a048802d993da3b. Original final newline: False.

```text
Use case: precise-object-edit. Image 1 is the C05 board to correct; Image 2 is the approved C01 dark identity reference. Change ONLY decorative state colors in the Reduced motion panel. The On pill must use selected container #3B2029, with burgundy text #DCA0B1, NOT Success green. The crossed-circle beside No pulse, camera fly-in or zoom must use #ECA06D burnt orange or #C3BAB7 neutral, NOT bright red. Leave the real Proof received Success-green confirmation unchanged. Preserve all wording, panels, duration values, geometry and all other colors. Full uncropped premium Storybook-style board, no sidebar. Keep everything else unchanged.
```

