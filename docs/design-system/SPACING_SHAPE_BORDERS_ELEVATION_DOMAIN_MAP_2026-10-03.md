# Agrimore — spacing, shape, borders and elevation domain map

Date: 2026-10-03. C03 design references. Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO.

## Evidence and decision boundaries

The source scan read **815 files / 271,456 lines** across five app lib trees, three shared package lib trees and Cloud Functions src. Observed branch `agrimore/foundation-f3c-distance-delivery-pricing` at `0e9eca576c375cd330040c4634e205a8b4c1086b`. Sensitive configuration/credential files were excluded. Domain mapping uses source inventory, token/component/theme reads and spatial syntax markers. Runtime screens, responsive rendering and accessibility behavior were not tested in this image-asset task. Backend/shared model reads supply domain context; they are not a backend/security audit. Per-file hashes and scan counts are retained in the session artifact `spacing-shape-borders-elevation/source-audit.json`.

The ten [C01 v2 boards](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md) are **OWNER_DECISION / APPROVED_LOCKED**. They were visually inspected before generating C03 and their checksums verified. Their light/dark palettes, status colors, base spacing, radius arrays and border widths remain authoritative. C02 typography is a provisional predecessor, not a new color authority. C03 app-specific spacing aliases, semantic radius assignments, shadow recipes and ten new boards are **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION** pending owner approval. This adds design references; it does not migrate runtime code.

| App | Source files | Literal all-padding markers | Literal radius markers | BoxShadow markers | Literal elevation markers |
| --- | --- | --- | --- | --- | --- |
| Agrimore Marketplace | 211 | 409 | 1028 | 262 | 86 |
| Agrimore Seller | 116 | 0 | 0 | 2 | 6 |
| Agrimore Delivery | 99 | 1 | 0 | 3 | 4 |
| Agrimore Sales Associate | 26 | 3 | 23 | 5 | 1 |
| Agrimore Admin | 123 | 390 | 612 | 84 | 52 |

Markers are syntax occurrences, not unique components or confirmed defects. Variable-based tokens are not counted as literals; zero literal markers does not mean an app lacks padding or corner shapes. All screen-family inventory paths are included per app below; each runtime screen was not independently rendered.

## Shared contract; five domain applications

- Keep approved core spacing **4 / 8 / 12 / 16 / 24 / 32** logical px. App-specific aliases express density and hierarchy on this grid. Control minimum heights 48, 52 and proposed Delivery 56 are touch/control sizes, not additions to the padding scale.
- The C03 mappings use the approved three radii for control / card / sheet-or-dialog. Marketplace **12 / 16 / 24**; Seller **10 / 14 / 20**; Delivery **8 / 12 / 18**; Sales Associate **12 / 18 / 24**; Admin **8 / 12 / 16**. Circular avatars, chip pills, image crops and conversation bubbles require explicit component exceptions rather than replacing these core roles.
- Default and strong borders are **1 px**; focus is **2 px**. Each app uses its C01 default, strong and focus colors. One boundary per component; focused/selected states reserve geometry and do not shift content. State text/icons supplement color.
- Surface depth has **Flat / Soft / Raised** roles. Flat ledgers use dividers and one enclosing border; Soft lifts a meaningful card/editor group; Raised separates a transient sheet/dialog. Avoid shadowing every row or adding nested elevation. In dark mode the locked near-black canvas, surface and raised tones plus borders provide separation; no bright panels or colored glows.
- Light shadow proposals below specify x/y/blur/spread in logical px, tint and opacity. They formalize the restrained C01 visual examples without claiming its lock already defined semantic numeric implementation. Dark default shadows may be omitted in favor of tonal surfaces and borders; an optional neutral black shadow must remain subordinate. These are implementation targets requiring rendering review.
- Phone page inset is 16; wide/desktop default is 24. Existing app responsive helpers determine when a layout changes; no new shared breakpoint policy is introduced here. Forms keep bounded readable width. Wider layouts use purposeful columns; phone tables become stacked records or bounded scroll rather than compressed labels.
- Apply the page inset once. Child cards own their padding, not another page margin. Section gap separates groups; row/cell gap structures data. Measurement arrows on the boards describe logical roles, not exact exported raster pixels.
- Minimum touch targets are 48. Text, translated copy and validation can increase height; a minimum is never a clipping constraint. Safe-area and keyboard insets add to content clearance. Sheets have constrained scrollable content and reachable actions; sticky footers contribute to feedback clearance so save buttons and messages are not covered.
- Supporting gold/copper/burgundy/orange/indigo/cyan identifies context in each app. It must not replace C01 success, warning, error or info semantics. Surface height does not communicate payment, approval or delivery state.

