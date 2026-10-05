# Agrimore — C10 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-image gallery](FIELDS_VALIDATION_ERROR_SUMMARIES_BOARDS_2026-10-03.md) · [C01 approval](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 source files / 271,604 lines**. All eligible Dart text in five app lib trees and agrimore_ui/core/services plus TypeScript functions/src was scanned for field/validation/focus markers. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Representative domain forms and primitives read contextually. This is a broad static inventory plus focused review, not exhaustive semantic review of every line or a rendered audit of every screen.

Marker totals include comments and construction text; they are not unique screen or defect counts. Backend inventory contextualizes authoritative validation; it does not imply backend owns field layout. Concurrent implementation proceeds independently; observations are a timestamped source snapshot, not deployed guarantees.

| Scope | TextFormField | TextField | Validator | Error text | Helper | Focus | Reveal | First invalid | Summary | Formatters |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 55 | 74 | 46 | 4 | 12 | 3 | 0 | 0 | 0 | 7 |
| delivery | 4 | 13 | 5 | 12 | 3 | 1 | 1 | 0 | 0 | 3 |
| employee | 14 | 2 | 12 | 1 | 0 | 5 | 0 | 0 | 0 | 5 |
| marketplace | 16 | 33 | 32 | 0 | 3 | 14 | 0 | 0 | 0 | 15 |
| seller | 0 | 8 | 36 | 4 | 9 | 1 | 1 | 4 | 4 | 17 |
| functions | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 2 | 1 | 2 | 0 | 0 | 1 | 0 | 0 | 0 | 2 |

## Shared target field contract

1. Persistent visible labels, required/optional wording, stable logical IDs, unit/prefix slots and useful examples. Placeholder text never replaces a label. Preserve strings such as phone/PIN codes instead of numeric coercion.
2. Show helper guidance before failure; errors name the field and correction after interaction or failed submit. Avoid validating untouched fields immediately. Clear/recheck corrected errors without losing other entries. Formatters guide input; validators enforce domain rules.
3. A summary uses the same field-specific errors as inline messages, logical form order and accessible links. One-field sheets may use a compact single error. Do not create unrelated errors just to fill a board. Announce the failed submission concisely, not every keystroke.
4. On failed submit: validate, reveal the correct section/tab/conditional branch, await layout, scroll clear of keyboard/sticky actions, focus the first invalid logical control. Do not double-move focus between summary and field; choose a consistent announcement/focus policy. Summary links focus their exact field by stable ID.
5. Include text fields, selectors, radio groups, images and composite code inputs in the error model. Keep logical order stable across responsive layouts and right-to-left rendering; visual geometry alone is not a universal ordering policy. Disabled/read-only fields need a reachable explanation or prerequisite action, not impossible validation traps.
6. Use role-correct errors plus text/icons; keep focus perceivable independently of error. Respect C01 per-app tokens, comfortable 48px targets, expanding labels/helper text and 100–200% text scaling. Actual contrast, hit areas and screen-reader order require runtime measurement.
7. Separate field syntax, cross-field rules, prerequisites, serviceability and server rejection. Map server field errors safely; retain values and a form-level retry for network errors. Never put raw exceptions, internal IDs or real personal data in error copy.
8. Code length is not delivery verification; valid money syntax is not payout approval/settlement; valid address syntax is not deliverability; parsed product price is not authoritative validity. Recheck server constraints at commit. Preserve actor/payload/request identity according to existing workflows.
9. Reuse existing SellerTextField/SellerFormScope, DeliveryTextField/DeliveryOtpField, CustomTextField and associate controls before extending equivalents. No new runtime widgets or canonical package folders are introduced in this asset task.

## Agrimore Marketplace

**Current source:** Address saving runs Form.validate, then sequential snackbar checks for name, 10-digit phone, building/road and regional choices; pincode fields use short Required/6 digits errors. Signup has explicit next-field focus, but address submit has no observed first-invalid summary routing.

**Target:** Persistent labels and helper patterns, inline address errors mirrored by a linked summary, and focus/scroll to the earliest invalid address control after failed Save.

**Character:** Welcoming address form, clear regional dependencies and generous helper text.

| Panel | Domain specimen |
| --- | --- |
| Address inputs | Fields: Recipient name, Mobile number, PIN code, Landmark (optional). Use empty input hints; helper Mobile number: Use 10 digits. PIN code: Use 6 digits. No personal data. |
| Helpful inline errors | Mobile number field empty, error Enter a 10-digit mobile number. PIN code field empty, error Enter a 6-digit PIN code. Show focus on Mobile number with visible outline. |
| Error summary | Title Check your address. Exactly two linked items: Mobile number — Enter a 10-digit mobile number; PIN code — Enter a 6-digit PIN code. Preserve other entries. |
| First invalid focus | Save address → Validate → Reveal Mobile number → Focus. Failed submit keeps values. Fix one error at a time. Location eligibility is a separate check. |

