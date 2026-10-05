# Agrimore — typography and number hierarchy domain map

Date: 2026-10-02. C02 scope: titles, body text, labels, captions, prices, quantities and domain-specific numbers. Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO.

## Evidence and decision boundaries

The current-source scan read **810 source files / 269,688 lines** across all five app `lib` trees, all three shared package `lib` trees and Cloud Functions `src`. Observed checkout: `agrimore/foundation-f2v-admin-owned-password-dialog` at `cc2f9698a4b47d2fb4463931984a647974cde7ea`. Sensitive Firebase configuration/credential files are excluded. Source-level analysis and selected direct reads establish domain mappings; rendered runtime screens were not inspected during this typography asset task. Source hashes and marker counts are retained in the session artifact `typography-number-hierarchy/source-audit.json`.

The five palettes are **OWNER_DECISION / APPROVED_LOCKED v2** from [C01](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md). The new C02 role mappings and ten boards are **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION** until the owner approves them. They refine typography and number roles without changing the approved colors. They are design references, not a completed runtime migration.

| App | Dart lib files read | Literal font-size occurrences | Tabular markers | toStringAsFixed occurrences |
| --- | --- | --- | --- | --- |
| Agrimore Marketplace | 211 | 1207 | 0 | 116 |
| Agrimore Seller | 115 | 0 | 72 | 19 |
| Agrimore Delivery | 99 | 3 | 16 | 8 |
| Agrimore Sales Associate | 26 | 41 | 0 | 2 |
| Agrimore Admin | 123 | 710 | 0 | 69 |

Counts are syntax markers, not unique widgets, confirmed defects or measured accessibility failures. In Seller, for example, the font-size builder uses variables and therefore is not counted as a literal.

## Shared numerical semantics; five separate hierarchies

- Use Indian grouping (`en_IN`) and the rupee symbol: `₹1,25,000.00`. Exact financial transactions, invoices, checkout totals, commissions and cash obligations retain two decimals. Explicit whole/compact overview KPIs may omit paise only when the exact detail remains accessible.
- Use tabular lining figures for aligned/updated monetary values, counts, quantities, times and reference digits. Text labels and identifiers remain readable; an associate code is not a currency value.
- Quantity is not pack weight. Current ProductModel stock and RFQ quantities are integer counts; product unit/pack specification is separate. A `1 kg pack` purchased twice is `2 packs`, not an invented fractional cart quantity. Do not convert stock counts into kg without a defined unit mapping.
- Keep the unit attached to its value and label the monetary context: price per pack, total, available balance, lifetime commission, pending payout, earnings and cash to collect are different roles.
- Show unknown/unavailable values explicitly rather than inventing zero. Negative/signed amounts, credit/debit direction and status require text or symbols beyond color.
- Body/label/caption roles have explicit line heights. Long product/entity names and translations wrap; essential totals and identifiers are not silently ellipsized. Implementation must allow user text scaling rather than forcing a smaller size. Operational instructions and money labels in Delivery stay at least 14 logical px; its 12 px caption is for subordinate reference metadata.
- The C01 default display/title scales remain the baseline. C02 adds semantic price/quantity/ledger roles and Delivery's 40/48 countdown and 28/36 distance roles; these are proposed domain refinements supported by current DeliveryType display-size capabilities.
- Inter is the approved visual family reference. Seller/Delivery bundle it locally and the shared UI package bundles Inter separately. Marketplace/Admin declare NotoSans in pubspec; SalesAssociateTheme names Inter without employee-local font registration. Actual family/package resolution and script-specific fallback coverage are implementation verification work; these boards do not claim it is already fixed.

## Agrimore Marketplace

**Identity (OWNER_DECISION):** Professional green; warm gold and natural stone support. **Repository app:** `apps/marketplace`.

**Proposed reading priority:** Product name → selling price → pack specification → purchase quantity → payable total.

| Screen families / domain | Typography and number responsibility |
| --- | --- |
| Home, search, categories, shop, wishlist, offers, flash sales, landing | Product title, price, original price, pack/variant labels, rating and discount; product names wrap before captions are reduced. |
| Cart, checkout, coupons, addresses, payment, success, subscriptions | Selected pack count and specification remain distinct; subtotal, discounts and payable total have progressively stronger emphasis. |
| Orders, live tracking, reviews, notifications | Order/task title, quantity, total, date and explicit status; estimated delivery values are labeled estimates. |
| Wallet, product credit, rewards, referral, transaction history | Exact transaction money, clearly named balance/credit types, count/points units and signed ledger entries. |
| RFQ, business feed/profile, storefront visibility, chat/AI | Integer requested pack counts, quoted unit price and exact total; business identity and quote status precede timestamps. |
| Auth, onboarding, associate application, profile, legal/help, language, seller handoff | Readable form labels, body/help/error text, consent/legal copy and masked identifiers. |