| App | Soft proposal (x y blur spread; tint; opacity) | Raised proposal |
| --- | --- | --- |
| Agrimore Marketplace | [0, 2, 8, 0, '#000000', 0.08] | [0, 8, 24, 0, '#000000', 0.1] |
| Agrimore Seller | [0, 2, 8, 0, '#142A34', 0.06] | [0, 8, 24, 0, '#142A34', 0.1] |
| Agrimore Delivery | [0, 1, 3, 0, '#1C1C1C', 0.08] | [0, 4, 12, 0, '#1C1C1C', 0.12] |
| Agrimore Sales Associate | [0, 2, 8, 0, '#142540', 0.08] | [0, 8, 24, 0, '#142540', 0.12] |
| Agrimore Admin | [0, 2, 8, 0, '#14243B', 0.08] | [0, 8, 24, 0, '#14243B', 0.12] |

## Agrimore Marketplace

**Identity:** Professional green, warm gold and natural stone. Repository app: `apps/marketplace`.

| Domain / screen families | Spatial responsibility |
| --- | --- |
| Home, search, categories, shop, wishlist, offers, flash sales, landing | 16 phone / 24 wide inset; product grid gap 12, internal padding 16; 24 between sections. Card groups align to one content grid, rather than each section adding another page inset. |
| Cart, checkout, coupons, addresses, payment, success, subscriptions | Flat cart rows and separated raised total/action group; 16 content padding, 24 group gap. Address/filter sheets use 24 top corners; keyboard and bottom system inset add to content clearance. |
| Orders, tracking, reviews, notifications | Flat grouped rows with explicit dividers; status and time remain part of the row. Tracking overlays sit above map content without obscuring actions or readable instructions. |
| Wallet, product credit, rewards, referral and transactions | Use bordered financial groups, 16 inner padding and 12 row separation; avoid giving every ledger entry an independent shadow. |
| RFQ, business/profile, storefront, chat/AI | Grouped quote fields, 24 section gap, sheet corner 24. Conversation bubbles are component-specific exceptions, not replacements for the core control/card/sheet roles. |
| Auth, onboarding, associate application, profile, settings, legal/help, seller handoff | Scrollable single-column forms with 16 phone inset and readable label/helper gaps; no nesting-induced double padding. Consent/help copy expands with text size. |

### Proposed domain roles — TARGET_IMPLEMENTATION

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Product card padding | 16 |
| Product grid gap | 12 |
| Section gap | 24 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius mapped by C03 |
| --- | --- |
| Control | 12 |
| Card | 16 |
| Sheet / dialog | 24 |

**Surface depth:** Flat → Cart row; Soft → Product card; Raised → Address sheet. Depth is about placement, not status.

**Current-source migration observations:** Marketplace contains 1,028 literal-radius markers and 409 EdgeInsets.all literal markers. Product variants use several local radii; cart cards use 20 and address sheets use 20, while the approved target core roles map to 12 / 16 / 24. This is a migration inventory, not a claim that every local radius is defective.

Source anchors:

