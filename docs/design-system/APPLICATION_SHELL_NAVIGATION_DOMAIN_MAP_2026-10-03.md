# Agrimore — C07 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Open ten-image gallery](APPLICATION_SHELL_NAVIGATION_BOARDS_2026-10-03.md). [C01 approval](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md) remains authoritative for color, typography, shapes and borders.

## Coverage and limits

HEAD f87ce8cd53b6971650dd0aeb79ee164aa3865ef8: **815 source files / 271,458 lines** inventoried across five app lib trees, three shared package lib trees and functions/src. Source text was scanned for navigation patterns; shell, routing, auth-gate, notification, browser-history and entry code was read contextually. Files ending .g.dart/.freezed.dart, firebase_options.dart and credential/secret-named files were excluded. Android manifests and iOS Info.plist declarations were also checked. This is a broad static source inventory plus focused navigation review, not a complete semantic review of every line or rendered audit of every screen. Backend code provides domain context rather than shell geometry.

No runtime build, emulator, live login, OS link launch, domain association verification, browser-history or navigation test execution was performed for these documentary assets. Existing tests are source anchors, not new passing test evidence. Marker counts include text/comments and may miss custom widgets; they do not count live navigators, unique screens or defects.

| Scope | Navigator text | Named push text | IndexedStack | PopScope | GoRoute | ShellRoute | Route handler | Link receiver | Nav-bar marker |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 208 | 0 | 0 | 0 | 53 | 1 | 0 | 0 | 0 |
| delivery | 76 | 0 | 1 | 2 | 0 | 0 | 0 | 0 | 3 |
| employee | 39 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| marketplace | 271 | 73 | 1 | 2 | 0 | 0 | 1 | 0 | 0 |
| seller | 69 | 0 | 1 | 4 | 0 | 0 | 0 | 0 | 2 |
| functions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 21 | 18 | 0 | 0 | 0 | 0 | 0 | 2 | 0 |
| agrimore_ui | 12 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |

## Shared target navigation contract

1. Root destinations express domains, not one-off actions. Preserve each app's root order and selected identity; use semantic route/tab IDs rather than shared positional indices. Keep labels visible and indicate selection with shape, icon and text rather than color alone. Avoid oversized central buttons that imply a primary action for a root destination.
2. Retain each root's meaningful state while switching roots. IndexedStack preserves mounted widget state; it does not create independent nested detail stacks. Independent stacks, restoration after process death and reselect-to-scroll behavior require explicit future decisions/tests, not a decorative board claim.
3. Back first dismisses the active keyboard/overlay as appropriate, then pops the current task detail. Only at a root does the app's root policy apply. Marketplace, Seller and Delivery already return non-Home roots to Home; Sales Associate adds that policy as a proposal. Admin follows route/module and browser history. Do not apply Android app-exit behavior to iOS or browser history.
4. Respect unsaved drafts before task Back, root replacement or deep-link navigation. Existing PopScope guards must be retained; guarding declarative route replacement also needs router-specific handling. Never claim a root-shell PopScope alone protects every editor.
5. An incoming intent has an allowlisted type and validated record ID. Wait until routing is ready, check live access and resource authorization, select a sensible parent and open the requested detail once. Preserve an intent through required sign-in/approval only for the same current session and revalidate it on resume. Clear stale intents and sensitive routes on account change. Public product entry may remain public; access checks are conditional and do not invent a mandatory sign-in screen.
6. Missing, deleted, expired or inaccessible records must resolve to a safe authorized parent with user-safe feedback. Do not dump a raw route exception, token, record payload or arbitrary external URL into the UI. A successful navigation does not imply order acceptance, payment completion or delivery state change.
7. Keep C06 measured safe areas, growing labels and minimum 48px targets; C05 motion/haptic preferences remain separate. Root bars belong to root surfaces. Full-screen editors and task details use deliberate Back chrome. Marketplace's Home-only bar is preserved; no universal tab-bar overlay is imposed.