### Proposed role scale — TARGET_IMPLEMENTATION

Typeface reference: Inter. Each app owns its role mapping; shared family/formatting semantics do not imply a shared theme. Size and line height below are logical Flutter pixels; size scales with the user's text settings.

| Role | Size / line height | Weight | Illustrative specimen |
| --- | --- | --- | --- |
| Display | 36 / 44 | 700 | Fresh from the farm |
| Title | 26 / 34 | 600 | Shop fresh produce |
| Product | 20 / 28 | 600 | Fresh tomatoes |
| Body | 16 / 24 | 400 | Choose a pack for your household. |
| Label | 14 / 20 | 600 | Pack size |
| Caption | 12 / 18 | 400 | Price includes applicable taxes |
| Price | 32 / 40 | 700 | ₹48.00 |
| Quantity | 16 / 24 | 600 | 2 packs |

**Current-source observation:** 1,207 literal font-size occurrences, no explicit tabular-numeral markers, and 116 toStringAsFixed calls in the scanned lib tree. These are scan markers, not a count of confirmed visual defects.

Source anchors:

- [app_text_styles.dart](../../packages/agrimore_ui/lib/themes/app_text_styles.dart)
- [price_formatter.dart](../../packages/agrimore_core/lib/utils/price_formatter.dart)
- [product_details_screen.dart](../../apps/marketplace/lib/screens/user/shop/product_details_screen.dart)
- [cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/cart_screen.dart)

## Agrimore Seller

**Identity (OWNER_DECISION):** Blue-teal; copper and cool neutral support. **Repository app:** `apps/seller`.

**Proposed reading priority:** Business revenue → workload → stock quantity → unit price/MOQ → quote or invoice total.

| Screen families / domain | Typography and number responsibility |
| --- | --- |
| Home, insights, health | Gross-sales KPI, orders, AOV and explicit comparison period; unknown or unavailable metrics use a labeled unavailable state rather than numeric zero. |
| Products, variants, tax, add product, inventory controls | Integer stock per purchasable unit/variant, pack size, price, tax label and low-stock status; no conversion of packs into kg without a defined product specification. |
| Orders, invoices, order-stage/reason sheets | Order identifier, item quantities, unit price and exact totals; aligned statement numbers and explicit stage labels. |
| RFQ inbox/detail, counter/decline/quote sheets | MOQ and requested integer quantity, quoted unit price, expiry/status and exact offer total; quantity and unit price are not visually interchangeable. |
| Payments, wallet, statements, payout profile/delivery fee | Whole-rupee summaries where appropriate, two-decimal monetary records, masked accounts and clearly named balance/payout states. |
| Storefront, posts, followers, reviews, search, notifications, AI | Store/product identity, count/rating and readable content; timestamps and badges remain subordinate. |
| Auth, application/onboarding, profile, account/settings/support/policies | Form title/body/label/helper/error roles, document-review and application status, readable consent copy. |

### Proposed role scale — TARGET_IMPLEMENTATION

Typeface reference: Inter. Each app owns its role mapping; shared family/formatting semantics do not imply a shared theme. Size and line height below are logical Flutter pixels; size scales with the user's text settings.

| Role | Size / line height | Weight | Illustrative specimen |
| --- | --- | --- | --- |
| Revenue | 32 / 40 | 600 | ₹1,25,000 |
| Title | 24 / 32 | 600 | Seller overview |
| Section | 18 / 26 | 600 | Inventory & quotes |
| Body | 16 / 24 | 400 | Review stock before confirming a quote. |
| Label | 14 / 20 | 500 | Available stock |
| Caption | 12 / 16 | 400 | Updated 2 Oct 2026 |
| Unit price | 18 / 24 | 600 | ₹48.00 / pack |
| Quantity | 16 / 24 | 600 | 250 packs |

**Current-source observation:** Dedicated Inter tokens and tabular figures exist, with 72 tabular markers and no literal font-size occurrences in this scan. Domain distinctions still need to be explicit: KPI rounding must not leak into invoice/quote totals.

Source anchors:

- [seller_typography.dart](../../apps/seller/lib/design_system/tokens/seller_typography.dart)
- [seller_format.dart](../../apps/seller/lib/design_system/format/seller_format.dart)
- [home_stats.dart](../../apps/seller/lib/screens/home/home_stats.dart)
- [product_stats.dart](../../apps/seller/lib/screens/products/product_stats.dart)
- [seller_rfq_detail_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart)

