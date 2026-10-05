# Agrimore Admin — C10 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: 4f4e840777af2e4ce0f905b6b8d746cea81db562e0a353fe719edfb616ffed04. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Admin" and LIGHT theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Professional institutional blue with cyan and steel/slate support.
Exact palette roles: {"primary":"#1D4F91","onPrimary":"#FFFFFF","support":"#087E8B","supportLabel":"Supporting cyan","canvas":"#F5F7FB","surface":"#FFFFFF","raised":"#F9FBFE","text":"#14243B","muted":"#5B6B82","border":"#D8E1EF","strongBorder":"#8C9DB5","selected":"#E8EFF8","focus":"#1D4F91"}.
Exact status roles: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E8F0FA","text":"#24528C"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 600/500/400, hierarchy 32/24/18/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 8/12/16; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Structured professional-blue editor, compact cyan section cues and tab-aware error routing.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Editor inputs" — Fields Product name, Category dropdown, Sale price with ₹ prefix. Compact tabs Basic info, Images, Delivery. Visible labels and required markers. No sidebar.
2. "Helpful inline errors" — Product name empty: Enter a product name. Category unselected: Choose a category. Focus Product name; cyan only section guidance, errors use locked error colors.
3. "Cross-section summary" — Title Check product details. Exactly two linked items Basic info / Product name — Enter a product name; Basic info / Category — Choose a category. Additional small routing note Image errors open Images tab (not an active third error).
4. "First invalid focus" — Save product → Validate → Open Basic info → Focus Product name. Reveal the correct tab before focus. Include dropdowns and image controls. Preserve unsaved edits.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Light theme calm neutral canvas and white surfaces; strong dark body text. Primary controls use exact primary and white onPrimary.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
```

## Light — refinement 1

Prompt SHA-256: 6e1e4c7adfaebe71dfd0960dd81f1de67650c45fbbea8645556e96c37a8e516f. Original final newline: False.

```text
Correct this existing C10 LIGHT board, preserve layout and institutional blue/cyan C01 identity. Remove ALL numeric price values/hints (120.00, 250.00 etc), use muted empty 'Enter sale price'. Replace every pricing helper about inclusive taxes with 'Set a valid sale price'. Product images are REQUIRED; replace '(optional)' with '(required)'. Remove invented 'up to 5 images', 'up to 5 MB' and file-size limits entirely, replace with 'Add at least one product image'. Keep existing exact two errors Product name — Enter a product name; Category — Choose a category, summary items and tab routing. Image routing note is guidance not an active third error. Do not add arbitrary limits, data, amounts, success marks or sidebar.
```

## Dark — initial generation

Prompt SHA-256: 1f4b7b08c2c17cea1a579a2707e64c91680d86327d6d1a62c726757e42e1775e. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Admin" and DARK theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Professional institutional blue with cyan and steel/slate support.
Exact palette roles: {"primary":"#93B3EC","onPrimary":"#0D203E","support":"#7BCBD5","supportLabel":"Supporting cyan","canvas":"#080B10","surface":"#121922","raised":"#1D2837","text":"#F2F6FC","muted":"#B5C3D6","border":"#314157","strongBorder":"#74869E","selected":"#192E4A","focus":"#93B3EC"}.
Exact status roles: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#172A42","text":"#AFCCF6"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 600/500/400, hierarchy 32/24/18/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 8/12/16; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Structured professional-blue editor, compact cyan section cues and tab-aware error routing.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Editor inputs" — Fields Product name, Category dropdown, Sale price with ₹ prefix. Compact tabs Basic info, Images, Delivery. Visible labels and required markers. No sidebar.
2. "Helpful inline errors" — Product name empty: Enter a product name. Category unselected: Choose a category. Focus Product name; cyan only section guidance, errors use locked error colors.
3. "Cross-section summary" — Title Check product details. Exactly two linked items Basic info / Product name — Enter a product name; Basic info / Category — Choose a category. Additional small routing note Image errors open Images tab (not an active third error).
4. "First invalid focus" — Save product → Validate → Open Basic info → Focus Product name. Reveal the correct tab before focus. Include dropdowns and image controls. Preserve unsaved edits.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Dark theme strictly near-black canvas, dark-grey neutral surfaces, never white panels or navy saturated slabs. Pale primary filled controls MUST use specified dark onPrimary text; secondary labels remain role-correct.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
PAIR INSTRUCTIONS: Reference 1 is approved C01 DARK palette, authoritative for all colors. Reference 2 is selected refined C10 LIGHT board; match its composition and EXACT labels/error wording. Seller Sale price/Stock quantity REQUIRED FOR PUBLISH, never optional; keep draft distinction. Admin product images REQUIRED, no invented image-count/size/tax rules. Sales Associate one empty focused amount with matching summary error, separate above-balance explanatory card and separate payout-account prerequisite, no approval/settlement controls. All prices/amount inputs use empty hints, NO numeric amounts whatsoever. Near-black canvas and dark-grey neutral panels. Every pale primary filled action MUST use specified DARK onPrimary foreground, never white labels. Do not add new rules, new palette colors or success marks.
```