Gaps/preservation:

- Replace ambiguous Required and 6 digits with field-specific corrections.
- Preserve manual state/district/city mode and entered values; reveal the active control before focusing.
- Format validation does not prove address serviceability or a saved address.

Verified source anchors:

- [add_address_screen.dart](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart)
- [signup_screen.dart](../../apps/marketplace/lib/screens/auth/signup_screen.dart)
- [custom_text_field.dart](../../packages/agrimore_ui/lib/widgets/common/custom_text_field.dart)

Scanned screen families (file counts, not unique screens):

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

**Current source:** SellerTextField/Dropdown register focus handles in SellerFormScope; summary links focus by label and first-invalid sorts rendered visual positions. Product publish schedules focus after validation; draft only requires name. Stock helper preserves malformed/missing raw stock as unknown.

**Target:** Extend the existing field/scope system with stable field identifiers, explicit numeric/unit rules and summary links that also reveal collapsed or offstage sections.

**Character:** Compact blue-teal product editor with copper section cues, units and draft-aware requirements.

| Panel | Domain specimen |
| --- | --- |
| Product inputs | Fields Product name, Sale price with ₹ prefix and helper Set a valid sale price, Stock quantity with units suffix and helper Use a whole-unit count. Copper chip Draft has fewer requirements. |
| Helpful inline errors | Product name empty: Enter a product name. Stock quantity empty: Enter a whole-unit stock count. Show first focused Product name. No fake monetary values. |
| Publish summary | Title Check before publishing. Exactly two linked errors: Product name — Enter a product name; Stock quantity — Enter a whole-unit stock count. Secondary text Your draft is preserved. |
| First invalid focus | Publish → Validate → Reveal Product name → Focus. Draft and publish use different rules. Missing stock stays unknown. Reuse existing field scope. |

Gaps/preservation:

- Retain draft versus publish requirements instead of enforcing all publish checks on drafts.
- Label-based focus can collide; stable field IDs are a target improvement, not current implementation.
- Audit numeric parsing independently: several editor validators only check nonempty; unknown stock must not silently become zero.

Verified source anchors:

- [seller_fields.dart](../../apps/seller/lib/design_system/components/seller_fields.dart)
- [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart)
- [stock_count_validation.dart](../../apps/seller/lib/screens/products/stock_count_validation.dart)

Scanned screen families (file counts, not unique screens):

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

## Agrimore Delivery

**Current source:** DeliveryTextField forwards labels, validators and focus nodes. Active-order verify sheet uses DeliveryOtpField with six cells, digit semantic labels, inline error and disabled while submitting; incomplete code sets an error and returned server errors stay in the open sheet.

**Target:** Treat six visible code cells as one logical input, focus its actual editable control on validation failure and distinguish incomplete input from server rejection without announcing every digit.

**Character:** High-contrast monochrome verification sheet, burgundy error states and burnt-orange focus.

| Panel | Domain specimen |
| --- | --- |
| Verification input | Single group Delivery code with six EMPTY square cells. Helper Enter the 6-digit delivery code. One logical accessible input. Black primary Verify delivery, never orange primary. |
| Helpful inline errors | Same six EMPTY cells and burgundy inline error Enter the complete 6-digit code. Separate server-error specimen Code not accepted. Check and try again. No digits or success tick. |
| Focused error summary | Title Check delivery code. One linked item Delivery code — Enter the complete 6-digit code. Single-field sheet uses a compact summary, no fake second error. |
| First invalid focus | Verify delivery → Validate format → Reveal code input → Focus. Server checks follow valid input. Keep sheet open on rejection. Proof photo is separate. |

Gaps/preservation:

- A six-digit format is not verification; only the server can confirm completion.
- Never display OTP digits, sensitive logs or assumed successful handover.
- Keep verification errors separate from optional proof-photo upload retry and rate-limit guidance.

Verified source anchors:

- [delivery_fields.dart](../../apps/delivery/lib/design_system/components/delivery_fields.dart)
- [delivery_otp.dart](../../apps/delivery/lib/design_system/components/delivery_otp.dart)
- [active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)

Scanned screen families (file counts, not unique screens):

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

## Agrimore Sales Associate

**Current source:** Payout request uses a digits-only TextFormField, validates positive amount against wallet balance, requires a saved payout account and navigates to review. No summary/first-invalid coordinator was found in this focused flow. Account screen has its own field validators.

**Target:** Make payout amount labels and whole-rupee input policy explicit, link errors to the amount field and provide a reachable account prerequisite action without confusing validation with settlement.

**Character:** Premium royal-blue payout form with indigo guidance, masked destination and deliberate money hierarchy.

