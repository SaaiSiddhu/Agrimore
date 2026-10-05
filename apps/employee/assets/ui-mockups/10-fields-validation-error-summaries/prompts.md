# Agrimore Sales Associate — C10 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: 37a06c0d5be03506a86b693953d443c6d666fb93772fe6be31ed242d777d7696. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Sales Associate" and LIGHT theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Premium royal blue with muted indigo, pearl and slate support.
Exact palette roles: {"primary":"#2D56C4","onPrimary":"#FFFFFF","support":"#6950A2","supportLabel":"Supporting indigo","canvas":"#F7F8FC","surface":"#FFFFFF","raised":"#FBFCFF","text":"#192840","muted":"#61708B","border":"#DDE3F0","strongBorder":"#94A0B7","selected":"#EAF0FE","focus":"#2D56C4"}.
Exact status roles: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#EDF1FB","text":"#31549E"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 600/500/400, hierarchy 34/24/18/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 12/18/24; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Premium royal-blue payout form with indigo guidance, masked destination and deliberate money hierarchy.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Payout inputs" — Field Payout amount with ₹ prefix, empty hint Enter amount, helper Enter a whole-rupee amount within your available balance. Separate destination card Masked payout account; no invented IDs, balances or amounts.
2. "Helpful inline errors" — Payout amount empty with error Enter a payout amount greater than zero. Separate explanatory specimen Amount exceeds available balance — Enter an amount within your available balance. Show these as alternate states, not simultaneous errors.
3. "Error summary" — Title Check payout amount. One linked item Payout amount — Enter a payout amount greater than zero. Separate prerequisite callout Payout account required and enabled Add payout account action.
4. "First invalid focus" — Review payout → Validate → Reveal Payout amount → Focus. Preserve entry. Valid input opens review. Request approval and settlement are separate.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Light theme calm neutral canvas and white surfaces; strong dark body text. Primary controls use exact primary and white onPrimary.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
```

## Light — refinement 1

Prompt SHA-256: d9f096bd30dd0f9660180096db43c1bd5ed15542fd8182dc6c23d42ac91bca1e. Original final newline: False.

```text
Correct this C10 LIGHT board, keep premium royal-blue/indigo identity and four-panel grid. Remove every numeric amount example including 12,000. Panel2 shows TWO CLEARLY ALTERNATIVE STATE specimens: 'Empty amount' input hint Enter amount + error Enter a payout amount greater than zero; 'Above available balance' show a textual explanatory card (NOT an input containing a number): Amount exceeds available balance / Enter an amount within your available balance. Panel4 first-invalid specimen must show EMPTY Payout amount input hint Enter amount, visible focus ring, error EXACTLY Enter a payout amount greater than zero, matching panel3 single summary link. Change 'Payout account required and enabled' to 'Payout account required'. Keep enabled Add payout account action and masked example card as separate state examples. Remove Request approval and Settlement button-looking controls; use a small plain-text sentence 'Valid input opens review. Approval and settlement are separate stages.' Keep Review payout primary. No amounts, balances, real account IDs or fabricated financial completion. Preserve whole-rupee guidance and footer.
```

## Dark — initial generation

Prompt SHA-256: 111a2f1bed5fec816e28754c335da566f0fd21bca2f90a3ce03783cfd6e84fce. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Sales Associate" and DARK theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Premium royal blue with muted indigo, pearl and slate support.
Exact palette roles: {"primary":"#96B4FF","onPrimary":"#142241","support":"#C0ADE7","supportLabel":"Supporting indigo","canvas":"#090B11","surface":"#131722","raised":"#1E2533","text":"#F2F5FC","muted":"#B9C5DD","border":"#354259","strongBorder":"#8393B2","selected":"#1B2C50","focus":"#96B4FF"}.
Exact status roles: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#1A2B4C","text":"#B2C8FF"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 600/500/400, hierarchy 34/24/18/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 12/18/24; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Premium royal-blue payout form with indigo guidance, masked destination and deliberate money hierarchy.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Payout inputs" — Field Payout amount with ₹ prefix, empty hint Enter amount, helper Enter a whole-rupee amount within your available balance. Separate destination card Masked payout account; no invented IDs, balances or amounts.
2. "Helpful inline errors" — Payout amount empty with error Enter a payout amount greater than zero. Separate explanatory specimen Amount exceeds available balance — Enter an amount within your available balance. Show these as alternate states, not simultaneous errors.
3. "Error summary" — Title Check payout amount. One linked item Payout amount — Enter a payout amount greater than zero. Separate prerequisite callout Payout account required and enabled Add payout account action.
4. "First invalid focus" — Review payout → Validate → Reveal Payout amount → Focus. Preserve entry. Valid input opens review. Request approval and settlement are separate.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Dark theme strictly near-black canvas, dark-grey neutral surfaces, never white panels or navy saturated slabs. Pale primary filled controls MUST use specified dark onPrimary text; secondary labels remain role-correct.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
PAIR INSTRUCTIONS: Reference 1 is approved C01 DARK palette, authoritative for all colors. Reference 2 is selected refined C10 LIGHT board; match its composition and EXACT labels/error wording. Seller Sale price/Stock quantity REQUIRED FOR PUBLISH, never optional; keep draft distinction. Admin product images REQUIRED, no invented image-count/size/tax rules. Sales Associate one empty focused amount with matching summary error, separate above-balance explanatory card and separate payout-account prerequisite, no approval/settlement controls. All prices/amount inputs use empty hints, NO numeric amounts whatsoever. Near-black canvas and dark-grey neutral panels. Every pale primary filled action MUST use specified DARK onPrimary foreground, never white labels. Do not add new rules, new palette colors or success marks.
```

