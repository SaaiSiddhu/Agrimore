# Agrimore Seller — C10 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: 60ed611a34b7f5fce5fcd7a1c66d2384c8e2428186fc88c7302ffa2078313dd4. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Seller" and LIGHT theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Blue-teal with warm copper and cool neutral support.
Exact palette roles: {"primary":"#0B6A80","onPrimary":"#FFFFFF","support":"#9B5E3D","supportLabel":"Warm copper","canvas":"#F5F8F9","surface":"#FFFFFF","raised":"#F9FCFD","text":"#142A34","muted":"#56717E","border":"#D5E3E8","strongBorder":"#879EAA","selected":"#E5F2F5","focus":"#0B6A80"}.
Exact status roles: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E6F3F7","text":"#17647B"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 600/500/400, hierarchy 32/24/18/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 10/14/20; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Compact blue-teal product editor with copper section cues, units and draft-aware requirements.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Product inputs" — Fields Product name, Sale price with ₹ prefix and helper Set a valid sale price, Stock quantity with units suffix and helper Use a whole-unit count. Copper chip Draft has fewer requirements.
2. "Helpful inline errors" — Product name empty: Enter a product name. Stock quantity empty: Enter a whole-unit stock count. Show first focused Product name. No fake monetary values.
3. "Publish summary" — Title Check before publishing. Exactly two linked errors: Product name — Enter a product name; Stock quantity — Enter a whole-unit stock count. Secondary text Your draft is preserved.
4. "First invalid focus" — Publish → Validate → Reveal Product name → Focus. Draft and publish use different rules. Missing stock stays unknown. Reuse existing field scope.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Light theme calm neutral canvas and white surfaces; strong dark body text. Primary controls use exact primary and white onPrimary.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
```

## Light — refinement 1

Prompt SHA-256: 36c505fcb82eb4ef75263c74b44c96c614fef3e7b26bb4e6a328ab04ed2457d9. Original final newline: False.

```text
Correct this existing C10 LIGHT board, keeping its premium layout, all four panels, C01 blue-teal/copper styling and headings. Critical: Sale price and Stock quantity are required for publish; replace every '(optional)' beside these two labels with '(required for publish)'. Keep the Draft has fewer requirements badge. Replace ALL e.g.120 numeric price hints with 'Enter sale price'; all e.g.0 stock hints with 'Enter stock count'. No numeric monetary values anywhere. Product name is required; use 'Product name (required)' in every specimen. Keep EXACT errors Product name — Enter a product name, Stock quantity — Enter a whole-unit stock count, and summary links matching those errors. Footer and first-invalid routing remain; replace claim 'Subsequent fields show errors after fix' with 'Show all errors; focus the first'. No invented domain limits, no new widgets, no sidebar.
```

## Dark — initial generation

Prompt SHA-256: 8f9457db28801d0e89aebe3cd9c41d07c151114d5dde62a04516610ea95ad2ed. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Seller" and DARK theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Blue-teal with warm copper and cool neutral support.
Exact palette roles: {"primary":"#70D0DF","onPrimary":"#0B2831","support":"#DAAE8C","supportLabel":"Warm copper","canvas":"#080C0F","surface":"#11191E","raised":"#1B262D","text":"#F1F7FA","muted":"#B5C9D1","border":"#33464F","strongBorder":"#7895A2","selected":"#14313A","focus":"#70D0DF"}.
Exact status roles: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#142D37","text":"#9BD9E9"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 600/500/400, hierarchy 32/24/18/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 10/14/20; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Compact blue-teal product editor with copper section cues, units and draft-aware requirements.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Product inputs" — Fields Product name, Sale price with ₹ prefix and helper Set a valid sale price, Stock quantity with units suffix and helper Use a whole-unit count. Copper chip Draft has fewer requirements.
2. "Helpful inline errors" — Product name empty: Enter a product name. Stock quantity empty: Enter a whole-unit stock count. Show first focused Product name. No fake monetary values.
3. "Publish summary" — Title Check before publishing. Exactly two linked errors: Product name — Enter a product name; Stock quantity — Enter a whole-unit stock count. Secondary text Your draft is preserved.
4. "First invalid focus" — Publish → Validate → Reveal Product name → Focus. Draft and publish use different rules. Missing stock stays unknown. Reuse existing field scope.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Dark theme strictly near-black canvas, dark-grey neutral surfaces, never white panels or navy saturated slabs. Pale primary filled controls MUST use specified dark onPrimary text; secondary labels remain role-correct.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
PAIR INSTRUCTIONS: Reference 1 is approved C01 DARK palette, authoritative for all colors. Reference 2 is selected refined C10 LIGHT board; match its composition and EXACT labels/error wording. Seller Sale price/Stock quantity REQUIRED FOR PUBLISH, never optional; keep draft distinction. Admin product images REQUIRED, no invented image-count/size/tax rules. Sales Associate one empty focused amount with matching summary error, separate above-balance explanatory card and separate payout-account prerequisite, no approval/settlement controls. All prices/amount inputs use empty hints, NO numeric amounts whatsoever. Near-black canvas and dark-grey neutral panels. Every pale primary filled action MUST use specified DARK onPrimary foreground, never white labels. Do not add new rules, new palette colors or success marks.
```