- [unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [cart_item_card.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart)
- [address_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart)
- [app_theme.dart](../../packages/agrimore_ui/lib/themes/app_theme.dart)

### Inventory coverage

The static scan includes these screen-family paths (counts include screen-support widgets, not unique screens):

| Family under app lib/screens | Source files |
| --- | --- |
| auth | 9 |
| business | 3 |
| chat | 2 |
| chat/widgets | 9 |
| employee | 1 |
| employee/onboarding | 6 |
| landing | 1 |
| legal | 2 |
| not_found_screen.dart | 1 |
| onboarding | 1 |
| seller | 1 |
| splash | 1 |
| user/cart | 9 |
| user/categories | 2 |
| user/checkout | 7 |
| user/flash_sale | 1 |
| user/help | 1 |
| user/home | 27 |
| user | 1 |
| user/notifications | 1 |
| user/offers | 1 |
| user/orders | 15 |
| user/profile | 9 |
| user/rewards | 1 |
| user/rfq | 3 |
| user/search | 3 |
| user/settings | 1 |
| user/shop | 20 |
| user/subscriptions | 2 |
| user/wallet | 9 |
| user/wishlist | 5 |

## Agrimore Seller

**Identity:** Blue-teal, copper and cool neutrals. Repository app: `apps/seller`.

| Domain / screen families | Spatial responsibility |
| --- | --- |
| Home, insights, health | Bounded content, 16 phone / 24 wide inset, 24 section gap; metrics are grouped rather than adding nested card margins. |
| Products, variants, tax, add product and inventory | 16 card padding; 12 table cell padding; 8 internal row gap. Dense data uses dividers and alignment, while interactive rows keep at least 48 touch height. |
| Orders, invoices and stage/reason sheets | Flat order/invoice groups with stable inset; detail forms grow and scroll. Order action sheets use 20 top corners, 16 content padding and protected footer clearance. |
| RFQ inbox/detail and counter/decline/quote sheets | Flat inbox, soft quote editor, raised quote overlay; copper signals secondary quote context. Core radii 10 controls / 14 cards / 20 sheets. |
| Payments, wallet, statements, payout profile, delivery fee | Aligned flat ledgers; financial summary may be soft, never every row. Keyboard-safe forms and footers share one horizontal inset. |
| Storefront, posts, followers, reviews, search, notifications, AI | Reusable content groups and 24 section gap; overflow/long copy expands instead of shrinking or accumulating padding. |
| Auth, application/onboarding, profile, account, shell, support and policies | SellerPage already applies 16/24 responsive inset and bounds forms at 640; SellerStickyFooter contributes bottom clearance to feedback. Preserve those behaviors while migrating shape roles. |

### Proposed domain roles — TARGET_IMPLEMENTATION

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Inventory card padding | 16 |
| Table cell padding | 12 |
| Row content gap | 8 |
| Section gap | 24 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius mapped by C03 |
| --- | --- |
| Control | 10 |
| Card | 14 |
| Sheet / dialog | 20 |

**Surface depth:** Flat → Inventory ledger; Soft → Quote editor; Raised → Quote sheet. Depth is about placement, not status.

**Current-source migration observations:** SellerSpace already supplies page 16 / wide 24, card 16 and section 24. SellerRadius currently uses control 8 and card 12; C01 approves 10 / 14 / 20. SellerSize.outline is 1.5, while C01 default/strong borders are 1. Existing raised/overlay shadow tints are older green tones. These are targeted migration gaps; tokenization itself should be retained.

Source anchors:

- [seller_tokens.dart](../../apps/seller/lib/design_system/tokens/seller_tokens.dart)
- [seller_card.dart](../../apps/seller/lib/design_system/components/seller_card.dart)
- [seller_rfq_detail_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart)

- [seller_layout.dart](../../apps/seller/lib/design_system/components/seller_layout.dart)

### Inventory coverage

The static scan includes these screen-family paths (counts include screen-support widgets, not unique screens):

| Family under app lib/screens | Source files |
| --- | --- |
| account | 8 |
| ai | 1 |
| auth | 6 |
| home | 4 |
| insights | 3 |
| notifications | 2 |
| onboarding | 10 |
| orders | 6 |
| payments | 3 |
| posts | 2 |
| products | 6 |
| profile | 5 |
| reviews | 2 |
| rfq | 7 |
| search | 2 |
| shell | 1 |
| storefront | 2 |

## Agrimore Delivery

**Identity:** Black/white, burgundy and burnt orange. Repository app: `apps/delivery`.

| Domain / screen families | Spatial responsibility |
| --- | --- |
| Incoming offers | 16 task padding and gap; 24 separation before decisive action; proposed primary action minimum 56, all interactive targets ≥48. Text may increase height; expiry/countdown stays separate from action. |
| Home map, operations panel, active-work and pending-proof states | Route sheet uses 18 top corners and tonal raised surface; preserve the draggable sheet’s single scroll controller and measured peek content. Safe area and map control clearance are additional insets. |
| Active order, route/recovery, proof and problem panels | Separate pickup/drop/cash/proof groups by 16 or 24; do not place competing actions adjacent without separation. Scroll constrained panels at large text/keyboard; no fixed-height proof form. |
| Money, cash account, statements, bank changes and history | Flat ledger rows; burgundy cash context distinct from personal earnings. Bordered groups do not rely on shadow to communicate financial state. |
| Inbox, support/help and request status | Flat groups and strong readable boundaries; help text expands. Primary action remains reachable above bottom system inset. |
| Auth, registration, approval, profile/documents, settings, identity and device readiness | One inset at screen edge, 16 group padding, 24 major gap; keyboard-safe forms and document previews use bounded scroll rather than clipping. |

### Proposed domain roles — TARGET_IMPLEMENTATION

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Task card padding | 16 |
| Task gap | 16 |
| Action separation | 24 |
| Primary action min height | 56 |

| Shape role | Approved C01 radius mapped by C03 |
| --- | --- |
| Control | 8 |
| Card | 12 |
| Sheet / dialog | 18 |

**Surface depth:** Flat → History row; Soft → Task card; Raised → Route sheet. Depth is about placement, not status.

**Current-source migration observations:** Delivery tokens include control 8 and card 12, but sheet 20 differs from C01 sheet-role proposal 18; DeliveryCard defaults to rLg (dialog 16), rather than card 12. Current large control height is 52; 56 for the primary task action is a C03 proposal. Existing map/sheet adaptive behavior must be preserved.

Source anchors:

- [delivery_tokens.dart](../../apps/delivery/lib/design_system/tokens/delivery_tokens.dart)
- [delivery_card.dart](../../apps/delivery/lib/design_system/components/delivery_card.dart)
- [home_operations_panel.dart](../../apps/delivery/lib/screens/home/home_operations_panel.dart)
- [incoming_offer_screen.dart](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart)

### Inventory coverage

The static scan includes these screen-family paths (counts include screen-support widgets, not unique screens):

| Family under app lib/screens | Source files |
| --- | --- |
| auth | 3 |
| history | 2 |
| home | 6 |
| inbox | 1 |
| money | 3 |
| offers | 1 |
| orders | 4 |
| profile | 3 |
| settings | 1 |
| support | 5 |

## Agrimore Sales Associate

**Identity:** Premium royal blue, indigo and pearl/slate. Repository app: `apps/employee`.

| Domain / screen families | Spatial responsibility |
| --- | --- |
| Dashboard and notifications | 24 balance-group padding; 16 record padding; 12 row gap, 24 section gap. Available balance and lifetime/pending summaries occupy distinct groups. |
| Orders and detail | Flat attributed-order groups with divider and readable commission context; increase row height for wrapped identifiers rather than reducing text. |
| Wallet, payout request/review/detail/history and payout account | Soft balance group, flat ledger, raised payout sheet; 24 sheet corners and clear boundary between available balance and pending amounts. Use 52 minimum controls and ≥48 tap targets. |
| Auth/OTP, pending approval, suspended and onboarding status | Scrollable readable forms, 16 phone / 24 wide inset; status and consent groups retain boundaries without decorative depth suggesting approval. |
| Profile, support and shell | One page inset; 24 section separation; safe area and keyboard clearance are added by layout rather than arbitrary spacer piles. |

### Proposed domain roles — TARGET_IMPLEMENTATION

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Wide page inset | 24 |
| Balance hero padding | 24 |
| Record padding | 16 |
| Record gap | 12 |
| Section gap | 24 |
| Minimum control height | 52 |

| Shape role | Approved C01 radius mapped by C03 |
| --- | --- |
| Control | 12 |
| Card | 18 |
| Sheet / dialog | 24 |

**Surface depth:** Flat → Commission row; Soft → Balance group; Raised → Payout sheet. Depth is about placement, not status.

**Current-source migration observations:** SalesAssociate tokens currently set page padding 20, control 52, card radius 16, input 12 and sheet 24. C03 proposes page 16/24 on the approved spacing grid and maps the approved C01 card radius 18 to balance/record groups. Keep the existing 52 minimum control-height domain behavior.

Source anchors:

- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)
- [sales_associate_theme.dart](../../packages/agrimore_ui/lib/themes/sales_associate_theme.dart)
- [dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)
- [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart)

