# Agrimore — C24 money, quantity, date and identifier formatting: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C24 is not owner-approved; assets/docs only.

[Ten-board gallery](MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: f88101beab79e2181013af45e61c0898782b14a0. 818 eligible files / 272075 source lines across five app lib trees, three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files excluded. Fresh hashes/marker searches cover formatting helpers, inline precision, dates/timezone calls, units/counts and masks. Focused semantic reads cover shared PriceFormatter/DateFormatter/AgFormat, SellerFormat and order/invoice/stock adoption, DeliveryFormat and money breakdown/offer precision, Associate wrappers/order detail/masks, Marketplace product/cart amounts/quantities, Admin dashboard/order UI/CSV/PDF/payouts, ProductModel stockConfigured/unit labels and backend pricing/count validation. Broad inventory plus focused review is not semantic certification of every line or rendered screen.

Marker totals include comments/call sites and generic toInt/quantity usages, not unique formatters or defect counts. Existing test source was inspected as convention evidence, not executed. No real order, balance, stock, identity, export or production account was read. Formatting proposals do not change financial arithmetic or backend authority. Shared-checkout implementation may advance during this asset task; changes are observed and preserved.

| Scope | numeric_formatter | inline_precision | date_formatter | units | identifier_mask |
| --- | --- | --- | --- | --- | --- |
| admin | 55 | 88 | 23 | 25 | 10 |
| delivery | 55 | 14 | 26 | 22 | 13 |
| employee | 47 | 6 | 2 | 4 | 10 |
| marketplace | 16 | 131 | 19 | 170 | 0 |
| seller | 180 | 40 | 23 | 83 | 14 |
| functions | 3 | 39 | 0 | 148 | 3 |
| agrimore_core | 4 | 48 | 14 | 78 | 0 |
| agrimore_services | 0 | 13 | 0 | 6 | 0 |
| agrimore_ui | 11 | 0 | 6 | 0 | 2 |

## Shared format target contract

1. Formatting is a display contract, never price authority, commission eligibility, payment status, record identity or backend mutation.
2. Use en_IN Indian grouping and INR rupee symbol consistently. Exact transaction/statement/reconciliation values keep required paise; whole/compact views are labelled rounded summaries.
3. Unknown/missing/invalid/non-finite amounts and counts remain unavailable, distinct from a real known zero. Do not invent Free, out of stock or zero balance.
4. Do not parse rendered currency/compact labels into calculation or export inputs. Preserve original typed values and server rounding; validate finite/safe numbers separately.
5. Signed adjustments need visible sign and accessible wording; minus/spacing conventions differ by current helper. Never use color alone to imply debit, credit or settlement.
6. Whole order/stock counts differ from free-form pack labels/physical measurements, record counts, distances and durations. Do not silently convert units or truncate fractional counts.
7. Quantity/count formatting needs singular/plural and known unit; missing unit is not inferred kg/unit. Measured labels do not define stock decrement semantics.
8. Preserve billable distance precision from source; map/offer approximations do not recompute pay. Duration and distance carry their units.
9. Dates require valid source fields and meaning; display locale, timezone, calendar range boundaries and absolute accessible form are explicit decisions. Formatting DateTime alone does not convert timezone.
10. Unknown/invalid/pending/future timestamps do not become Now/Today/zero time; date-only helpers must not fabricate a clock time. Long-lived audit displays need a year.
11. Private summaries use conservative masks, including short/malformed values. Masking is not encryption/access control; legitimate owned editing/full-key lookup remain distinct.
12. Display abbreviation/reference is not a backend ID: retain full keys for routing, deduplication, copy where authorized and machine exports. UI masks do not guarantee exported/logged data privacy.
13. Format samples are independent synthetic values, fixed dates and pure bullet masks. No live amount, metric, stock, personal identifier, payment or availability outcome is asserted.
14. Preserve locked identity and tabular numerals with readable value alignment, labels/units beyond color, text scaling and screen-reader meaning. Runtime locale/precision/timezone/accessibility checks remain future work.

## Existing formatting layers and adoption

| Layer | Observed behavior | Adoption or boundary |
| --- | --- | --- |
| PriceFormatter | en_IN two decimals, integer and compact helpers; direct rupee-symbol prefix; parse removes symbol/commas then double.parse | Associate currency wrapper uses it; Marketplace many inline fixed decimals remain. Numeric/sign/finite validation separate |
| AgFormat | en_IN exact/whole/compact money and grouped counts; d MMM y date; dateTime omits year/lowercases am/pm; partial masks | Modern Admin payout and some Delivery money paths; not uniformly adopted by Admin legacy UI/export |
| SellerFormat | Display money rounds to paise/hides whole decimals; moneyExact two decimals; Unicode minus; whole/compact summaries | Orders/invoices still often use money, so exact-invoice adoption needs correction |
| DeliveryFormat | Exact/optional/whole roles, Unicode minus with space; year/range date helpers, partial masks | Money screens use exact rupees; map/offer distances one decimal versus pay breakdown distance two |
| SaFormatters | PriceFormatter exact currency, d MMM yyyy date only, phone/account masks | Order list/detail adoption exists; missing total zero and quantity fallback/truncation are separate data-quality issues |
| DateFormatter | Multiple date/time patterns and relative-time helpers, no explicit zone conversion | Future difference may satisfy Just now branch; calling a formatter does not validate source meaning |
| Inline UI/export | toStringAsFixed, independent NumberFormat/DateFormat, CSV numeric fields and PDF Rs. text | Display, reconciliation and machine exports need deliberate contracts without parsing rendered labels |

Reuse these layers and their domain adapters during later implementation. Do not create another formatter merely to copy the board. Shared syntax can coexist with per-app density/hierarchy and supported domain precision. A helper comment is not adoption evidence or a missing method implementation.

## Domain-by-domain systems

### Agrimore Marketplace

**Current source:** Shared PriceFormatter supports en_IN two-decimal, whole and compact rupees, but product/cart cards still interpolate rupee symbols with toStringAsFixed across 0/2 decimal variants. Cart quantity selectors and server order inputs are integer counts; ProductModel has optional free-form unit and variant name/weight labels, not universal pack-conversion semantics. Shared DateFormatter has multiple patterns and relative helpers without explicit timezone conversion; future values can become Just now. Profile phone/email readable. Formatting is display only; order pricing remains server authority.

**Target:** Use shared exact transaction formatting, distinguish valid zero from unavailable, keep order counts separate from pack measurements, propose explicit-zone timestamps and summary masking without changing order IDs or calculating prices from rounded labels.

| Panel | Domain specimen |
| --- | --- |
| Shopper currency precision | Card "Currency examples", rows "Exact amount" = "₹1,23,456.78", "Known zero" = "₹0.00", "Unknown amount" = "Amount unavailable". Right-aligned tabular values. Gold BOARD note "Two decimals for transaction amounts". These are FORMAT EXAMPLES, not cart/payment totals; no Pay/Free/success/balance. |
| Counts and pack labels | Card "Quantity examples", rows "Order quantity" = "2 units", "Pack label" = "2.5 kg", "Unknown unit" = "Unit unavailable". Gold BOARD note "Count and pack measurement are separate". No multiplication, conversion, stock availability or product photo. |
| Explicit date and time | Card "Timestamp example", value exactly "18 Sep 2026 · 09:40 IST"; separate unknown row "Time unavailable". Gold BOARD note "Proposed explicit timezone / fixed example". No Today/Just now/relative age/ETA/last-updated/live claim. |
| Private identifiers and references | Card "Identifier presentation", rows "Phone" = "••••••••", "Email" = "••••••••", "Order reference" = EMPTY neutral skeleton. Gold BOARD note "Display label does not change the record key". No actual/synthetic contact digits/email/ID, eye/reveal/copy or encryption badge. |

Preserve or resolve:

- Formatting adoption is mixed; target grouped exact amounts are not already uniform across product/cart screens.
- Physical pack label is not order quantity or stock base unit; no automatic kg-to-unit conversion.
- PriceFormatter.parsePrice can accept non-finite numeric text and isValidPrice does not impose finite bound; presentation must not substitute for input/server validation.
- Explicit-zone timestamps and contact summary masks are target policies; missing time/amount stays unavailable.

Sources:

- [packages/agrimore_core/lib/utils/price_formatter.dart](../../packages/agrimore_core/lib/utils/price_formatter.dart)
- [packages/agrimore_core/lib/utils/date_formatter.dart](../../packages/agrimore_core/lib/utils/date_formatter.dart)
- [apps/marketplace/lib/widgets/product/unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart)
- [apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart)
- [apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart](../../apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart)
- [packages/agrimore_core/lib/models/product_model.dart](../../packages/agrimore_core/lib/models/product_model.dart)
- [functions/src/customer/orderPricing.ts](../../functions/src/customer/orderPricing.ts)
- [functions/src/customer/createOrder.ts](../../functions/src/customer/createOrder.ts)

### Agrimore Seller

**Current source:** SellerFormat uses Indian grouping, money hides decimals when rounded paise are whole, moneyExact always two decimals, moneyWhole for rounded summaries and compact K/L/Cr notation. Signs use Unicode minus without spacing before rupee. Seller order/invoice screens currently often call money rather than moneyExact, so documented exact-invoice convention is not uniform. Dates have year/time/range helpers but no timezone conversion. Whole-stock parsing now rejects missing, non-finite, fractional, negative or unsafe raw counts; variant stockConfigured preserves unknown. Existing phone/account/UPI masks retain partial characters.

**Target:** Preserve display/statement amount roles and signs, adopt exact invoice/statement decimals where required, keep whole stock and pack text separate, use full-year date provenance and conservative private summaries. Unknown stock is not zero/out-of-stock.

| Panel | Domain specimen |
| --- | --- |
| Merchant amount roles | Card "Money examples", independent rows "Whole display" = "₹1,24,500", "Exact statement" = "₹64.50", "Signed adjustment" = "−₹64.50". Copper BOARD note "Exact decimals for financial documents". No invoice total, fee, debt, settlement or paid/approved status. |
| Whole stock and measured packs | Card "Quantity examples", rows "Whole-unit count" = "24 units", "Pack label" = "2.5 kg", "Unknown stock" = "Stock unknown". Copper BOARD note "Unknown is not zero / pack text is separate". No out-of-stock/success badge or fractional stock operation. |
| Merchant date and range | Card "Date examples", "18 Sep 2026, 9:40 AM" and range "18 – 24 Sep 2026"; separate "Time unavailable". Small "Example timezone: IST". Copper BOARD note "Fixed examples / define source timezone". No invoice issue/paid deadline, Today or live time. |
| Private merchant identifiers | Card "Masked summaries", rows "Bank account" = "••••••••", "UPI" = "••••••••"; below EMPTY "Record reference" skeleton. Copper BOARD note "Mask summaries / preserve full record keys". No account digits, UPI suffix, merchant identity, eye or secure-storage claim. |

Preserve or resolve:

- Actual invoice call sites need adoption review before claiming all invoices use moneyExact.
- Seller compact suffixes differ from PriceFormatter and cannot be reused for exact reconciliation.
- Date/time formatting consumes supplied DateTime without converting zone; explicit IST policy needs implementation.
- Existing masks disclose tails/UPI domain; masking is display minimization, not authorization/encryption.

Sources:

- [apps/seller/lib/design_system/format/seller_format.dart](../../apps/seller/lib/design_system/format/seller_format.dart)
- [apps/seller/lib/screens/orders/seller_order_detail_screen.dart](../../apps/seller/lib/screens/orders/seller_order_detail_screen.dart)
- [apps/seller/lib/screens/orders/invoice_screen.dart](../../apps/seller/lib/screens/orders/invoice_screen.dart)
- [apps/seller/lib/screens/products/stock_count_validation.dart](../../apps/seller/lib/screens/products/stock_count_validation.dart)
- [apps/seller/lib/screens/products/widgets/product_variants_section.dart](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart)
- [packages/agrimore_core/lib/models/product_model.dart](../../packages/agrimore_core/lib/models/product_model.dart)

### Agrimore Delivery

**Current source:** DeliveryFormat money/moneyExact round to paise, optional versus exact decimal roles and Unicode minus with a space. Money screens use DeliveryFormat.rupees exact; earningBreakdown uses AgFormat exact money, stored distance with two decimals and whole waiting minutes. Offer distances often use one decimal. Helper comment mentions distance but no dedicated distance formatter method exists in inspected DeliveryFormat. Date helpers have year/range but no conversion themselves. Delivery profile local masks differ from helper; UPI raw summary and paidToUpi destination text can remain raw. maskUpi returns malformed no-at text unchanged; maskTail/Aadhaar retain short/tail values.

**Target:** Keep exact monetary statements, preserve stored billable-distance precision separately from map approximation, label minutes/counts and date/time source. Unify conservative identifier summaries without changing destination/record IDs; malformed raw values must not leak by fallback.

| Panel | Domain specimen |
| --- | --- |
| Statement precision and signs | Card "Money examples", rows "Exact statement" = "₹1,250.00", "Signed adjustment" = "− ₹64.50", "Unknown amount" = "Amount unavailable". Orange BOARD note "Exact paise / no payment status implied". No balance, cash-held, paid tick, payout date or financial action. |
| Billable distance and field units | Card "Unit examples", rows "Distance precision" = "4.05 km", "Waiting duration" = "7 min", "Item count" = "2 units". Orange BOARD note "Preserve stored precision for pay breakdowns". No pay rate, computed fee, route/ETA or precision guarantee about GPS. |
| Rider dates and time | Card "Date and time examples", "18 Sep 2026, 9:40 AM", date range "18 – 24 Sep 2026"; separate "Time unavailable". Small "Example timezone: IST". Orange BOARD note "Fixed examples / source time only". No payment schedule, countdown, delivered/paid timeline, live clock or Today. |
| Sensitive rider identifiers | Card "Private summaries", rows "Identity document" = "••••••••", "Bank account" = "••••••••", "UPI" = "••••••••". Small burgundy label "Sensitive information". Orange BOARD note "Malformed values must not reveal raw text". No last digits, ID, photo, actual UPI handle, eye/reveal or verified/encrypted claim. |

Preserve or resolve:

- Map/offer rounding must never be used to recompute rider pay; two-decimal billable breakdown is intentional.
- Statement date zone and calendar-week meaning need explicit policy; helper formatting alone does not resolve timezone.
- Existing DeliveryFormat.maskUpi does not imply all delivery screens use it; malformed/short masks need tests.
- No statement amount/date on the board proves paid, cash received or delivery completion.

Sources:

- [apps/delivery/lib/design_system/format/delivery_format.dart](../../apps/delivery/lib/design_system/format/delivery_format.dart)
- [apps/delivery/lib/money/money_text.dart](../../apps/delivery/lib/money/money_text.dart)
- [apps/delivery/lib/screens/money/money_screen.dart](../../apps/delivery/lib/screens/money/money_screen.dart)
- [apps/delivery/lib/screens/money/statement_screen.dart](../../apps/delivery/lib/screens/money/statement_screen.dart)
- [apps/delivery/lib/screens/offers/incoming_offer_screen.dart](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart)
- [apps/delivery/lib/screens/profile/rider_profile_screen.dart](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart)

### Agrimore Sales Associate

**Current source:** SaFormatters.formatCurrency delegates PriceFormatter exact two decimals/en_IN; order list/detail use it and date-only d MMM yyyy. Detail item quantity currently toInt with fallback one, missing total fallback zero, so missing/malformed source values can look valid. Date fields use Timestamp check and date-only formatter; no time is supplied by that helper. Phone mask returns raw when fewer than four digits; account mask exposes short entire value after Account ending. Full order display reference falls back to document ID; this is distinct from routing identity.

**Target:** Preserve exact monetary/date-only hierarchy, label quantities as whole counts and missing monetary/quantity/date values unavailable rather than defaulting valid values. Harden private masks and separate readable reference from full record key. Do not invent a precise clock time or commission/settlement state.

| Panel | Domain specimen |
| --- | --- |
| Associate monetary hierarchy | Card "Currency examples", rows "Exact amount" = "₹1,25,000.00", "Fractional amount" = "₹64.50", "Unknown amount" = "Amount unavailable". Indigo BOARD note "Two decimals / value is not payout status". No commission percentage, earnings, balance, eligibility, paid/credited tick or fee. |
| Attributed-order quantities | Card "Quantity examples", rows "Whole-unit count" = "2 units", "Unknown quantity" = "Quantity unavailable". Separate small neutral "1 unit" singular-label example. Indigo BOARD note "Do not truncate or infer missing quantities". No product photo, computed order value or fraction-to-int conversion. |
| Date-only provenance | Card "Date examples", "18 Sep 2026", separate "Date unavailable". Indigo BOARD note "Date-only source / no invented time". No clock time, AM/PM, timezone, Today, credited/payout date, deadline or current event. |
| Private associate identifiers | Card "Masked summaries", rows "Phone" = "••••••••", "Bank account" = "••••••••"; below EMPTY "Order reference" skeleton. Indigo BOARD note "Short values stay private / keys remain intact". No phone prefix/digits, account tails, referral code, eye/copy, identity or encryption claim. |

Preserve or resolve:

- Date-only source/helper must not gain fabricated time; future richer timestamps need explicit source/zone implementation.
- toInt truncation/fallback one and zero totals need domain validation before treating values as actual quantities or money.
- Phone short/malformed input currently leaks raw text; short account tail exposes all characters.
- Formatting/attributed order value does not determine commission eligibility, credit or payout outcome.

Sources:

- [apps/employee/lib/utils/sa_formatters.dart](../../apps/employee/lib/utils/sa_formatters.dart)
- [apps/employee/lib/screens/orders/order_detail_screen.dart](../../apps/employee/lib/screens/orders/order_detail_screen.dart)
- [apps/employee/lib/screens/orders/orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [packages/agrimore_core/lib/utils/price_formatter.dart](../../packages/agrimore_core/lib/utils/price_formatter.dart)

### Agrimore Admin

**Current source:** Shared AgFormat provides en_IN exact/whole/compact money, counts, dates and partial masks; modern seller payout screens use it. Admin dashboards/details/product cards also use inline NumberFormat/DateFormat/toStringAsFixed, various decimal/sign/date conventions and US-style month-first dates. AgFormat.dateTime omits year and lowercases am/pm; local order CSV exports currency-free two-decimal numbers and dd/MM/yyyy HH:mm, includes full raw order/customer fields. PDF uses Rs. and rounded line prices in inspected method. UI masking/abbreviation does not make exports private or change backend keys.

**Target:** Use shared exact monetary values for reconciliation and labelled compact summaries, distinguish record count from units, propose full-year explicit-zone event timestamps, and separate display masks from authorized identifiers/exports. Preserve machine export types and server amounts; no audit record truncation.

| Panel | Domain specimen |
| --- | --- |
| Operational exact and compact values | Card "Money examples", rows "Exact amount" = "₹1,23,456.78", "Compact summary" = "≈ ₹1.2L", "Unknown amount" = "Amount unavailable". Cyan BOARD note "Compact is approximate / exact for reconciliation". No revenue dashboard, total/balance, payment outcome or export calculation. |
| Record counts and unit counts | Card "Count examples", rows "Grouped count" = "1,23,456 records", "Unit count" = "24 units", "Unknown count" = "Count unavailable". Cyan BOARD note "Records and quantities are different measures". FORMAT SAMPLES only, no real KPI totals or success/count badge. |
| Full audit timestamp | Card "Timestamp example", "18 Sep 2026 · 09:40 IST", separate "Time unavailable". Cyan BOARD note "Proposed full year and explicit timezone". No Today/Just now/relative age, recorded success, paid/deleted event or live clock. |
| Private values and stable keys | Card "Identifier presentation", rows "Phone" = "••••••••", "Bank account" = "••••••••"; below EMPTY "Record reference" skeleton. Cyan BOARD note "Display masking does not change export permissions". No IDs, customer digits/names, export action, eye/copy, compliance or encryption claim. |

Preserve or resolve:

- Compact summaries are rounded/approximate, never settlement/export inputs. AgFormat sign conventions differ from Seller/Delivery Unicode minus.
- Shared dateTime lacks year; long-lived audit UI needs full-year pattern and explicit zone policy.
- UI/export/PDF formatting and precision require separate contracts; current CSV has no explicit timezone/currency header.
- Masking UI does not remove PII from exports, logs or raw model; authorization/retention are separate.

Sources:

- [packages/agrimore_ui/lib/workspace/ws_format.dart](../../packages/agrimore_ui/lib/workspace/ws_format.dart)
- [apps/admin/lib/screens/admin/admin_dashboard.dart](../../apps/admin/lib/screens/admin/admin_dashboard.dart)
- [apps/admin/lib/screens/admin/orders/order_management_screen.dart](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart)
- [apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart)
- [apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart)
- [packages/agrimore_core/lib/utils/price_formatter.dart](../../packages/agrimore_core/lib/utils/price_formatter.dart)

## Numeric meaning and synthetic examples

| Specimen | Meaning | Boundary |
| --- | --- | --- |
| ₹1,23,456.78 / ₹1,25,000.00 / ₹64.50 | Independent positive currency syntax examples with Indian commas and paise | Not a cart total, invoice, balance, commission, payable or financial event |
| ₹0.00 | Explicit known-zero format example | Missing/invalid is Amount unavailable; zero does not imply Free or no liability |
| ₹1,24,500 | Independent whole-display example | Not a truncated rendering of the adjacent exact value |
| −₹64.50 / − ₹64.50 | Seller versus Delivery existing sign/spacing convention | Negative amount sample, not charged/refunded/settled outcome; accessible sign meaning needed |
| ≈ ₹1.2L | Approximate Admin compact summary for illustrative scale | Not exact reconciliation value, export input or actual KPI |
| 2 units / 1 unit / 24 units | Whole-unit count and singular/plural examples | Not stock availability, fractional stock or real order |
| 2.5 kg | Illustrative free-form measured pack label | Does not define order quantity, stock decrement or unit conversion |
| 4.05 km / 7 min | Illustrative billable-distance precision and waiting-duration units | No pay rate, GPS accuracy, route estimate or actual wait |
| 1,23,456 records | Indian-grouped count example | Records are not sold units or a live operational metric |

Numbers were deliberately introduced for C24 because this foundation demonstrates formatting. Earlier foundations remain untouched. Every numeric/date panel labels Format examples only; samples are independent unless an approximation is explicitly marked. No examples establish commercial price, fee, commission rate, eligibility, debt, actual stock, payout or service commitment.

## Dates, timezones and source quality

| App | Board specimen | Current versus target |
| --- | --- | --- |
| Marketplace | 18 Sep 2026 · 09:40 IST; Time unavailable | Proposed full-year explicit-zone display, not current universal adoption |
| Seller | 18 Sep 2026, 9:40 AM; 18 – 24 Sep 2026; Example timezone: IST | Existing date/range syntax, explicit source-zone policy to implement |
| Delivery | 18 Sep 2026, 9:40 AM; 18 – 24 Sep 2026; Example timezone: IST | Existing syntax, source timezone/calendar-week handling remains explicit domain decision |
| Sales Associate | 18 Sep 2026; Date unavailable | Existing date-only helper; no fabricated time or zone |
| Admin | 18 Sep 2026 · 09:40 IST; Time unavailable | Proposed full-year event timestamp; AgFormat.dateTime currently omits year |

All dates are fixed synthetic format examples, not current event times. An IST label is an illustrative target policy; no app was changed to convert times by this task. Before implementation, choose event source meaning and zone, perform deliberate conversion, and test calendar boundaries. Missing/pending/invalid timestamps never become Now/Today/00:00. Future source times need skew handling before relative labels. Inclusive calendar range display differs from a timestamp interval; no settlement week/payday schedule is promised.

## Identifiers, masks and exports

Current helpers reveal different tails/head characters. Seller masks retain phone/account tails and UPI domain; AgFormat phone exposes first two/last three national digits. Delivery maskUpi returns malformed no-at text unchanged and short maskTail/Aadhaar expose short values; some actual screens use local/raw fields. Associate phone returns raw text when fewer than four digits and Account ending can reveal a short whole value. These are targeted display-hardening gaps, not proof a mask supplies authorization or encryption.

All board private values are pure bullets without sample tail digits. Reference rows are neutral skeletons. This avoids generating actual or fictitious personal data while illustrating alignment and labels. Decide per field whether full owned editing, masked summary or authorized readable reference is appropriate; do not globally hide a public order reference or overwrite full IDs. Routing, deduplication, server lookup and machine export keep full typed keys. UI masking alone does not remove private fields from CSV, logs, PDFs or storage. Export headers should separately declare currency/timezone/quantity meaning; current UI label formatting is not the export schema.

## Future implementation verification

- Golden formatter fixtures for Indian grouping, known zero, negatives, fractional paise, large values, compact thresholds and boundary rounding; null/non-finite/unsafe values remain unavailable and are rejected appropriately at input/domain boundaries. Avoid parsing compact/display strings.
- Exact transaction versus whole/compact summaries and accessible approximate/sign wording; repeated formatting never changes stored totals. Preserve backend pricing and integer-count validation rather than duplicating calculations from labels.
- Marketplace inline product/cart precision adoption; correct selected SKU/unit context; no Free inference. Seller order/invoice moneyExact adoption and stockConfigured/raw whole-count handling. Unknown stock is distinct from zero.
- Delivery one-decimal map/offer distance versus stored two-decimal earning breakdown; units/minutes, known amount versus missing, statement period and current destination summary. Formatting does not recalculate rider pay.
- Associate missing total/quantity fallback, fractional truncation, date-only fields and phone/account short masks; formatting does not infer commission or payout status.
- Admin legacy date/decimal patterns, exact/compact scope and independent CSV/PDF contracts; export raw numeric amounts/full IDs with declared currency/timezone and proper authorized private-field handling. UI masks do not certify export privacy.
- UTC/local/IST conversion, midnight/month/year boundaries, inclusive date ranges, time-only versus date-only versus full event date, null/pending/future/skewed timestamps and relative label refresh. Never append a timezone label without corresponding source/conversion policy.
- Units from real product/variant context, whole counts/plurals, malformed or missing unit, distance precision and no implicit pack conversion. Quantity coercion/rounding is a domain decision, not formatting.
- Mask malformed/short/empty/unicode inputs conservatively; enforce current owner/access before raw values. Display abbreviation must retain distinct full record keys for navigation/lookup/deduplication; no raw values leaked by fallback.
- All app light/dark systems, narrow/wide widths, long amounts/dates/labels, tabular alignment, symbol/unit nonbreaking behavior, text scaling, screen-reader value/sign/unit/approximation and real TalkBack/VoiceOver. Raster boards do not certify pixel-exact tokens, contrast or accessibility.
- Later implementation requires meaningful formatter/domain tests and applicable analyzers. No Flutter runtime/emulator/analyzer, backend mutation, financial transaction, export or production-data read was performed by this asset task.

## Delivery scope and design review

27 new files: ten PNGs, five per-app README/prompts/manifest sets and two master documents. C01–C23 and repeated existing C16 are preserved. C24 is provisional, owner approval pending. Classifier: docs; voluntary UIUX/feedback review covers locked identities, synthetic examples, exact/summary precision, source-quality distinctions, unit/time/identifier meaning.

Only this task’s design assets/docs are written. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption by this task. Concurrent shared-checkout implementation is observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart, apps/marketplace/lib/screens/user/orders/order_details_screen.dart.

## Asset integrity check

First post-packaging validation snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs. PNG chunk checksums, copied-output hashes, 10 exact prompt blocks, reference-input hashes, approved C01 token metadata and 91 local document links passed. Exactly 27 new repository files; all 972 earlier design files remained byte-for-byte intact.

All ten selected images received visual review for grouping, decimals, signs, units, dates, approximation labels, masked examples and light/dark identity. Values are synthetic format examples, not actual transactions or personal identifiers.

Snapshot HEAD: a5a8af1f7dc44f8f5a80dad5d01e8668fab8fda2; inventory HEAD: f88101beab79e2181013af45e61c0898782b14a0; branch: agrimore/foundation-f3c-distance-delivery-pricing. Indexed source changes between inventory and packaging were observed and preserved: apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart, apps/marketplace/lib/screens/user/orders/order_details_screen.dart. No additional indexed source changes were observed during this first packaging/check snapshot. Platform configuration hashes matched the inventory. This records a point in time, not a guarantee that the other chat or HEAD stops advancing.

Scope: design assets/docs only. Integrity checks and visual review do not certify pixel-exact tokens, runtime rendering, accessibility, financial arithmetic, locale/timezone conversion or privacy enforcement. C24 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.
