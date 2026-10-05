# Agrimore — C28 component catalogue and adoption governance: codebase and adoption map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-04.** C01 remains APPROVED_LOCKED. C28 owner approval is pending. Assets/docs only.

[Ten-board gallery](COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_BOARDS_2026-10-04.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh coverage and evidence boundaries

Inventory HEAD: 64a71d4e6e6bff5ab04e9dcd38bc84d24f3b266a. 816 eligible files / 253097 lines across five app lib trees, three package lib trees and functions/src. Generated .g/.freezed sources, generated app_localizations classes, firebase_options and credential/secret-named files are excluded. Focused semantic reads covered app roots/themes, component/barrel definitions, declared variants, standalone catalogue/test sources and the five manually resolved callers below. This is a broad static inventory plus targeted analysis, not a read of every source line or a rendered audit of every screen.

The additional component map contains 57 candidate component-family source files and 372 Dart presentation files under apps/*/lib/screens, including nested widgets. A file is not necessarily a distinct route or screen. Candidate families cover Seller/Delivery local components, all shared widgets/workspace kit and app lib/widgets; private helpers, screen-local definitions, aliases, extensions, inherited Material styling and other folders require manual review. No total number of distinct components or percentage adopted is inferred.

Textual source inventory with lightweight comment/string screening; not Dart AST, resolved imports, route coverage, distinct screen counts, adoption percentages or rendered verification. Five separately reviewed call-site traces are SOURCE_TRACED only.

Marker totals below include comments, logs and usages; they are not defects, unique widgets, canonical coverage or migration progress.

| Scope | shared_ui_import | local_design_import | custom_components | inline_material | local_color_literals | state_parameters |
| --- | --- | --- | --- | --- | --- | --- |
| admin | 77 | 0 | 1 | 500 | 257 | 405 |
| delivery | 5 | 38 | 84 | 14 | 96 | 150 |
| employee | 21 | 0 | 36 | 36 | 4 | 59 |
| marketplace | 147 | 0 | 18 | 289 | 1120 | 256 |
| seller | 0 | 58 | 100 | 7 | 90 | 203 |
| functions | 0 | 0 | 0 | 0 | 0 | 1 |
| agrimore_core | 0 | 0 | 0 | 0 | 8 | 0 |
| agrimore_services | 0 | 0 | 0 | 3 | 3 | 2 |
| agrimore_ui | 0 | 0 | 20 | 47 | 266 | 27 |

## Shared catalogue and governance contract

1. Document each component family with source ownership, public API/variants, states, content and accessibility behavior, domain constraints and actual callers.
2. Catalogue definitions, source references, rendered states, tested interactions, review decisions and release adoption are distinct evidence stages. Never call a screen verified from an import, symbol count or raster mockup.
3. Retain five independent C01 identities and domain vocabularies. Shared generic behavior is reusable without making every app use the same palette, type scale or operational meaning.
4. Target package organization uses five app-owned folders: admin, marketplace, seller, sales_associate and delivery. These are future locations, not current folders or changes made by this asset task.
5. Reuse and extend documented primitives rather than creating equivalent wrappers; preserve valid domain-specific record/chart/map content inside canonical composition.
6. Each state example is independent: ready, busy, disabled, error, empty, restricted, focus, selection and recovery require appropriate actual contracts. No outcome follows from a catalogue specimen.
7. Static source tracing includes definition, resolved import/caller and state branch. Regex counts are candidates only; record ambiguity, aliases, hidden exports and mixed inline UI.
8. Verify screen adoption with rendered light/dark states, relevant widths/large text, meaningful interactions, semantics, keyboard/touch/reduced motion and error/recovery boundaries.
9. Use deterministic synthetic fixtures and safe preview mounts; do not access production accounts, private records or real financial/auth/delivery mutations for catalogue work.
10. Track exceptions and migration/deprecation decisions with exact caller scope and evidence. Remove a legacy API only after callers are migrated and relevant checks pass.
11. Preserve auth/session/owner guards, localization sources, navigation, privacy and server-authoritative outcomes during later presentation migration; do not treat them as duplicate UI.
12. C28 is asset documentation only: no runtime package folders, widgets, screen migration, render tests, adoption pass/completion percentages, assigned reviewer or release decision is created.

## Five domain systems

### Agrimore Marketplace

**Current source:** Marketplace root uses shared AppTheme, while screens also have app-local widgets and inline Material/literal presentation. Shared CustomButton declares filled/outlined/text with loading and null-callback disabling, but its explicit child text/spinner is white for all variants. ErrorView is used in EditProfileScreen session-change refusal; this proves a source use in that branch, not that every profile state is migrated or visually verified.

**Target:** Catalogue customer action variants, read states and product composition with locked C01 roles. Track each screen/branch against component source and rendered state evidence; later package ownership should give Marketplace its own folder/API without moving shopper behavior or conflating shared imports with adoption.

| Panel | Domain specimen |
| --- | --- |
| Customer action variants | Panel "Action variants": three independently labelled examples "Primary", "Secondary", "Text action", each with exact action "View details"; filled, outlined and text-only using C01 primary. Gold note "Use a variant for its action priority". |
| Read-state examples | Panel "State examples": compact independent rows "Ready" with View details button, "Loading" with static neutral progress icon plus "Loading details…", "Unavailable" with disabled View details and helper "Action unavailable in this example". Caption "Independent examples". Gold note "Document state meaning and recovery". No percentage, real task or outcome. |
| Customer composition | Panel "Product composition": synthetic neutral product icon, title "Vegetable growing kit", small text "Product information", primary "View product details" and outlined "Choose options". External annotation "Card + content + actions" and "Target composition". No price, availability or cart result. |
| Honest screen adoption | Panel "Adoption evidence": a developer-documentation record "Edit profile" with "ErrorView", rows "Source use located" and "Render review pending"; below proposed review steps "Component", "Screen state", "Rendered evidence", "Review decision". Gold note "Source use is not a completed screen migration". Explicit "Source trace / Target review record". No completed/approved/pass badge, progress percentage or operational user workflow. |

Preserve or resolve:

- Shared CustomButton and the hidden CustomButton in custom_bottom_nav are separate declarations; textual symbol matches need import resolution.
- Catalogue variants require correct foreground roles; C28 depicts target C01 roles rather than copying current white-label secondary risk.
- Account/session refusal branches are not ordinary retry branches; do not replace their recovery with a generic retry.
- A product/domain card can compose canonical primitives without deleting merchant/customer domain content.

Sources:

- [apps/marketplace/lib/app/app.dart](../../apps/marketplace/lib/app/app.dart)
- [apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart)
- [apps/marketplace/lib/widgets/product/unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [packages/agrimore_ui/lib/widgets/common/custom_button.dart](../../packages/agrimore_ui/lib/widgets/common/custom_button.dart)
- [packages/agrimore_ui/lib/widgets/common/error_view.dart](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)
- [packages/agrimore_ui/lib/agrimore_ui.dart](../../packages/agrimore_ui/lib/agrimore_ui.dart)

### Agrimore Seller

**Current source:** Seller owns app-local design_system barrel/tokens/theme and reusable components. SellerButton declares primary, secondary, tertiary, tonal, danger and dangerOutline, plus loading/compact/focus semantics. SellerProductsScreen composes SellerSearchField, SellerErrorState/SkeletonList/EmptyState and SellerButton variants. catalogue_visual_test is a product catalogue-screen test harness, not a standalone all-components Storybook application.

**Target:** Catalogue merchant variants/states and product-edit composition with source ownership and per-screen evidence. Preserve own-border keyboard focus, reduced motion, loading guard and localization. A future seller package folder is an explicit ownership/migration target, not evidence that the current app-local library already lives there.

| Panel | Domain specimen |
| --- | --- |
| Merchant action variants | Panel "Action variants": labelled "Primary", "Secondary", "Tonal", each exact "Review details"; C01 filled, outlined and subtle selected-container specimens. Copper note "Keep merchant action priority consistent". No destructive/save/publish state. |
| Merchant component states | Panel "State examples": independent rows "Ready" with Review details, "Loading" with static hourglass and "Loading product details…", "Unavailable" disabled Review details with "Action unavailable in this example". Caption "Independent examples". Copper note "Include busy and unavailable examples". |
| Editor composition | Panel "Editor composition": title "Product details", visible labels "Product name" and "Description" above empty neutral fields; primary "Review product details", secondary "Back". External annotation "Fields + section + actions", "Target composition". Copper note "Compose editor patterns from reusable parts". No save outcome or real product. |
| Merchant source evidence | Panel "Adoption evidence": documentation record "Product catalogue" with "SellerSearchField"; rows "Source use located", "Render review pending"; proposed steps "Component", "Screen state", "Rendered evidence", "Review decision"; copper note "Check each screen state before adoption sign-off"; caption "Source trace / Target review record". No approval/tick/completion claim. |

Preserve or resolve:

- Product Catalogue as a business destination is different from a developer component catalogue.
- Native component tokens/geometry differ from C01 board tokens; docs must not claim the artwork was adopted in runtime.
- Danger/secondary/tonal need their own behavior/state contracts; generic action examples do not authorize destructive merchant actions.
- Catalogue test-source existence is not execution or visual acceptance.

Sources:

- [apps/seller/lib/design_system/design_system.dart](../../apps/seller/lib/design_system/design_system.dart)
- [apps/seller/lib/design_system/components/seller_button.dart](../../apps/seller/lib/design_system/components/seller_button.dart)
- [apps/seller/lib/design_system/components/seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart)
- [apps/seller/lib/design_system/theme/seller_focus.dart](../../apps/seller/lib/design_system/theme/seller_focus.dart)
- [apps/seller/lib/screens/products/seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [apps/seller/test/visual/catalogue_visual_test.dart](../../apps/seller/test/visual/catalogue_visual_test.dart)

### Agrimore Delivery

**Current source:** Delivery owns app-local design_system library with button, card, field, banner, layout, list, route/media and state families. DeliveryButton declares primary/secondary/tonal/ghost/danger and sizes sm/md/lg with loading aliases; its actual labels are capped, so comments about universal 200% wrapping are not runtime proof. ActiveOrderScreen uses DeliveryButton and DeliveryBanner; profile uses DeliveryCard. Design-system tests exist but were not executed for C28.

**Target:** Catalogue rider action/state contracts and instruction composition with correct C01 monochrome primary and orange/burgundy support. Source mapping must distinguish route/offer/task/proof/verification branches and preserve operational/server state. Trace plus rendered evidence is required for later adoption.

| Panel | Domain specimen |
| --- | --- |
| Rider action variants | Panel "Action variants": labelled "Primary", "Secondary", "Quiet action" each "Review instructions"; monochrome filled, outlined and text-only. Orange note "Keep the main rider action unmistakable". Quiet action is target ghost-style sample, not a new variant claim. |
| Rider state examples | Panel "State examples": independent rows "Ready" with Review instructions, "Loading" static neutral progress icon and "Loading task details…", "Unavailable" disabled Review instructions with "Action unavailable in this example". Caption "Independent examples"; orange note "Show state without implying completion". No location/route/ETA outcome. |
| Instruction composition | Panel "Task composition": heading "Pickup instructions", readable text "Review the collection instructions before continuing."; primary "Review instructions", secondary "Help". External annotation "Instruction card + context + actions", "Target composition". No actual pickup, route, phone/address or emergency action. |
| Rider source evidence | Panel "Adoption evidence": documentation record "Active order" with "DeliveryButton"; rows "Source use located", "Render review pending"; proposed steps "Component", "Screen state", "Rendered evidence", "Review decision"; burgundy note "Review task states and safe recovery separately"; caption "Source trace / Target review record". No delivery/approval/verified test result. |

Preserve or resolve:

- Do not equate Delivery barrel comments about orange primary with the approved C01 monochrome target identity.
- Read loading examples do not imply a delivery-confirmation, proof upload or command was completed.
- Focus/large-label limits and size/target behavior need actual state/device tests, not source comments alone.
- A shared delivery package folder is a future migration target; existing app-local imports must be transitioned deliberately.

Sources:

- [apps/delivery/lib/design_system/design_system.dart](../../apps/delivery/lib/design_system/design_system.dart)
- [apps/delivery/lib/design_system/components/delivery_button.dart](../../apps/delivery/lib/design_system/components/delivery_button.dart)
- [apps/delivery/lib/design_system/components/delivery_banner.dart](../../apps/delivery/lib/design_system/components/delivery_banner.dart)
- [apps/delivery/lib/design_system/components/delivery_card.dart](../../apps/delivery/lib/design_system/components/delivery_card.dart)
- [apps/delivery/lib/screens/orders/active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)
- [apps/delivery/test/design_system_test.dart](../../apps/delivery/test/design_system_test.dart)

### Agrimore Sales Associate

**Current source:** Sales Associate production root uses shared SalesAssociateTheme and shared SaLoadingButton/SaInfoBanner alongside inline Material fields/cards. SaLoadingButton declares primary/outlined and loading/disabled controls. SaCatalogueApp is a standalone developer entry point without Firebase initialization: it declares a light theme, has typography text-scale slider and component loading switch, and shows synthetic tokens/components/content. It does not wire a dark theme, and its existing light token values differ from approved C01 board metadata. ForgotPasswordScreen directly uses SaLoadingButton.

**Target:** Catalogue associate action/banners/form/record composition while keeping tooling examples separate from production adoption. Extend later catalogue verification to C01 identities and both themes with actual screen states, privacy and ownership checks. Proposed sales_associate package folder should retain existing APIs/callers during a deliberate migration.

| Panel | Domain specimen |
| --- | --- |
| Associate action variants | Panel "Action variants": labelled "Primary" and "Outlined" with exact "View order details"; primary blue filled and secondary outlined. Indigo note "Document the associate action contract". No invented tertiary SaButtonVariant. |
| Associate state examples | Panel "State examples": independent rows "Ready" with View order details, "Loading" static progress icon with "Loading order details…", "Unavailable" disabled View order details plus "Action unavailable in this example". Caption "Independent examples". Indigo note "Catalogue examples are not live records". |
| Associate record composition | Panel "Record composition": title "Attributed order details", body "Order information", neutral record icon; primary "View order details", secondary "Back". External annotation "Record + context + actions", "Target composition". No real record, commission, payout, balance or program promise. |
| Associate source evidence | Panel "Adoption evidence": documentation record "Forgot password" with "SaLoadingButton"; rows "Source use located", "Render review pending"; proposed stages "Component", "Screen state", "Rendered evidence", "Review decision". Indigo note "Verify production screens beyond the catalogue"; caption "Source trace / Target review record". No actual account/password reset, pass badge or finished migration. |

Preserve or resolve:

- Standalone catalogue rendering or a source test cannot prove every production screen adopted its components.
- Do not replace behavioral/access state or financial/request ownership while migrating presentation.
- Current catalogue dark-theme coverage is absent at the root; C28 dark artwork is a target, not a screenshot of that app.
- Two-line label caps and legacy inline forms still need per-state rendered review; no adoption completion percentage invented.

Sources:

- [apps/employee/lib/app/app.dart](../../apps/employee/lib/app/app.dart)
- [apps/employee/lib/catalogue/catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart)
- [apps/employee/lib/catalogue/main_catalogue.dart](../../apps/employee/lib/catalogue/main_catalogue.dart)
- [packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart)
- [packages/agrimore_ui/lib/widgets/common/sa_info_banner.dart](../../packages/agrimore_ui/lib/widgets/common/sa_info_banner.dart)
- [apps/employee/lib/screens/auth/forgot_password_screen.dart](../../apps/employee/lib/screens/auth/forgot_password_screen.dart)
- [apps/employee/test/design_system/catalogue_test.dart](../../apps/employee/test/design_system/catalogue_test.dart)

### Agrimore Admin

**Current source:** Admin root uses its own AdminTheme with Material button/card/input theming while screens mix inline Material structures and shared feedback helpers. SupportCaseDetailScreen calls SnackbarHelper.showError/showSuccess; this is source-confirmed helper use, not whole-screen canonical adoption. No standalone developer component-catalogue entry point was located in the scanned Admin lib tree. Shared CustomButton uses generic AppColors rather than automatically following AdminTheme.

**Target:** Catalogue operations control variants and context-heavy record composition, then map every review screen/branch to the intended admin-owned API and evidence. Preserve permissions, server-confirmed actions and private evidence. A future admin folder in agrimore_ui is an ownership target, not an existing folder or completed refactor.

| Panel | Domain specimen |
| --- | --- |
| Operations action variants | Panel "Action variants": labelled "Primary", "Secondary", "Text action" each "Open details"; professional-blue filled, outlined and text-only specimens. Cyan note "Document review actions by priority". |
| Review state examples | Panel "State examples": independent rows "Ready" with Open details, "Loading" static progress icon plus "Loading case details…", "Unavailable" disabled Open details with "Action unavailable in this example"; caption "Independent examples". Cyan note "Keep state and permissions distinct". No real denial, approval or resolved case. |
| Review composition | Panel "Case composition": title "Support case details", body "Review the available context.", neutral document icon; primary "Open case details", secondary "Back". External annotation "Record + context + actions", "Target composition". No case ID, user evidence, account or audit outcome. |
| Operations source evidence | Panel "Adoption evidence": documentation record "Support case" with "SnackbarHelper"; rows "Source use located", "Render review pending"; proposed steps "Component", "Screen state", "Rendered evidence", "Review decision". Cyan note "Helper usage is not whole-screen adoption"; caption "Source trace / Target review record". No fake success toast, passed coverage percentage, approved account or resolved case. |

Preserve or resolve:

- A themed Material control can be valid canonical composition if its contract is documented; wrapper presence alone is not the adoption criterion.
- Feedback-helper use does not prove caller copy is sanitized or entire case workflow is redesigned.
- Generic shared primary colors and AdminTheme can disagree; approved C01 identity needs explicit migration rather than assuming inheritance.
- Tables/details/dialogs need their own branch/keyboard/viewport evidence before a screen is marked verified.

Sources:

- [apps/admin/lib/app/app.dart](../../apps/admin/lib/app/app.dart)
- [apps/admin/lib/app/themes/admin_theme.dart](../../apps/admin/lib/app/themes/admin_theme.dart)
- [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart)
- [packages/agrimore_ui/lib/widgets/snackbar_helper.dart](../../packages/agrimore_ui/lib/widgets/snackbar_helper.dart)
- [packages/agrimore_ui/lib/widgets/common/custom_button.dart](../../packages/agrimore_ui/lib/widgets/common/custom_button.dart)

## Five manually traced uses

Each caller and definition was read, its barrel/import chain checked, and the relevant branch distinguished. SOURCE_TRACED proves an existing call site only. Render review, interaction checks, C01 visual match and whole-screen adoption were not performed. These are the five source records pictured in panel four.

| App / record | Actual caller | Actual definition | State scope | Evidence |
| --- | --- | --- | --- | --- |
| marketplace / Edit profile | [apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart:1120](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) | [ErrorView](../../packages/agrimore_ui/lib/widgets/common/error_view.dart) | Session ownership refusal: !_ownsForm; useThemeColors true, no ordinary retry supplied. | SOURCE_TRACED · Render NOT_RUN · Adoption NOT_VERIFIED |
| seller / Product catalogue | [apps/seller/lib/screens/products/seller_products_screen.dart:244](../../apps/seller/lib/screens/products/seller_products_screen.dart) | [SellerSearchField](../../apps/seller/lib/design_system/components/seller_search.dart) | Search field in product catalogue composition, not every product editor/list state. | SOURCE_TRACED · Render NOT_RUN · Adoption NOT_VERIFIED |
| delivery / Active order | [apps/delivery/lib/screens/orders/active_order_screen.dart:483](../../apps/delivery/lib/screens/orders/active_order_screen.dart) | [DeliveryButton](../../apps/delivery/lib/design_system/components/delivery_button.dart) | Secondary button call in active-order presentation; other task/proof/command branches need separate review. | SOURCE_TRACED · Render NOT_RUN · Adoption NOT_VERIFIED |
| sales-associate / Forgot password | [apps/employee/lib/screens/auth/forgot_password_screen.dart:139](../../apps/employee/lib/screens/auth/forgot_password_screen.dart) | [SaLoadingButton](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart) | Reset-link action uses _isSubmitting guard. Source use does not prove a reset-link result. | SOURCE_TRACED · Render NOT_RUN · Adoption NOT_VERIFIED |
| admin / Support case | [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart:92](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) | [SnackbarHelper](../../packages/agrimore_ui/lib/widgets/snackbar_helper.dart) | FirebaseFunctionsException catch feedback. Helper use is not whole-screen adoption or copy sanitization. | SOURCE_TRACED · Render NOT_RUN · Adoption NOT_VERIFIED |

Per-app manifests record caller/definition hashes, lines, import dependency, branch scope and explicit pending status. Source references are snapshots and must be rechecked against later code changes. A production branch that uses one component does not establish coverage of every branch, theme, device or state on that screen.

## Current component families and variants

This source index lists public class declarations and enum values, not approved APIs or rendered coverage. Helpers, navigation data and feedback utilities can appear alongside widgets. Textual candidates are deliberately not upgraded to verified use.

| Layer | Source family | Public declarations | Declared enums | Candidate caller files |
| --- | --- | --- | --- | --- |
| delivery | [delivery_badge.dart](../../apps/delivery/lib/design_system/components/delivery_badge.dart) | DeliveryBadge, DeliveryCountPill, DeliveryCountdownRing | None | 3 |
| delivery | [delivery_banner.dart](../../apps/delivery/lib/design_system/components/delivery_banner.dart) | DeliveryBanner | None | 8 |
| delivery | [delivery_brand.dart](../../apps/delivery/lib/design_system/components/delivery_brand.dart) | DeliveryBrandMark, DeliveryLogo, DeliveryHeroIllustration, DeliveryVehicleIllustration, DeliveryIllustration, DeliveryVehicleOption, DeliveryVehicleSelector, DeliveryTestDataRibbon | DeliveryIllustrationKind: empty, emptyHistory, offline, kycReview, kycRejected, orderComplete, warning, error; DeliveryVehicleKind: bicycle, motorcycle, scooter, evTwoWheeler, autoThreeWheeler, miniTruck | 4 |
| delivery | [delivery_button.dart](../../apps/delivery/lib/design_system/components/delivery_button.dart) | DeliveryButton, DeliveryIconButton | DeliveryButtonVariant: primary, secondary, tonal, ghost, danger; DeliveryButtonSize: sm, md, lg | 19 |
| delivery | [delivery_card.dart](../../apps/delivery/lib/design_system/components/delivery_card.dart) | DeliveryCard, DeliverySectionHeader | DeliveryCardVariant: standard, muted, brand, outlined, elevated | 15 |
| delivery | [delivery_chips.dart](../../apps/delivery/lib/design_system/components/delivery_chips.dart) | DeliveryChipItem, DeliveryChipRow, DeliverySegmented | None | 3 |
| delivery | [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart) | DeliveryEmptyState, DeliveryErrorState, DeliveryLoadingList | None | 2 |
| delivery | [delivery_fields.dart](../../apps/delivery/lib/design_system/components/delivery_fields.dart) | DeliveryTextField, DeliveryPasswordField, DeliveryCurrencyField | None | 0 |
| delivery | [delivery_layout.dart](../../apps/delivery/lib/design_system/components/delivery_layout.dart) | DeliveryAppBar, DeliveryBottomActionBar, DeliveryResponsiveBody | None | 0 |
| delivery | [delivery_list.dart](../../apps/delivery/lib/design_system/components/delivery_list.dart) | DeliveryAvatar, DeliveryListTile, DeliveryKeyValueRow | None | 1 |
| delivery | [delivery_media.dart](../../apps/delivery/lib/design_system/components/delivery_media.dart) | DeliveryDocUploadTile | DeliveryPhotoSlotState: empty, uploading, ready, error | 0 |
| delivery | [delivery_metrics.dart](../../apps/delivery/lib/design_system/components/delivery_metrics.dart) | DeliveryMetricTile, DeliveryMoneyLine, DeliveryMoneyBreakdown | None | 0 |
| delivery | [delivery_nav.dart](../../apps/delivery/lib/design_system/components/delivery_nav.dart) | DeliveryNavDestination, DeliveryBottomNav, DeliveryOnlineSwitch | None | 0 |
| delivery | [delivery_otp.dart](../../apps/delivery/lib/design_system/components/delivery_otp.dart) | DeliveryOtpField | None | 1 |
| delivery | [delivery_search.dart](../../apps/delivery/lib/design_system/components/delivery_search.dart) | DeliverySearchField | None | 1 |
| delivery | [delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart) | DeliveryInteractive, DeliverySkeleton, DeliveryLoadingState | None | 2 |
| delivery | [delivery_timeline.dart](../../apps/delivery/lib/design_system/components/delivery_timeline.dart) | DeliveryTimelineStep, DeliveryStepIndicator, DeliveryRouteTimeline, DeliveryMapHeader | DeliveryTimelineStepState: completed, active, upcoming, error | 3 |
| marketplace | [auth_gate.dart](../../apps/marketplace/lib/widgets/auth_gate.dart) | AuthGate | None | 0 |
| marketplace | [cart_fly_animation.dart](../../apps/marketplace/lib/widgets/cart_fly_animation.dart) | CartFlyAnimationOverlay | None | 1 |
| marketplace | [category_card.dart](../../apps/marketplace/lib/widgets/category/category_card.dart) | CategoryCard | None | 0 |
| marketplace | [unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart) | UnifiedProductCard | ProductCardLayout: grid, list, compact, horizontal, shop, home | 5 |
| seller | [seller_badge.dart](../../apps/seller/lib/design_system/components/seller_badge.dart) | SellerStatusBadge, SellerTag, SellerDot, SellerCount | None | 17 |
| seller | [seller_banner.dart](../../apps/seller/lib/design_system/components/seller_banner.dart) | SellerBanner | None | 32 |
| seller | [seller_brand.dart](../../apps/seller/lib/design_system/components/seller_brand.dart) | SellerLeafMark, SellerLogo, SellerIllustration, SellerTestDataRibbon, SellerFarmScene, SellerGoogleMark | None | 6 |
| seller | [seller_button.dart](../../apps/seller/lib/design_system/components/seller_button.dart) | SellerButton, SellerIconButton, SellerFab | SellerButtonVariant: primary, secondary, tertiary, tonal, danger, dangerOutline | 38 |
| seller | [seller_card.dart](../../apps/seller/lib/design_system/components/seller_card.dart) | SellerCard, SellerIconTile | SellerCardTone: surface, subtle, mint, sunken, success, warning, danger, info | 34 |
| seller | [seller_charts.dart](../../apps/seller/lib/design_system/components/seller_charts.dart) | SellerChartPoint, SellerChartSeries, SellerLineChart, SellerSparkline, SellerBarChart, SellerBarItem, SellerBarList, SellerComparisonBars, SellerMeter, SellerDonut, SellerScoreRing, SellerLegendItem, SellerChartLegend, SellerTableColumn, SellerDataTable, SellerChartUnavailable, SellerDashedBorder, SellerChartCard | SellerBarStyle: solid, hatched; SellerLegendKind: line, dashedLine, bar, hatchedBar | 4 |
| seller | [seller_chips.dart](../../apps/seller/lib/design_system/components/seller_chips.dart) | SellerChip, SellerChipBar, SellerSegment, SellerSegmented | SellerChipStyle: tab, toggle | 17 |
| seller | [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart) | SellerToast, SellerDiscardGuard, SellerSheetFrame | SellerToastTone: neutral, success, danger | 23 |
| seller | [seller_fields.dart](../../apps/seller/lib/design_system/components/seller_fields.dart) | SellerFormScope, SellerFormScopeState, SellerFieldLabel, SellerFieldMessage, SellerTextField, SellerOption, SellerSelectField, SellerPickerField, SellerSliderField, SellerChoiceRow, SellerCheckRow, SellerSwitchRow, SellerFormErrorSummary | None | 23 |
| seller | [seller_layout.dart](../../apps/seller/lib/design_system/components/seller_layout.dart) | SellerPage, SellerStickyFooter, SellerButtonBar, SellerListDetail, SellerOrDivider, SellerExpandableRow | None | 36 |
| seller | [seller_list.dart](../../apps/seller/lib/design_system/components/seller_list.dart) | SellerListRow, SellerMenuGroup, SellerKeyValueRow, SellerSectionHeader | None | 25 |
| seller | [seller_media.dart](../../apps/seller/lib/design_system/components/seller_media.dart) | SellerImage, SellerAvatar, SellerPhotoTile | SellerUploadState: empty, uploading, uploaded, failed | 11 |
| seller | [seller_metrics.dart](../../apps/seller/lib/design_system/components/seller_metrics.dart) | SellerDelta, SellerMetricCard, SellerMoneyLine, SellerMoneyBreakdown, SellerAmountHero | SellerTrend: up, down, flat, none | 7 |
| seller | [seller_nav.dart](../../apps/seller/lib/design_system/components/seller_nav.dart) | SellerNavItem, SellerNavBar, SellerNavRail, SellerAppBar | None | 33 |
| seller | [seller_otp.dart](../../apps/seller/lib/design_system/components/seller_otp.dart) | SellerOtpInput | None | 1 |
| seller | [seller_search.dart](../../apps/seller/lib/design_system/components/seller_search.dart) | SellerSearchField | None | 4 |
| seller | [seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart) | SellerSpinner, SellerProgressLabel, SellerLoadingView, SellerSkeleton, SellerSkeletonList, SellerEmptyState, SellerErrorState | None | 25 |
| seller | [seller_timeline.dart](../../apps/seller/lib/design_system/components/seller_timeline.dart) | SellerTimelineStep, SellerTimeline, SellerStepProgress | SellerStepState: done, current, upcoming, failed; SellerStepProgressStyle: dots, segments | 5 |
| shared | [custom_bottom_nav.dart](../../packages/agrimore_ui/lib/widgets/common/custom_bottom_nav.dart) | CustomButton | ButtonType: primary, secondary, outlined, text | 2 |
| shared | [custom_button.dart](../../packages/agrimore_ui/lib/widgets/common/custom_button.dart) | CustomButton | ButtonType: filled, outlined, text | 2 |
| shared | [custom_text_field.dart](../../packages/agrimore_ui/lib/widgets/common/custom_text_field.dart) | CustomTextField | None | 0 |
| shared | [empty_state_widget.dart](../../packages/agrimore_ui/lib/widgets/common/empty_state_widget.dart) | EmptyState | None | 4 |
| shared | [error_view.dart](../../packages/agrimore_ui/lib/widgets/common/error_view.dart) | ErrorView | None | 11 |
| shared | [loading_overlay.dart](../../packages/agrimore_ui/lib/widgets/common/loading_overlay.dart) | LoadingOverlay | None | 0 |
| shared | [sa_info_banner.dart](../../packages/agrimore_ui/lib/widgets/common/sa_info_banner.dart) | SaInfoBanner | SaBannerVariant: info, warning, error, success | 8 |
| shared | [sa_loading_button.dart](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart) | SaLoadingButton | SaButtonVariant: primary, outlined | 9 |
| shared | [sticky_photo_header.dart](../../packages/agrimore_ui/lib/widgets/common/sticky_photo_header.dart) | StickyHeaderBackButton, StickyPhotoHeaderSliver | None | 2 |
| shared | [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart) | DialogHelper | None | 7 |
| shared | [premium_splash_screen.dart](../../packages/agrimore_ui/lib/widgets/premium_splash_screen.dart) | PremiumSplashScreen | SplashAnimationType: customer, seller, delivery, admin | 0 |
| shared | [snackbar_helper.dart](../../packages/agrimore_ui/lib/widgets/snackbar_helper.dart) | SnackbarHelper | None | 62 |
| shared | [ws_countdown_ring.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_countdown_ring.dart) | WsCountdownRing | None | 0 |
| shared | [ws_feedback.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_feedback.dart) | WsToast | WsToastTone: neutral, success, error | 0 |
| shared | [ws_otp_input.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_otp_input.dart) | WsOtpInput | None | 0 |
| shared | [ws_step_header.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_step_header.dart) | WsStepHeader | None | 0 |
| shared | [ws_test_mode_ribbon.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_test_mode_ribbon.dart) | WsTestModeRibbon | None | 0 |
| shared | [ws_timeline.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_timeline.dart) | WsTimelineStep, WsTimeline | WsTimelineState: done, current, upcoming | 0 |

The shared package has two public CustomButton class declarations and two ButtonType enums in custom_button.dart and custom_bottom_nav.dart. The root barrel hides the latter CustomButton/ButtonType exports. A name-only match cannot decide which class a caller uses; imports/exports must be resolved before adoption. SellerButtonVariant has primary, secondary, tertiary, tonal, danger, dangerOutline; DeliveryButtonVariant has primary, secondary, tonal, ghost, danger with sm/md/lg sizes; SaButtonVariant has primary/outlined. Board labels describe target action priority, not newly implemented enum members.

Generic CustomButton explicitly uses white label/spinner content for filled, outlined and text variants; this may conflict with a neutral secondary surface. AdminTheme and generic shared AppColors also do not guarantee one identity. C28 specimens follow approved C01 roles; these findings were documented, not patched. Seller/Delivery live tokens and geometry likewise are not silently claimed to equal approved raster tokens. Existing private domain cards/charts/maps should retain their content and business state while composing approved primitives.

## Complete presentation-file mapping queue

Every eligible Dart file currently under each app lib/screens is listed separately. Symbols are call-pattern candidates after lightweight comment/string screening; static helper calls are included. The method does not resolve imports, scope shadowing, factory aliases, generated routes or all Dart syntax. Repeated names, ambiguous exports and files without candidate matches need manual mapping. Inline Material is not automatically a defect: a properly themed Material control can satisfy a documented canonical contract. All rows remain render-pending and adoption-unverified. Full candidate definitions, lines, imports and file hashes are in the app manifests.

### Agrimore Marketplace — 155 presentation files

| Source file | Candidate symbols | Inline Material call markers | Mapping / render / adoption |
| --- | --- | --- | --- |
| [apps/marketplace/lib/screens/auth/auth_guard.dart](../../apps/marketplace/lib/screens/auth/auth_guard.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/auth_wrapper.dart](../../apps/marketplace/lib/screens/auth/auth_wrapper.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/complete_profile_screen.dart](../../apps/marketplace/lib/screens/auth/complete_profile_screen.dart) | ErrorView | ElevatedButton × 6, TextButton × 1, TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/enable_notifications_screen.dart](../../apps/marketplace/lib/screens/auth/enable_notifications_screen.dart) | Manual mapping needed | ElevatedButton × 2, OutlinedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/login_screen.dart](../../apps/marketplace/lib/screens/auth/login_screen.dart) | SnackbarHelper | ElevatedButton × 2, OutlinedButton × 2, TextButton × 2, TextFormField × 1, TextField × 1, ListTile × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/mobile_number_screen.dart](../../apps/marketplace/lib/screens/auth/mobile_number_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/onboarding_address_screen.dart](../../apps/marketplace/lib/screens/auth/onboarding_address_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/post_auth_router.dart](../../apps/marketplace/lib/screens/auth/post_auth_router.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/auth/signup_screen.dart](../../apps/marketplace/lib/screens/auth/signup_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/business/business_feed_screen.dart](../../apps/marketplace/lib/screens/business/business_feed_screen.dart) | EmptyState, ErrorView | OutlinedButton × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/business/business_profile_screen.dart](../../apps/marketplace/lib/screens/business/business_profile_screen.dart) | EmptyState, ErrorView, SnackbarHelper | OutlinedButton × 4 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/business/storefront_visibility.dart](../../apps/marketplace/lib/screens/business/storefront_visibility.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/ai_chat_screen.dart](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) | Manual mapping needed | TextButton × 2, TextField × 1, AlertDialog × 1, SnackBar × 2, ListTile × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/chat_history_screen.dart](../../apps/marketplace/lib/screens/chat/chat_history_screen.dart) | Manual mapping needed | TextButton × 1, Card × 1, AlertDialog × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/chat_app_bar.dart](../../apps/marketplace/lib/screens/chat/widgets/chat_app_bar.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/chat_message_widget.dart](../../apps/marketplace/lib/screens/chat/widgets/chat_message_widget.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/message_bubble.dart](../../apps/marketplace/lib/screens/chat/widgets/message_bubble.dart) | Manual mapping needed | TextButton × 2, AlertDialog × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/message_list_view.dart](../../apps/marketplace/lib/screens/chat/widgets/message_list_view.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/order_card_renderer.dart](../../apps/marketplace/lib/screens/chat/widgets/order_card_renderer.dart) | Manual mapping needed | Card × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/product_card_horizontal.dart](../../apps/marketplace/lib/screens/chat/widgets/product_card_horizontal.dart) | UnifiedProductCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/product_card_widget.dart](../../apps/marketplace/lib/screens/chat/widgets/product_card_widget.dart) | UnifiedProductCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/quick_reply_chip.dart](../../apps/marketplace/lib/screens/chat/widgets/quick_reply_chip.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/chat/widgets/typing_indicator.dart](../../apps/marketplace/lib/screens/chat/widgets/typing_indicator.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/employee_apply_screen.dart](../../apps/marketplace/lib/screens/employee/employee_apply_screen.dart) | Manual mapping needed | TextField × 1, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) | Manual mapping needed | ElevatedButton × 4 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_confirmation_step.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_confirmation_step.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_details_step.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_details_step.dart) | Manual mapping needed | ElevatedButton × 2, TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_fee_text.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_fee_text.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_payment_step.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_payment_step.dart) | Manual mapping needed | ElevatedButton × 4 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/landing/landing_screen.dart](../../apps/marketplace/lib/screens/landing/landing_screen.dart) | Manual mapping needed | ElevatedButton × 4, OutlinedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/legal/privacy_policy_screen.dart](../../apps/marketplace/lib/screens/legal/privacy_policy_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/legal/terms_screen.dart](../../apps/marketplace/lib/screens/legal/terms_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/not_found_screen.dart](../../apps/marketplace/lib/screens/not_found_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/onboarding/onboarding_screen.dart](../../apps/marketplace/lib/screens/onboarding/onboarding_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/seller/seller_handoff_screen.dart](../../apps/marketplace/lib/screens/seller/seller_handoff_screen.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/splash/splash_screen.dart](../../apps/marketplace/lib/screens/splash/splash_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/blinkit_coupon_screen.dart](../../apps/marketplace/lib/screens/user/cart/blinkit_coupon_screen.dart) | Manual mapping needed | ElevatedButton × 4, TextField × 1, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/cart_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/coupon_selection_screen.dart](../../apps/marketplace/lib/screens/user/cart/coupon_selection_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextField × 1, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) | SnackbarHelper | ElevatedButton × 4, TextButton × 1, TextField × 1, AlertDialog × 1, SnackBar × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/web_cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/web_cart_screen.dart) | SnackbarHelper | ElevatedButton × 4, OutlinedButton × 2, TextButton × 2, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1, AlertDialog × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1, TextField × 1, SnackBar × 3, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/widgets/empty_cart.dart](../../apps/marketplace/lib/screens/user/cart/widgets/empty_cart.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart](../../apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/categories/categories_screen.dart](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) | Manual mapping needed | TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart](../../apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/add_address_screen.dart](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) | Manual mapping needed | ElevatedButton × 6, TextButton × 4, TextFormField × 6, TextField × 2, AlertDialog × 3, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/checkout_screen.dart](../../apps/marketplace/lib/screens/user/checkout/checkout_screen.dart) | Manual mapping needed | ElevatedButton × 2, OutlinedButton × 2, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/order_success_screen.dart](../../apps/marketplace/lib/screens/user/checkout/order_success_screen.dart) | Manual mapping needed | ElevatedButton × 2, OutlinedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/payment_method_screen.dart](../../apps/marketplace/lib/screens/user/checkout/payment_method_screen.dart) | SnackbarHelper | ElevatedButton × 4, TextField × 1, SnackBar × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/widgets/associate_code_field.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/associate_code_field.dart) | Manual mapping needed | ElevatedButton × 2, TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/widgets/checkout_steps.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/checkout_steps.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart) | CustomButton (ambiguous), DialogHelper | Card × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/flash_sale/flash_sale_screen.dart](../../apps/marketplace/lib/screens/user/flash_sale/flash_sale_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/help/help_screen.dart](../../apps/marketplace/lib/screens/user/help/help_screen.dart) | Manual mapping needed | TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/home_screen.dart](../../apps/marketplace/lib/screens/user/home/home_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/mobile_home_screen.dart](../../apps/marketplace/lib/screens/user/home/mobile_home_screen.dart) | Manual mapping needed | SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/search_results_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart) | Manual mapping needed | ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/search_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_screen.dart) | Manual mapping needed | TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/widgets/recent_searches.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/recent_searches.dart) | Manual mapping needed | TextButton × 1, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/widgets/search_bar_widget.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_bar_widget.dart) | Manual mapping needed | TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/widgets/search_product_card.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_product_card.dart) | UnifiedProductCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/widgets/search_suggestions.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_suggestions.dart) | Manual mapping needed | ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/search/widgets/trending_searches.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/trending_searches.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/web_home_screen.dart](../../apps/marketplace/lib/screens/user/home/web_home_screen.dart) | Manual mapping needed | ElevatedButton × 6, TextButton × 2, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/all_products_grid.dart](../../apps/marketplace/lib/screens/user/home/widgets/all_products_grid.dart) | UnifiedProductCard | OutlinedButton × 2, TextButton × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/banner_slider.dart](../../apps/marketplace/lib/screens/user/home/widgets/banner_slider.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart](../../apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/categories_grid.dart](../../apps/marketplace/lib/screens/user/home/widgets/categories_grid.dart) | Manual mapping needed | TextButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart](../../apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/featured_products.dart](../../apps/marketplace/lib/screens/user/home/widgets/featured_products.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/grocery_kitchen_home_strip.dart](../../apps/marketplace/lib/screens/user/home/widgets/grocery_kitchen_home_strip.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart](../../apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/home_search_bar.dart](../../apps/marketplace/lib/screens/user/home/widgets/home_search_bar.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/product_card_compact.dart](../../apps/marketplace/lib/screens/user/home/widgets/product_card_compact.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/product_section_widget.dart](../../apps/marketplace/lib/screens/user/home/widgets/product_section_widget.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/recently_viewed_widget.dart](../../apps/marketplace/lib/screens/user/home/widgets/recently_viewed_widget.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/section_banner_carousel.dart](../../apps/marketplace/lib/screens/user/home/widgets/section_banner_carousel.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/sponsored_banner_strip.dart](../../apps/marketplace/lib/screens/user/home/widgets/sponsored_banner_strip.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/home/widgets/trending_products.dart](../../apps/marketplace/lib/screens/user/home/widgets/trending_products.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/main_screen.dart](../../apps/marketplace/lib/screens/user/main_screen.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/notifications/notifications_screen.dart](../../apps/marketplace/lib/screens/user/notifications/notifications_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/offers/offers_screen.dart](../../apps/marketplace/lib/screens/user/offers/offers_screen.dart) | Manual mapping needed | SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart](../../apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart) | Manual mapping needed | SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/order_details_screen.dart](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) | Manual mapping needed | ElevatedButton × 8, OutlinedButton × 6, TextButton × 2, TextField × 1, Checkbox × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/order_tracking_screen.dart](../../apps/marketplace/lib/screens/user/orders/order_tracking_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/orders_screen.dart](../../apps/marketplace/lib/screens/user/orders/orders_screen.dart) | Manual mapping needed | ElevatedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/rate_order_screen.dart](../../apps/marketplace/lib/screens/user/orders/rate_order_screen.dart) | SnackbarHelper | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/delivered_view.dart](../../apps/marketplace/lib/screens/user/orders/widgets/delivered_view.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/empty_orders.dart](../../apps/marketplace/lib/screens/user/orders/widgets/empty_orders.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart](../../apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/order_card.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_card.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/order_item_card.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_item_card.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/order_status_badge.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_status_badge.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/order_timeline.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_timeline.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/tracking_map.dart](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_map.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/tracking_marker_icons.dart](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_marker_icons.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/change_email_screen.dart](../../apps/marketplace/lib/screens/user/profile/change_email_screen.dart) | ErrorView | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/change_password_screen.dart](../../apps/marketplace/lib/screens/user/profile/change_password_screen.dart) | ErrorView | TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/change_phone_screen.dart](../../apps/marketplace/lib/screens/user/profile/change_phone_screen.dart) | ErrorView | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/delete_account_screen.dart](../../apps/marketplace/lib/screens/user/profile/delete_account_screen.dart) | ErrorView | ElevatedButton × 2, OutlinedButton × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) | ErrorView, StickyPhotoHeaderSliver | TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) | SnackbarHelper, StickyPhotoHeaderSliver | ElevatedButton × 2, OutlinedButton × 2, SnackBar × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart](../../apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart) | Manual mapping needed | ElevatedButton × 2, OutlinedButton × 6 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/settings_screen.dart](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) | DialogHelper, SnackbarHelper | ElevatedButton × 2, TextField × 1, ListTile × 4, Switch × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) | Manual mapping needed | ElevatedButton × 4 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/rewards/rewards_screen.dart](../../apps/marketplace/lib/screens/user/rewards/rewards_screen.dart) | SnackbarHelper | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/rfq/my_rfqs_screen.dart](../../apps/marketplace/lib/screens/user/rfq/my_rfqs_screen.dart) | EmptyState | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) | DialogHelper, EmptyState, SnackbarHelper | ElevatedButton × 6, OutlinedButton × 2, TextField × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart](../../apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart) | SnackbarHelper | ElevatedButton × 2, TextField × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/search/mobile_search_screen.dart](../../apps/marketplace/lib/screens/user/search/mobile_search_screen.dart) | Manual mapping needed | TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/search/search_screen.dart](../../apps/marketplace/lib/screens/user/search/search_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/search/web_search_screen.dart](../../apps/marketplace/lib/screens/user/search/web_search_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/settings/language_screen.dart](../../apps/marketplace/lib/screens/user/settings/language_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/mobile_shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/mobile_shop_screen.dart) | Manual mapping needed | ElevatedButton × 2, SnackBar × 1, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/product_details_screen.dart](../../apps/marketplace/lib/screens/user/shop/product_details_screen.dart) | CartFlyAnimationOverlay, SnackbarHelper | ElevatedButton × 8, OutlinedButton × 2, SnackBar × 3, Checkbox × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/web_shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/web_shop_screen.dart) | Manual mapping needed | ElevatedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart](../../apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 1, TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/delivery_info_widget.dart](../../apps/marketplace/lib/screens/user/shop/widgets/delivery_info_widget.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart](../../apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 2, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/product_card.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_card.dart) | UnifiedProductCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/product_image_hero.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_image_hero.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/product_info_section.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_info_section.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/product_list.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_list.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/product_share_widget.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_share_widget.dart) | Manual mapping needed | SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/review_card.dart](../../apps/marketplace/lib/screens/user/shop/widgets/review_card.dart) | Manual mapping needed | ElevatedButton × 4, TextButton × 2, TextField × 2, Card × 1, AlertDialog × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/reviews_section.dart](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section.dart) | ErrorView | TextButton × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart) | ErrorView | TextButton × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart](../../apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart) | Manual mapping needed | TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/specification_list.dart](../../apps/marketplace/lib/screens/user/shop/widgets/specification_list.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/shop/widgets/variant_selector.dart](../../apps/marketplace/lib/screens/user/shop/widgets/variant_selector.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/subscriptions/my_subscriptions_screen.dart](../../apps/marketplace/lib/screens/user/subscriptions/my_subscriptions_screen.dart) | Manual mapping needed | TextButton × 3, AlertDialog × 1, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/subscriptions/subscription_setup_screen.dart](../../apps/marketplace/lib/screens/user/subscriptions/subscription_setup_screen.dart) | Manual mapping needed | SnackBar × 3 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/add_money_screen.dart](../../apps/marketplace/lib/screens/user/wallet/add_money_screen.dart) | CustomButton (ambiguous), DialogHelper, SnackbarHelper | ElevatedButton × 2, TextField × 1, Card × 2, SnackBar × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/product_credit_screen.dart](../../apps/marketplace/lib/screens/user/wallet/product_credit_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/referral_screen.dart](../../apps/marketplace/lib/screens/user/wallet/referral_screen.dart) | Manual mapping needed | ElevatedButton × 4, TextField × 1, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/transaction_history_screen.dart](../../apps/marketplace/lib/screens/user/wallet/transaction_history_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/wallet_screen.dart](../../apps/marketplace/lib/screens/user/wallet/wallet_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/widgets/product_credit_card.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_card.dart) | Manual mapping needed | OutlinedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/widgets/product_credit_ledger_tile.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_ledger_tile.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/widgets/transaction_tile.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/transaction_tile.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wallet/widgets/wallet_balance_card.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/wallet_balance_card.dart) | Manual mapping needed | ElevatedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart](../../apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart) | Manual mapping needed | ElevatedButton × 4, OutlinedButton × 2, AlertDialog × 1, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wishlist/web_wishlist_screen.dart](../../apps/marketplace/lib/screens/user/wishlist/web_wishlist_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 4, AlertDialog × 1, SnackBar × 3 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wishlist/widgets/empty_wishlist.dart](../../apps/marketplace/lib/screens/user/wishlist/widgets/empty_wishlist.dart) | Manual mapping needed | ElevatedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wishlist/widgets/wishlist_item_card.dart](../../apps/marketplace/lib/screens/user/wishlist/widgets/wishlist_item_card.dart) | Manual mapping needed | ElevatedButton × 4, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart](../../apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |

### Agrimore Seller — 70 presentation files

| Source file | Candidate symbols | Inline Material call markers | Mapping / render / adoption |
| --- | --- | --- | --- |
| [apps/seller/lib/screens/account/help_screen.dart](../../apps/seller/lib/screens/account/help_screen.dart) | SellerAppBar, SellerEmptyState, SellerExpandableRow, SellerListRow, SellerMenuGroup, SellerPage, SellerSearchField, SellerSectionHeader | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/notification_prefs.dart](../../apps/seller/lib/screens/account/notification_prefs.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/notification_settings_screen.dart](../../apps/seller/lib/screens/account/notification_settings_screen.dart) | SellerAppBar, SellerBanner, SellerCard, SellerLoadingView, SellerMenuGroup, SellerPage, SellerPickerField, SellerStatusBadge, SellerSwitchRow | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/policies_screen.dart](../../apps/seller/lib/screens/account/policies_screen.dart) | SellerAppBar, SellerCard, SellerListRow, SellerMenuGroup, SellerPage | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/settings_screen.dart](../../apps/seller/lib/screens/account/settings_screen.dart) | SellerAppBar, SellerCard, SellerListRow, SellerMenuGroup, SellerPage, SellerSectionHeader, SellerSegment | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/store_schedule.dart](../../apps/seller/lib/screens/account/store_schedule.dart) | SellerAppBar, SellerBanner, SellerButton, SellerCard, SellerChip, SellerDiscardGuard, SellerEmptyState, SellerIconButton, SellerListRow, SellerPage, SellerSectionHeader, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/store_status.dart](../../apps/seller/lib/screens/account/store_status.dart) | SellerBanner, SellerButton, SellerButtonBar, SellerFieldLabel, SellerSegment, SellerSheetFrame, SellerSwitchRow | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/account/widgets/support_card.dart](../../apps/seller/lib/screens/account/widgets/support_card.dart) | SellerIconTile, SellerListRow, SellerMenuGroup | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/ai/seller_ai_chat_screen.dart](../../apps/seller/lib/screens/ai/seller_ai_chat_screen.dart) | SellerAppBar, SellerButton, SellerChip, SellerChipBar, SellerEmptyState, SellerIconButton, SellerIconTile, SellerLoadingView, SellerProgressLabel, SellerStatusBadge | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/auth/account_restricted_screen.dart](../../apps/seller/lib/screens/auth/account_restricted_screen.dart) | SellerButton, SellerIllustration, SellerLogo, SellerPage | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/auth/application_status_screen.dart](../../apps/seller/lib/screens/auth/application_status_screen.dart) | SellerBanner, SellerButton, SellerCard, SellerIllustration, SellerLogo, SellerPage, SellerTimeline, SellerTimelineStep | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/auth/email_sign_in_screen.dart](../../apps/seller/lib/screens/auth/email_sign_in_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerFormScope, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/auth/seller_sign_in_screen.dart](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerFarmScene, SellerFormScope, SellerGoogleMark, SellerLogo, SellerOrDivider, SellerOtpInput, SellerSpinner, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/auth/widgets/auth_brand_panel.dart](../../apps/seller/lib/screens/auth/widgets/auth_brand_panel.dart) | SellerFarmScene, SellerIconTile, SellerLogo | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/auth/widgets/auth_error_banner.dart](../../apps/seller/lib/screens/auth/widgets/auth_error_banner.dart) | SellerBanner | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/home/add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerButtonBar, SellerCard, SellerDiscardGuard, SellerEmptyState, SellerFormErrorSummary, SellerFormScope, SellerIconTile, SellerImage, SellerKeyValueRow, SellerListRow, SellerMenuGroup, SellerOption, SellerPage, SellerPhotoTile, SellerProgressLabel, SellerSectionHeader, SellerSegment, SellerSliderField, SellerStatusBadge, SellerSwitchRow, SellerTextField, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/home/dashboard_screen.dart](../../apps/seller/lib/screens/home/dashboard_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerButtonBar, SellerCard, SellerDelta, SellerDonut, SellerIconButton, SellerIconTile, SellerListRow, SellerMenuGroup, SellerMetricCard, SellerPage, SellerSectionHeader, SellerSegment, SellerSkeletonList, SellerSparkline, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/home/home_stats.dart](../../apps/seller/lib/screens/home/home_stats.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/home/widgets/home_widgets.dart](../../apps/seller/lib/screens/home/widgets/home_widgets.dart) | SellerCard, SellerIconTile, SellerListRow, SellerMenuGroup | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/insights/health_screen.dart](../../apps/seller/lib/screens/insights/health_screen.dart) | SellerAppBar, SellerCard, SellerIconTile, SellerMenuGroup, SellerPage, SellerScoreRing, SellerSectionHeader, SellerStatusBadge | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/insights/insights_rules.dart](../../apps/seller/lib/screens/insights/insights_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/insights/insights_screen.dart](../../apps/seller/lib/screens/insights/insights_screen.dart) | SellerAppBar, SellerBanner, SellerBarItem, SellerBarList, SellerButton, SellerCard, SellerChartCard, SellerChartLegend, SellerChartPoint, SellerChartSeries, SellerChartUnavailable, SellerComparisonBars, SellerDataTable, SellerDelta, SellerDonut, SellerEmptyState, SellerIconButton, SellerLegendItem, SellerLineChart, SellerListRow, SellerMetricCard, SellerPage, SellerSectionHeader, SellerSegment, SellerTableColumn | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/notifications/inbox_rules.dart](../../apps/seller/lib/screens/notifications/inbox_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/notifications/notifications_screen.dart](../../apps/seller/lib/screens/notifications/notifications_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerChip, SellerChipBar, SellerDot, SellerEmptyState, SellerErrorState, SellerIconButton, SellerListRow, SellerMenuGroup, SellerSkeletonList | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/application_rules.dart](../../apps/seller/lib/screens/onboarding/application_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) | SellerAppBar, SellerBanner, SellerLoadingView, SellerStepProgress | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/apply_intro_screen.dart](../../apps/seller/lib/screens/onboarding/apply_intro_screen.dart) | SellerBanner, SellerButton, SellerCard, SellerLeafMark, SellerListRow, SellerLogo, SellerMenuGroup, SellerPage | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/steps/business_step.dart](../../apps/seller/lib/screens/onboarding/steps/business_step.dart) | SellerOption, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/steps/documents_step.dart](../../apps/seller/lib/screens/onboarding/steps/documents_step.dart) | SellerBanner, SellerButton, SellerFieldMessage, SellerIconTile, SellerProgressLabel, SellerStatusBadge | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/steps/location_step.dart](../../apps/seller/lib/screens/onboarding/steps/location_step.dart) | SellerBanner, SellerButton, SellerSliderField, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/steps/payout_step.dart](../../apps/seller/lib/screens/onboarding/steps/payout_step.dart) | SellerSegment, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/steps/review_step.dart](../../apps/seller/lib/screens/onboarding/steps/review_step.dart) | SellerBanner, SellerButton, SellerCard, SellerCheckRow, SellerIconTile | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/widgets/application_copy.dart](../../apps/seller/lib/screens/onboarding/widgets/application_copy.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/onboarding/widgets/step_footer.dart](../../apps/seller/lib/screens/onboarding/widgets/step_footer.dart) | SellerButton, SellerButtonBar, SellerStickyFooter | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/orders/invoice_screen.dart](../../apps/seller/lib/screens/orders/invoice_screen.dart) | SellerAppBar, SellerBanner, SellerCard, SellerErrorState, SellerIconButton, SellerLoadingView, SellerMoneyBreakdown, SellerMoneyLine, SellerPage, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/orders/order_stage.dart](../../apps/seller/lib/screens/orders/order_stage.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/orders/seller_order_detail_screen.dart](../../apps/seller/lib/screens/orders/seller_order_detail_screen.dart) | SellerAppBar, SellerButton, SellerButtonBar, SellerCard, SellerIconButton, SellerIconTile, SellerImage, SellerKeyValueRow, SellerListRow, SellerMoneyBreakdown, SellerMoneyLine, SellerPage, SellerStatusBadge, SellerTimeline, SellerTimelineStep, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/orders/seller_orders_screen.dart](../../apps/seller/lib/screens/orders/seller_orders_screen.dart) | SellerAppBar, SellerCard, SellerChip, SellerChipBar, SellerEmptyState, SellerErrorState, SellerListDetail, SellerSearchField, SellerSkeletonList, SellerStatusBadge | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/orders/widgets/order_invoice_card.dart](../../apps/seller/lib/screens/orders/widgets/order_invoice_card.dart) | SellerBanner, SellerButton, SellerCard, SellerIconButton, SellerIconTile, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/orders/widgets/order_reason_sheet.dart](../../apps/seller/lib/screens/orders/widgets/order_reason_sheet.dart) | SellerBanner, SellerButton, SellerButtonBar, SellerCard, SellerFieldMessage, SellerIconTile, SellerSheetFrame, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/payments/payments_screen.dart](../../apps/seller/lib/screens/payments/payments_screen.dart) | SellerAmountHero, SellerAppBar, SellerCard, SellerEmptyState, SellerErrorState, SellerIconButton, SellerIconTile, SellerListRow, SellerMenuGroup, SellerMoneyBreakdown, SellerMoneyLine, SellerPage, SellerSectionHeader, SellerSkeletonList, SellerStatusBadge, SellerTimeline, SellerTimelineStep, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/payments/statements.dart](../../apps/seller/lib/screens/payments/statements.dart) | SellerAppBar, SellerButton, SellerCard, SellerIconButton, SellerListRow, SellerMenuGroup, SellerMoneyBreakdown, SellerMoneyLine, SellerPage, SellerSectionHeader, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/payments/wallet.dart](../../apps/seller/lib/screens/payments/wallet.dart) | SellerAppBar, SellerBanner, SellerButton, SellerCard, SellerDiscardGuard, SellerFormScope, SellerIconTile, SellerListRow, SellerLoadingView, SellerMenuGroup, SellerPage, SellerSectionHeader, SellerSegment, SellerStatusBadge, SellerTextField, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/posts/create_post_screen.dart](../../apps/seller/lib/screens/posts/create_post_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerDiscardGuard, SellerPage, SellerPhotoTile, SellerTextField, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/posts/followers_screen.dart](../../apps/seller/lib/screens/posts/followers_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerCard, SellerDelta, SellerEmptyState, SellerIconButton, SellerIconTile, SellerImage, SellerPage, SellerSectionHeader, SellerSkeletonList, SellerStatusBadge, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/products/product_stats.dart](../../apps/seller/lib/screens/products/product_stats.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/products/seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerCard, SellerEmptyState, SellerErrorState, SellerIconButton, SellerImage, SellerSearchField, SellerSheetFrame, SellerSkeletonList, SellerStatusBadge, SellerStickyFooter, SellerSwitchRow, SellerTag, SellerTextField, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/products/stock_count_validation.dart](../../apps/seller/lib/screens/products/stock_count_validation.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/products/widgets/product_list_controls.dart](../../apps/seller/lib/screens/products/widgets/product_list_controls.dart) | SellerButton, SellerButtonBar, SellerChip, SellerChipBar, SellerStickyFooter | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/products/widgets/product_tax_section.dart](../../apps/seller/lib/screens/products/widgets/product_tax_section.dart) | SellerSectionHeader, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/products/widgets/product_variants_section.dart](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart) | SellerBanner, SellerButton, SellerEmptyState, SellerIconButton, SellerListRow, SellerMenuGroup, SellerSectionHeader, SellerSheetFrame, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/profile/business_details_sheet.dart](../../apps/seller/lib/screens/profile/business_details_sheet.dart) | SellerAppBar, SellerButton, SellerButtonBar, SellerDiscardGuard, SellerFormErrorSummary, SellerFormScope, SellerPage, SellerPickerField, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/profile/delivery_fee_sheet.dart](../../apps/seller/lib/screens/profile/delivery_fee_sheet.dart) | SellerAppBar, SellerBanner, SellerButton, SellerCard, SellerDiscardGuard, SellerIconButton, SellerPage, SellerSegment, SellerTextField, SellerToast | TextField × 4 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/profile/delivery_fee_validation.dart](../../apps/seller/lib/screens/profile/delivery_fee_validation.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/profile/seller_ai_integration_screen.dart](../../apps/seller/lib/screens/profile/seller_ai_integration_screen.dart) | SellerAppBar, SellerBanner, SellerButton, SellerCard, SellerIconTile, SellerKeyValueRow, SellerLoadingView, SellerOption, SellerPage, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/profile/seller_profile_screen.dart](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | SellerAppBar, SellerAvatar, SellerBanner, SellerButton, SellerCard, SellerDot, SellerIconButton, SellerIconTile, SellerListRow, SellerLoadingView, SellerMenuGroup, SellerPage, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/reviews/review_rules.dart](../../apps/seller/lib/screens/reviews/review_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/reviews/reviews_screen.dart](../../apps/seller/lib/screens/reviews/reviews_screen.dart) | SellerAppBar, SellerAvatar, SellerBanner, SellerBarItem, SellerBarList, SellerButton, SellerButtonBar, SellerCard, SellerChip, SellerChipBar, SellerEmptyState, SellerErrorState, SellerPage, SellerSheetFrame, SellerSkeletonList, SellerStatusBadge, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/quote_rules.dart](../../apps/seller/lib/screens/rfq/quote_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart) | SellerAppBar, SellerAvatar, SellerBanner, SellerButton, SellerButtonBar, SellerCard, SellerEmptyState, SellerImage, SellerKeyValueRow, SellerListRow, SellerMenuGroup, SellerPage, SellerStatusBadge, SellerTimeline, SellerTimelineStep, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/seller_rfq_inbox_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_inbox_screen.dart) | SellerAppBar, SellerChip, SellerChipBar, SellerEmptyState, SellerErrorState, SellerSkeletonList | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/widgets/quote_copy.dart](../../apps/seller/lib/screens/rfq/widgets/quote_copy.dart) | SellerStatusBadge | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/widgets/quote_counter_sheet.dart](../../apps/seller/lib/screens/rfq/widgets/quote_counter_sheet.dart) | SellerBanner, SellerButton, SellerButtonBar, SellerCard, SellerChip, SellerFieldLabel, SellerSheetFrame, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/widgets/quote_decline_sheet.dart](../../apps/seller/lib/screens/rfq/widgets/quote_decline_sheet.dart) | SellerBanner, SellerButton, SellerButtonBar, SellerSheetFrame, SellerTextField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/rfq/widgets/quote_tile.dart](../../apps/seller/lib/screens/rfq/widgets/quote_tile.dart) | SellerCard, SellerImage | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/search/search_rules.dart](../../apps/seller/lib/screens/search/search_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/search/search_screen.dart](../../apps/seller/lib/screens/search/search_screen.dart) | SellerAppBar, SellerButton, SellerEmptyState, SellerImage, SellerListRow, SellerMenuGroup, SellerPage, SellerSearchField | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/shell/seller_shell.dart](../../apps/seller/lib/screens/shell/seller_shell.dart) | SellerLeafMark, SellerNavBar, SellerNavItem, SellerNavRail | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/storefront/storefront_editor_screen.dart](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart) | SellerAppBar, SellerAvatar, SellerBanner, SellerButton, SellerCard, SellerChip, SellerErrorState, SellerImage, SellerLoadingView, SellerPage, SellerSectionHeader, SellerSpinner, SellerStatusBadge, SellerTextField, SellerToast | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/seller/lib/screens/storefront/storefront_rules.dart](../../apps/seller/lib/screens/storefront/storefront_rules.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |

### Agrimore Delivery — 29 presentation files

| Source file | Candidate symbols | Inline Material call markers | Mapping / render / adoption |
| --- | --- | --- | --- |
| [apps/delivery/lib/screens/auth/login_screen.dart](../../apps/delivery/lib/screens/auth/login_screen.dart) | DeliveryBanner, DeliveryButton, DeliveryCard, DeliveryHeroIllustration, DeliveryLogo | TextButton × 1, TextFormField × 2, TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/auth/pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) | DeliveryBadge, DeliveryBanner, DeliveryButton, DeliveryCard, DeliveryIllustration | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/auth/rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) | DeliveryButton, DeliveryStepIndicator, DeliveryVehicleOption, DeliveryVehicleSelector | TextButton × 1, TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/history/history_filter_sheet.dart](../../apps/delivery/lib/screens/history/history_filter_sheet.dart) | DeliveryButton | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/history/rider_history_screen.dart](../../apps/delivery/lib/screens/history/rider_history_screen.dart) | DeliveryButton, DeliveryEmptyState, DeliveryErrorState, DeliveryRouteTimeline, DeliverySearchField, DeliveryTimelineStep | ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/home/active_work_states.dart](../../apps/delivery/lib/screens/home/active_work_states.dart) | DeliveryBanner, DeliveryButton, DeliveryCard, DeliveryErrorState, DeliveryLoadingState | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/home/dashboard_screen.dart](../../apps/delivery/lib/screens/home/dashboard_screen.dart) | DeliveryCard, DeliveryChipItem | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/home/home_app_bar.dart](../../apps/delivery/lib/screens/home/home_app_bar.dart) | Manual mapping needed | Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/home/home_map.dart](../../apps/delivery/lib/screens/home/home_map.dart) | DeliveryBanner, DeliveryLoadingState | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/home/home_operations_panel.dart](../../apps/delivery/lib/screens/home/home_operations_panel.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/home/pending_proof_banner.dart](../../apps/delivery/lib/screens/home/pending_proof_banner.dart) | DeliveryBanner | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/inbox/inbox_screen.dart](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) | DeliveryChipItem | TextButton × 1, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/money/bank_change_request_screen.dart](../../apps/delivery/lib/screens/money/bank_change_request_screen.dart) | DeliveryButton | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/money/money_screen.dart](../../apps/delivery/lib/screens/money/money_screen.dart) | DeliveryButton, DeliveryCard | TextField × 4, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/money/statement_screen.dart](../../apps/delivery/lib/screens/money/statement_screen.dart) | DeliveryButton, DeliveryCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/offers/incoming_offer_screen.dart](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart) | DeliveryButton, DeliveryCard, DeliveryCountdownRing | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/orders/active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart) | DeliveryBanner, DeliveryButton, DeliveryCard, DeliveryIllustration, DeliveryOtpField, DeliveryStepIndicator | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/orders/delivery_problem_panel.dart](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart) | DeliveryButton | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/orders/widgets/rider_route_card.dart](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart) | DeliveryBanner, DeliveryButton, DeliveryCard, DeliveryChipItem | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/orders/widgets/route_recovery.dart](../../apps/delivery/lib/screens/orders/widgets/route_recovery.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/profile/document_submission_screen.dart](../../apps/delivery/lib/screens/profile/document_submission_screen.dart) | DeliveryButton | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/profile/identity_change_screen.dart](../../apps/delivery/lib/screens/profile/identity_change_screen.dart) | DeliveryButton, DeliveryCard | TextField × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/profile/rider_profile_screen.dart](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) | DeliveryAvatar, DeliveryButton, DeliveryCard, DeliveryKeyValueRow, DeliveryListTile, DeliverySectionHeader | TextButton × 2, TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/settings/device_readiness_screen.dart](../../apps/delivery/lib/screens/settings/device_readiness_screen.dart) | DeliveryBanner | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/support/help_sheet.dart](../../apps/delivery/lib/screens/support/help_sheet.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/support/help_support_screen.dart](../../apps/delivery/lib/screens/support/help_support_screen.dart) | DeliveryCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/support/my_support_requests_screen.dart](../../apps/delivery/lib/screens/support/my_support_requests_screen.dart) | DeliveryBadge, DeliveryButton, DeliveryCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/support/submit_support_request_screen.dart](../../apps/delivery/lib/screens/support/submit_support_request_screen.dart) | DeliveryButton, DeliveryCard | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/delivery/lib/screens/support/support_request_status_screen.dart](../../apps/delivery/lib/screens/support/support_request_status_screen.dart) | DeliveryButton, DeliveryCard | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |

### Agrimore Sales Associate — 19 presentation files

| Source file | Candidate symbols | Inline Material call markers | Mapping / render / adoption |
| --- | --- | --- | --- |
| [apps/employee/lib/screens/auth/associate_otp_screen.dart](../../apps/employee/lib/screens/auth/associate_otp_screen.dart) | SaInfoBanner, SaLoadingButton | TextButton × 1, TextField × 1, SnackBar × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/auth/forgot_password_screen.dart](../../apps/employee/lib/screens/auth/forgot_password_screen.dart) | SaInfoBanner, SaLoadingButton | TextButton × 1, TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/auth/login_screen.dart](../../apps/employee/lib/screens/auth/login_screen.dart) | SaInfoBanner, SaLoadingButton | TextFormField × 3, SnackBar × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/auth/pending_approval_screen.dart](../../apps/employee/lib/screens/auth/pending_approval_screen.dart) | SaLoadingButton | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/auth/suspended_screen.dart](../../apps/employee/lib/screens/auth/suspended_screen.dart) | SaLoadingButton | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/home/dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart) | Manual mapping needed | TextButton × 1, SnackBar × 1, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/notifications/notifications_screen.dart](../../apps/employee/lib/screens/notifications/notifications_screen.dart) | Manual mapping needed | SnackBar × 2, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/orders/order_detail_screen.dart](../../apps/employee/lib/screens/orders/order_detail_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/orders/orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart) | Manual mapping needed | OutlinedButton × 1, TextField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/profile/onboarding_status_screen.dart](../../apps/employee/lib/screens/profile/onboarding_status_screen.dart) | SaInfoBanner | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart) | DialogHelper, SaLoadingButton | TextButton × 1, SnackBar × 1, ListTile × 1, Switch × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/shell/employee_shell_screen.dart](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/support/help_support_screen.dart](../../apps/employee/lib/screens/support/help_support_screen.dart) | SaInfoBanner | TextButton × 1, SnackBar × 1, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/wallet/payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart) | SaInfoBanner, SaLoadingButton | TextFormField × 7, SnackBar × 5 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/wallet/payout_details_screen.dart](../../apps/employee/lib/screens/wallet/payout_details_screen.dart) | Manual mapping needed | TextButton × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/wallet/payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart) | Manual mapping needed | OutlinedButton × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/wallet/payout_request_screen.dart](../../apps/employee/lib/screens/wallet/payout_request_screen.dart) | SaInfoBanner, SaLoadingButton | OutlinedButton × 2, TextButton × 1, TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/wallet/payout_review_screen.dart](../../apps/employee/lib/screens/wallet/payout_review_screen.dart) | SaInfoBanner, SaLoadingButton | TextButton × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/employee/lib/screens/wallet/wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) | Manual mapping needed | TextButton × 1, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |

### Agrimore Admin — 99 presentation files

| Source file | Candidate symbols | Inline Material call markers | Mapping / render / adoption |
| --- | --- | --- | --- |
| [apps/admin/lib/screens/admin/admin_dashboard.dart](../../apps/admin/lib/screens/admin/admin_dashboard.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/admin_shell.dart](../../apps/admin/lib/screens/admin/admin_shell.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 1, AlertDialog × 1, ListTile × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/analytics/analytics_screen.dart](../../apps/admin/lib/screens/admin/analytics/analytics_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart](../../apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 2, SnackBar × 4 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/banners/banner_card.dart](../../apps/admin/lib/screens/admin/banners/banner_card.dart) | Manual mapping needed | Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/banners/banner_management_screen.dart](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 6, TextField × 1, AlertDialog × 2, Checkbox × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart](../../apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart) | Manual mapping needed | ElevatedButton × 6, TextButton × 5, TextField × 4, AlertDialog × 3, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/benefit_program/feature_flags_screen.dart](../../apps/admin/lib/screens/admin/benefit_program/feature_flags_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1, TextField × 1, AlertDialog × 1, SnackBar × 1, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart](../../apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart) | Manual mapping needed | ElevatedButton × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart](../../apps/admin/lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart) | Manual mapping needed | ElevatedButton × 4, TextButton × 3, AlertDialog × 1, SnackBar × 6 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) | Manual mapping needed | ElevatedButton × 3, TextButton × 1, AlertDialog × 1, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart) | Manual mapping needed | ElevatedButton × 4, OutlinedButton × 2, TextButton × 1, TextFormField × 1, AlertDialog × 1, SnackBar × 7, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/coupon/add_edit_coupon_dialog.dart](../../apps/admin/lib/screens/admin/coupon/add_edit_coupon_dialog.dart) | SnackbarHelper | ElevatedButton × 2, TextFormField × 7, Switch × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/coupon/coupon_card.dart](../../apps/admin/lib/screens/admin/coupon/coupon_card.dart) | Manual mapping needed | SnackBar × 1, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) | SnackbarHelper | ElevatedButton × 6, TextButton × 4, TextField × 1, AlertDialog × 2, Checkbox × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/add_delivery_partner_dialog.dart](../../apps/admin/lib/screens/admin/delivery/add_delivery_partner_dialog.dart) | Manual mapping needed | TextButton × 1, TextFormField × 5, AlertDialog × 1, SnackBar × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/delivery_flags.dart](../../apps/admin/lib/screens/admin/delivery/delivery_flags.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart](../../apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart) | Manual mapping needed | OutlinedButton × 1, TextButton × 1, TextField × 1, AlertDialog × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/delivery_problems_admin.dart](../../apps/admin/lib/screens/admin/delivery/delivery_problems_admin.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart](../../apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart) | SnackbarHelper | OutlinedButton × 3, TextButton × 1, TextField × 1, Card × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/dispatch_queue.dart](../../apps/admin/lib/screens/admin/delivery/dispatch_queue.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/order_assignment_screen.dart](../../apps/admin/lib/screens/admin/delivery/order_assignment_screen.dart) | DialogHelper, SnackbarHelper | None located | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart) | Manual mapping needed | Card × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) | SnackbarHelper | OutlinedButton × 1, TextButton × 5, TextField × 2, Card × 6, AlertDialog × 2, ListTile × 5 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_incidents_admin.dart](../../apps/admin/lib/screens/admin/delivery/rider_incidents_admin.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart) | SnackbarHelper | OutlinedButton × 3, TextButton × 1, TextField × 1, Card × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_money_admin.dart](../../apps/admin/lib/screens/admin/delivery/rider_money_admin.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) | SnackbarHelper | OutlinedButton × 1, TextButton × 8, TextField × 7, Card × 5, AlertDialog × 5, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_review.dart](../../apps/admin/lib/screens/admin/delivery/rider_review.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) | DialogHelper, SnackbarHelper | OutlinedButton × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/delivery/rider_support_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart) | SnackbarHelper | OutlinedButton × 2, TextButton × 1, TextField × 1, Card × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/add_employee_screen.dart](../../apps/admin/lib/screens/admin/employees/add_employee_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 5, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/associate_detail_screen.dart](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) | SnackbarHelper | TextButton × 2, TextField × 1, Card × 4, AlertDialog × 1, ListTile × 4 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart](../../apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart) | SnackbarHelper | OutlinedButton × 1, Card × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/employee_management_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_management_screen.dart) | SnackbarHelper | OutlinedButton × 2, TextButton × 1, TextField × 1, Card × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart) | SnackbarHelper | TextButton × 2, TextField × 1, Card × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart) | SnackbarHelper | OutlinedButton × 2, TextButton × 2, TextField × 2, AlertDialog × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart) | SnackbarHelper | TextButton × 1, TextField × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/finance/finance_reconciliation_models.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_models.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart) | SnackbarHelper | OutlinedButton × 2, Card × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart](../../apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart) | SnackbarHelper | OutlinedButton × 3, TextButton × 1, TextField × 1, Card × 4, AlertDialog × 1, ListTile × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/home_sections/add_edit_home_product_section_dialog.dart](../../apps/admin/lib/screens/admin/home_sections/add_edit_home_product_section_dialog.dart) | SnackbarHelper | ElevatedButton × 1, TextButton × 1, TextField × 2, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart](../../apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart) | SnackbarHelper | TextButton × 3, Card × 1, AlertDialog × 1, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/notifications/send_notification_screen.dart](../../apps/admin/lib/screens/admin/notifications/send_notification_screen.dart) | SnackbarHelper | ElevatedButton × 4, TextButton × 1, TextFormField × 3, Card × 1, AlertDialog × 1, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart) | Manual mapping needed | ElevatedButton × 4, OutlinedButton × 2, SnackBar × 3 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/order_management_screen.dart](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart) | SnackbarHelper | TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/web_download_impl.dart](../../apps/admin/lib/screens/admin/orders/web_download_impl.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/web_download_stub.dart](../../apps/admin/lib/screens/admin/orders/web_download_stub.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/widgets/admin_order_card.dart](../../apps/admin/lib/screens/admin/orders/widgets/admin_order_card.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/widgets/order_reason_dialog.dart](../../apps/admin/lib/screens/admin/orders/widgets/order_reason_dialog.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 1, TextField × 1, AlertDialog × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/orders/widgets/order_status_updater.dart](../../apps/admin/lib/screens/admin/orders/widgets/order_status_updater.dart) | Manual mapping needed | ElevatedButton × 2, TextField × 1, SnackBar × 3 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/category_management_screen.dart](../../apps/admin/lib/screens/admin/products/category_management_screen.dart) | SnackbarHelper | ElevatedButton × 6, TextButton × 5, TextFormField × 3, AlertDialog × 1, SnackBar × 5, Switch × 3 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/product_form_screen.dart](../../apps/admin/lib/screens/admin/products/product_form_screen.dart) | SnackbarHelper | ElevatedButton × 4, OutlinedButton × 2, TextButton × 1, AlertDialog × 1, SnackBar × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/product_management_screen.dart](../../apps/admin/lib/screens/admin/products/product_management_screen.dart) | SnackbarHelper | ElevatedButton × 6, TextButton × 4, TextField × 1, AlertDialog × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart) | SnackbarHelper | Card × 1, Switch × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/admin_product_card.dart](../../apps/admin/lib/screens/admin/products/widgets/admin_product_card.dart) | Manual mapping needed | Card × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart](../../apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart) | Manual mapping needed | TextFormField × 1, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/image_uploader.dart](../../apps/admin/lib/screens/admin/products/widgets/image_uploader.dart) | SnackbarHelper | TextFormField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/product_form.dart](../../apps/admin/lib/screens/admin/products/widgets/product_form.dart) | Manual mapping needed | TextFormField × 1, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/specification_form.dart](../../apps/admin/lib/screens/admin/products/widgets/specification_form.dart) | Manual mapping needed | TextFormField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/stock_manager.dart](../../apps/admin/lib/screens/admin/products/widgets/stock_manager.dart) | Manual mapping needed | TextFormField × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/products/widgets/variant_form.dart](../../apps/admin/lib/screens/admin/products/widgets/variant_form.dart) | Manual mapping needed | TextFormField × 3 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/reviews/review_management_screen.dart](../../apps/admin/lib/screens/admin/reviews/review_management_screen.dart) | Manual mapping needed | ElevatedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/rewards/rewards_management_screen.dart](../../apps/admin/lib/screens/admin/rewards/rewards_management_screen.dart) | Manual mapping needed | ElevatedButton × 2, SnackBar × 2, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/section_banners/add_edit_section_banner_dialog.dart](../../apps/admin/lib/screens/admin/section_banners/add_edit_section_banner_dialog.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 1, TextFormField × 5 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 3, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/security/payment_security_logs_screen.dart](../../apps/admin/lib/screens/admin/security/payment_security_logs_screen.dart) | Manual mapping needed | Card × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/security/verified_payment_lookup_screen.dart](../../apps/admin/lib/screens/admin/security/verified_payment_lookup_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextField × 1, Card × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/add_seller_screen.dart](../../apps/admin/lib/screens/admin/sellers/add_seller_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 6, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/edit_seller_screen.dart](../../apps/admin/lib/screens/admin/sellers/edit_seller_screen.dart) | SnackbarHelper | TextFormField × 3, Card × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/manage_sellers_screen.dart](../../apps/admin/lib/screens/admin/sellers/manage_sellers_screen.dart) | Manual mapping needed | Card × 1, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 2, TextField × 1, Card × 3, AlertDialog × 1, ListTile × 4 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart) | SnackbarHelper | TextButton × 1, TextField × 1, Card × 1, AlertDialog × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart) | SnackbarHelper | OutlinedButton × 1, TextButton × 1, Card × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) | SnackbarHelper | TextButton × 4, TextField × 2, Card × 2, AlertDialog × 2 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/settings/admin_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | ErrorView, SnackbarHelper | ElevatedButton × 11, OutlinedButton × 2, TextButton × 11, TextField × 4, AlertDialog × 11, ListTile × 15, Switch × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/settings/delivery_time_slots_management_screen.dart](../../apps/admin/lib/screens/admin/settings/delivery_time_slots_management_screen.dart) | SnackbarHelper | TextButton × 1, TextField × 4, Card × 1, AlertDialog × 1, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/settings/home_grocery_strip_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/home_grocery_strip_settings_screen.dart) | SnackbarHelper | ElevatedButton × 2, TextField × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/settings/home_section_order_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/home_section_order_settings_screen.dart) | SnackbarHelper | ElevatedButton × 2, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/settings/location_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/location_settings_screen.dart) | SnackbarHelper | ElevatedButton × 4, TextField × 5, Card × 3, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/settings/wallet_config_screen.dart](../../apps/admin/lib/screens/admin/settings/wallet_config_screen.dart) | Manual mapping needed | ElevatedButton × 6, TextButton × 2, TextFormField × 1, TextField × 4, AlertDialog × 2, SnackBar × 1, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sponsored_banners/add_edit_sponsored_banner_dialog.dart](../../apps/admin/lib/screens/admin/sponsored_banners/add_edit_sponsored_banner_dialog.dart) | Manual mapping needed | ElevatedButton × 2, TextFormField × 2, SnackBar × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_card.dart](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_card.dart) | Manual mapping needed | Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) | SnackbarHelper | ElevatedButton × 2, TextButton × 6, TextField × 1, AlertDialog × 2, Checkbox × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/subscriptions/subscription_management_screen.dart](../../apps/admin/lib/screens/admin/subscriptions/subscription_management_screen.dart) | Manual mapping needed | ElevatedButton × 4, TextButton × 1, TextField × 4, AlertDialog × 1, SnackBar × 2, Switch × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/support/support_case_constants.dart](../../apps/admin/lib/screens/admin/support/support_case_constants.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) | SnackbarHelper | OutlinedButton × 5, TextButton × 10, TextField × 4, Card × 4, AlertDialog × 6, ListTile × 5 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/support/support_queue_screen.dart](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) | SnackbarHelper | TextButton × 1, TextField × 2, Card × 1, AlertDialog × 1, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/users/customer_detail_screen.dart](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) | SnackbarHelper | ElevatedButton × 2, OutlinedButton × 1, Card × 3, ListTile × 5 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/users/edit_user_screen.dart](../../apps/admin/lib/screens/admin/users/edit_user_screen.dart) | SnackbarHelper | ElevatedButton × 4, TextButton × 1, TextFormField × 3, AlertDialog × 1, Switch × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/users/user_management_screen.dart](../../apps/admin/lib/screens/admin/users/user_management_screen.dart) | SnackbarHelper | TextButton × 3, TextField × 1, AlertDialog × 1, Checkbox × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/users/widgets/role_badge.dart](../../apps/admin/lib/screens/admin/users/widgets/role_badge.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/users/widgets/user_card.dart](../../apps/admin/lib/screens/admin/users/widgets/user_card.dart) | Manual mapping needed | ElevatedButton × 2, OutlinedButton × 2, Card × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart](../../apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart) | Manual mapping needed | ElevatedButton × 2, TextButton × 2, TextField × 3, Card × 1, AlertDialog × 2, ListTile × 1 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart](../../apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart) | Manual mapping needed | None located | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) | SnackbarHelper | OutlinedButton × 2, TextButton × 3, TextField × 3, Card × 1, AlertDialog × 3, ListTile × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/admin/widgets/paginated_query_list.dart](../../apps/admin/lib/screens/admin/widgets/paginated_query_list.dart) | Manual mapping needed | OutlinedButton × 2 | MANUAL_MAPPING_NEEDED / NOT_RUN / NOT_VERIFIED |
| [apps/admin/lib/screens/auth/auth_screen.dart](../../apps/admin/lib/screens/auth/auth_screen.dart) | SnackbarHelper | ElevatedButton × 2, OutlinedButton × 2, TextFormField × 1, Checkbox × 1 | CANDIDATE_SOURCE_USE / NOT_RUN / NOT_VERIFIED |

## Catalogue entry points and existing test sources

Sales Associate has the located standalone developer entry main_catalogue.dart and SaCatalogueApp without Firebase initialization. It displays five tabs, a typography scale slider and component loading toggle. The root currently supplies only a light theme, without darkTheme/themeMode, and its token specimen values differ from approved C01 metadata. The C28 dark image is a proposed catalogue design, not an executed dark catalogue screenshot. No standalone developer component-catalogue entry was located in the scanned Marketplace/Admin/Seller/Delivery lib trees; their business Product Catalogue pages are a separate concept.

| Source | What it provides | Execution here |
| --- | --- | --- |
| [apps/employee/lib/catalogue/main_catalogue.dart](../../apps/employee/lib/catalogue/main_catalogue.dart) | Standalone associate catalogue source | NOT_RUN |
| [apps/employee/lib/catalogue/catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) | Standalone associate catalogue source | NOT_RUN |
| [apps/seller/test/visual/catalogue_visual_test.dart](../../apps/seller/test/visual/catalogue_visual_test.dart) | Seller product catalogue visual-test harness with synthetic fixtures; not an all-components developer catalogue | NOT_RUN |
| [apps/delivery/test/design_system_test.dart](../../apps/delivery/test/design_system_test.dart) | Delivery component semantics/geometry/loading and other design-system checks in source | NOT_RUN |
| [apps/employee/test/design_system/catalogue_test.dart](../../apps/employee/test/design_system/catalogue_test.dart) | Associate catalogue widget-test source | NOT_RUN |

Existing assertions and comments are not passed tests. Seller focus/loading/reduced-motion behavior, Delivery label caps and Associate label caps must be rendered and exercised in relevant states before acceptance. C28 did not execute any test harness, run a Flutter app, call production accounts or perform an auth, financial, approval, stock, delivery or support command.

## Proposed five-folder ownership

These future package locations are requested architecture targets, not existing directories or changes made here:

| App | Proposed folder under packages/agrimore_ui/lib | Domain responsibility | Migration starting point |
| --- | --- | --- | --- |
| Admin | admin/ | Operations controls, review records, permission-aware feedback | AdminTheme, themed Material and shared helper callers |
| Marketplace | marketplace/ | Customer discovery/product/cart/order/account presentation | Generic shared widgets plus local shopper composition |
| Seller | seller/ | Merchant forms, inventory/catalogue, analytics, orders and states | App-local Seller design_system; preserve public call contracts |
| Sales Associate | sales_associate/ | Attribution/associate records, eligibility and account presentation | Shared Sa* APIs and existing developer catalogue |
| Delivery | delivery/ | Rider instructions, offers/tasks, route/proof and recovery surfaces | App-local Delivery design_system; preserve operational boundaries |

Keep shared neutral behavior/formatting/theme plumbing independently reusable and give each app its own identity/API entry point. Do not force domain-specific cards into one generic record or copy five identical systems with different primary colors. Future moves must define stable imports, retain compatible exports during transition, map callers, preserve tests and remove legacy symbols only after evidence. No folder, runtime widget, public export, import, theme binding or screen was moved/created by C28.

## Required catalogue record and state matrix

Each future component record should include stable family/variant ID, source path/owner, supported props and content contracts, five-app/theme applicability, typography/geometry tokens, focus/touch/semantics behavior, long-label/large-text behavior, loading/disabled explanation, error/recovery semantics, localization/privacy boundaries, deterministic fixtures and actual callers. Record supported states; mark inapplicable ones with a reason rather than inventing every state for every component.

State examples should distinguish default, pressed/selected/focus, unavailable with explanation, submitting/loading with duplicate-tap protection, error/empty/restricted where meaningful, and retry/resume only when supported. Record component, composition and whole-screen contexts separately. C28 illustrations show only representative independent read/action states. They do not establish error recovery, server-authoritative command completion, live permissions or rendering at every size. C01–C27 supply the separate identity, layout, accessibility, privacy, formatting, async ownership and copy contracts.

## Proposed adoption lifecycle and release evidence

This is a proposed responsibility/evidence model; no named reviewer, staffed owner, release approval or adoption completion was supplied.

| Stage | Required evidence | Meaning |
| --- | --- | --- |
| Inventory | Definition/API and actual source snapshot recorded | A family exists; no adoption inferred |
| Source traced | Resolved import/export, precise caller/branch and contract recorded | A component is used in source; visual acceptance pending |
| Rendered and exercised | Synthetic fixture; actual light/dark screen/state captures plus relevant meaningful interactions/semantics/layout checks | Evidence exists for specified state/device/revision only |
| Reviewed | Recorded reviewer decision, exception rationale, issue scope and evidence links | Accepted or changes requested for exact scope |
| Adopted | Current caller/version, verified relevant screen matrix and release scope linked; unresolved exceptions explicit | Screen adoption claimed only for its reviewed scope |

Suggested adoption record: app, route/presentation file, branch/state, component/variant, resolved definition and API version, source revision/hash, fixture, theme/viewport/text scale/input method, actual capture/test reference, observed result, review decision, exceptions and migration/release scope. A counter of import statements or component examples cannot replace this evidence. Do not show global adoption percentages without a defined denominator and validated per-state records.

Golden screenshots provide visual comparison; meaningful widget tests must separately exercise behavior, semantics and ownership/recovery boundaries. Capture actual Flutter output with deterministic fixtures; AI raster proposals are design references and cannot be used as evidence of executed runtime behavior or blindly treated as pixel-perfect Flutter goldens. [Flutter widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction) documents building and interacting with widgets; [matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html) compares captured visual output. These primary references guide future checks and certify no Agrimore adoption.

Catalogue harnesses should mount safe synthetic states without production initialization. Sensitive examples must mask private values and preserve auth/session ownership, late-result guards, exact server-authoritative outcomes and localization ownership during real migrations. Deprecation needs a documented replacement and caller map, no untracked equivalent wrappers, a transition period where necessary and relevant checks before old APIs are removed. Screen-specific exceptions remain visible until resolved; a wrapper import does not erase them.

## Scope and verification

27 new files: ten PNGs, five README/prompts/manifest sets and two masters. C01–C27 and repeated C16 remain intact. Classifier: docs; voluntary UIUX/feedback review covers per-app locked identity, target variants, independent state examples, domain composition, pending render/adoption evidence and no fabricated source paths or operational results. C27 interrupted integrity/proof checks were completed before C28 packaging.

No runtime/package folders, screen migration, Flutter analyzer/emulator, runtime tests, reviewer approval, branch/index/commit/deploy or other-chat interruption. Asset checks cover PNG integrity/copy hashes, exact prompts, C01 metadata/reference hashes, links and earlier design preservation. They are not accessibility, behavioral, performance or screen-adoption certification. Concurrent shared-checkout source changes are preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent indexed source changes since inventory: apps/marketplace/lib/providers/review_provider.dart, apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart, apps/marketplace/lib/screens/user/shop/widgets/review_card.dart.

## Asset integrity check

First post-packaging snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs. PNG chunk checksums, copied-output hashes, 15 exact generation/refinement prompt blocks, reference-input hashes, approved C01 token metadata, source-snapshot manifest records and 534 local document links verified. Exactly 27 new repository files; all 1080 earlier design files remained byte-for-byte intact.

All ten selected boards received visual review for distinct C01 identities, readable inverse dark-primary content, target action variants, independent loading/unavailable examples, domain composition and honest source-use/render-pending records. Every light board received a focused refinement to remove implementation/code/token annotations and certification-like icons; the Seller refinement removed an invented source-file path. Dark boards use approved C01 dark identity plus selected light composition references. Source call sites are documentation annotations, not proof of completed runtime screen migration. Exact selected generation/refinement history is preserved in app prompts/manifests.

Component source inventory: 57 candidate family files; presentation mapping queue: 372 Dart files, not a distinct-route count; 5 manual source traces. All rendered/adoption states remain NOT_RUN / NOT_VERIFIED. Widget/golden test sources exist but were not executed. No reviewer approval or release adoption was created.

Snapshot HEAD: d3af89aea725924241f35505397772d8c48e15f6; inventory HEAD: 64a71d4e6e6bff5ab04e9dcd38bc84d24f3b266a; branch: agrimore/foundation-f3c-distance-delivery-pricing. Source changes between inventory and packaging were observed and preserved: apps/marketplace/lib/providers/review_provider.dart, apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart, apps/marketplace/lib/screens/user/shop/widgets/review_card.dart. Additional source changes during packaging/check were observed and preserved: apps/marketplace/lib/screens/user/shop/widgets/review_card.dart. Platform configuration changes since inventory were not observed. Component/presentation source changes since mapping snapshot were observed and preserved: apps/marketplace/lib/screens/user/shop/widgets/review_card.dart. This is a point-in-time observation; another chat may continue advancing the shared checkout.

Scope: asset/doc/source-snapshot integrity only. Raster review does not establish rendered Flutter behavior, accessibility compliance, executed state tests, C01 pixel-exact adoption, full screen migration or a release decision. No runtime/package folder, app/widget, test source or backend was changed by this task. C28 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.