### Inventory coverage

The static scan includes these screen-family paths (counts include screen-support widgets, not unique screens):

| Family under app lib/screens | Source files |
| --- | --- |
| auth | 5 |
| home | 1 |
| notifications | 1 |
| orders | 2 |
| profile | 2 |
| shell | 1 |
| support | 1 |
| wallet | 6 |

## Agrimore Admin

**Identity:** Professional blue, cyan and steel/slate. Repository app: `apps/admin`.

| Domain / screen families | Spatial responsibility |
| --- | --- |
| Dashboard, analytics and finance | 24 desktop / 16 phone inset, 16 panel padding, 32 section separation. Flat analytics/ledger groups; raised only for transient editors/reviews. |
| Products, vendors, sellers, categories, orders and subscriptions | Aligned flat tables with 12 cell padding and 16 column gap. Phone views become grouped records rather than shrinking columns; interactive rows remain ≥48. |
| Delivery, employees, users and application approvals | Strong 1 px grouping boundaries; blue 2 px focus. Review dialogs use 16 corners; independent approval/action regions have visible separation. |
| Wallet, rewards, benefits, coupons and program controls | Financial/program ledgers stay flat; editor soft, review dialog raised. Do not imply transaction success or permission from surface depth. |
| Banners, sponsored/section banners, bestsellers and home/category sections | Bounded content-editor groups with 16 padding and 32 section gap; previews get one boundary, rather than nested shadowed cards. |
| Security, settings, auth, notifications, support and reviews | Scrollable labeled forms; keyboard-safe dialogs; long audit/support content wraps; page grid and focus outline are consistent across panels. |

