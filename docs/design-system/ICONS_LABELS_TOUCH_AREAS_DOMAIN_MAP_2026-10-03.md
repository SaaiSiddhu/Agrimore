# Agrimore — icons, labels and touch areas domain map

C04 · 2026-10-03. Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO.

## Evidence and authority

The fresh source scan read **815 files / 272,222 lines** across the five app lib trees, all three shared package lib trees and Functions src, excluding sensitive configuration/credential files. Observed branch `agrimore/foundation-f3c-distance-delivery-pricing` at `f87ce8cd53b6971650dd0aeb79ee164aa3865ef8`. Source hashes, syntax markers, existing icon-asset paths and screen-family inventory are retained in the session artifact `icons-labels-touch-areas/source-audit.json`. Selected direct reads cover icon registries, buttons, interactive/semantics helpers, quantity controls, code actions and admin refresh controls. This is static domain/interaction mapping, not independent rendering of every screen or a backend/security audit.

[C01 v2](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md) remains **OWNER_DECISION / APPROVED_LOCKED** for palettes, status colors, base spacing, radii and border widths. All ten reference images were inspected before C04 generation and their approved checksums checked. C02 and C03 remain provisional proposals; C04 reuses their role direction without treating it as owner approval. New icon/target/label mappings and ten C04 boards are **PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION**, not runtime migration or accessibility certification.

| App | Files | Direct Icons names | IconButton markers | Explicit Semantics widgets | Tooltip markers |
| --- | --- | --- | --- | --- | --- |
| Agrimore Marketplace | 211 | 1100 | 45 | 7 | 14 |
| Agrimore Seller | 116 | 0 | 10 | 73 | 10 |
| Agrimore Delivery | 99 | 0 | 16 | 16 | 17 |
| Agrimore Sales Associate | 26 | 29 | 16 | 0 | 3 |
| Agrimore Admin | 123 | 959 | 100 | 0 | 53 |

These are syntax occurrences, not unique controls or failures. Built-in widgets and shared components can provide labels/semantics without an app-local Semantics call. Central aliases explain zero raw Icons names in Seller and Delivery. Source counts cannot establish final hit bounds, announced strings, duplicate nodes, keyboard reachability or contrast. Those require rendered testing.

## Shared accessibility and interaction contract

