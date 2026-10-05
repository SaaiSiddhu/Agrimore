# Agrimore Admin — C24 money, quantity, date and identifier formatting

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C24 owner approval is pending.

Professional-blue operational money/count columns, cyan exact-versus-summary and timestamp context, steel/slate audit/private identifiers.

[Ten-board gallery](../../../../../docs/design-system/MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/MONEY_QUANTITY_DATE_IDENTIFIER_FORMATTING_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Shared AgFormat provides en_IN exact/whole/compact money, counts, dates and partial masks; modern seller payout screens use it. Admin dashboards/details/product cards also use inline NumberFormat/DateFormat/toStringAsFixed, various decimal/sign/date conventions and US-style month-first dates. AgFormat.dateTime omits year and lowercases am/pm; local order CSV exports currency-free two-decimal numbers and dd/MM/yyyy HH:mm, includes full raw order/customer fields. PDF uses Rs. and rounded line prices in inspected method. UI masking/abbreviation does not make exports private or change backend keys.

## Target direction

Use shared exact monetary values for reconciliation and labelled compact summaries, distinguish record count from units, propose full-year explicit-zone event timestamps, and separate display masks from authorized identifiers/exports. Preserve machine export types and server amounts; no audit record truncation.

| Panel | Domain specimen |
| --- | --- |
| Operational exact and compact values | Card "Money examples", rows "Exact amount" = "₹1,23,456.78", "Compact summary" = "≈ ₹1.2L", "Unknown amount" = "Amount unavailable". Cyan BOARD note "Compact is approximate / exact for reconciliation". No revenue dashboard, total/balance, payment outcome or export calculation. |
| Record counts and unit counts | Card "Count examples", rows "Grouped count" = "1,23,456 records", "Unit count" = "24 units", "Unknown count" = "Count unavailable". Cyan BOARD note "Records and quantities are different measures". FORMAT SAMPLES only, no real KPI totals or success/count badge. |
| Full audit timestamp | Card "Timestamp example", "18 Sep 2026 · 09:40 IST", separate "Time unavailable". Cyan BOARD note "Proposed full year and explicit timezone". No Today/Just now/relative age, recorded success, paid/deleted event or live clock. |
| Private values and stable keys | Card "Identifier presentation", rows "Phone" = "••••••••", "Bank account" = "••••••••"; below EMPTY "Record reference" skeleton. Cyan BOARD note "Display masking does not change export permissions". No IDs, customer digits/names, export action, eye/copy, compliance or encryption claim. |

Preservation and gaps:

- Compact summaries are rounded/approximate, never settlement/export inputs. AgFormat sign conventions differ from Seller/Delivery Unicode minus.
- Shared dateTime lacks year; long-lived audit UI needs full-year pattern and explicit zone policy.
- UI/export/PDF formatting and precision require separate contracts; current CSV has no explicit timezone/currency header.
- Masking UI does not remove PII from exports, logs or raw model; authorization/retention are separate.

## Light

![Agrimore Admin C24 light](agrimore-admin-money-quantity-date-identifier-formatting-light.png)

## Dark

![Agrimore Admin C24 dark](agrimore-admin-money-quantity-date-identifier-formatting-dark.png)

