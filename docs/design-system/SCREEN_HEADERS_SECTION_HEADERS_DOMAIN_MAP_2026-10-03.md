# Agrimore — C08 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-image gallery](SCREEN_HEADERS_SECTION_HEADERS_BOARDS_2026-10-03.md) · [C01 identity approval](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and limits

Source inventory at HEAD 8a06f3ce1459beec163a279e0061d134e288b386: **816 files / 271,543 lines**, covering the five app lib trees, agrimore_ui/core/services lib and functions/src. All eligible source text was scanned for header-related markers; header primitives and representative domain screens were read contextually. This is a broad static inventory plus focused header review, not a complete semantic review of every line or a rendered audit of every screen. Generated .g/.freezed files, firebase_options and credential/secret-named files are excluded. Backend inventory supplies domain coverage, not a claim that backend code owns header geometry.

Marker totals include comments and construction text, may miss custom widgets and are not counts of unique screens or defects. No Flutter build, emulator, live account, financial transaction, test suite or runtime accessibility audit was run for this asset-only task. Existing runtime work belongs to the concurrent implementation session.

| Scope | AppBar | SliverAppBar | SellerAppBar | DeliveryAppBar | Section/step marker | Subtitle | Actions | Header semantics | Ellipsis |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 56 | 2 | 0 | 0 | 19 | 115 | 96 | 0 | 39 |
| delivery | 22 | 0 | 0 | 3 | 0 | 28 | 9 | 0 | 21 |
| employee | 16 | 0 | 0 | 0 | 16 | 16 | 2 | 0 | 9 |
| marketplace | 32 | 3 | 0 | 0 | 0 | 40 | 22 | 0 | 111 |
| seller | 4 | 0 | 37 | 0 | 22 | 60 | 12 | 29 | 7 |
| functions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 6 | 0 | 0 | 0 |
| agrimore_services | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| agrimore_ui | 0 | 2 | 0 | 0 | 2 | 0 | 7 | 1 | 4 |

## Shared target header contract

1. Name the current page once. Root destinations do not get an invented Back button. Details/tasks do; Close dismisses transient selection/modal context. Preserve C07 navigation and existing draft guards.
2. Screen title, supporting subtitle, current contextual state and trailing action each have a distinct role. The subtitle explains scope, not marketing or duplicated title text. A status is not an action and color alone never conveys it.
3. Use C01 type scales and five separate palettes. Proposed title/subtitle gap is 4px, section spacing 24px, compact inset 16px and wide inset 24px. Screen headings dominate quieter sections. Keep semantic heading roles and meaningful labels, with no duplicate accessibility heading after collapse.
4. Required titles and context grow/wrap under long translations and large text. Actions move below or into a clearly labeled overflow before the title loses meaning. Do not claim a fixed 56/64/138px toolbar satisfies all text scales. Never reduce type merely to preserve a decorative row.
5. Header actions are contextual and labeled. Primary commerce/editor actions differ from supplementary utilities and destructive actions. Minimum 48px interaction targets are proposed; visual glyphs/circles can remain smaller. Delivery's owner-requested 40px visible circles are preserved as a design constraint, with a larger invisible hit region proposed separately.
6. Section actions operate on their own section, with clear labels. Counts appear only from loaded data; unknown values are omitted or explicitly unavailable. A section heading should remain useful without an action or count.
7. Runtime status comes from authoritative domain state. Delivery duty flips only on confirmation; Marketplace uses resolved location/mode; Sales Associate Requested is not settlement; Admin Editing is not Saved/Synced. Loading, unavailable and failure must not be turned into success by a decorative badge.
8. Expanded/collapsed headers preserve the same page identity and accessible reading order. Avoid hiding required context under scroll effects; C05 reduced-motion and C06 safe-area/layout proposals remain relevant. Keep admin workspace headers responsive without silently removing desktop navigation.

These are target design decisions, not normative accessibility certification or implemented widget APIs. Existing agrimore_ui StickyPhotoHeaderSliver and WsStepHeader, SellerAppBar/SellerSectionHeader and DeliveryAppBar must be evaluated for extension/reuse before building equivalents. No new widget is introduced here.

## Agrimore Marketplace

**Current source:** HomeAppBar resolves retail ETA from location settings and B2B to Bulk Freight; its delivery line and address are ellipsized. ShopAppBar has a fixed 138px preferred height. ProductSectionWidget uses a single-line section title and a GestureDetector See all action. Shared photo headers collapse title/subtitle to single lines.

**Target:** A shopping context header separates page title, delivery location and live serviceability. Product/category sections remain visually quieter. Do not invent an ETA before location resolution or hide the current B2B mode.

