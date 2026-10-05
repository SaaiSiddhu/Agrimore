# Agrimore Marketplace — C10 exact generation prompts

Built-in image_gen. **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION.** Fenced text preserves exact prompts. If Original final newline is false, omit the separator newline before the closing fence when reproducing the hash.

## Light — initial generation

Prompt SHA-256: b29e24e9e7e4a63d76f6f04ec56df12aaab9f12c2941d213e63bcdd11207df41. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Marketplace" and LIGHT theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Professional green with warm gold and natural stone support.
Exact palette roles: {"primary":"#087A4B","onPrimary":"#FFFFFF","support":"#9A6826","supportLabel":"Warm gold","canvas":"#F7F9F6","surface":"#FFFFFF","raised":"#FBFCF9","text":"#1A2C21","muted":"#5D7062","border":"#DAE4DB","strongBorder":"#91A594","selected":"#E5F3E9","focus":"#087A4B"}.
Exact status roles: [{"role":"Success","container":"#E7F5ED","text":"#146C43"},{"role":"Warning","container":"#FFF4D6","text":"#805400"},{"role":"Error","container":"#FDECEA","text":"#B42318"},{"role":"Info","container":"#E7F2EC","text":"#286B4D"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 700/600/400, hierarchy 36/26/20/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 12/16/24; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Welcoming address form, clear regional dependencies and generous helper text.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Address inputs" — Fields: Recipient name, Mobile number, PIN code, Landmark (optional). Use empty input hints; helper Mobile number: Use 10 digits. PIN code: Use 6 digits. No personal data.
2. "Helpful inline errors" — Mobile number field empty, error Enter a 10-digit mobile number. PIN code field empty, error Enter a 6-digit PIN code. Show focus on Mobile number with visible outline.
3. "Error summary" — Title Check your address. Exactly two linked items: Mobile number — Enter a 10-digit mobile number; PIN code — Enter a 6-digit PIN code. Preserve other entries.
4. "First invalid focus" — Save address → Validate → Reveal Mobile number → Focus. Failed submit keeps values. Fix one error at a time. Location eligibility is a separate check.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Light theme calm neutral canvas and white surfaces; strong dark body text. Primary controls use exact primary and white onPrimary.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
```

## Dark — initial generation

Prompt SHA-256: 3c7cf45f9eb3e6aff9c868b287729aa4c1f1152748f2368465a8ffaf9a49de00. Original final newline: False.

```text
Create a polished premium Storybook design-system board as a landscape 1536x1024 raster image. App heading "Agrimore Marketplace" and DARK theme chip; subtitle "Fields, validation and error summaries". Foundation "C10 · Target design". No sidebar, browser chrome, phone mockup shell, logos, photography or oversized empty space. Full canvas with four meticulously aligned spacious numbered panels, 2x2 grid, subtle borders, readable text and field specimens. Interpret the attached C01 image as the authoritative app identity; match its type character, surfaces, accents and premium quality. This is a static design proposal.
Identity: Professional green with warm gold and natural stone support.
Exact palette roles: {"primary":"#67D2A1","onPrimary":"#0B291D","support":"#DDB97A","supportLabel":"Warm gold","canvas":"#090C0A","surface":"#141A16","raised":"#1E2721","text":"#F2F7F3","muted":"#B9C9BD","border":"#344338","strongBorder":"#798F7E","selected":"#163325","focus":"#67D2A1"}.
Exact status roles: [{"role":"Success","container":"#102C20","text":"#8DE0B0"},{"role":"Warning","container":"#302612","text":"#F1CE7B"},{"role":"Error","container":"#341B1B","text":"#FFA39C"},{"role":"Info","container":"#173126","text":"#A1D8B9"}]. Use Error container and text for inline validation and summaries, not the primary brand color. Focus remains distinguishable from error via a visible ring and textual message.
Type: Inter, weights 700/600/400, hierarchy 36/26/20/16/14/12. Spacing 4/8/12/16/24/32; Control/Card/Sheet radii 12/16/24; 1px default border, 2px focus. Suggested comfortable 48px hit areas; do not crowd helper text.
Domain character: Welcoming address form, clear regional dependencies and generous helper text.
Panel content (shorten secondary explanations if needed, preserve all labels and error correspondence):
1. "Address inputs" — Fields: Recipient name, Mobile number, PIN code, Landmark (optional). Use empty input hints; helper Mobile number: Use 10 digits. PIN code: Use 6 digits. No personal data.
2. "Helpful inline errors" — Mobile number field empty, error Enter a 10-digit mobile number. PIN code field empty, error Enter a 6-digit PIN code. Show focus on Mobile number with visible outline.
3. "Error summary" — Title Check your address. Exactly two linked items: Mobile number — Enter a 10-digit mobile number; PIN code — Enter a 6-digit PIN code. Preserve other entries.
4. "First invalid focus" — Save address → Validate → Reveal Mobile number → Focus. Failed submit keeps values. Fix one error at a time. Location eligibility is a separate check.
Show persistent labels above fields, optional markers written explicitly, empty input hints in muted color, clear unit/prefix anatomy, helpful plain-language error text and underlined summary links. First-invalid diagram should show logical order and one focused field, not every field focused. State cards are independent examples, not a live transaction. Errors appear after interaction/submit; do not make every untouched field red. Small footer: "C10 · Proposed system · Preserve entries · Reveal then focus". Maintain large readable fonts with crisp English text.
Dark theme strictly near-black canvas, dark-grey neutral surfaces, never white panels or navy saturated slabs. Pale primary filled controls MUST use specified dark onPrimary text; secondary labels remain role-correct.
No personal data, no real or invented phone numbers/addresses/OTP digits/account IDs, no numeric financial amounts, no success marks suggesting saved/payment/delivery confirmation. Focus routing and accessible behavior are target annotations, not claims of runtime implementation. Produce one complete board only.
PAIR INSTRUCTIONS: Reference 1 is approved C01 DARK palette, authoritative for all colors. Reference 2 is selected C10 LIGHT layout/content. Match the C10 light composition, app-specific typography, panel labels and error/summary wording, reinterpreted in exact dark roles. Near-black canvas and dark-grey panels. Primary pale-filled controls use DARK onPrimary foreground, never white labels. Keep code cells empty. No new numerical amounts, rules or success marks.
```

