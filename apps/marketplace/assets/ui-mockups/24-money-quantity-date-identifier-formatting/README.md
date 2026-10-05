# Agrimore Marketplace — C24 money, quantity, date and identifier formatting

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C24 owner approval is pending.

Professional-green shopper prices/counts, warm-gold format provenance and calm natural-stone units/private summaries.

[Ten-board gallery](../../../../../docs/design-system/MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Shared PriceFormatter supports en_IN two-decimal, whole and compact rupees, but product/cart cards still interpolate rupee symbols with toStringAsFixed across 0/2 decimal variants. Cart quantity selectors and server order inputs are integer counts; ProductModel has optional free-form unit and variant name/weight labels, not universal pack-conversion semantics. Shared DateFormatter has multiple patterns and relative helpers without explicit timezone conversion; future values can become Just now. Profile phone/email readable. Formatting is display only; order pricing remains server authority.

## Target direction

Use shared exact transaction formatting, distinguish valid zero from unavailable, keep order counts separate from pack measurements, propose explicit-zone timestamps and summary masking without changing order IDs or calculating prices from rounded labels.

| Panel | Domain specimen |
| --- | --- |
| Shopper currency precision | Card "Currency examples", rows "Exact amount" = "₹1,23,456.78", "Known zero" = "₹0.00", "Unknown amount" = "Amount unavailable". Right-aligned tabular values. Gold BOARD note "Two decimals for transaction amounts". These are FORMAT EXAMPLES, not cart/payment totals; no Pay/Free/success/balance. |
| Counts and pack labels | Card "Quantity examples", rows "Order quantity" = "2 units", "Pack label" = "2.5 kg", "Unknown unit" = "Unit unavailable". Gold BOARD note "Count and pack measurement are separate". No multiplication, conversion, stock availability or product photo. |
| Explicit date and time | Card "Timestamp example", value exactly "18 Sep 2026 · 09:40 IST"; separate unknown row "Time unavailable". Gold BOARD note "Proposed explicit timezone / fixed example". No Today/Just now/relative age/ETA/last-updated/live claim. |
| Private identifiers and references | Card "Identifier presentation", rows "Phone" = "••••••••", "Email" = "••••••••", "Order reference" = EMPTY neutral skeleton. Gold BOARD note "Display label does not change the record key". No actual/synthetic contact digits/email/ID, eye/reveal/copy or encryption badge. |

Preservation and gaps:

- Formatting adoption is mixed; target grouped exact amounts are not already uniform across product/cart screens.
- Physical pack label is not order quantity or stock base unit; no automatic kg-to-unit conversion.
- PriceFormatter.parsePrice can accept non-finite numeric text and isValidPrice does not impose finite bound; presentation must not substitute for input/server validation.
- Explicit-zone timestamps and contact summary masks are target policies; missing time/amount stays unavailable.

## Light

![Agrimore Marketplace C24 light](agrimore-marketplace-money-quantity-date-identifier-formatting-light.png)

## Dark

![Agrimore Marketplace C24 dark](agrimore-marketplace-money-quantity-date-identifier-formatting-dark.png)