**Distinct character:** Calm editorial shopping headers; generous natural-stone breathing room, green text actions, tiny warm-gold non-status overlines.

| Panel | Domain-specific specimen |
| --- | --- |
| 01 · Shopping context | Root specimen: title 'Shop'; subtitle 'Select location'; compact outlined action 'Change location'. Detail specimen below: Back icon, title 'Product details', secondary action heart labeled 'Save item'. No root Back. |
| 02 · Product sections | Section title 'Fresh produce'; subtitle 'Explore the category'; trailing green text action 'See all'. Second quiet section 'Product information' with no action. No invented quantity badges. |
| 03 · Delivery context | Two separate status specimens: neutral/info 'Checking delivery time...' with small progress glyph; neutral/info 'Bulk Freight' with truck glyph and caption 'B2B shopping'. Caption: 'Use resolved delivery context'. Do not display a fabricated minutes estimate or availability success. |
| 04 · Long titles & actions | Large-text specimen title split visibly across two lines 'Product information / and delivery options' (slash denotes newline, do not print slash); subtitle 'Details before you order'; outlined 'More options' moved onto a separate row below title. Footer note 'Wrap titles · keep actions reachable'. |

Findings and preservation rules:

- Retain current location/B2B resolution semantics while replacing literal typography and fixed heights.
- Use a real labeled button and generous hit region for See all; preserve category routing.
- Expanded and collapsed photo headers need one accessible page heading and scale-aware height.

Verified source anchors:

- [home_app_bar.dart](../../apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart)
- [shop_app_bar.dart](../../apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart)
- [product_section_widget.dart](../../apps/marketplace/lib/screens/user/home/widgets/product_section_widget.dart)
- [sticky_photo_header.dart](../../packages/agrimore_ui/lib/widgets/common/sticky_photo_header.dart)

Scanned screen-family inventory (file counts, not unique screens):

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

**Current source:** SellerAppBar already provides root, actionsOnly, backOnly and detail variants with semantic headings and text-scale-dependent heights. Titles/subtitles still have ellipsis limits. SellerSectionHeader supports subtitle, count and action in a Row. Catalogue exposes Sort, New post and Add product actions; selection replaces its header with Close.

**Target:** Keep SellerAppBar/SellerSectionHeader as the foundation. Distinguish persistent Catalogue from a pushed product editor and temporary selection mode. Move crowded actions to a secondary row/overflow before sacrificing the title.

**Distinct character:** Precise merchant workspace headers; blue-teal action ownership, restrained copper category rules, denser but balanced control rows.

| Panel | Domain-specific specimen |
| --- | --- |
| 01 · Catalogue & task | Root specimen title 'Catalogue'; subtitle 'Products and inventory'; blue-teal filled 'Add product' action with plus icon. Secondary outlined 'Sort' action. Detail specimen: Back arrow, title 'Add product'; subtitle 'Product details'; no root Back. |
| 02 · Inventory sections | Section title 'Stock and variants'; subtitle 'Manage available quantities'; trailing blue-teal action 'Edit'. Second quiet section 'Product information' without an action. Copper accent only in small neutral overline, never as success status. |
| 03 · Contextual modes | Separate header-state specimen title 'Selection mode' with Close icon and caption 'Close returns to Catalogue'; status chip 'Hidden' with neutral/info palette and eye-off icon; nearby label 'Product visibility'. No numeric selected count fabricated. |
| 04 · Growing task headers | Large-text title on two visible lines 'Stock and variants / for this product'; subtitle 'Review each quantity'; outlined 'More options' on its own lower action row. Footer note 'Wrap titles · stack crowded actions'. |

Findings and preservation rules:

- Existing scale-aware bars and Semantics are strengths to retain, not replace with a parallel widget system.
- Root Catalogue's three trailing actions need a narrow-width and large-text layout contract.
- Selection Close clears selection; task Back preserves existing draft guards. Count must come from loaded data.

Verified source anchors:

