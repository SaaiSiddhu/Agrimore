# Agrimore Seller — C08 screen headers and section headers

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Blue-teal with warm copper and cool neutral support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-seller-screen-headers-section-headers-light.png) |
| Dark | [Open dark](agrimore-seller-screen-headers-section-headers-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/SCREEN_HEADERS_SECTION_HEADERS_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/SCREEN_HEADERS_SECTION_HEADERS_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

SellerAppBar already provides root, actionsOnly, backOnly and detail variants with semantic headings and text-scale-dependent heights. Titles/subtitles still have ellipsis limits. SellerSectionHeader supports subtitle, count and action in a Row. Catalogue exposes Sort, New post and Add product actions; selection replaces its header with Close.

## Target direction

Keep SellerAppBar/SellerSectionHeader as the foundation. Distinguish persistent Catalogue from a pushed product editor and temporary selection mode. Move crowded actions to a secondary row/overflow before sacrificing the title.

| Panel | Specimen intent |
| --- | --- |
| 01 · Catalogue & task | Root specimen title 'Catalogue'; subtitle 'Products and inventory'; blue-teal filled 'Add product' action with plus icon. Secondary outlined 'Sort' action. Detail specimen: Back arrow, title 'Add product'; subtitle 'Product details'; no root Back. |
| 02 · Inventory sections | Section title 'Stock and variants'; subtitle 'Manage available quantities'; trailing blue-teal action 'Edit'. Second quiet section 'Product information' without an action. Copper accent only in small neutral overline, never as success status. |
| 03 · Contextual modes | Separate header-state specimen title 'Selection mode' with Close icon and caption 'Close returns to Catalogue'; status chip 'Hidden' with neutral/info palette and eye-off icon; nearby label 'Product visibility'. No numeric selected count fabricated. |
| 04 · Growing task headers | Large-text title on two visible lines 'Stock and variants / for this product'; subtitle 'Review each quantity'; outlined 'More options' on its own lower action row. Footer note 'Wrap titles · stack crowded actions'. |

Source gaps and preservation rules:

- Existing scale-aware bars and Semantics are strengths to retain, not replace with a parallel widget system.
- Root Catalogue's three trailing actions need a narrow-width and large-text layout contract.
- Selection Close clears selection; task Back preserves existing draft guards. Count must come from loaded data.

Use one accessible page heading, 4px title/subtitle gap, quieter section headings, 24px section rhythm and scale-aware height. Proposed actions have minimum 48px hit regions; required task titles wrap and crowded actions move below. Delivery retains its existing 40px visual-circle decision, with larger invisible hit regions proposed. Actual text scaling, translations, accessibility and layout must be verified in later implementation. Synthetic status examples are not financial, duty or delivery confirmation.

## Light

![Agrimore Seller C08 light](agrimore-seller-screen-headers-section-headers-light.png)

## Dark

![Agrimore Seller C08 dark](agrimore-seller-screen-headers-section-headers-dark.png)