| Panel | Domain specimen |
| --- | --- |
| Payout inputs | Field Payout amount with ₹ prefix, empty hint Enter amount, helper Enter a whole-rupee amount within your available balance. Separate destination card Masked payout account; no invented IDs, balances or amounts. |
| Helpful inline errors | Payout amount empty with error Enter a payout amount greater than zero. Separate explanatory specimen Amount exceeds available balance — Enter an amount within your available balance. Show these as alternate states, not simultaneous errors. |
| Error summary | Title Check payout amount. One linked item Payout amount — Enter a payout amount greater than zero. Separate prerequisite callout Payout account required and enabled Add payout account action. |
| First invalid focus | Review payout → Validate → Reveal Payout amount → Focus. Preserve entry. Valid input opens review. Request approval and settlement are separate. |

Gaps/preservation:

- Current request input is digits-only; do not invent a decimal-entry policy or broaden it silently.
- Missing account is a prerequisite with Add payout account action, not a fictitious amount error.
- Recheck authoritative balance at submission; a locally valid amount does not mean payout paid.

Verified source anchors:

- [payout_request_screen.dart](../../apps/employee/lib/screens/wallet/payout_request_screen.dart)
- [payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart)
- [requestEmployeePayout.ts](../../functions/src/customer/requestEmployeePayout.ts)

Scanned screen families (file counts, not unique screens):

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

## Agrimore Admin

**Current source:** Product form uses custom styled TextFormField and dropdowns; validators require product name/category/location/description and parse price, with some generic Required/Invalid price messages. Editor save redirects basic-form failure to tab 0 and missing images to tab 1 with snackbar, rather than linking every failure to its control.

**Target:** A cross-section error summary links text, dropdown and image-control failures; switch/reveal the target tab, await layout, then scroll/focus the exact invalid control with safe user-facing copy.

**Character:** Structured professional-blue editor, compact cyan section cues and tab-aware error routing.

| Panel | Domain specimen |
| --- | --- |
| Editor inputs | Fields Product name, Category dropdown, Sale price with ₹ prefix. Compact tabs Basic info, Images, Delivery. Visible labels and required markers. No sidebar. |
| Helpful inline errors | Product name empty: Enter a product name. Category unselected: Choose a category. Focus Product name; cyan only section guidance, errors use locked error colors. |
| Cross-section summary | Title Check product details. Exactly two linked items Basic info / Product name — Enter a product name; Basic info / Category — Choose a category. Additional small routing note Image errors open Images tab (not an active third error). |
| First invalid focus | Save product → Validate → Open Basic info → Focus Product name. Reveal the correct tab before focus. Include dropdowns and image controls. Preserve unsaved edits. |

Gaps/preservation:

- A parseable price is not necessarily valid for its domain; enforce authoritative constraints without invented limits.
- Offstage tab fields must not be focused before their tab is visible.
- Include category/image/coverage controls in the error model; do not implement text-only summary routing.

Verified source anchors:

- [product_form.dart](../../apps/admin/lib/screens/admin/products/widgets/product_form.dart)
- [delivery_info_form.dart](../../apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart)
- [product_form_screen.dart](../../apps/admin/lib/screens/admin/products/product_form_screen.dart)

Scanned screen families (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Blank submit, malformed values, corrected fields and long localized errors; untouched fields remain calm. Summary links and inline errors agree.
- Hidden tab/section, conditional manual address entry, repeated labels, dropdown/image failures, composite OTP and keyboard next/done paths; focus reaches the correct logical control after reveal.
- Keyboard open, sticky actions, narrow phone and applicable desktop layouts, large text, screen readers and reduced motion. No clipped helper text or color-only errors.
- Unknown/malformed stock remains unknown; draft versus publish keeps different requirements. Payout account prerequisite remains separate and existing digits-only entry is preserved unless deliberately changed later.
- Offline/server rejection preserves entries and offers a safe retry; authoritative acceptance is distinct from local validation. No real codes or financial transactions needed for a mocked UI review.

## Handoff scope

Ten PNGs, five per-app README/prompt/manifest sets and two master documents: 27 new repository files. C01–C09 prior design files preserved. Exact prompts and reference/source/output hashes retained. C10 remains provisional until owner approval. No Flutter build, emulator, runtime accessibility certification, implementation migration, pubspec registration, branch, staging, commit, deploy or other-chat interruption.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset validation result

**PASS** at source HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: 10 PNGs / 5 theme pairs, 27 new repository files, 13 exact generation/refinement prompt blocks and 74 local links checked. PNG signatures/dimensions, selected-output hashes, input-reference hashes, prompt hashes and C01 palette/status/spacing/radius/border metadata inheritance passed. All 594 earlier design files retained their pre-task hashes.

The 817-file runtime snapshot showed no byte changes between inventory, packaging and this validation. This task wrote only the 27 declared design assets/documents; the independent implementation conversation was not messaged or interrupted. All selected boards were visually inspected. These checks certify asset integrity and documented token targets, not exact raster color reproduction, working field focus, accessible runtime behavior or deployment. Future implementation checks above remain outstanding.
