# Agrimore Sales Associate — C08 screen headers and section headers

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Premium royal blue with muted indigo, pearl and slate support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-sales-associate-screen-headers-section-headers-light.png) |
| Dark | [Open dark](agrimore-sales-associate-screen-headers-section-headers-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/SCREEN_HEADERS_SECTION_HEADERS_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/SCREEN_HEADERS_SECTION_HEADERS_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

Attributed Orders uses a plain AppBar and a separate search/filter header for All, B2B and Retail orders. Payout History uses a plain AppBar with an unlabeled custom leading button and separate All/Requested/Paid-Settled filters. Shared workspace WsStepHeader supplies a semantic multi-step header but is a distinct flow primitive, not a general AppBar.

## Target direction

Use royal-blue hierarchy for attributed business context and quieter indigo for sections. Explicitly distinguish order attribution from earnings and payout requests from settlement. Add meaningful leading/action labels and consistent section semantics.

| Panel | Specimen intent |
| --- | --- |
| 01 · Attributed work | Root specimen title 'Attributed Orders'; subtitle 'B2B and retail orders'; outlined labeled 'Search orders' with magnifier. Detail specimen Back arrow, title 'Payout History'; subtitle 'Requests and settlement status'. Do not fabricate earnings or commission totals. |
| 02 · Relationship sections | Section heading 'Order attribution'; subtitle 'Your associated orders'; quiet royal-blue action 'View orders'. Second quiet section 'Payout destination' with subtitle 'Account used for requests'; muted indigo supporting rule. |
| 03 · Payout context | Separate specimen info chip 'Requested' with clock icon; label 'Payout status'; secondary caption 'Request recorded; settlement pending'. Another neutral text context line 'B2B orders' with briefcase icon. No Paid/Settled checkmark or payout amount. |
| 04 · Long contextual titles | Large-text title across two visible lines 'Payout destination / and account details'; subtitle 'Review before requesting'; outlined 'More options' below on its own action row. Footer note 'Wrap titles · label Back and actions'. |

Source gaps and preservation rules:

- Search/filter rows stay separate from screen hierarchy; no duplicate heading for the same page.
- Back and icon actions need tooltips/semantic labels.
- Status derives from actual payout records; Requested cannot imply successful transfer.
- Internal employee paths are retained; user-facing product remains Sales Associate.

Use one accessible page heading, 4px title/subtitle gap, quieter section headings, 24px section rhythm and scale-aware height. Proposed actions have minimum 48px hit regions; required task titles wrap and crowded actions move below. Delivery retains its existing 40px visual-circle decision, with larger invisible hit regions proposed. Actual text scaling, translations, accessibility and layout must be verified in later implementation. Synthetic status examples are not financial, duty or delivery confirmation.

## Light

![Agrimore Sales Associate C08 light](agrimore-sales-associate-screen-headers-section-headers-light.png)

## Dark

![Agrimore Sales Associate C08 dark](agrimore-sales-associate-screen-headers-section-headers-dark.png)

