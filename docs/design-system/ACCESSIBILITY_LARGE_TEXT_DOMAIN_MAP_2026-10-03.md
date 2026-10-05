# Agrimore — C26 accessibility and large text: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 remains APPROVED_LOCKED; C26 owner approval pending. Assets/docs only.

[Ten-board gallery](ACCESSIBILITY_LARGE_TEXT_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: f829ea26e6d226b99eca023d8d2b6504941d37ea. 819 eligible files / 272406 source lines across all five app lib trees, all three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files excluded. Fresh hashes/marker searches cover explicit semantics, keyboard/focus, text scaling, clipping, touch target styling and preference flags. Focused semantic reads cover Seller focus/button/page/footer/button bar/nav/progress/charts, Delivery focus/button/banner/route/document primitives, Associate shell/cards/values/shared loading button/banner and existing tests, Marketplace product/quantity controls and shared CustomButton, Admin review/detail/tooltips and dense layouts. Broad static inventory is not a semantic read of every source line or rendered screen.

Marker totals include comments/call sites, not unique components or defect counts. No explicit Semantics in an app scope does not mean no semantics: Material/shared widgets supply defaults. Explicit textScaler counts likewise do not establish whether normal Text inherits scaling. Source heuristics and tests are evidence of intent, not runtime/device results. No real user/cart/order/financial/document/support record was accessed. Shared-checkout changes are observed and preserved.

| Scope | semantics | focus | scaling | clipping | targets_preferences |
| --- | --- | --- | --- | --- | --- |
| admin | 0 | 60 | 0 | 81 | 6 |
| delivery | 23 | 43 | 1 | 57 | 8 |
| employee | 0 | 5 | 10 | 16 | 0 |
| marketplace | 7 | 40 | 0 | 226 | 9 |
| seller | 150 | 52 | 17 | 30 | 16 |
| functions | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 7 | 3 | 0 | 12 | 12 |

## Shared accessibility target contract

1. Use approved text/surface/primary/onPrimary pairs, including inverse dark-mode button content. Supporting accents are not the sole carrier of status meaning.
2. Contrast is evaluated against actual rendered neighboring colors and states. Calculated locked sRGB token pairs are source data, not proof of runtime/raster contrast or WCAG conformance.
3. Keep essential labels/content available at large text: wrap, grow, stack and scroll. Do not reduce requested system font scaling to fit fixed height or rely only on hidden ellipsis.
4. Use TextScaler at actual font sizes; scale(1) threshold heuristics do not fully represent nonlinear scaling. No global production font-size slider is invented.
5. Preserve deliberate semantic and visual order through responsive changes. Heading, record/context and actions have useful names/roles/states; hide only decorative duplicate icons.
6. Keyboard focus is visible on the existing control border, without extra ring/halo/gap. Traversal, activation, modal focus/return and unobscured focused content need runtime checks.
7. Touch hit bounds remain comfortable independently of icon size. Native/web guideline units differ; minimum widget height does not certify target bounds.
8. Screen-reader announcements describe meaningful changes once without needless focus movement; decorative spinner rebuilds are not repeated alerts.
9. Essential financial quantities/signs and private-field purpose require correct accessible wording without inventing values or exposing masked raw data.
10. High contrast, bold text, reduced motion, display scaling and real OS large text are separate preferences; preserve meaningful progress states even without animation.
11. All specimens are labelled examples/target designs. No live record, actual announcement, AT testing result, accessible compliance badge or financial/identity/order outcome asserted.
12. Later implementation should reuse current helpers, measure the semantics/rendering tree and test actual TalkBack/VoiceOver/keyboard paths across all relevant screens.

## Primary guidance and intended checks

Normal text contrast target is at least 4.5:1; qualifying large text has a 3:1 minimum under WCAG definitions. Numeric token contrast below is source-color analysis, not a product conformance audit. [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

For essential control/state visual cues, evaluate 3:1 against adjacent colors rather than assuming every decorative hairline must meet it. Focus must be visible and the focused component must not be entirely hidden by author-created content. A 2px single border is our inherited design shape, not a claim that thickness alone passes every focus criterion. [W3C non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), [focus visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html), [focus not obscured](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html).

Web resize-text verification includes enlargement up to 200% without loss of content/functionality; reflow is a separate check with content-specific exceptions, including genuinely two-dimensional information. Do not force an audit table into inaccessible cards solely to claim reflow. [W3C resize text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html), [reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html).

Flutter guidance distinguishes Android 48×48 dp and iOS 44×44 point minimum target recommendations and calls for usable large text. This board set uses a comfortable 48-plus logical target direction; raster pixel dimensions are not device hit bounds or WCAG CSS-pixel measurements. Check actual rendered targets, OS settings, keyboard and screen readers. [Flutter UI guidance](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), [testing guidance](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

TextScaler supports nonlinear font scaling. Applying scale(1) as a layout threshold is an approximation, not a linear multiplier for all font sizes. Test actual font sizes/system preferences rather than clamping text or assuming a single synthetic scale proves all OS modes. [Flutter nonlinear scaling](https://docs.flutter.dev/release/breaking-changes/android-14-nonlinear-text-scaling-migration), [TextScaler migration](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor).

## Locked token contrast reference

Calculated from exact C01 hex foreground/background pairs using sRGB relative luminance (linearize channels at 0.04045; weights 0.2126/0.7152/0.0722; (Lmax+0.05)/(Lmin+0.05)). Ratios shown to two decimals; evaluate full precision, not rounded display. No screenshot pixels, anti-aliasing, opacity, gradient, hover/pressed state, overlays or actual runtime colors were measured. Do not translate these source figures into a Passed/Certified UI label.

| App | Theme | body | muted | primary-content | focus-on-surface | strong-border | default-border |
| --- | --- | --- | --- | --- | --- | --- | --- |
| marketplace | light | 14.72 | 5.30 | 5.39 | 5.39 | 2.62 | 1.30 |
| marketplace | dark | 16.29 | 10.22 | 8.38 | 9.51 | 5.08 | 1.69 |
| seller | light | 14.89 | 5.17 | 6.20 | 6.20 | 2.80 | 1.31 |
| seller | dark | 16.44 | 10.36 | 8.65 | 9.97 | 5.60 | 1.80 |
| delivery | light | 17.04 | 5.99 | 17.58 | 5.56 | 2.78 | 1.42 |
| delivery | dark | 16.51 | 9.59 | 16.60 | 8.54 | 5.10 | 1.54 |
| sales-associate | light | 14.80 | 5.00 | 6.48 | 6.48 | 2.63 | 1.29 |
| sales-associate | dark | 16.40 | 10.31 | 7.69 | 8.75 | 5.78 | 1.77 |
| admin | light | 15.61 | 5.43 | 8.14 | 8.14 | 2.76 | 1.32 |
| admin | dark | 16.30 | 9.88 | 7.65 | 8.33 | 4.75 | 1.70 |

Pairs: body=text/surface; muted=muted/surface; primary-content=onPrimary/primary; focus-on-surface=focus/surface; strong-border=strongBorder/surface; default-border=border/surface. C01 token metadata is stored in per-app manifests; the calculation is a reference, not a palette amendment.

The selected body/muted/primary-content source pairs exceed 4.5:1. All five light strong-border/surface pairs are below 3:1; default hairlines are below 3:1 in both themes. These borders can remain decorative where label/shape/context already identifies a control, but should not be the sole required cue for an input or selected/focused state. C26 focuses outlined examples with approved high-contrast primary/focus tokens and uses words/icons for status. This does not unlock/rewrite C01 or certify every other pair/state. Review actual control boundaries during implementation. No new color tokens or runtime palette fixes were made.

## Current layers and gaps

| Layer | Observed source | Target boundary |
| --- | --- | --- |
| Shared CustomButton | White child text/spinner used across filled/outlined/text variants | Resolve theme/variant roles later; white text on light secondary is a concrete source risk, not evidence every caller renders invisible |
| Seller | Material button names or custom replacement Semantics, own-border keyboard focus, large-text footer/bar/header adaptation and live regions | Retain current helper rules; test stacking order and nonlinear sizing; bounded title/chart text can still lose information |
| Delivery | Own-border keyboard tracker, button semantic labels/min heights, two-line normal/one-line loading label caps, warning/danger live regions | Grow essential labels, inspect keyboard versus AT focus, meaningful notice/change announcements |
| Associate shared | SaLoadingButton labelled outer Semantics and Material child; SaInfoBanner container label without liveRegion; values sometimes FittedBox.scaleDown | Inspect actual merged tree before duplicate-label fixes; do not negate requested text enlargement |
| Marketplace/Admin | Many inline fixed/clipped layouts and sparse explicit textScaler/semantics adaptation; Material defaults remain | Rendered hit bounds, accessible names, full essential content, web focus and adaptable density need screen-specific tests |

## Domain-by-domain systems

### Agrimore Marketplace

**Current source:** Catalogue product titles commonly maxLines/ellipsis with fixed grids/actions; quantity selector contains small 28px busy indicator (not itself proof of target size). Direct semantic labels on the examined product/quantity widgets are sparse; Material controls still provide default semantics, so absence of explicit Semantics does not prove every control inaccessible. Shared CustomButton hardcodes white text/spinner for all variants, including outlined/text, and does not explicitly adapt content. Profile/save owner guards are outside accessibility presentation.

**Target:** Prioritize full product names/details, scalable quantity/action labels, useful names for add/remove/wishlist controls and keyboard operation for web discovery. Use actual theme contrast pairs and visible own-border focus; replace constrained layouts rather than shrink text.

| Panel | Domain specimen |
| --- | --- |
| Readable discovery contrast | Panel "Readable discovery": title "Vegetable growing kit" above neutral product-outline icon. Primary filled "View product details"; secondary outlined "Choose options". Beneath small text-plus-info-icon "Information example". Gold note "Readable text and labels carry meaning". No price, availability, added-to-cart outcome or real product image. |
| Scalable product layout | Panel "Text and layout": two comparable specimens labelled "Standard text" and "Large text". EXACT SAME title "Vegetable growing kit" and secondary "View product details". Large title visibly bigger, wraps into two lines, action moves BELOW title and grows vertically with wrapped label as needed; no clipping/ellipsis/shrinking. Gold note "Let rows grow; keep the full product name". |
| Keyboard and touch | Panel "Focus and controls": outlined action "Choose options" has ONE strong own border labelled "Keyboard focus example"; below labelled minus and plus actions "Decrease quantity" / "Increase quantity", each comfortably sized, no numeric quantity. Gold note "Visible focus / comfortable labelled targets". No outer ring, glow, duplicate border, fake cursor or stock limit. |
| Screen-reader presentation | Panel "Reading and updates": three ordered text rows "Product title", "Available actions", "Relevant notice" with small sequential guide markers, external caption "Reading order example". Separate info notice "Could not load product details. Try again." with outlined "Try again", labelled "Example notice". Gold note "Announce meaningful changes without moving focus". No device speech bubble/audio icon as proof, live shopping state or compliance badge. |

Preserve or resolve:

- Ellipsis is a risk to essential product/variant/action text; keep a supported full-text path without relying solely on hover.
- Small spinner/icon dimensions do not establish actual hit target; measure rendered tap bounds.
- CustomButton outlined/text white labels need later theme-aware correction; C26 uses locked primary/onPrimary and readable secondary roles.
- Screen-reader order, quantity changes and cart notices need runtime semantics/device checks; no real cart result asserted.

Sources:

- [apps/marketplace/lib/widgets/product/unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart](../../apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart)
- [packages/agrimore_ui/lib/widgets/common/custom_button.dart](../../packages/agrimore_ui/lib/widgets/common/custom_button.dart)
- [apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart)

### Agrimore Seller

**Current source:** SellerFocusTracker distinguishes keyboard highlight and thickens existing inside border. SellerButton uses Material labels/roles or custom semanticLabel, wrapping content and minimum height; compact variants differ. SellerPage scrolls with safe sticky footer; SellerButtonBar stacks/reverses children at narrow or large text, which needs semantic/visual-order review. App bar scales actual font size but uses capped lines; largeText checks scale(1), an approximation for nonlinear scaling. Progress/banner/state helpers use live regions. Chart text painter follows scaler but some summaries clamp font scale.

**Target:** Preserve single-border focus and label semantics, grow product-editor fields/actions, keep focus visible above footer/keyboard and reconcile responsive action ordering. Replace inaccessible chart-only meaning with readable descriptions/data where supported; no universal runtime pass inferred.

| Panel | Domain specimen |
| --- | --- |
| Editor contrast and labels | Panel "Merchant controls": title "Product details", field label "Description" above empty neutral field specimen; primary filled "Review changes", secondary outlined "Back". Copper note "Labels remain visible before and after input". No actual product, Save success, KYC/business data or publication claim. |
| Adaptive editor actions | Panel "Scalable editor": Standard text specimen has "Review product details" and side-by-side actions "Back" / "Review changes"; Large text specimen same title bigger/wrapped with actions STACKED full width in clear intentional order. Copper note "Grow controls; preserve a deliberate reading order". No numeric scale claim, clipped label or resized-down text. |
| Single-border focus | Panel "Keyboard focus": outline field "Product name" with one stronger own border; separate outlined "Review changes". Small "Focus example" and "Comfortable action height". Copper note "Strengthen the existing border; keep geometry stable". No outer focus ring/halo/double border. |
| Announcements and summaries | Panel "Accessible updates": neutral text-plus-hourglass "Loading product details" and independent error icon+text "Could not load products. Try again." with secondary "Try again". Caption "Example states"; external reading label example "Review changes, button". Copper note "Useful announcements; no repeated decorative noise". No spoken-AT-pass/compliance/payment/stock or published outcome. |

Preserve or resolve:

- Keyboard highlight implementation is present; actual Tab/Shift+Tab/Enter behavior and focus restoration still require interaction tests.
- SellerButtonBar changes child order when stacked; preserve intentional reading/action order rather than blindly copying last-first everywhere.
- scale(1) and chart clamps are not complete nonlinear text-scaling support.
- Live regions should announce meaningful change once, not every spinner rebuild. Existing Seller focus tests were inspected, not run.

Sources:

- [apps/seller/lib/design_system/theme/seller_focus.dart](../../apps/seller/lib/design_system/theme/seller_focus.dart)
- [apps/seller/lib/design_system/components/seller_button.dart](../../apps/seller/lib/design_system/components/seller_button.dart)
- [apps/seller/lib/design_system/components/seller_layout.dart](../../apps/seller/lib/design_system/components/seller_layout.dart)
- [apps/seller/lib/design_system/components/seller_nav.dart](../../apps/seller/lib/design_system/components/seller_nav.dart)
- [apps/seller/lib/design_system/components/seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart)
- [apps/seller/lib/design_system/components/seller_charts.dart](../../apps/seller/lib/design_system/components/seller_charts.dart)

### Agrimore Delivery

**Current source:** DeliveryFocusTracker/outline use own inside keyboard border; button minimum heights and semanticLabel exist, with non-loading labels capped at two lines/loading one. DeliveryBanner warning/danger use liveRegion, while generic loading/notice semantics vary. Route card merges/excludes some decorative icons and combines labels. Document viewer uses image loading/error without showing private data in this audit. Explicit textScaler adaptation is sparse; min height alone does not ensure large labels fit.

**Target:** Keep rider task instructions full and actions reachable, readable names for route/help/document controls, field-friendly high contrast and one orange focus border. Large text stacks instructions/actions, keeps error next action readable; media/maps supplement text rather than substitute it.

| Panel | Domain specimen |
| --- | --- |
| High-contrast field controls | Panel "Field readability": title "Pickup instructions" and readable body "Review the collection instructions before continuing."; primary black/white "Review pickup"; secondary "Help". Orange note "Use words and icons alongside colour". No actual address, map route, ETA, delivery/paid/completed outcome. |
| Instruction reflow | Panel "Large-text instructions": Standard text and Large text specimens with EXACT SAME title "Pickup and drop-off instructions" and secondary "Review pickup". Large title wraps and action STACKS below body; full label legible, tall control. Orange note "Keep instructions readable; let the layout grow". No clipped route/address or fake system text-size toggle. |
| Rider focus and targets | Panel "Focus and actions": "Review pickup" outlined button with single strong burnt-orange own border, caption "Keyboard focus example"; secondary "Help" with labelled help icon. Orange note "Focus stays visible above fixed actions". No glow/second ring, actual keyboard overlay or coordinate. |
| Meaningful reading | Panel "Labels and updates": ordered rows "Task instructions", "Available action", "Relevant warning"; external "Reading order example". Independent warning+text "Could not load task details. Try again.", outlined "Try again", caption "Example notice". Burgundy small note "Describe private document purpose, not its contents". No identity document number/verified tick, completed delivery, safety guarantee or emergency dispatch. |

Preserve or resolve:

- Two-line/one-line label caps can truncate long translations/loading labels at large text.
- Minimum touch height is not proof actual hit area/focus unobscured with sticky footer/keyboard.
- Keyboard focus and accessibility focus are separate; tracker appearance does not prove screen-reader traversal.
- Private document image alternative should describe purpose/state without exposing sensitive identifiers; no identity or delivery outcome announced here.

Sources:

- [apps/delivery/lib/design_system/theme/delivery_focus.dart](../../apps/delivery/lib/design_system/theme/delivery_focus.dart)
- [apps/delivery/lib/design_system/components/delivery_button.dart](../../apps/delivery/lib/design_system/components/delivery_button.dart)
- [apps/delivery/lib/design_system/components/delivery_banner.dart](../../apps/delivery/lib/design_system/components/delivery_banner.dart)
- [apps/delivery/lib/design_system/components/delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart)
- [apps/delivery/lib/screens/orders/widgets/rider_route_card.dart](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart)
- [apps/delivery/lib/screens/profile/rider_profile_screen.dart](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart)

### Agrimore Sales Associate

**Current source:** Profile/onboarding/dashboard contain some LayoutBuilder and textScale threshold adaptations; shell increases NavigationBar height from 64 to72 at scale(1)>1.2. SaLoadingButton min-height/semantic name exists but caps labels at two lines and wraps Semantics around Material button without excluding children, so combined tree needs duplicate-name review. SaInfoBanner adds container/label but not liveRegion. Monetary display uses FittedBox scaleDown in several screens. Catalogue textScale control is preview tooling, not a production appearance/accessibility setting. Existing linear text-scale tests inspect overflow in selected widgets.

**Target:** Full attributed-record titles and value meaning should remain readable at system large text without shrink-to-fit; stacked identity/status/action layout, single labelled focus target and useful announcement semantics. Keep current app functions; do not invent production text-size slider or infer commission/payout status.

| Panel | Domain specimen |
| --- | --- |
| Record readability | Panel "Associate record actions": title "Attributed order details", neutral bag icon and readable helper "Read the full order information."; primary "View order details", secondary "Back". Indigo note "Keep identity and value meaning in text". No order number, amount, commission/payout/approval outcome or fake person. |
| Large-text record cards | Panel "Adaptable records": Standard text and Large text samples with same title "Attributed order details" and secondary "View order details". Large title wraps; supporting label and action move below with taller button. Indigo note "Wrap and grow; do not shrink essential text". No FittedBox visual tiny values or numeric text-scale pass claim. |
| Focus and names | Panel "Labelled focus": outlined "View order details" uses one strong royal-blue own border, "Keyboard focus example"; separate icon-plus-label "Help and support". Indigo note "One clear name and role per action". No duplicate external ring, photo/referral code or production font-size setting. |
| Reading and notices | Panel "Screen-reader content": ordered text "Record title", "Record information", "Next action", caption "Reading order example". Independent info/error notice "Could not load orders. Try again." and secondary "Try again", caption "Example notice". External label sample "View order details, button". Indigo note "Announce updates once; keep focus predictable". No AT pass, guaranteed benefit, pending/success financial state. |

Preserve or resolve:

- Fixed nav 64/72 threshold is partial adaptation, not unlimited text-scale support.
- FittedBox.scaleDown can negate increased text; enlarge/wrap/scroll with typed value meaning rather than hiding or clipping.
- Semantics wrapper plus child Material semantics may need merging/exclusion based on actual semantics tree, not source-count assumption.
- Tests exist but were not run; one Continue fixture and 150% banner cannot certify all screens/device AT behavior.

Sources:

- [apps/employee/lib/screens/shell/employee_shell_screen.dart](../../apps/employee/lib/screens/shell/employee_shell_screen.dart)
- [apps/employee/lib/screens/profile/onboarding_status_screen.dart](../../apps/employee/lib/screens/profile/onboarding_status_screen.dart)
- [apps/employee/lib/screens/home/dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)
- [apps/employee/lib/screens/orders/order_detail_screen.dart](../../apps/employee/lib/screens/orders/order_detail_screen.dart)
- [packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart)
- [packages/agrimore_ui/lib/widgets/common/sa_info_banner.dart](../../packages/agrimore_ui/lib/widgets/common/sa_info_banner.dart)
- [apps/employee/lib/catalogue/catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart)

### Agrimore Admin

**Current source:** Admin has mixed Material and legacy table/dialog/card layouts with many maxLines/ellipsis and fixed dimensions; explicit textScaler/focus-order adaptation is sparse in marker search. Support evidence/action UI has tooltips in selected places; actual Material widgets contribute default semantics. Shared CustomButton white text on outlined/text persists where adopted. Dashboard and order panels use independent widgets; table-to-stacked record adaptation is a target, not existing universal behavior.

**Target:** Prioritize keyboard access through filters/records/detail/dialogs, full audit/context text at large scale, adaptable record rows and labelled status/action meaning. Maintain reading order and focus return on close without assuming every table can become a card or publishing compliance claims.

| Panel | Domain specimen |
| --- | --- |
| Operational contrast | Panel "Review controls": title "Support case details", primary "Open case details", secondary "Review filters"; readable text+info-icon "Context example". Cyan note "Readable labels and status meaning beyond colour". No actual case ID/user/status outcome/export/resolve action. |
| Dense to adaptable | Panel "Record reflow": Standard text specimen a compact row with labels "Category", "General", "Action", "Open details"; Large text specimen SAME info in vertically stacked label/value lines and full-width outlined "Open details". Header "Case summary". Cyan note "Preserve context when columns become stacked rows". No real case, success/status or global-all-tables support claim. |
| Keyboard traversal | Panel "Focus and order": outlined field "Search cases" has strong single professional-blue own border; below outlined "Review filters" and "Open case details". External small guide "Search → Filters → Record" and "Keyboard focus example". Cyan note "Visible focus with a predictable order". No outer ring/glow, fake typed query or resolved case. |
| Review announcements | Panel "Reading and feedback": ordered rows "Record heading", "Relevant context", "Available actions", caption "Reading order example"; independent icon+text notice "Could not load cases. Try again." with outlined "Try again", caption "Example notice". Cyan note "Announce the update; keep current focus". No real audit/private info/compliance/WCAG pass badge. |

Preserve or resolve:

- Absence of explicit Semantics is not proof all Material controls inaccessible; inspect merged tree and labels.
- Legacy dense tables/detail widgets need specific overflow/traversal tests, not one universal responsive claim.
- Focus trapping/restoration for dialogs and focus unobscured by banners/footer require runtime keyboard checks.
- Masked identifiers/export permissions remain separate from readable a11y labels; do not narrate hidden private values or infer case resolution.

Sources:

- [apps/admin/lib/screens/admin/admin_shell.dart](../../apps/admin/lib/screens/admin/admin_shell.dart)
- [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [apps/admin/lib/screens/admin/orders/order_management_screen.dart](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart)
- [apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart)
- [packages/agrimore_ui/lib/widgets/common/custom_button.dart](../../packages/agrimore_ui/lib/widgets/common/custom_button.dart)

## Focus, semantics and announcements

Single-border focus preserves Seller/Delivery current owner-directed style: strengthen the control’s own inside border rather than adding another ring/glow/offset gap. Current Seller filled/outlined focus may use a 3dp strong stroke, while C01 board foundations give a 2px focus reference; C26 illustrates the inherited board reference and does not overwrite current runtime geometry. A visible border is not proof Tab order, Enter/Space activation, keyboard versus accessibility focus or focus restoration works. Focus should remain discoverable through scroll, dialog and sticky-action changes.

Reading-order rows and label samples are external design annotations, not actual TalkBack/VoiceOver transcripts. Name, role, current state/value and hint should represent the real object without duplicate icon/label speech. Exclude only decorative duplicates; do not remove meaningful warning, quantity or private-field-purpose content. Numeric signs/units and approximate values need accessible meaning while masked raw identifiers stay private.

A liveRegion declaration indicates intent, not confirmed delivery of one announcement or polite/assertive timing on all platforms. Distinguish meaningful async changes from rebuilding decorative progress, and keep focus with the user unless a supported error/focus path requires movement. Example retry notices are isolated design specimens; no cart save, payout, identity approval, delivery or case resolution is announced. Actual owner checks/server state remain outside design samples.

## Large text and adaptable layouts

Standard/Large labels illustrate reflow rather than a measured 200% screenshot. Essential titles, long action labels, instructions and values grow/wrap; secondary/context moves below when width is constrained. Scroll is allowed. Decorative icon/media may stay fixed while its text grows. Avoid shrinking requested font size with FittedBox/scaleDown or clamping solely to preserve old geometry. Ellipsis may be intentional for summaries only when essential full content remains available through an accessible supported path.

Seller button bars reverse action order on stack; verify deliberate primary action and traversal order rather than assuming every reversal is correct. Sales Associate nav-height changes and scale(1) cards are partial adaptations; its catalogue slider is tooling, not a production accessibility setting. Delivery instructions/action/loading labels and Admin dense tables need their own overflow and focus checks. Maps/plots/images require appropriate textual alternatives when they carry information, with private-document purpose rather than exposed ID contents. No new text-size/high-contrast setting is invented in these images.

## Existing test evidence and future verification

The following test sources exist and were read or located; no test was run or reported passing by this assets task:

- [apps/seller/test/design_system/seller_focus_test.dart](../../apps/seller/test/design_system/seller_focus_test.dart)
- [apps/employee/test/design_system/text_scale_test.dart](../../apps/employee/test/design_system/text_scale_test.dart)
- [apps/employee/test/design_system/sa_loading_button_test.dart](../../apps/employee/test/design_system/sa_loading_button_test.dart)
- [apps/employee/test/screens/large_display_overflow_test.dart](../../apps/employee/test/screens/large_display_overflow_test.dart)
- [apps/admin/test/order_360_layout_test.dart](../../apps/admin/test/order_360_layout_test.dart)
- [apps/delivery/test/workspace_layout_test.dart](../../apps/delivery/test/workspace_layout_test.dart)

Future implementation checks:

- Render all relevant screens/controls at normal through 200% linear fixtures, real OS nonlinear/max text and display scaling, narrow/wide widths, long localized labels, landscape and keyboard-open modes. Inspect content loss, tappable actions and scroll.
- Inspect merged semantics with names, roles, values, enabled/selected/expanded states, headings and actual traversal. Test TalkBack/VoiceOver, keyboard Tab/Shift+Tab/Enter/Space/Escape, dialog focus trap/return and non-obscured controls.
- Measure actual rendered contrast pairs/states, essential boundaries/focus, status words/icons, bold/high-contrast preferences and images/overlays. Do not rely on token ratio tables or raster color sampling alone.
- Flutter accessibility guideline tests for labelled taps, actual Android/iOS target bounds and text contrast on supported rendered widgets; these supplement device/user-flow review rather than certify every screen.
- Exercise async busy/error notices once, duplicate/noisy speech, progress with reduced motion and useful focus after first-invalid-field/error summaries. Keep server-confirmed state and privacy boundaries intact.
- Address Marketplace product/quantity/full name/control variants; Seller footer/bar/order/chart text; Delivery long instructions/loading labels and private-media purpose; Associate shrinking monetary values/nav/button/banner semantics; Admin table/detail/filter/modal keyboard paths.
- Validate private labels do not narrate masked secrets/identifiers, and account changes/late results do not announce another owner’s record. No runtime/auth/backend owner guard change is part of C26 assets.

No Flutter runtime/emulator/analyzer, accessibility guideline test, financial/backend mutation, screen-reader/device test or production-data access was performed. Later runtime implementation requires meaningful relevant tests/analyzers and rendered screenshots/device evidence.

## Scope and design review

27 new files: ten PNGs, five README/prompts/manifest sets and two master documents. C01–C25 and repeated C16 remain intact; C26 remains provisional. Classifier: docs; voluntary UIUX/feedback review covers locked identities, text/layout/focus/announcement examples and honest testing limits. Accessibility images do not themselves provide an accessible implementation or a compliance certificate.

Only new design assets/docs written. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption by this task. Concurrent shared-checkout work is observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/screens/user/orders/orders_screen.dart, apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart.

## Asset integrity check

Completed review: 2026-10-04; set retains its 2026-10-03 start-date filenames. First post-packaging snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs. PNG chunk checksums, copied-output hashes, 13 exact prompt blocks, reference-input hashes, approved C01 token metadata, 60 embedded source contrast-reference pairs and 93 local document links verified. Exactly 27 new repository files; all 1026 earlier design files remained byte-for-byte intact.

All ten selected boards received visual review for app identity, inverse primary labels, large/wrapping text, adaptable layouts, single own-border focus, labelled actions and example reading/announcement content. Marketplace light was refined to remove its extra focus outline. Delivery light was refined to correct the outer light canvas and enlarge its instruction title. Admin light was refined for its professional-blue action palette. Their dark boards reference the selected light compositions and the approved C01 dark identities. Notices, field content and reading guides are synthetic examples; no actual record or assistive-technology transcript was accessed.

Snapshot HEAD: be6c1dae99497dd674fb2f484c2d7cc0cfa16d30; inventory HEAD: f829ea26e6d226b99eca023d8d2b6504941d37ea; branch: agrimore/foundation-f3c-distance-delivery-pricing. Source changes observed between inventory and packaging were preserved: apps/marketplace/lib/screens/user/orders/orders_screen.dart, apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart. No additional indexed source changes were observed during this first packaging/check snapshot. Platform configuration hashes matched the inventory. This is a point-in-time observation; another chat may continue advancing the shared checkout.

Scope: design assets/docs only. Asset checks, source-token calculations and visual review do not establish actual rendered contrast, semantic output, device hit bounds, keyboard traversal, nonlinear text scaling or WCAG conformance. Runtime/device accessibility testing is still required. C26 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.