The official [Flutter navigation guide](https://docs.flutter.dev/ui/navigation) distinguishes imperative Navigator routes, declarative Router history and web integration. [Deep-link guidance](https://docs.flutter.dev/ui/navigation/deep-linking) separates platform URL delivery from app route resolution. [PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html) documents platform-dependent pop handling; an Android policy is not proof of iOS/web behavior.

## Entry support matrix

| App | Current entry foundation | Target gap |
| --- | --- | --- |
| Marketplace | Named/dynamic routes; FCM taps; web pop-state listener; Android filters/iOS scheme | Consistent pending-intent/access checks, safe cold-entry parent, cold/warm/browser validation |
| Seller | Access gate + direct pushes; Android custom scheme | App-specific URI/notification resolver and safe approved-seller intent resume |
| Delivery | Session gate; offer intent queue/coordinator; Inbox detail pushes; Android scheme | Separate offer versus ordinary detail intents; generic URL resolution and duty-safe fallback |
| Sales Associate | Four-root shell; direct pushes; unknown named routes return auth gate; Android scheme | Typed payout/order intents and root-back policy |
| Admin | GoRouter parameterized URLs, ShellRoute and role-aware redirects | Auth intent continuity, stable module identity, cold-entry/editor/browser validation |

A scheme declaration is not an implemented destination resolver. Android queries entries describe outbound visibility, not inbound app links. Shared DeepLinkService declares a URI stream and initial-link handler, but no initialize call sites were found in app lib. This does not mean Flutter platform routes are absent; Marketplace and Admin have their own route entry foundations. No deployed domain association or universal-link entitlement result is asserted.

## Agrimore Marketplace

**Current shell:** MainScreen lazily builds and retains Home, Shop, Categories, Cart and Profile in an IndexedStack. Its navigation bar appears only on Home and can hide on scroll. Other destinations use onBack callbacks to select Home. Android Home uses a two-second second-back exit policy. The current bar label Category is normalized to Categories in this proposal. Tab URLs are replaced via history.replaceState; app/app.dart installs the pop-state listener and replaces the named route on browser history changes.

**Current entry:** routes.dart resolves /product/:id, /category/:id, /order/:id and other named routes; main.dart handles order/product notification taps. Dynamic product/order handlers are not themselves wrapped in AuthGuard. AuthGuard passes mobile children through and gates web children. DeepLinkService.initialize and navigateFromUrl call sites were not found. Platform filters and route parsing do not prove cold/warm app-link behavior or domain association verification.

**Target direction:** Retain Home-only destination launch bar, give Categories the full label, remove decorative prominence that confuses root destinations with actions, keep focus/labels and safe inset treatment consistent. Product entry receives a deterministic Shop fallback when no prior stack exists. Retained tab state does not imply independent per-tab detail stacks.

| Root destination | Purpose |
| --- | --- |
| Home | Browse entry |
| Shop | Product catalogue |
| Categories | Browse by type |
| Cart | Review items |
| Profile | Account & support |

Target Back rules:

- Product detail → Previous screen
- Other destination → Home
- Home → Back again to exit

Target entry flow: **Product link → Access check → Shop → Product details**.

- Keep the requested product after access checks.
- Open once; use a safe parent when history is empty.

Source anchors:

- [main_screen.dart](../../apps/marketplace/lib/screens/user/main_screen.dart)
- [routes.dart](../../apps/marketplace/lib/app/routes.dart)
- [main.dart](../../apps/marketplace/lib/main.dart)
- [auth_guard.dart](../../apps/marketplace/lib/screens/auth/auth_guard.dart)
- [web_url_helper_web.dart](../../apps/marketplace/lib/utils/web_url_helper_web.dart)
- [app.dart](../../apps/marketplace/lib/app/app.dart)

Existing test sources (not executed in this asset task):

- [routes_test.dart](../../apps/marketplace/test/routes_test.dart)

Scanned screen-family directory inventory (files, not unique screens):

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

**Current shell:** SellerShell has Home, Orders, Catalogue, Payments and Account roots, an IndexedStack, selection haptics and a pending-action order badge. PopScope returns non-Home roots to Home. A rail is used from the non-compact layout (600dp in current layout logic). The compact shell is shown here to respect the no-sidebar board format.

**Current entry:** App uses MaterialApp with SellerAuthGate and direct imperative detail navigation. Android declares agrimore-seller; no app-level URI receiver, named-route resolver or deep-link coordinator was found in the scanned app lib. The Order link flow is a target proposal, not working URL support.

**Target direction:** Keep the five root labels and retained workspace. Root selection is an identity, not a primary action. Add typed, allowlisted detail intents with seller access and order ownership checks before constructing a detail route; preserve unsaved-edit guard behavior. No fabricated notification badges.

| Root destination | Purpose |
| --- | --- |
| Home | Work overview |
| Orders | Fulfilment queue |
| Catalogue | Products & stock |
| Payments | Seller funds |
| Account | Store & settings |

Target Back rules:

- Order detail → Orders
- Other root → Home
- Home → Platform back

Target entry flow: **Order link → Seller access → Orders → Order details**.

- Wait for approved seller access before opening.
- Validate ownership and avoid duplicate detail pages.

Source anchors:

- [seller_shell.dart](../../apps/seller/lib/screens/shell/seller_shell.dart)
- [app.dart](../../apps/seller/lib/app/app.dart)
- [seller_orders_screen.dart](../../apps/seller/lib/screens/orders/seller_orders_screen.dart)
- [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart)

Existing test sources (not executed in this asset task):

- [shell_test.dart](../../apps/seller/test/shell/shell_test.dart)

Scanned screen-family directory inventory (files, not unique screens):

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

**Current shell:** DeliveryShell lazily retains five roots: Home, Deliveries, Earnings, Inbox and Profile. Deliveries mounts RiderHistoryScreen, not an active-job tab. The Inbox unread stream is shared/memoized. Non-Home back selects Home; at Home, online back requests backgrounding with a SystemNavigator.pop fallback if backgrounding fails; offline permits platform exit. Navigation itself does not mark a rider offline.

**Current entry:** OfferLaunch queues an orderId and OfferCoordinator opens incoming offers; main.dart wires delivery_offer FCM/local notification entry. RiderSessionGate clears offer intents and old-session routes on rider changes. Inbox opens delivery/order details imperatively with current record validation. Android declares agrimore-delivery, but no generic URI route resolver was found. The Delivery alert flow shown here targets a delivery detail notification; incoming offers must continue through the dedicated offer coordinator rather than this history-detail flow.

**Target direction:** Retain the duty-aware five-root shell and clearly name Deliveries as history. Back on duty must preserve duty state; handle background fallback honestly. Route incoming offers and ordinary delivery detail alerts as separate intent types, with assignment/state validation and one open detail instance.

| Root destination | Purpose |
| --- | --- |
| Home | Duty & live work |
| Deliveries | Delivery history |
| Earnings | Statements & payouts |
| Inbox | Updates & support |
| Profile | Rider account |

Target Back rules:

- Delivery detail → Deliveries
- Other root → Home
- On-duty Home → Background app

Target entry flow: **Delivery alert → Rider access → Deliveries → Delivery details**.

- Check assignment and current delivery state.
- Back never changes duty status.

Source anchors:

- [delivery_shell.dart](../../apps/delivery/lib/app/delivery_shell.dart)
- [app.dart](../../apps/delivery/lib/app/app.dart)
- [offer_launch.dart](../../apps/delivery/lib/offers/offer_launch.dart)
- [offer_coordinator.dart](../../apps/delivery/lib/offers/offer_coordinator.dart)
- [main.dart](../../apps/delivery/lib/main.dart)
- [inbox_screen.dart](../../apps/delivery/lib/screens/inbox/inbox_screen.dart)

Existing test sources (not executed in this asset task):

- [delivery_shell_test.dart](../../apps/delivery/test/delivery_shell_test.dart)
- [rider_inbox_history_test.dart](../../apps/delivery/test/rider_inbox_history_test.dart)

Scanned screen-family directory inventory (files, not unique screens):

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

**Current shell:** EmployeeShellScreen has four roots: Home, Orders, Wallet and Profile, retained in an IndexedStack. initialTab is clamped and a controller can switch roots. Navigation labels are always visible. No shell-level PopScope was found, so the proposed non-Home-back-to-Home policy is new. Internal app path remains employee; user-facing name is Sales Associate.

**Current entry:** MaterialApp uses a navigator key, direct MaterialPageRoute pushes, and onUnknownRoute returning the live auth gate. Shared named-route notification navigation therefore falls back to that gate; it does not prove that a payout-specific destination opens. Android declares agrimore-employee, but no URI resolver was found. Payout update → Wallet → detail is a target intent contract.

**Target direction:** Keep the four roots and add one explicit root-back policy. Introduce typed notification intents after live associate approval checks, with Wallet as the cold-entry parent. Never label a payout paid merely because navigation succeeded.

| Root destination | Purpose |
| --- | --- |
| Home | Sales overview |
| Orders | Attributed orders |
| Wallet | Commission & payouts |
| Profile | Account & support |

Target Back rules:

- Payout detail → Wallet
- Other root → Home
- Home → Platform back

Target entry flow: **Payout update → Associate access → Wallet → Payout details**.

- Resume only after approval and access checks.
- An update never implies payment completion.

Source anchors:

- [employee_shell_screen.dart](../../apps/employee/lib/screens/shell/employee_shell_screen.dart)
- [app.dart](../../apps/employee/lib/app/app.dart)
- [main.dart](../../apps/employee/lib/main.dart)
- [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart)
- [notification_service.dart](../../packages/agrimore_services/lib/notifications/notification_service.dart)
- [payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart)
- [payout_details_screen.dart](../../apps/employee/lib/screens/wallet/payout_details_screen.dart)

Existing test sources (not executed in this asset task):

- [shell_and_sales_screens_test.dart](../../apps/employee/test/screens/shell_and_sales_screens_test.dart)
- [foundation_auth_gate_test.dart](../../apps/employee/test/foundation_auth_gate_test.dart)

Scanned screen-family directory inventory (files, not unique screens):

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

**Current shell:** Admin uses GoRouter with 53 GoRoute syntax occurrences and one ShellRoute. Its compact shortcuts are Home (Dashboard), Products, Orders, Users and Settings; the mobile drawer exposes the larger module list. Desktop uses a sidebar at widths of 900px or greater. Product add/edit is full-screen outside the shell. Mobile items refer to numeric indices in a shared _navItems list; selection uses prefix matching. The board shows compact navigation and an All modules launcher, not a sidebar.

**Current entry:** GoRouter defines parameterized detail/editor URLs and role-aware redirects, with an initial splash route. Signed-out redirects go to auth; intent preservation through auth was not established in this review. Direct URL cold-start, refresh, browser history and authorized-parent fallback still require runtime tests. Existing guarded logout/router lifecycle tests were inspected as sources, not executed.

**Target direction:** Keep five compact shortcuts. Expose all operational modules through a full-page or sheet directory in this no-sidebar proposal, preserving current route identities and module availability. Replace fragile index-based lookup with stable route identity only in a future bounded migration. Product editing remains a separate task route; Back falls to Products when no history exists.

| Root destination | Purpose |
| --- | --- |
| Home | Dashboard |
| Products | Catalogue controls |
| Orders | Order operations |
| Users | Customer records |
| Settings | Workspace settings |

Target Back rules:

- Editor → Products
- Cold entry → Owning module
- Browser back → Previous URL

Target entry flow: **Product link → Admin access → Products → Edit product**.

- Resolve authorized routes by stable identity.
- Keep direct URLs and module selection aligned.

Source anchors:

- [app_router.dart](../../apps/admin/lib/app/app_router.dart)
- [admin_shell.dart](../../apps/admin/lib/screens/admin/admin_shell.dart)
- [app.dart](../../apps/admin/lib/app/app.dart)
- [product_form_screen.dart](../../apps/admin/lib/screens/admin/products/product_form_screen.dart)

Existing test sources (not executed in this asset task):

- [foundation_admin_router_lifecycle_test.dart](../../apps/admin/test/foundation_admin_router_lifecycle_test.dart)
- [foundation_admin_logout_navigation_test.dart](../../apps/admin/test/foundation_admin_logout_navigation_test.dart)

Scanned screen-family directory inventory (files, not unique screens):

| Family | Dart files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Admin module reachability

The current navigation list contains **35 modules**. The five shortcuts are not the whole admin workspace. A future All modules directory must retain reachability and authorized route identity for every module. The no-sidebar requirement controls these reference boards; it does not remove the current desktop/sidebar functionality. Existing Employees/Employee Payouts labels below are recorded source labels; target user-facing copy should use Sales Associate terminology without renaming internal employee paths casually.

| Current source label | Route identity |
| --- | --- |
| Dashboard | dashboard |
| Products | products |
| Orders | orders |
| Subscriptions | subscriptions |
| Time Slots | deliveryTimeSlots |
| Delivery Partners | deliveryPartners |
| Users | users |
| Vendors | vendors |
| Seller requests | sellerRequests |
| Reviews | reviews |
| Wallet Top-ups | walletTopups |
| Coupons | coupons |
| Rewards | rewards |
| Banners | banners |
| Sponsored | sponsored |
| Section Banners | sectionBanners |
| Bestsellers | bestsellers |
| Sections | sections |
| Notifications | notifications |
| Analytics | analytics |
| Settings | settings |
| Employees | employees |
| Employee Payouts | employeePayouts |
| Benefit Compliance | benefitComplianceControl |
| Benefit Feature Flags | benefitFeatureFlags |
| Manage Sellers | manageSellers |
| Seller Payouts | sellerPayouts |
| Dispatch Queue | deliveryDispatch |
| Rider Payouts | riderPayouts |
| Rider Incidents | riderIncidents |
| Delivery Problems | deliveryProblems |
| Rider Support | riderSupport |
| Commission Exceptions | commissionExceptions |
| Support Cases | supportCases |
| Finance Reconciliation | financeReconciliation |

## Proposed implementation acceptance checks

These checks remain future implementation work:

- Switch every root and return: preserve meaningful list/filter/scroll state without duplicate streams or detail pages. Check selected semantics and long labels in both themes.
- Exercise keyboard, sheet, dialog, detail and root Back in order. Verify predictive/system Android Back, iOS gesture/AppBar Back and browser back/forward separately. Preserve unsaved drafts on all entry/exit paths.
- Launch an authorized detail cold, warm and while signed out; resume after required access checks without showing stale cross-account content. Test pending/rejected/suspended seller, rider and associate states and non-admin access.
- Test malformed, missing, deleted, expired and forbidden destination IDs; choose a safe authorized parent. Repeated notifications must not create duplicate details.
- Marketplace: verify Home-only bar, Categories label, dynamic product/order routes and browser pop-state/tab URL consistency. Seller: verify root-back and future order-link resolver. Delivery: verify active/history detail routing versus incoming offers, background fallback and unchanged duty state.
- Sales Associate: verify new root-back policy and exact payout destination after access; keep actual payout status from records. Admin: verify all 35 module identities, direct editor URLs, auth return continuity and cold-entry parent fallback.
- Verify actual Android/iOS link association and scheme handling on installed builds; manifest or route source alone is insufficient.

## Handoff scope

Single-agent documentary work: ten selected PNGs, fifteen per-app README/prompt/manifest files and two master documents. Built-in image_gen; exact prompts and source/reference hashes are saved per app. No source, navigation behavior, app dependency, asset registration, branch or prior C01–C06 asset is changed. No deploy consequence. C07 remains a proposal until explicitly approved. Raster drawings and colors are approximate; manifest identity and navigation-contract targets are authoritative for this proposal.