### Proposed domain roles — TARGET_IMPLEMENTATION

| Spacing role | Logical px |
| --- | --- |
| Phone page inset | 16 |
| Desktop page inset | 24 |
| Panel padding | 16 |
| Table cell padding | 12 |
| Column gap | 16 |
| Section gap | 32 |
| Minimum control height | 48 |

| Shape role | Approved C01 radius mapped by C03 |
| --- | --- |
| Control | 8 |
| Card | 12 |
| Sheet / dialog | 16 |

**Surface depth:** Flat → Approval table; Soft → Review panel; Raised → Review dialog. Depth is about placement, not status.

**Current-source migration observations:** Admin has 612 literal-radius and 390 literal all-padding markers. AdminTheme uses 10 for several field/button shapes while C01 approves control 8; card 12 and dialog 16 align. Its local widget variants and focus-border width need a bounded later migration rather than a new universal theme.

Source anchors:

- [admin_theme.dart](../../apps/admin/lib/app/themes/admin_theme.dart)
- [breakpoints.dart](../../packages/agrimore_ui/lib/responsive/breakpoints.dart)

- [seller_product_approval_screen.dart](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart)
- [finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart)

### Inventory coverage

The static scan includes these screen-family paths (counts include screen-support widgets, not unique screens):

| Family under app lib/screens | Source files |
| --- | --- |
| admin | 2 |
| admin/analytics | 1 |
| admin/banners | 3 |
| admin/benefit_program | 2 |
| admin/bestsellers | 2 |
| admin/category_sections | 2 |
| admin/coupon | 3 |
| admin/delivery | 17 |
| admin/employees | 7 |
| admin/finance | 3 |
| admin/home_sections | 2 |
| admin/notifications | 1 |
| admin/orders | 7 |
| admin/products | 11 |
| admin/reviews | 1 |
| admin/rewards | 1 |
| admin/section_banners | 2 |
| admin/security | 2 |
| admin/sellers | 7 |
| admin/settings | 6 |
| admin/sponsored_banners | 3 |
| admin/subscriptions | 1 |
| admin/support | 3 |
| admin/users | 5 |
| admin/vendors | 1 |
| admin/wallet | 1 |
| admin/widgets | 2 |
| auth | 1 |

## Future implementation boundary

Keep five independently owned theme/token entry points when migrating the system through agrimore_ui; shared geometry helpers do not imply one shared palette. Audit component exceptions before replacing every literal. Migrate tokens and affected components in a bounded implementation phase, then verify phone/wide × light/dark, increased text scale, keyboard/safe-area clearance, focus and interaction targets. This asset task changes no runtime tokens, widgets, packages, pubspec entries, branch state or live Firebase data.
