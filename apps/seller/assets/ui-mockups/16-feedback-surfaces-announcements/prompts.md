# Agrimore Seller — C16 exact image prompts

Built-in image_gen; **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**. Exact fenced prompts and reference inputs recorded for every selected generation stage. For a false Original final newline, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: efd4e59e84a8473ff0e11523e9d5d05d4db9b0ca398e6d44553e5881824067a0. Original final newline: False.

Inputs:

- /Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-light.png · SHA-256 04d17f7ec077a040e8689bea57f1cc678d3b24ee0bd4a7f9be4717b5a848185c

```text
Use case: ui-mockup
Asset: Agrimore C16 premium Storybook board, Agrimore Seller / LIGHT, full landscape image approximately 1536 x 1024.
Reference image 1 is APPROVED C01 light identity ONLY. Inherit its palette, Inter hierarchy, spacing, radius, border and understated elevation. Create a NEW feedback design board, not a token table. Full canvas, NO sidebar or device/browser chrome.
Heading exactly "Agrimore Seller"; small "Light" theme chip. Subtitle exactly "Feedback surfaces and announcements". Small "C16 / Design proposal". Four generous labelled panels in a 2x2 grid: Transient toast, Inline notice, Persistent banner, Accessible updates. Premium restrained editorial style, sharp readable text, simple outline icons. Domain character: Blue-teal operational feedback, copper guidance, compact cool-neutral surfaces and footer-aware floating toasts.
Locked palette {"primary": "#0B6A80", "onPrimary": "#FFFFFF", "support": "#9B5E3D", "supportLabel": "Warm copper", "canvas": "#F5F8F9", "surface": "#FFFFFF", "raised": "#F9FCFD", "text": "#142A34", "muted": "#56717E", "border": "#D5E3E8", "strongBorder": "#879EAA", "selected": "#E5F2F5", "focus": "#0B6A80"}; semantic status pairs [{"role": "Success", "container": "#E7F5ED", "text": "#146C43"}, {"role": "Warning", "container": "#FFF4D6", "text": "#805400"}, {"role": "Error", "container": "#FDECEA", "text": "#B42318"}, {"role": "Info", "container": "#E6F3F7", "text": "#17647B"}]. Maintain app-specific brand and support colors, never apply green as primary to all apps. Toast uses neutral app surfaces, app-primary accent and small status icon; notices use restrained status container/tone. Secondary actions OUTLINED with neutral surface fill and primary border/text. Any filled primary action must have onPrimary inverse text. Dark boards use neutral near-black canvas and dark-grey cards, no white cards or saturated blue/green washes. Support colors are context, not a rival primary.
Inter scale [32, 24, 18, 16, 14, 12], weights [600, 500, 400]; spacing [4, 8, 12, 16, 24, 32]px; radius roles {"Control": 10, "Card": 14, "Sheet / dialog": 20}px; 1px borders, 2px focus, comfortable labelled 48px action/dismiss targets. No tiny dense text.
Exact panel content:
1. Transient toast: Floating blue-teal neutral-surface toast "Stock updated" with success icon and labelled "Dismiss" secondary text control. Caption "Sample confirmed response". Small note "Above sticky actions". Do not show stock numbers or Undo.
2. Inline notice: Stock-sheet notice with error icon, heading "Stock couldn’t be saved", body "Your entered value is still here." Nearby empty field labelled "Stock quantity". Small note "Review before resubmitting". No automatic Retry mutation or cleared input.
3. Persistent banner: Warning banner "Store paused", body "Ordering is paused for your store." OUTLINED blue-teal action "Resume store". Copper board note "Wait for confirmation before clearing". No fake countdown, end date or dismiss X.
4. Accessible updates: Explicit "Announcement design" area. Quoted sample "Stock updated" with small speaker icon. Rule rows "One update per saved change", "Keep focus in context", "Reduced motion: static feedback". Copper annotation "Announce only meaningful changes".
Critical: four panels are independent illustrative specimens. Success and failure are separate sample outcomes, never simultaneous live state. Accessible updates panel is a proposed announcement specification, not an actual screen-reader transcript or certification. Do not invent Undo, Retry mutations, backend actions or dismissal of unresolved conditions. Preserve supported actions only. A confirmed request/upload/case update does not mean approved, paid, delivered, ordered or reconciled. Toast cannot replace persistent feedback. Include text and icon cues, no color-only meaning, no focus stealing.
No PII, IDs, names, email, phone, address, account details, prices, rupee amounts, stock/quantity values, timers, timestamps, counts, ETA or guarantees. No screenshots claiming live data. Only synthetic samples and explicitly confirmed-response examples.
Footer exactly "Illustrative feedback / Target design / C01 identity". No sidebar, watermark, fake metrics, gradients or unrelated typography/token charts.
```

## Light — refinement 1

Prompt SHA-256: 13ce84a35de993679461089a67def9e5b3b82fff32396c6ea0434f7b03ae593d. Original final newline: False.

Inputs:

- /Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-052bf374-cbb5-48cf-86f8-55d99a280fee.png · SHA-256 c3c9dbc9217ef5a6a8d64bb9828d7ff900dee45427a68790bd129ec09cd259f3

```text
Refine this existing C16 Seller light Storybook board. Change ONLY the top-left toast context below the floating toast: remove the invented Home / Products / Orders / More navigation icons and labels. Replace them with a quiet neutral sticky-action placeholder strip labelled exactly 'Sticky actions' in muted small text; this is a board context annotation, not a new product control. Preserve the toast, Dismiss, all four panels, exact messages, Resume store outlined action, sample labels, palette and footer. No other additions.
```

## Dark — initial generation

Prompt SHA-256: db4a88eda4c228b0d3bbe3c4a8f280f3bb37eac3f73e532dfa597a8586796f71. Original final newline: False.

