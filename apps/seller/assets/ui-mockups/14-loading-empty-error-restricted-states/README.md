# Agrimore Seller — C14 loading, empty, error and restricted states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C14 owner approval is pending.

Compact blue-teal catalogue operations with cool-neutral loading rows, restrained copper context and clearly different rejected versus suspended account treatments.

[Ten-board gallery](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/LOADING_EMPTY_ERROR_RESTRICTED_STATES_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SellerSpinner/SellerProgressLabel/SellerLoadingView/SellerSkeletonList already cover loading, including reduced-motion support in spinner and skeleton families. SellerEmptyState and SellerErrorState provide optional actions and localized copy. SellerProductsScreen chooses error when no base data, then skeleton, then catalogue empty/no-match. AccountRestrictedScreen reopens the application only for rejected sellers; suspension has support and sign-out.

## Target direction

Reuse the existing state primitives with the approved C01 identity. Catalogue loading and recovery stay operational and compact; first-product creation differs from filtered no-match. The rejected path reopens a draft; suspension cannot be self-cleared.

| Panel | Domain specimen |
| --- | --- |
| Loading | Compact catalogue skeleton rows with neutral square thumbnails and two text bars. Heading "Loading catalogue". Helper "Keep existing rows during refresh". Small note "One loading announcement; reduced-motion static". No product counts or stock numbers. |
| Empty | Catalogue box outline. Title "No products yet". Body "Create your first catalogue item." Primary "Add product". Separate thin inset labelled Filtered catalogue: "No matching products" with text action "Clear filters". Note "Keep search and sort". These are independent illustrative cases. |
| Error | Compact error block title "Catalogue unavailable". Body "We couldn’t load your products. Try again." Filled blue-teal button "Retry". Copper helper "Retry loading; keep catalogue controls". No raw server error, fake stock or publish action. |
| Restricted | Two separately labelled small cases. Rejected: title "Application not approved", helper "Reopen the application as a draft", button "Fix and resubmit". Divider. Suspended: title "Seller account suspended", helper "Contact support to resolve access", actions "Contact support" and "Sign out". No retry or self-reactivate control for suspension. No automatic approval or immediate-resubmit success. |

Preservation and gaps:

- Review initial-error/loading precedence and refresh with retained catalogue data so an old error does not suppress new progress or vanish behind records.
- The current no-match branch does not expose an explicit reset action; Clear filters is a target enhancement with stated scope.
- Fix and resubmit reopens a rejected application draft; it is not approval, publishing or account reinstatement.
- Only show permitted actions with handlers. Reduced-motion and semantics must remain intact during token adoption.

## Light

![Agrimore Seller C14 light](agrimore-seller-loading-empty-error-restricted-states-light.png)

## Dark

![Agrimore Seller C14 dark](agrimore-seller-loading-empty-error-restricted-states-dark.png)

