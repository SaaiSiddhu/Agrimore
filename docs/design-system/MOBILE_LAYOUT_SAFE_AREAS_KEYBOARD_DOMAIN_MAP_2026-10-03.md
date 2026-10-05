# Agrimore — C06 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Open ten-image gallery](MOBILE_LAYOUT_SAFE_AREAS_KEYBOARD_BOARDS_2026-10-03.md). [C01 approval](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md) remains authoritative for color, typography, shapes and borders.

## Coverage and limits

Source inventory at HEAD f87ce8cd53b6971650dd0aeb79ee164aa3865ef8: **815 files / 271,458 lines** across all five app lib trees, shared package lib trees and functions/src. Static source text was scanned for layout patterns; relevant frames, sheets and forms were read contextually. Files ending .g.dart/.freezed.dart, firebase_options.dart and credential/secret-named files were excluded. This is a broad source inventory plus targeted semantic review, not a complete line-by-line review or rendered audit of every screen. Counts describe syntax occurrences, not failures or unique screens. Backend source supplies domain context, not mobile geometry. No build, emulator or device keyboard tests were run for these documentary assets.

Missing explicit resizeToAvoidBottomInset does not mean keyboard resizing is absent: Scaffold defaults to true. Likewise a missing explicit ensureVisible call does not prove that framework text-field scrolling fails. The screen-family inventories below are directories, not verified screen counts.

| Source scope | SafeArea | Explicit resize | viewInsets | viewPadding | Scroll views | Keyboard dismiss | ensureVisible | Bottom nav | Sheets |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| marketplace | 42 | 7 | 5 | 1 | 116 | 4 | 0 | 3 | 25 |
| seller | 12 | 0 | 1 | 0 | 15 | 0 | 1 | 1 | 8 |
| delivery | 14 | 0 | 12 | 0 | 36 | 0 | 1 | 1 | 16 |
| employee | 6 | 0 | 0 | 0 | 32 | 0 | 0 | 1 | 0 |
| admin | 20 | 1 | 4 | 0 | 125 | 1 | 0 | 4 | 3 |
| agrimore_services | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 1 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 1 |
| src | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Shared target contract

1. Each route declares an inset owner. Either a resizing viewport owns keyboard clearance, or a manually inset frame owns it; never apply the full keyboard inset twice. Current Admin auth deliberately uses manual clearance, while stock sheets need a bounded sheet-level owner.
2. Read top/bottom safe areas and keyboard obscuration from system metrics. A keyboard is not a fixed device-sized bottom spacer. Recompute consumed padding as the keyboard opens; do not preserve a duplicate closed-state gesture-area band above it.
3. On form task routes, use a flexible scrolling body and reserve footer space outside the body. Keep the focused field, helper and error text visible. No overlay may silently cover the last field. Do not insert global tabs into standalone editing routes.
4. Sticky actions must grow for translated labels and large text. Wrap labels, stack secondary actions when necessary and avoid fixed-height text clipping. On very short/landscape layouts, collapse optional context first. If header and footer cannot fit, use an accessible scrolling action fallback instead of forcing an unusable sticky layout.
5. Keep lists, maps, draggable sheets and forms in their own intentional scroll scopes. Use the provided draggable-sheet controller. Tap/drag keyboard dismissal must not consume an intended field edit or primary action. Focus/validation recovery stays in the visible form.
6. Keyboard transitions should follow C05 reduced-motion direction when implemented. These images are stills; they do not establish animation or keyboard platform behavior.

Flutter's [Scaffold resizing contract](https://api.flutter.dev/flutter/material/Scaffold/resizeToAvoidBottomInset.html) describes resizing the body and floating widgets. It does not certify the clearance of every bottomNavigationBar. [SafeArea](https://api.flutter.dev/flutter/widgets/SafeArea-class.html) handles system intrusions and consumed descendant padding; [viewInsets](https://api.flutter.dev/flutter/widgets/MediaQueryData/viewInsets.html) describes obscured regions such as the keyboard. [showModalBottomSheet](https://api.flutter.dev/flutter/material/showModalBottomSheet.html) distinguishes scroll-controlled content and top/left/right safe areas; useSafeArea alone is not a keyboard-clearance policy.

## Per-app mapping

### Agrimore Marketplace

