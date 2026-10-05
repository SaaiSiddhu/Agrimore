# Agrimore Sales Associate — C05 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Generated using built-in image_gen. C01 inputs are identity references. Each fenced block preserves the exact original text; omit its added separator newline if Original final newline is false.

## Light — initial generation

Prompt SHA-256: 802530f78fdcc1aff7c47d50afdf618fa2d74c3280c658cc3523d697a2eadfed. Original final newline: True.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Sales Associate — light theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 light theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Sales Associate" and "Light" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Calm financial trust; contained opacity changes and static monetary figures. Indigo payout context, blue actions. Inter 600/500/400.
Palette exact specification: {"primary":"#2D56C4","onPrimary":"#FFFFFF","support":"#6950A2","supportLabel":"Supporting indigo","canvas":"#F7F8FC","surface":"#FFFFFF","raised":"#FBFCFF","text":"#192840","muted":"#61708B","border":"#DDE3F0","strongBorder":"#94A0B7","selected":"#EAF0FE","focus":"#2D56C4"}.
Status colors exact pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#EDF1FB","text":"#31549E"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #2D56C4 with text and embedded icons #FFFFFF; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #F7F8FC with dark-grey #FFFFFF/#FBFCFF panels, no pale large areas or neon/glow. Light canvas #F7F8FC, clean #FFFFFF cards. Supporting Supporting indigo #6950A2 is secondary.
Inherited radii: {"Control":12,"Card":18,"Sheet / dialog":24}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: Large payout request review strip with stable rupee typography; indigo context headings. Quiet motion role table and paired progress specimens, with haptic and reduced-motion policies underneath. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 120 ms
Content fade | 180 ms
Result reveal | 240 ms
Dialog enter | 280 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Payout request": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "₹2,400.00 · Request review". Ready has a filled primary button "Submit request"; Pending has a neutral disabled/loading button labeled "Sending request…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Request submitted" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Request submitted means awaiting review, not paid.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Sending request…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Code copied successfully | Optional light impact
Request accepted by server | Optional light impact
Balance refresh | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No balance count-up or card zoom
Keep payout status and amount visible
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.
```

## Light — refinement 1

Prompt SHA-256: f0b5e1e20043675e9fbe46d29dd1fd313f1bab33b7048859f888e380137addfc. Original final newline: False.

```text
Use case: precise-object-edit. Input image 1 is the C05 board to refine. Input image 2 is the approved C01 light identity reference. Correct ONLY the timing curve and canonical primary identity: the curve under ease-out · cubic(0.2, 0, 0, 1) must rise STEEPLY from Start then continuously flatten toward End, concave down, with NO shallow-start S-curve. Preserve its size. Filled Submit request button, normal progress arc and primary action/focus accents use EXACT approved royal-blue #2D56C4, NOT electric #2563EB or #0047FF; white text on button. Indigo context #6950A2, body #192840, muted #61708B. Preserve all text, rupee amount, panels, motion role values, layout and semantics. Premium Storybook board, full uncropped landscape image, no sidebar. This is a correction of a documentary design proposal, not a runtime screen. Keep everything else unchanged.
```

## Dark — initial generation

Prompt SHA-256: 61ca24ca9274b9c1af28c1bedbd671d2e7ccb82ad23d4b0adc23ea0f26189323. Original final newline: False.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Sales Associate — dark theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 dark theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Sales Associate" and "Dark" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Calm financial trust; contained opacity changes and static monetary figures. Indigo payout context, blue actions. Inter 600/500/400.
Palette exact specification: {"primary":"#96B4FF","onPrimary":"#142241","support":"#C0ADE7","supportLabel":"Supporting indigo","canvas":"#090B11","surface":"#131722","raised":"#1E2533","text":"#F2F5FC","muted":"#B9C5DD","border":"#354259","strongBorder":"#8393B2","selected":"#1B2C50","focus":"#96B4FF"}.
Status colors exact pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#1A2B4C","text":"#B2C8FF"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #96B4FF with text and embedded icons #142241; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #090B11 with dark-grey #131722/#1E2533 panels, no pale large areas or neon/glow. Light canvas #090B11, clean #131722 cards. Supporting Supporting indigo #C0ADE7 is secondary.
Inherited radii: {"Control":12,"Card":18,"Sheet / dialog":24}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: Large payout request review strip with stable rupee typography; indigo context headings. Quiet motion role table and paired progress specimens, with haptic and reduced-motion policies underneath. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 120 ms
Content fade | 180 ms
Result reveal | 240 ms
Dialog enter | 280 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Payout request": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "₹2,400.00 · Request review". Ready has a filled primary button "Submit request"; Pending has a neutral disabled/loading button labeled "Sending request…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Request submitted" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Request submitted means awaiting review, not paid.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Sending request…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Code copied successfully | Optional light impact
Request accepted by server | Optional light impact
Balance refresh | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
No balance count-up or card zoom
Keep payout status and amount visible
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.

Input image 2 is the selected C05 LIGHT board for this app: use its exact corrected panel structure, action/state copy, role table and haptic mapping as a content/layout reference. Change the entire board to Input image 1's APPROVED DARK palette. Remove every light canvas/card fill, retain black/dark-grey surfaces throughout. No product photos, prices except the specified associate amount, or extra stock data. Any curve drawing rises steeply then flattens, no S-curve.  Buttons use the specified pale primary with DARK onPrimary text, never white on pale button. Keep Proposal status.
```

