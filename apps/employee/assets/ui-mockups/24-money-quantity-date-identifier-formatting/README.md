# Agrimore Sales Associate — C24 money, quantity, date and identifier formatting

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C24 owner approval is pending.

Premium royal-blue attributed-order numeric hierarchy, indigo format/date provenance and pearl/slate masked contact/payout summaries.

[Ten-board gallery](../../../../../docs/design-system/MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SaFormatters.formatCurrency delegates PriceFormatter exact two decimals/en_IN; order list/detail use it and date-only d MMM yyyy. Detail item quantity currently toInt with fallback one, missing total fallback zero, so missing/malformed source values can look valid. Date fields use Timestamp check and date-only formatter; no time is supplied by that helper. Phone mask returns raw when fewer than four digits; account mask exposes short entire value after Account ending. Full order display reference falls back to document ID; this is distinct from routing identity.

## Target direction

Preserve exact monetary/date-only hierarchy, label quantities as whole counts and missing monetary/quantity/date values unavailable rather than defaulting valid values. Harden private masks and separate readable reference from full record key. Do not invent a precise clock time or commission/settlement state.

| Panel | Domain specimen |
| --- | --- |
| Associate monetary hierarchy | Card "Currency examples", rows "Exact amount" = "₹1,25,000.00", "Fractional amount" = "₹64.50", "Unknown amount" = "Amount unavailable". Indigo BOARD note "Two decimals / value is not payout status". No commission percentage, earnings, balance, eligibility, paid/credited tick or fee. |
| Attributed-order quantities | Card "Quantity examples", rows "Whole-unit count" = "2 units", "Unknown quantity" = "Quantity unavailable". Separate small neutral "1 unit" singular-label example. Indigo BOARD note "Do not truncate or infer missing quantities". No product photo, computed order value or fraction-to-int conversion. |
| Date-only provenance | Card "Date examples", "18 Sep 2026", separate "Date unavailable". Indigo BOARD note "Date-only source / no invented time". No clock time, AM/PM, timezone, Today, credited/payout date, deadline or current event. |
| Private associate identifiers | Card "Masked summaries", rows "Phone" = "••••••••", "Bank account" = "••••••••"; below EMPTY "Order reference" skeleton. Indigo BOARD note "Short values stay private / keys remain intact". No phone prefix/digits, account tails, referral code, eye/copy, identity or encryption claim. |

Preservation and gaps:

- Date-only source/helper must not gain fabricated time; future richer timestamps need explicit source/zone implementation.
- toInt truncation/fallback one and zero totals need domain validation before treating values as actual quantities or money.
- Phone short/malformed input currently leaks raw text; short account tail exposes all characters.
- Formatting/attributed order value does not determine commission eligibility, credit or payout outcome.

## Light

![Agrimore Sales Associate C24 light](agrimore-sales-associate-money-quantity-date-identifier-formatting-light.png)

## Dark

![Agrimore Sales Associate C24 dark](agrimore-sales-associate-money-quantity-date-identifier-formatting-dark.png)