**Current source:** The checkout address screen positions a non-scrolling bottom form over a map, with a fixed map-control offset and a 42px save control. The address page below is a target proposal, not a claim that the current screen has been migrated.

**Domain families:** Browse/search/shop: scroll content with deliberate route-specific bottom controls. Cart/checkout/address: reserve primary action space and reveal validation. Auth/profile: keyboard-safe forms. RFQ/chat: bounded sheets or message composer. Orders/map: preserve map-control clearance without fixed screen assumptions.

**Target specimen:** Scrollable task page — Delivery address. Focus: Pincode. Primary: Save address. Synthetic examples; preserve existing validation and real outcome semantics.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Field gap | 16 |
| Section gap | 24 |
| Footer inset | 16 |
| Footer vertical | 12 |
| Action minimum | 48 |

Target rules:

- Keep address fields in one flexible scroll region.
- Reserve the footer outside the form scroll.
- Reveal the focused field and its validation text.
- Measure safe areas again when the keyboard changes.

Source anchors:

- [add_address_screen.dart](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart)
- [main_screen.dart](../../apps/marketplace/lib/screens/user/main_screen.dart)
- [complete_profile_screen.dart](../../apps/marketplace/lib/screens/auth/complete_profile_screen.dart)
- [request_quote_sheet.dart](../../apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart)

Scanned screen-family directory inventory:

| Family | Dart files |
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

### Agrimore Seller

**Current source:** SellerPage already separates scrolling content and its sticky footer. SellerSheetFrame has a flexible scrolling body, explicit viewInsets padding and a safe footer. The stock sheet uses an autofocus numeric input. Current sheet horizontal padding is 20px; the 24px role in this board is a proposed alignment with the locked spacing scale.

**Domain families:** Products/stock/variants: flexible editing and bounded input sheets. Orders/RFQ: safe approval/action footers. Payments/account/onboarding: focusable forms and verification. Home/insights/storefront/posts/reviews: long lists with contextual actions, not universal sticky form controls.

**Target specimen:** Bounded stock sheet — Edit stock. Focus: Stock quantity. Primary: Save stock. Synthetic examples; preserve existing validation and real outcome semantics.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Sheet inset | 24 |
| Field gap | 16 |
| Footer inset | 24 |
| Footer vertical | 12 |
| Action minimum | 48 |

Target rules:

- Bound the sheet to the available height.
- Scroll the sheet body; reserve its footer.
- Apply the keyboard inset once at the sheet edge.
- Keep stock quantity visible during numeric entry.

Source anchors:

- [seller_layout.dart](../../apps/seller/lib/design_system/components/seller_layout.dart)
- [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart)
- [seller_fields.dart](../../apps/seller/lib/design_system/components/seller_fields.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)

Scanned screen-family directory inventory:

| Family | Dart files |
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

### Agrimore Delivery

**Current source:** The support form and delivery-problem panel put submit actions inside scroll content. DeliveryBottomActionBar defines manual keyboard padding, but no call sites were found in the scanned source. Its adoption and the sticky support footer shown here are proposals. A resizing parent plus the helper's manual inset must not double-apply clearance.

**Domain families:** Home/map/operations: controller-connected draggable sheet and unobscured map controls. Orders/problems/support: safe message/attachment entry and reachable submit. Money/history: scrollable statements and receipts. Auth/profile/settings: focusable input with dynamic inset handling.

**Target specimen:** Field-friendly task page — Support request. Focus: Message. Primary: Send request. Synthetic examples; preserve existing validation and real outcome semantics.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Field gap | 16 |
| Section gap | 24 |
| Footer inset | 16 |
| Footer vertical | 12 |
| Action minimum | 56 |

Target rules:

- Use a large action reachable above the keyboard.
- Keep the message and its helper text visible.
- Separate map gestures from sheet scrolling.
- Use one owner for keyboard clearance.

Source anchors:

- [delivery_layout.dart](../../apps/delivery/lib/design_system/components/delivery_layout.dart)
- [submit_support_request_screen.dart](../../apps/delivery/lib/screens/support/submit_support_request_screen.dart)
- [delivery_problem_panel.dart](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart)
- [home_operations_panel.dart](../../apps/delivery/lib/screens/home/home_operations_panel.dart)

Scanned screen-family directory inventory:

| Family | Dart files |
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

### Agrimore Sales Associate