Inputs:

- /Users/saai_siddharth/Projects/Clients/Agrimore/apps/seller/assets/ui-mockups/01-color-roles-theme-identity/agrimore-seller-design-tokens-dark.png · SHA-256 2608e9115e73f8ff7bf1a06e5921757fd488f0c4f3e0b6a219271b0e5d01de90
- /Users/saai_siddharth/.codex/generated_images/01a0fa3d-dc7c-79e3-9b9f-7818d175628b/exec-f719331c-1739-405a-8469-939b8fc09dda.png · SHA-256 1c39b2836cf579ec7450c903138fea5a64acbc8d301f3feb24374ae03326d579

```text
Use case: ui-mockup
Asset: Agrimore C16 premium Storybook board, Agrimore Seller / DARK, full landscape image approximately 1536 x 1024.
Reference image 1 is APPROVED C01 dark identity ONLY. Inherit its palette, Inter hierarchy, spacing, radius, border and understated elevation. Create a NEW feedback design board, not a token table. Full canvas, NO sidebar or device/browser chrome.
Heading exactly "Agrimore Seller"; small "Dark" theme chip. Subtitle exactly "Feedback surfaces and announcements". Small "C16 / Design proposal". Four generous labelled panels in a 2x2 grid: Transient toast, Inline notice, Persistent banner, Accessible updates. Premium restrained editorial style, sharp readable text, simple outline icons. Domain character: Blue-teal operational feedback, copper guidance, compact cool-neutral surfaces and footer-aware floating toasts.
Locked palette {"primary": "#70D0DF", "onPrimary": "#0B2831", "support": "#DAAE8C", "supportLabel": "Warm copper", "canvas": "#080C0F", "surface": "#11191E", "raised": "#1B262D", "text": "#F1F7FA", "muted": "#B5C9D1", "border": "#33464F", "strongBorder": "#7895A2", "selected": "#14313A", "focus": "#70D0DF"}; semantic status pairs [{"role": "Success", "container": "#102C20", "text": "#8DE0B0"}, {"role": "Warning", "container": "#302612", "text": "#F1CE7B"}, {"role": "Error", "container": "#341B1B", "text": "#FFA39C"}, {"role": "Info", "container": "#142D37", "text": "#9BD9E9"}]. Maintain app-specific brand and support colors, never apply green as primary to all apps. Toast uses neutral app surfaces, app-primary accent and small status icon; notices use restrained status container/tone. Secondary actions OUTLINED with neutral surface fill and primary border/text. Any filled primary action must have onPrimary inverse text. Dark boards use neutral near-black canvas and dark-grey cards, no white cards or saturated blue/green washes. Support colors are context, not a rival primary.
Inter scale [32, 24, 18, 16, 14, 12], weights [600, 500, 400]; spacing [4, 8, 12, 16, 24, 32]px; radius roles {"Control": 10, "Card": 14, "Sheet / dialog": 20}px; 1px borders, 2px focus, comfortable labelled 48px action/dismiss targets. No tiny dense text.
Exact panel content:
1. Transient toast: Floating blue-teal neutral-surface toast "Stock updated" with success icon and labelled "Dismiss" secondary text control. Caption "Sample confirmed response". Small note "Above sticky actions". Do not show stock numbers or Undo.
2. Inline notice: Stock-sheet notice with error icon, heading "Stock couldn’t be saved", body "Your entered value is still here." Nearby empty field labelled "Stock quantity". Small note "Review before resubmitting". No automatic Retry mutation or cleared input.
3. Persistent banner: Warning banner "Store paused", body "Ordering is paused for your store." OUTLINED blue-teal action "Resume store". Copper board note "Wait for confirmation before clearing". No fake countdown, end date or dismiss X.
4. Accessible updates: Explicit "Announcement design" area. Quoted sample "Stock updated" with small speaker icon. Rule rows "One update per saved change", "Keep focus in context", "Reduced motion: static feedback". Copper annotation "Announce only meaningful changes".
Critical: four panels are independent illustrative specimens. Success and failure are separate sample outcomes, never simultaneous live state. Accessible updates panel is a proposed announcement specification, not an actual screen-reader transcript or certification. Do not invent Undo, Retry mutations, backend actions or dismissal of unresolved conditions. Preserve supported actions only. A confirmed request/upload/case update does not mean approved, paid, delivered, ordered or reconciled. Toast cannot replace persistent feedback. Include text and icon cues, no color-only meaning, no focus stealing.
No PII, IDs, names, email, phone, address, account details, prices, rupee amounts, stock/quantity values, timers, timestamps, counts, ETA or guarantees. No screenshots claiming live data. Only synthetic samples and explicitly confirmed-response examples.
Footer exactly "Illustrative feedback / Target design / C01 identity". No sidebar, watermark, fake metrics, gradients or unrelated typography/token charts.
Additional reference image 2 is the SELECTED C16 LIGHT board: inherit its four-panel composition and selected wording ONLY, including refinements. Image 1 is the authoritative DARK palette. Transform all white/light specimen surfaces to near-black/dark-grey with light readable text; keep dark status pairs, no saturated card washes. Toast and notice are dark surfaces, status icon may use its status pair. All secondary actions including Resume store, Cancel request and Retry photo upload remain OUTLINED, transparent dark-surface fill, app-primary label/border; pending label muted. Never use a pale filled button with white text. Preserve revised 'Sample submission failure' and 'Values omitted in this specimen' for Sales Associate. Seller has only a muted Sticky actions context strip, NO navigation icons or destinations; add small 'Values omitted in this specimen' below its empty Stock quantity field. No tagline, leaf footer logo or promotional slogan. All four panels remain independent sample variants.
```