## Agrimore Delivery

**Identity (OWNER_DECISION):** Black/white; burgundy and burnt orange support. **Repository app:** `apps/delivery`.

**Proposed reading priority:** Offer/task timing → pickup/drop distance and address → cash to collect → item count → reference metadata.

| Screen families / domain | Typography and number responsibility |
| --- | --- |
| Incoming offers | Stable tabular expiry timer, pickup/drop distance with units, item count and cash to collect; no invented customer data before offer acceptance. |
| Home map, operation panel, active-work/pending-proof states | Current task and readable operational counts; earned money is labeled separately from cash held/collected; unavailable/stale route data is explicit. |
| Active order, route details/recovery, proof/problem panels | Pickup/drop title and address, task instructions, pack count, exact COD and proof code/reference; critical labels use at least 14 logical px in this proposal. |
| Money, cash account, statements, bank-change requests, history | Exact cash ledger and payout amounts, signed records, date range and transaction identifiers; rounded earnings summaries do not replace exact cash obligations. |
| Inbox, support/help/request status | Task/problem title, explicit status and actionable body text; chronology/captions remain subordinate. |
| Auth, registration, approval, profile/documents/identity, device readiness | Readable fields and errors, masked private identifiers, clear permission/readiness/status language. |

### Proposed role scale — TARGET_IMPLEMENTATION

Typeface reference: Inter. Each app owns its role mapping; shared family/formatting semantics do not imply a shared theme. Size and line height below are logical Flutter pixels; size scales with the user's text settings.

| Role | Size / line height | Weight | Illustrative specimen |
| --- | --- | --- | --- |
| Countdown | 40 / 48 | 700 | 00:24 |
| Title | 24 / 32 | 700 | Next pickup |
| Task | 20 / 28 | 600 | Collect from seller |
| Body | 17 / 26 | 400 | Check the pack count at pickup. |
| Label | 14 / 20 | 600 | Cash to collect |
| Caption | 12 / 18 | 400 | Order reference |
| Cash | 32 / 40 | 700 | ₹960.00 |
| Distance | 28 / 36 | 700 | 2.4 km |

**Current-source observation:** Dedicated Inter/tabular typography exists. The proposed 40/48 countdown and 28/36 distance are operational number roles consistent with existing display-size capabilities; they refine C01 rather than changing its palette.

Source anchors:

- [delivery_typography.dart](../../apps/delivery/lib/design_system/tokens/delivery_typography.dart)
- [delivery_format.dart](../../apps/delivery/lib/design_system/format/delivery_format.dart)
- [incoming_offer_screen.dart](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart)
- [rider_route_card.dart](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart)
- [money_screen.dart](../../apps/delivery/lib/screens/money/money_screen.dart)

## Agrimore Sales Associate

**Identity (OWNER_DECISION):** Premium royal blue; indigo and pearl/slate support. **Repository app:** `apps/employee`.

**Proposed reading priority:** Available balance → credited commission → payout status → attributed-order count → associate code.

| Screen families / domain | Typography and number responsibility |
| --- | --- |
| Dashboard, notifications | Associate code, wallet/commission metrics and recent attributed orders; balances, lifetime totals and counts have distinct labels. |
| Orders and order detail | Order identifier/status, order value and credited/eligible commission; cancelled orders never display a fabricated earned amount. |
| Wallet, payout request/review/details/history, payout account | Exact available money, requested payout, payout status and masked bank identifiers; pending/processed/available amounts are not interchangeable. |
| Auth/OTP, pending approval, suspended, onboarding status | Readable validation/error text, OTP/code clarity, payment/application status; no promise of approved status from a numeric fee. |
| Profile, shell, support | Title/body/field/helper/caption roles and clear navigation labels; long text wraps at increased scale. |

### Proposed role scale — TARGET_IMPLEMENTATION

Typeface reference: Inter. Each app owns its role mapping; shared family/formatting semantics do not imply a shared theme. Size and line height below are logical Flutter pixels; size scales with the user's text settings.

| Role | Size / line height | Weight | Illustrative specimen |
| --- | --- | --- | --- |
| Balance | 34 / 42 | 600 | ₹12,500.00 |
| Title | 24 / 32 | 600 | Sales overview |
| Section | 18 / 26 | 600 | Your commissions |
| Body | 16 / 24 | 400 | Track credited commission and payouts. |
| Label | 14 / 20 | 500 | Available balance |
| Caption | 12 / 18 | 400 | Credited 2 Oct 2026 |
| Commission | 20 / 28 | 600 | ₹125.00 |
| Code | 18 / 26 | 600 | AG-2048 |