**Current source:** The payout request screen uses a 16px-padded scrollable form and a review button inside the content. Review remains gated by account, balance and amount validation. The board proposes a separate sticky review footer and 24px page inset; it does not submit a payout or imply payment completion.

**Domain families:** Wallet/payout: legible amount entry, eligibility and review. Orders/home: route-specific summaries and lists. Auth/profile: comfortable forms. Notifications/support: readable scrolling content. Internal app path remains employee.

**Target specimen:** Calm financial task page — Request payout. Focus: Payout amount. Primary: Review payout request. Synthetic examples; preserve existing validation and real outcome semantics.

| Target role | px |
| --- | --- |
| Page inset | 24 |
| Field gap | 16 |
| Section gap | 24 |
| Footer inset | 24 |
| Footer vertical | 16 |
| Action minimum | 52 |

Target rules:

- Keep amount and eligibility guidance together.
- Reserve the review action outside the scroll.
- Reveal the amount field during numeric entry.
- Let financial labels wrap at larger text sizes.

Source anchors:

- [payout_request_screen.dart](../../apps/employee/lib/screens/wallet/payout_request_screen.dart)
- [employee_shell_screen.dart](../../apps/employee/lib/screens/shell/employee_shell_screen.dart)
- [sa_loading_button.dart](../../packages/agrimore_ui/lib/widgets/common/sa_loading_button.dart)

Scanned screen-family directory inventory:

| Family | Dart files |
| --- | --- |
| auth | 5 |
| home | 1 |
| notifications | 1 |
| orders | 2 |
| profile | 2 |
| shell | 1 |
| support | 1 |
| wallet | 6 |

### Agrimore Admin

**Current source:** Product editing uses a Form/TabBarView and a bottomNavigationBar containing Cancel and Save changes. The footer is not explicitly keyboard-aware. Admin auth uses resizeToAvoidBottomInset:false and manual input clearance, so a blanket resize-true replacement is inappropriate. The board proposes a keyboard-safe mobile editor footer and locked token styling.

**Domain families:** Products/categories/content: long editors with safe save/cancel. Orders/delivery/sellers/employees/users: responsive operational lists and detail tasks. Finance/wallet/security/settings: cautious input/review. Analytics: readable mobile summaries. Desktop rails are outside these mobile boards.

**Target specimen:** Compact mobile editor — Edit product. Focus: Description. Primary: Save changes. Synthetic examples; preserve existing validation and real outcome semantics.

| Target role | px |
| --- | --- |
| Page inset | 16 |
| Field gap | 12 |
| Section gap | 24 |
| Footer inset | 16 |
| Footer vertical | 12 |
| Action minimum | 48 |

Target rules:

- Keep editor sections inside one flexible scroll.
- Reserve Save changes and Cancel below the form.
- Stack actions when labels or text need more room.
- Keep the focused field above the action footer.

Source anchors:

- [product_form_screen.dart](../../apps/admin/lib/screens/admin/products/product_form_screen.dart)
- [product_form.dart](../../apps/admin/lib/screens/admin/products/widgets/product_form.dart)
- [auth_screen.dart](../../apps/admin/lib/screens/auth/auth_screen.dart)
- [admin_shell.dart](../../apps/admin/lib/screens/admin/admin_shell.dart)

Scanned screen-family directory inventory:

| Family | Dart files |
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

## Proposed acceptance checks for implementation

These are future checks, not completed runtime tests:

- Open/close text and numeric keyboards on short and tall screens, landscape and split-screen where supported. Verify no footer/field overlap and no double inset.
- Tab/focus through every field and reveal validation messages without losing the current value. Check explicit focus recovery and software/hardware keyboard operation.
- At large text and longer translations, let titles, labels and actions grow; ensure the last field and actions remain reachable. Verify short-height fallback.
- Exercise gesture/navigation safe areas, display cutouts and changing metrics. Keep map controls and draggable sheets inside their intended bounds.
- Confirm Seller stock sheets retain save/error behavior; Marketplace address save validation; Delivery attachment/message submission; Sales Associate payout eligibility and review; Admin cancellation/save semantics.
- Check both themes against the C01 role specification. PNG colors and geometry are approximate illustrations; manifest targets are exact.

## Handoff scope

Only the 10 PNGs, 15 per-app README/prompt/manifest files and these two master documents are added. No runtime source, app dependency, asset registration, behavior or C01 lock is changed. C06 remains a review proposal until explicitly approved.
