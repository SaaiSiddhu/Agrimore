# Agrimore Marketplace — C14 loading, empty, error and restricted states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C14 owner approval is pending.

Spacious professional-green shopping states with natural-stone skeletons, warm-gold guidance and a gentle path back to product discovery.

[Ten-board gallery](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

OrdersScreen already separates initial empty loading, load error, no orders and locally filtered no-results. OrderProvider returns an unauthenticated error when userId is missing and may store raw listener error text. EmptyOrders provides Start shopping only when its callback exists. SearchResultsScreen logs search exceptions without a dedicated visible error branch. The web AuthGuard redirects unauthenticated sessions to LandingScreen; it returns its child on mobile.

## Target direction

A shopping-focused state family separates first load, truly empty cart, order-load failure and personal-order sign-in requirement. Preserve query/filter state on a recoverable retry; keep browsing available through an existing safe destination. Loading unknown prices remain placeholders.

| Panel | Domain specimen |
| --- | --- |
| Loading | Product-discovery skeleton: two neutral product tile placeholders with media boxes and text bars, no real product or price. Heading "Loading products". Small helper "Refresh keeps available content visible". Tiny accessibility note "Announce once; static when motion is reduced". No percentage or ETA. |
| Empty | Large cart outline icon. Title "Your cart is empty". Body "Browse products to start an order." Primary button "Start shopping". A separate small inset, labelled Filtered view, says "No matches in loaded products" with text action "Clear filters". True empty and filtered no-match are visibly separate examples. |
| Error | Restrained error icon/status container. Title "Orders unavailable". Body "We couldn’t load your orders. Check your connection and try again." Primary button "Retry". Small note "Retry the read; keep filters". Do not display raw exception, money, totals or a success tick. |
| Restricted | Lock outline on neutral green-tinted surface. Title "Sign in to view your orders". Body "Your order history belongs to your account." Primary button "Sign in", secondary text action "Browse products". Small caption "Authentication required". No account suspension or approval claim. |

Preservation and gaps:

- Map unauthenticated reads to a sign-in explanation rather than presenting them as a retryable connection error.
- Search failures must not become empty results. Orders with retained data need refresh/error indication instead of silently hiding the failure.
- Current provider exposes raw error text and shared/default empty-state styling varies; safe copy and C01 themes are future implementation work.
- A missing userId is not proof of zero orders; auth and successful data completion precede true-empty decisions. Cart and orders are separate collections/contexts.

## Light

![Agrimore Marketplace C14 light](agrimore-marketplace-loading-empty-error-restricted-states-light.png)

## Dark

![Agrimore Marketplace C14 dark](agrimore-marketplace-loading-empty-error-restricted-states-dark.png)