**Current-source observation:** SaTokens defines a clear scale and SaFormatters delegates to Indian-grouped exact currency. The lib scan still finds 41 literal font sizes and no explicit tabular-numeral markers. The theme names Inter while the employee pubspec has no app-local font registration; actual font resolution needs verification during implementation.

Source anchors:

- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)
- [sales_associate_theme.dart](../../packages/agrimore_ui/lib/themes/sales_associate_theme.dart)
- [sa_formatters.dart](../../apps/employee/lib/utils/sa_formatters.dart)
- [dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)
- [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart)
- [order_detail_screen.dart](../../apps/employee/lib/screens/orders/order_detail_screen.dart)

## Agrimore Admin

**Identity (OWNER_DECISION):** Professional institutional blue; cyan and steel/slate support. **Repository app:** `apps/admin`.

**Proposed reading priority:** Review/exception title → exact financial amount or queue count → status → actor/record identifier → audit timestamp.

| Screen families / domain | Typography and number responsibility |
| --- | --- |
| Dashboard, analytics | Operational KPI and period/denominator; whole/compact overview values only where exact detail is accessible. |
| Finance reconciliation, wallet tracking, security/payment lookup, payouts, commission exceptions | Exact money with two decimals, aligned comparison columns, reason/status, record ID and audit timestamp; compact values do not substitute for financial review detail. |
| Orders, subscriptions, delivery/rider operations/problems/flags/slots/support | Queue count, order/task identifier, operational status, item quantities, cash obligation and explicit dates/time. |
| Products, categories, sellers, vendors, users, associates and actor detail | Entity/title and identifier, product/variant stock and price, review status and relevant counts; readable dense desktop tables. |
| Banners, bestsellers, sections, sponsored content, coupons, rewards, reviews | Content hierarchy and validation labels; typed discounts, quantity/limit, dates and positions with explicit units. |
| Benefit/compliance/feature flags, admin/settings/location, notifications, auth | Policy/status/field labels, clear instructions, audit metadata and action text; no reliance on color alone. |

### Proposed role scale — TARGET_IMPLEMENTATION

Typeface reference: Inter. Each app owns its role mapping; shared family/formatting semantics do not imply a shared theme. Size and line height below are logical Flutter pixels; size scales with the user's text settings.

| Role | Size / line height | Weight | Illustrative specimen |
| --- | --- | --- | --- |
| KPI | 32 / 40 | 600 | 1,248 |
| Title | 24 / 32 | 600 | Finance reconciliation |
| Section | 18 / 26 | 600 | Settlement summary |
| Body | 16 / 24 | 400 | Review unmatched financial records. |
| Label | 14 / 20 | 500 | Unmatched amount |
| Caption | 12 / 18 | 400 | Updated 2 Oct 2026 |
| Money | 16 / 24 | 600 | ₹1,25,000.00 |
| Record ID | 14 / 20 | 500 | PAY-2048 |

**Current-source observation:** 710 literal font-size occurrences, no explicit tabular-numeral markers and 69 toStringAsFixed calls in the lib scan. The finance screen visibly constructs rupee amounts inline; canonical role/formatting migration is a later implementation task.

Source anchors:

- [admin_theme.dart](../../apps/admin/lib/app/themes/admin_theme.dart)
- [finance_reconciliation_models.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_models.dart)
- [finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart)
- [commission_exceptions_screen.dart](../../apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart)
- [rider_cash_ledger_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart)


## Deliverables and validation

Generate ten separate full-width Storybook-style boards: one light and one dark per app, no sidebar. Preserve each pair's role values and content, use the approved C01 palettes, and vary the domain specimen composition. Save each pair in that app's `assets/ui-mockups/02-typography-number-hierarchy/` with meaningful names, a gallery, exact generation prompts and machine-readable provenance. Sales Associate uses `apps/employee`.

Visual review checks app/theme identity, hierarchy, rupee/grouping/unit text and uncropped readable panels. File validation checks all ten PNGs, hashes, prompts, per-app pairing and portable Markdown links. A raster board illustrates the type system; exact family/weight/line-height compliance is specified in the prompt/provenance and must be tested in Flutter when implemented.

## C01 continuity review before generation

All ten approved C01 PNGs were viewed individually and checked against their five app lock records before generation. Their hashes match the approved files. Each C02 prompt inherits its corresponding C01 palette and all four exact semantic status container/foreground pairs, plus the existing borders, radius/spacing rhythm and shadow appearance. C01 remains unchanged. Any paired-dark edit also uses the generated C02 light board for its composition/content while the approved C01 dark board remains the color authority.