- [seller_nav.dart](../../apps/seller/lib/design_system/components/seller_nav.dart)
- [seller_list.dart](../../apps/seller/lib/design_system/components/seller_list.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [product_variants_section.dart](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart)

Scanned screen-family inventory (file counts, not unique screens):

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

**Current source:** HomeAppBar is duty control plus Emergency, Help and Inbox, with Offline/Online bound to confirmed state and a busy spinner during changes. Current supplementary circles are intentionally 40px by earlier owner request. DeliveryAppBar has 56/64px heights and single-line title/subtitle. Active order screens use AppBar with order number and local _Section headings for progress, customer, address, items, payment and proof.

**Target:** Keep duty chrome distinct from delivery task chrome. Status identifies real duty/task state; a header is never an accept/complete action. Keep Emergency immediately identifiable. A proposed 48px invisible hit region may preserve the owner's 40px visual circles, pending later implementation review.

**Distinct character:** Field-first monochrome, strong legible titles, compact neutral duty chrome, tiny burgundy dividers and burnt-orange emergency emphasis.

| Panel | Domain-specific specimen |
| --- | --- |
| 01 · Duty & task chrome | Home chrome specimen: neutral outlined duty pill 'Offline' with toggle off. Three restrained circle actions, visibly labeled beneath 'Emergency', 'Help', 'Inbox'; Emergency glyph burnt orange. Below chrome, page title 'Home'. Task specimen below: Back arrow, title 'Active delivery', subtitle 'Current assignment'. Main controls black/white, no online green celebration. |
| 02 · Delivery sections | Clear stacked section headers 'Delivery address' with small location outline glyph and quiet action 'View map'; subtitle 'Destination details'. Second quiet heading 'Delivery progress' with no action. Burgundy is a restrained secondary accent. |
| 03 · Truthful duty status | Two separate specimen chips 'Offline' neutral/info with power icon; 'Changing availability...' neutral/info with spinner. Caption 'Confirm state before updating label'. No success check, ETA, customer name, order number or proof-of-delivery claim. |
| 04 · Field readability | Large-text title across two lines 'Delivery address / and customer instructions'; subtitle 'Read before arrival'; outlined 'More options' moved to a separate lower row. Footer note 'Keep Emergency reachable · allow text to grow'. |

Findings and preservation rules:

- Source honors confirmed duty state and busy state; preserve this behavior exactly.
- Fixed title/subtitle heights need scale and long-translation testing.
- 48px invisible hit regions are a proposed interaction enhancement; do not silently reverse the prior owner decision for 40px visual circles.
- Future task title may use authorized order number when loaded; illustrations avoid IDs and customer data.

Verified source anchors:

- [home_app_bar.dart](../../apps/delivery/lib/screens/home/home_app_bar.dart)
- [delivery_layout.dart](../../apps/delivery/lib/design_system/components/delivery_layout.dart)
- [active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)

Scanned screen-family inventory (file counts, not unique screens):

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

**Current source:** Attributed Orders uses a plain AppBar and a separate search/filter header for All, B2B and Retail orders. Payout History uses a plain AppBar with an unlabeled custom leading button and separate All/Requested/Paid-Settled filters. Shared workspace WsStepHeader supplies a semantic multi-step header but is a distinct flow primitive, not a general AppBar.

**Target:** Use royal-blue hierarchy for attributed business context and quieter indigo for sections. Explicitly distinguish order attribution from earnings and payout requests from settlement. Add meaningful leading/action labels and consistent section semantics.

**Distinct character:** Refined advisory workspace, premium royal blue with pearl/slate, understated indigo section markers, careful financial status language.

| Panel | Domain-specific specimen |
| --- | --- |
| 01 · Attributed work | Root specimen title 'Attributed Orders'; subtitle 'B2B and retail orders'; outlined labeled 'Search orders' with magnifier. Detail specimen Back arrow, title 'Payout History'; subtitle 'Requests and settlement status'. Do not fabricate earnings or commission totals. |
| 02 · Relationship sections | Section heading 'Order attribution'; subtitle 'Your associated orders'; quiet royal-blue action 'View orders'. Second quiet section 'Payout destination' with subtitle 'Account used for requests'; muted indigo supporting rule. |
| 03 · Payout context | Separate specimen info chip 'Requested' with clock icon; label 'Payout status'; secondary caption 'Request recorded; settlement pending'. Another neutral text context line 'B2B orders' with briefcase icon. No Paid/Settled checkmark or payout amount. |
| 04 · Long contextual titles | Large-text title across two visible lines 'Payout destination / and account details'; subtitle 'Review before requesting'; outlined 'More options' below on its own action row. Footer note 'Wrap titles · label Back and actions'. |

Findings and preservation rules:

- Search/filter rows stay separate from screen hierarchy; no duplicate heading for the same page.
- Back and icon actions need tooltips/semantic labels.
- Status derives from actual payout records; Requested cannot imply successful transfer.
- Internal employee paths are retained; user-facing product remains Sales Associate.

Verified source anchors:

- [orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart)
- [payout_details_screen.dart](../../apps/employee/lib/screens/wallet/payout_details_screen.dart)
- [ws_step_header.dart](../../packages/agrimore_ui/lib/workspace/kit/ws_step_header.dart)

Scanned screen-family inventory (file counts, not unique screens):

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

**Current source:** AdminShell's mobile header shows current module label/subtitle, menu, brand icon and initials. Subtitle mapping only explicitly covers indices 0–17, with empty default despite more modules. Product Management adds a pinned gradient SliverAppBar with title, subtitle, Refresh and Categories. Product editor has its own white AppBar with dynamic Add/Edit title, product-name subtitle and Delete action.

**Target:** One authoritative page heading per surface; shell chrome handles navigation while the page owns its title/context. Use professional blue for hierarchy, cyan support, neutral backgrounds. Keep module identity and destructive actions explicit; Admin is a responsive workspace, not forced into a phone-only UI.

**Distinct character:** Disciplined responsive operations workspace; wide title/action rows, crisp steel borders, blue hierarchy and restrained cyan outlines.

| Panel | Domain-specific specimen |
| --- | --- |
| 01 · Workspace heading | Wide page-header specimen title 'Product Management'; subtitle 'Manage your product catalog'; right side outlined labeled actions 'Refresh' and 'Categories'. Quiet overline 'Products'. Smaller detail strip beneath: Back arrow, title 'Edit Product', subtitle 'Product details'. No sidebar or avatar. |
| 02 · Form sections | Section title 'Stock and variants'; subtitle 'Product configuration'; trailing professional-blue action 'Edit'. Second quiet heading 'Delivery information', subtle cyan outline glyph. Keep white or dark neutral surfaces. |
| 03 · Editing context | Two separate specimens: info chip 'Editing' with pencil icon; neutral context text 'Product details'. Separate outlined destructive header action 'Delete product' using Error text color and trash icon. Caption 'Confirm destructive actions'. No fake synchronized or saved status. |
| 04 · Responsive header | Large-text/narrow specimen title split across two visible lines 'Product categories / and inventory rules'; subtitle 'Catalog configuration'; move 'Refresh' and 'Categories' outlined buttons to a lower row. Footer note 'One page heading · actions reflow below'. |

Findings and preservation rules:

- Avoid duplicate module/page titles on compact Product Management; decide shell versus page ownership explicitly.
- Map subtitles by stable module identity rather than partially covered positional indices.
- Remove literal white/gradient assumptions during a future header migration; C01 dark is near-black with pale blue/cyan accents.
- Keep destructive action visible and confirmation behavior; do not invent header Saved or Synced badges.

Verified source anchors:

- [admin_shell.dart](../../apps/admin/lib/screens/admin/admin_shell.dart)
- [product_management_screen.dart](../../apps/admin/lib/screens/admin/products/product_management_screen.dart)
- [product_form_screen.dart](../../apps/admin/lib/screens/admin/products/product_form_screen.dart)
- [seller_detail_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart)

Scanned screen-family inventory (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation acceptance checks

- Review every root/detail/modal/selection header variant and ensure one page-title owner. Verify root Back, task Back, Close and unsaved draft behavior separately.
- Inspect both themes at narrow phone and applicable desktop widths, 100–200% text scale and long translations. Keep subtitles/context useful and full action labels reachable.
- Check screen/section headings, collapsed headings, button labels, keyboard focus, reading order and invisible hit areas with platform accessibility tools.
- Verify duty pending/failure, location loading/unserviceable/B2B, product visibility, payout Requested versus actual settlement and editor dirty/save/failure states against real providers.
- Verify admin module subtitles for all modules, not only the current partial index mapping. Confirm compact Product Management shell/page composition does not duplicate titles.
- Reuse/extend current components with all-five-app checks for shared changes; avoid a parallel generic header kit that loses per-app identities.

## Handoff and validation scope

Ten selected PNGs plus fifteen per-app README/prompt/manifest files and this gallery/domain pair (27 new repository files). Exact prompt text, generation/refinement history, source/reference hashes, PNG dimensions and C01 inheritance are saved. Earlier C01–C07 assets/documents remain unchanged. C08 is provisional until owner approval; it is not added to pubspec, runtime widgets or shared exports. No branch, staging, commit, emulator or implementation session interruption.

## Asset validation

**PASS:** ten PNGs / five light-dark pairs; all ten C01 input hashes and inherited palette, status, spacing, radius, border and typography targets verified. Twelve exact prompt blocks preserve successful generation and refinement provenance. All 93 local documentation links resolve. The 540 earlier design files are byte-for-byte unchanged. The 816 inventoried runtime files were unchanged across packaging and validation; this session only wrote its 27 C08 documentary files. Source work in another session continued before the final snapshot. Selected images were visually reviewed; these checks establish asset integrity and provenance, not pixel-perfect color matching or runtime UI correctness.
