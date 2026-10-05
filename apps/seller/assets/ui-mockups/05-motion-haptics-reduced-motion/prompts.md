# Agrimore Seller — C05 exact generation prompts

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Generated using built-in image_gen. C01 inputs are identity references. Each fenced block preserves the exact original text; omit its added separator newline if Original final newline is false.

## Light — initial generation

Prompt SHA-256: 0b6889cb9e884fbb233709bce3393ee445b03205b70d77cecd53debe815f5442. Original final newline: True.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Seller — light theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 light theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Seller" and "Light" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Efficient inventory and quotation workspace; retain SellerMotion vocabulary, gentle fades and anchored sheets. Inter 600/500/400.
Palette exact specification: {"primary":"#0B6A80","onPrimary":"#FFFFFF","support":"#9B5E3D","supportLabel":"Warm copper","canvas":"#F5F8F9","surface":"#FFFFFF","raised":"#F9FCFD","text":"#142A34","muted":"#56717E","border":"#D5E3E8","strongBorder":"#879EAA","selected":"#E5F2F5","focus":"#0B6A80"}.
Status colors exact pairs: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E6F3F7","text":"#17647B"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #0B6A80 with text and embedded icons #FFFFFF; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #F5F8F9 with dark-grey #FFFFFF/#F9FCFD panels, no pale large areas or neon/glow. Light canvas #F5F8F9, clean #FFFFFF cards. Supporting Warm copper #9B5E3D is secondary.
Inherited radii: {"Control":10,"Card":14,"Sheet / dialog":20}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: Inventory stock editor storyboard as the dominant middle row, copper context captions; compact motion table left, progress comparison right, policy panels below. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 120 ms
Content fade | 200 ms
Result reveal | 200 ms
Sheet enter | 320 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Stock update": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Fresh tomatoes · 250 packs". Ready has a filled primary button "Save stock"; Pending has a neutral disabled/loading button labeled "Saving stock…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Stock updated" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Show confirmation after the stock update succeeds.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Saving stock…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Catalogue selection | Selection click
Stock update confirmed | Optional light impact
Background sync | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
Static skeleton; no pulse or ripple
Keep values and validation visible
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.
```

## Light — refinement 1

Prompt SHA-256: 4f569f34a36986e964ba0bbaef913f53dde6eb83f9fc1b0db6e6ce59626c95d3. Original final newline: False.

```text
Use case: precise-object-edit. Input image 1 is the C05 board to refine. Input image 2 is the approved C01 light identity reference. Change ONLY the Stock update storyboard product content: remove all three tomato photo thumbnails. Keep the exact Fresh tomatoes name, 250 packs, stock quantity 250 and all existing button/state labels. Use a tiny outline package icon or whitespace instead of photos. Keep copper #9B5E3D in the stock context heading/accent. Preserve every other panel, duration, text and layout. Premium Storybook board, full uncropped landscape image, no sidebar. This is a correction of a documentary design proposal, not a runtime screen. Keep everything else unchanged.
```

## Dark — initial generation

Prompt SHA-256: 27890e9459dcfd6d0fc99684d26521fddf0a8ce99ee69adc67d0ac90882bfef4. Original final newline: False.

```text
Use case: ui-mockup
Asset type: C05 premium Storybook-style design reference board, one complete landscape 16:10 image.
Primary request: Create Agrimore Seller — dark theme, showing Motion, haptics and reduced motion. A beautiful, legible full-bleed design-system board, no sidebar.
Input image 1 is the APPROVED C01 dark theme reference for this app. It is an identity reference, not an edit target. Inherit its colors, Inter type personality, thin borders, spacing and radii; replace all old panels with C05 panels. Do not repeat color swatches, typography alphabets or icon catalog.
Header ONLY "Agrimore Seller" and "Dark" pill. Subtitle "Motion, haptics & reduced motion". Small badge "C05 · Proposal".
App personality: Efficient inventory and quotation workspace; retain SellerMotion vocabulary, gentle fades and anchored sheets. Inter 600/500/400.
Palette exact specification: {"primary":"#70D0DF","onPrimary":"#0B2831","support":"#DAAE8C","supportLabel":"Warm copper","canvas":"#080C0F","surface":"#11191E","raised":"#1B262D","text":"#F1F7FA","muted":"#B5C9D1","border":"#33464F","strongBorder":"#7895A2","selected":"#14313A","focus":"#70D0DF"}.
Status colors exact pairs: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#142D37","text":"#9BD9E9"}]. Confirmation check + text uses Success pair only after result; progress stays neutral/primary. Supporting colors are context, not success. Filled primary buttons ALWAYS background #70D0DF with text and embedded icons #0B2831; in dark mode never put pale/white lettering on pale primary buttons. Dark background is near-black #080C0F with dark-grey #11191E/#1B262D panels, no pale large areas or neon/glow. Light canvas #080C0F, clean #11191E cards. Supporting Warm copper #DAAE8C is secondary.
Inherited radii: {"Control":10,"Card":14,"Sheet / dialog":20}, spacing scale [4,8,12,16,24,32] logical px; border widths {"default":1,"strong":1,"focus":2}. Use comfortable targets consistent with previous C04: minimum 48 px, delivery critical actions 56 px, Sales Associate primary height 52 px. These are logical UI proportions, not raster-pixel measurements.
Composition: Inventory stock editor storyboard as the dominant middle row, copper context captions; compact motion table left, progress comparison right, policy panels below. Fit FIVE clear panels. Large clean heading, precise line icons, ample whitespace, no clipping or tiny unreadable copy. Keep app-specific structure, consistent theme pair content.
Panel 1 "Motion roles": show a compact table EXACT rows:
Press state | 120 ms
Content fade | 200 ms
Result reveal | 200 ms
Sheet enter | 320 ms
Reduced motion | 0 ms
Below table exact text "ease-out · cubic(0.2, 0, 0, 1)". A small smooth ease-out curve diagram uses abstract start/end with no invented axes, durations or bounce. Small caption "Visual duration only".
Panel 2 "Stock update": three anchored UI snapshots left-to-right with EXACT column captions Ready, Pending, Confirmed. Each retains exact entity "Fresh tomatoes · 250 packs". Ready has a filled primary button "Save stock"; Pending has a neutral disabled/loading button labeled "Saving stock…" with a small ring snapshot; Confirmed has a static Success-colored check and label "Stock updated" in a quiet status container. Snapshot widths and typography stay stable; long pending text wraps as needed. Only lightweight arrows between frames, never on top of controls. Captions below arrows "Request starts" and "Result arrives"; DO NOT put ms values or network-duration percentages on these transitions. Exact note "Show confirmation after the stock update succeeds.". This is a state storyboard; optional results illustrate a real confirmed outcome, not a promised result. Delivery proof received is separate from order completion; associate request submitted is not paid; admin refresh is not approval. No fake fixed-delay success, fabricated record statuses or numeric progress.
Panel 3 "Progress without motion": TWO side-by-side equal pending specimens labeled "Standard" and "Reduced motion". Standard shows an indeterminate ring snapshot with tiny curved rotation arrow; Reduced motion shows a STATIC hourglass icon without arrows. BOTH show EXACT same text "Saving stock…". Below show plain text "Unknown duration · no percentage". Both remain busy, not success/check/disabled-without-explanation. Static hourglass is a pending symbol, not completion. Preserve clear labels. This is a still-image animation specification, not an animated file.
Panel 4 "Haptic policy": EXACT two-column table "Event" | "Feedback":
Catalogue selection | Selection click
Stock update confirmed | Optional light impact
Background sync | None
Show subtle event dots, NOT audio waveforms or invented vibration timing/strength graphs. Text below EXACTLY "Optional · device supported · user enabled". No repeated pulses, decorative vibration or device-performance claims. Haptics disabled does not disable visible feedback.
Panel 5 "Reduced motion": show small pill "On", four crisp rules EXACTLY:
Instant state changes · 0 ms
Static hourglass + progress text
Static skeleton; no pulse or ripple
Keep values and validation visible
Add simple static UI icon beside each rule. Reduced-motion appearance retains the same actions, text, actual data, focus and status meaning. 0 ms applies visual effects only, not real operations, OTP/offer countdowns, timeouts or backend latency. Reduced motion and haptic preference are separate controls.
Footer EXACTLY "Show progress in text · Confirm the actual result · Haptics are optional".
Avoid: sidebar, app navigation chrome, device/browser frame, watermark, logos, product photos, confetti, particles, large glowing gradients, lorem ipsum, exaggerated blur, bouncing ease curves, success during pending, invented percentages, color-only state, dense microscopic text, technical source paths or implementation code. Render all quoted labels/values legibly and verbatim.

Input image 2 is the selected C05 LIGHT board for this app: use its exact corrected panel structure, action/state copy, role table and haptic mapping as a content/layout reference. Change the entire board to Input image 1's APPROVED DARK palette. Remove every light canvas/card fill, retain black/dark-grey surfaces throughout. No product photos, prices except the specified associate amount, or extra stock data. Any curve drawing rises steeply then flattens, no S-curve.  Buttons use the specified pale primary with DARK onPrimary text, never white on pale button. Keep Proposal status.
```

