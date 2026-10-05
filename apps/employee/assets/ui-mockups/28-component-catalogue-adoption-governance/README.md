# Agrimore Sales Associate — C28 component catalogue and adoption governance

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-04.** C01 is approved and locked; C28 owner approval is pending.

Premium royal-blue catalogue, indigo evidence notes and pearl/slate associate records.

[Ten-board gallery](../../../../../docs/design-system/COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_BOARDS_2026-10-04.md) · [Codebase/domain map](../../../../../docs/design-system/COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_DOMAIN_MAP_2026-10-04.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Sales Associate production root uses shared SalesAssociateTheme and shared SaLoadingButton/SaInfoBanner alongside inline Material fields/cards. SaLoadingButton declares primary/outlined and loading/disabled controls. SaCatalogueApp is a standalone developer entry point without Firebase initialization: it declares a light theme, has typography text-scale slider and component loading switch, and shows synthetic tokens/components/content. It does not wire a dark theme, and its existing light token values differ from approved C01 board metadata. ForgotPasswordScreen directly uses SaLoadingButton.

## Target direction

Catalogue associate action/banners/form/record composition while keeping tooling examples separate from production adoption. Extend later catalogue verification to C01 identities and both themes with actual screen states, privacy and ownership checks. Proposed sales_associate package folder should retain existing APIs/callers during a deliberate migration.

| Panel | Domain specimen |
| --- | --- |
| Associate action variants | Panel "Action variants": labelled "Primary" and "Outlined" with exact "View order details"; primary blue filled and secondary outlined. Indigo note "Document the associate action contract". No invented tertiary SaButtonVariant. |
| Associate state examples | Panel "State examples": independent rows "Ready" with View order details, "Loading" static progress icon with "Loading order details…", "Unavailable" disabled View order details plus "Action unavailable in this example". Caption "Independent examples". Indigo note "Catalogue examples are not live records". |
| Associate record composition | Panel "Record composition": title "Attributed order details", body "Order information", neutral record icon; primary "View order details", secondary "Back". External annotation "Record + context + actions", "Target composition". No real record, commission, payout, balance or program promise. |
| Associate source evidence | Panel "Adoption evidence": documentation record "Forgot password" with "SaLoadingButton"; rows "Source use located", "Render review pending"; proposed stages "Component", "Screen state", "Rendered evidence", "Review decision". Indigo note "Verify production screens beyond the catalogue"; caption "Source trace / Target review record". No actual account/password reset, pass badge or finished migration. |

Preservation and gaps:

- Standalone catalogue rendering or a source test cannot prove every production screen adopted its components.
- Do not replace behavioral/access state or financial/request ownership while migrating presentation.
- Current catalogue dark-theme coverage is absent at the root; C28 dark artwork is a target, not a screenshot of that app.
- Two-line label caps and legacy inline forms still need per-state rendered review; no adoption completion percentage invented.

## Light

![Agrimore Sales Associate C28 light](agrimore-sales-associate-component-catalogue-adoption-governance-light.png)

## Dark

![Agrimore Sales Associate C28 dark](agrimore-sales-associate-component-catalogue-adoption-governance-dark.png)