- Separate **glyph bounds** from **interaction bounds**. All tappable targets have a proposed minimum of **48 × 48 logical px**; smaller 16/20/24 glyphs are centered inside the target. This baseline is supported by [Flutter’s accessibility checklist](https://docs.flutter.dev/ui/accessibility), which also calls for intelligible screen-reader descriptions, usability at large text/display scale and color-independent information. It is not a blanket claim of WCAG conformance.
- Delivery’s **56 × 56 field action** and **28 glyph** are proposals for glanceable task controls; ordinary actions remain ≥48. Sales Associate retains existing **52 minimum labeled button height** and ≥48 icon-only targets. Admin may have compact 20 glyphs but not 20/32/40 interaction bounds. Minimum heights grow with wrapping text.
- Target gaps are app roles on the approved spacing scale: Marketplace/Seller/Admin 8, Sales Associate 12, Delivery field controls 16. Independent targets never overlap. A row-level detail action and nested edit/menu button remain separately named/focusable; merging the whole row is appropriate only if it has one operation.
- Names describe the action and necessary entity context, without repeating the framework role (for example, button). Keep enabled/selected/toggled state separate. Visible labels and accessible names share intent; translated names use localized resources rather than English literals. Dynamic wishlist labels follow the real save/remove action; quantity actions identify product and current bounds.
- For icon-only actions, tooltips should describe the operation; [IconButton.tooltip](https://api.flutter.dev/flutter/material/IconButton/tooltip.html) is also used for accessibility. A [Semantics label](https://api.flutter.dev/flutter/semantics/SemanticsProperties/label.html) is a textual widget description, not an automatic substitute for role/state/value. Verify final semantics output when wrappers and built-in controls both contribute names.
- Decorative glyphs next to already labeled text should not create redundant announcements. Badge counts belong to their control’s accessible context. Selected/focused/disabled states use a text/shape/state signal in addition to color. A selected copy glyph is a state specimen, not a claim that a copy operation succeeded.
- Preserve existing icon registries where they exist: SellerIcons, DeliveryIcons and SaIcons use Lucide. Marketplace/Admin currently mix direct Material/other usage; C04 proposes coherent app-owned aliases and outlined groups in a later bounded migration. Distinct app systems come from domain vocabulary, density, size roles, target/label rules and brand usage, not five arbitrary new icon packages. Scale a glyph consistently; do not pretend a font Icon has a freely adjustable vector stroke parameter.
- Default icon colors use readable text roles; active controls use brand primary/onPrimary. Supporting gold/copper/burgundy/orange/indigo/cyan is contextual. Actual status pairs remain C01; do not replace selected/focus states with Success green. Dark filled buttons use the locked light primary and dark onPrimary pair.
- Keep C01 control/card/overlay radii and 1 default / 1 strong / 2 focus border widths. C04 does not unlock C01 or replace C03’s spacing/depth proposals. A single focus boundary reserves space and does not change target geometry. Circular status marks are glyphs, not a new core button shape.
- At large text size, long labels wrap and controls/rows expand. RTL back/forward conventions and visual/semantic order require explicit implementation review. Non-directional currency, camera, phone and brand-independent action meanings must not be mirrored indiscriminately.

## Agrimore Marketplace

Identity: Professional green; warm gold and natural stone. App directory: `apps/marketplace`.

**Icon direction:** Material outlined commerce icons, one consistent optical weight. Default outlines; a filled heart only for saved state, with text and semantic state. Do not mix FontAwesome and Material within a control group.

| Screen families / domain | Icons, labels and interaction responsibility |
| --- | --- |
| Home, search, categories, shop, wishlist, offers, flash sales, landing | Search/filter/cart/wishlist/order icons have consistent Material outline style; names identify actual actions. Saved state changes heart shape plus state text/semantics. Product-card save and purchase targets do not overlap. |
| Cart, checkout, coupons, addresses, payment, success, subscriptions | Name quantity increment/decrement and removal with product context; expose current quantity separately and disable bounds truthfully. ≥48 targets, 8 separation; payment/address actions retain readable visible text. |
| Orders, tracking, reviews and notifications | Tracking and support actions name destination/purpose; badge counts belong to the accessible control name. Timeline/status glyphs with matching text are decorative children, not redundant buttons. |
| Wallet, product credit, rewards, referral and transactions | Use wallet/receipt/reward meaning, never generic currency icons for every action; ledger arrows/status are noninteractive unless there is an actual detail action. |
| RFQ, business/profile, storefront, chat and AI | Quote, send, attach, copy and share labels name the actual operation; attachments and message controls keep separate hit areas. Do not merge a row’s detail action with a nested quote action. |
| Auth, onboarding, associate application, profile, settings, legal/help and seller handoff | Back/close/show-password/clear controls receive localized purpose labels; decorative form icons are excluded from duplicate announcements. Toggle values and errors are separate from names. |

### C04 proposed role map — TARGET_IMPLEMENTATION

| Icon / target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Shopping action glyph | 24 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 48 |
| Adjacent target gap | 8 |

Target anatomy specimen: **24 glyph inside 48 target**, centered inset **12 per side**. Adjacent target gap **8**. Insets derive from (target − glyph) / 2; 14 is calculated optical centering, not an added C03 spacing token.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Save | Save Fresh tomatoes | Not saved |
| Add to cart | Add Fresh tomatoes to cart | Enabled |
| Cart · 2 | Open cart, 2 items | Enabled |

**Current-source observations:** Marketplace has 1,100 direct Icons names, 127 FaIcon/FontAwesome markers and only 7 explicit Semantics-widget markers in its app lib tree. Built-in/shared controls can supply semantics without local markers. QuantitySelector._buildButton uses custom InkWell with no explicit action label and compact icon 18 plus padding 8, or normal icon 22 plus padding 10: declared base glyph/padding bounds are smaller than 48. Actual final hit-test geometry was not measured. Its delete-shaped glyph at the disabled minimum quantity also needs a truthful decrement/remove distinction in a later implementation phase.

Source anchors:

- [quantity_selector.dart](../../apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart)
- [unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [custom_button.dart](../../packages/agrimore_ui/lib/widgets/common/custom_button.dart)

### Inventory coverage

Counts include supporting screen widgets, not unique rendered screens.

| Path family under app lib/screens | Source files |
| --- | --- |
| auth | 9 |
| business | 3 |
| chat | 11 |
| employee | 7 |
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
| user/main_screen.dart | 1 |
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

Identity: Blue-teal; copper and cool neutrals. App directory: `apps/seller`.

**Icon direction:** Retain the centralized SellerIcons Lucide outline family, 24-unit grid and nominal 2 px stroke at 24 px. Scale complete glyphs uniformly for 20 px controls; no mixed raw Material or FontAwesome control group.

| Screen families / domain | Icons, labels and interaction responsibility |
| --- | --- |
| Home, insights and health | Retain centralized Lucide semantic aliases and 16/20/24 size roles. Info/chart actions need meaningful labels; trend glyphs and metric decoration are not standalone controls. |
| Products, variants, tax, add product and inventory | Product/stock/edit/filter actions name item context; 20 glyph inside ≥48 targets. Row navigation and nested edit controls are separate semantic actions. Compact data does not justify smaller tap areas. |
| Orders, invoices and stage/reason sheets | Order actions include relevant identifier; download/print/copy describe actual operation. Stage symbols are paired with readable status and do not depend on color alone. |
| RFQ inbox/detail, quote/counter/decline sheets | Quote/counter/review aliases remain distinct; copper signals quote context, not error or approval. Destructive/decline meaning needs explicit visible action text. |
| Payments, wallet, statements, payout profile and delivery fee | Payments/receipt/bank glyphs align to 20/24 roles. Financial controls use visible verb labels, truthful loading/disabled state and nonoverlapping hit regions. |
| Storefront, posts, followers, reviews, search, notifications and AI | Like/share/send/search-clear actions have localized names and state; badge count is associated with its control, not read as an unrelated floating number. |
| Auth, onboarding, profile, account, support, policies and shell | SellerIconButton already requires label and theme minimum 48; reuse this behavior. Preserve decorative icon exclusion and meaningful merged rows; verify nested chip-remove targets separately. |

### C04 proposed role map — TARGET_IMPLEMENTATION

| Icon / target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Inventory control glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 48 |
| Adjacent target gap | 8 |

Target anatomy specimen: **20 glyph inside 48 target**, centered inset **14 per side**. Adjacent target gap **8**. Insets derive from (target − glyph) / 2; 14 is calculated optical centering, not an added C03 spacing token.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Edit stock | Edit stock for Fresh tomatoes | Enabled |
| Review quote | Review quote RFQ-2048 | Enabled |
| Filter | Filter catalogue | Enabled |

**Current-source observations:** Seller has centralized Lucide aliases, required SellerIconButton.label mapped to tooltip, and theme minimum sizes 48. Its 73 Semantics / 21 MergeSemantics / 46 ExcludeSemantics markers are adoption evidence, not proof of accessible output. A nested chip remove button has an explicit width 40 and a chip-derived height; preserve its label while checking/enlarging the actual target later. The C01 target control radius 10 differs from current runtime 8.

Source anchors:

- [seller_icons.dart](../../apps/seller/lib/design_system/icons/seller_icons.dart)
- [seller_button.dart](../../apps/seller/lib/design_system/components/seller_button.dart)
- [seller_chips.dart](../../apps/seller/lib/design_system/components/seller_chips.dart)
- [seller_theme.dart](../../apps/seller/lib/design_system/theme/seller_theme.dart)

### Inventory coverage

Counts include supporting screen widgets, not unique rendered screens.

| Path family under app lib/screens | Source files |
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

Identity: Black/white; burgundy and burnt orange. App directory: `apps/delivery`.

**Icon direction:** Retain centralized DeliveryIcons Lucide outline and the existing house600 home exception. Regular glyphs 20/24; propose 28 px for critical field-task controls, scaling the same family uniformly rather than inventing heavier random strokes.

| Screen families / domain | Icons, labels and interaction responsibility |
| --- | --- |
| Incoming offers | Offer/task controls have explicit verb labels; time and distance symbols remain context. Preserve acceptance/rejection meaning and disabled state; no unlabeled accept checkmark or ambiguous close icon. |
| Home map, operations panel, active-work and pending-proof states | Route/recenter/list/task controls keep ≥48 target; proposed critical field controls 56 with 16 adjacent gap. The map drag surface is distinct from action hit areas; content/labels do not disappear at sheet collapse. |
| Active order, route/recovery, proof and problem panels | Pickup/drop/call/proof/support actions receive destination-specific names. Camera means add evidence, not completion. Cash banknote is contextual, not synonymous with earnings or collection confirmation. |
| Money, cash account, statements, bank changes and history | Cash/wallet/statement icons have different meanings; financial actions retain visible text. Ledger status is not made interactive solely because a glyph is present. |
| Inbox, support/help and request status | Problem/report/contact/retry meanings stay explicit; labeled targets remain large. Decorative severity icons do not duplicate message announcements. |
| Auth, registration, approval, profile/documents, identity, settings and readiness | Show/hide/clear/upload controls name their operation and target document. Readiness, permission and identity states use icons plus text; a disabled operation exposes truthful enabled state. |

### C04 proposed role map — TARGET_IMPLEMENTATION

| Icon / target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Standard control glyph | 24 |
| Field action glyph | 28 |
| Standard target | 48 |
| Field action target | 56 |
| Adjacent field gap | 16 |

Target anatomy specimen: **28 glyph inside 56 target**, centered inset **14 per side**. Adjacent target gap **16**. Insets derive from (target − glyph) / 2; 14 is calculated optical centering, not an added C03 spacing token.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Route | Open pickup route | Enabled |
| Call seller | Call pickup seller | Enabled |
| Add proof | Add pickup proof photo | Enabled |

**Current-source observations:** DeliveryIconButton requires tooltip, supplies a Semantics label and explicit ≥48 constraints. DeliveryInteractive adds semantics only when semanticLabel or semanticButton is supplied; caller coverage and possible duplicate labels in nested wrappers need runtime review. Existing sizes are 14/16/20/24/32/48; 28 field glyph and 56 field target are proposed C04/C03 roles, not current implementation. The house600 alias is a verified specific exception, not evidence that the entire family is bold.

Source anchors:

- [delivery_icons.dart](../../apps/delivery/lib/design_system/icons/delivery_icons.dart)
- [delivery_button.dart](../../apps/delivery/lib/design_system/components/delivery_button.dart)
- [delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart)
- [delivery_tokens.dart](../../apps/delivery/lib/design_system/tokens/delivery_tokens.dart)

### Inventory coverage

Counts include supporting screen widgets, not unique rendered screens.

| Path family under app lib/screens | Source files |
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

Identity: Premium royal blue; indigo and pearl/slate. App directory: `apps/employee`.

**Icon direction:** Retain SaIcons Lucide outline with 16 supporting / 20 control / 24 navigation roles. Calm consistent outline finance/identity icons; royal-blue actions and distinct indigo payout context.

| Screen families / domain | Icons, labels and interaction responsibility |
| --- | --- |
| Dashboard and notifications | Associate code copy/share controls identify code context; notifications include counts when present. Static balance/wallet decoration is not announced as an extra action. |
| Orders and detail | Order/commission actions name order context; credited/cancelled/eligible state stays text-backed. Navigation glyph does not imply earned commission. |
| Wallet, payout request/review/detail/history and payout account | 52 minimum labeled financial buttons; 48 icon-only actions. Review/request/copy-account meanings stay distinct; indigo is payout context, not payment success. |
| Auth/OTP, pending approval, suspended and onboarding status | OTP/password/retry actions have localized names and enabled state; decorative identity icons excluded. Approval/waiting symbols are not actionable unless backed by a real operation. |
| Profile, support and shell | Use SaIcons aliases and 16/20/24 roles; selected navigation state announced separately from its name. Long labels wrap and controls grow, with keyboard focus visible. |

### C04 proposed role map — TARGET_IMPLEMENTATION

| Icon / target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Code-action glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Primary button min height | 52 |
| Adjacent target gap | 12 |

Target anatomy specimen: **20 glyph inside 48 target**, centered inset **14 per side**. Adjacent target gap **12**. Insets derive from (target − glyph) / 2; 14 is calculated optical centering, not an added C03 spacing token.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Copy code | Copy associate code AG-2048 | Enabled |
| Share code | Share associate code AG-2048 | Enabled |
| Review payout | Review payout request | Enabled |

**Current-source observations:** The employee app contains no explicit local Semantics-widget markers, but shared SaLoadingButton supplies a label and enabled state, and built-in controls have framework semantics. Dashboard Share code has a tooltip; the copy-code InkWell has visible Tap to copy code helper text but no explicit action name in that block. Verify that it announces the action, not only a code/string. The shared loading button wraps a labeled built-in button, so duplicate announcements and clipped long labels need later rendered testing.

Source anchors:

- [sales_associate_icons.dart](../../packages/agrimore_ui/lib/themes/sales_associate_icons.dart)
- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)
- [sa_loading_button.dart](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart)
- [dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)

### Inventory coverage

Counts include supporting screen widgets, not unique rendered screens.

| Path family under app lib/screens | Source files |
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

Identity: Professional blue; cyan and steel/slate. App directory: `apps/admin`.

**Icon direction:** Professional Material outlined operations icons, consistent optical weight. 20 px table actions with 24 navigation; centralize semantic aliases in a later migration rather than mix decorative families or replace domain symbols arbitrarily.

| Screen families / domain | Icons, labels and interaction responsibility |
| --- | --- |
| Dashboard, analytics and finance | Chart/context icons are decorative unless they invoke real operations; refresh/export/reconcile need precise names. Use 20 action glyphs inside ≥48 targets, even on dense desktop pages. |
| Products, vendors, sellers, categories, orders and subscriptions | Table actions include entity/reference context; nested edit/delete/menu targets stay separate from row navigation. No unconditional merging of independent row actions. |
| Delivery, employees, users and application approvals | Review, approve, suspend and delete are different operations and glyph meanings. Permission availability controls actual enabled state; labels never imply approval from a checkmark alone. |
| Wallet, rewards, benefits, coupons and program controls | Financial/program actions retain visible verbs and context; status icons match text and C01 status pairs. Dense rows grow for large text and remain ≥48 if interactive. |
| Banners, sponsored/section banners, bestsellers and home/category sections | Edit/reorder/preview controls name content item and operation; drag operations require accessible alternatives in a later implementation review. |
| Security, settings, auth, notifications, support and reviews | Search/filter/show-password/close controls have localized labels; tooltips supplement visible text. Keyboard focus uses professional blue, selected state separately conveyed. |

### C04 proposed role map — TARGET_IMPLEMENTATION

| Icon / target role | Logical px |
| --- | --- |
| Supporting glyph | 16 |
| Table-action glyph | 20 |
| Navigation glyph | 24 |
| Icon-only target | 48 |
| Interactive row min height | 48 |
| Adjacent target gap | 8 |

Target anatomy specimen: **20 glyph inside 48 target**, centered inset **14 per side**. Adjacent target gap **8**. Insets derive from (target − glyph) / 2; 14 is calculated optical centering, not an added C03 spacing token.

| Visible label | Proposed accessible name | Separate state |
| --- | --- | --- |
| Filter | Filter seller applications | Enabled |
| Refresh | Refresh application list | Enabled |
| Review | Review seller application AGR-2048 | Enabled |

**Current-source observations:** Admin has 959 direct Icons names, 100 IconButton markers and 53 tooltip markers; counts cannot establish which controls lack labels. Finance Reconciliation refresh has a Re-scan tooltip, a concrete labeled example to retain. Local explicit Semantics markers are zero, but built-in/shared widgets provide implicit semantics. Dense nested action cells require contextual names, disjoint targets and keyboard focus checks in a later UI migration.

Source anchors:

- [admin_theme.dart](../../apps/admin/lib/app/themes/admin_theme.dart)
- [finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart)
- [seller_product_approval_screen.dart](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart)

### Inventory coverage

Counts include supporting screen widgets, not unique rendered screens.

| Path family under app lib/screens | Source files |
| --- | --- |
| admin/admin_dashboard.dart | 1 |
| admin/admin_shell.dart | 1 |
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

## Implementation and verification boundary

These boards document proposed labels and target roles. No runtime code, icon package, asset registration, shared theme/token, localization file, branch or shared work ledger is changed by this task. Preserve existing canonical icon registries; evaluate each component exception before consolidating remaining literals. A later implementation phase must verify actual ≥48 hit geometry, disjoint nested targets, TalkBack/VoiceOver names/role/state, localized and large-text layouts, keyboard focus/order and both light/dark themes. Asset validation verifies files/specifications/provenance, not executable accessibility behavior.
