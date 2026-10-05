# Agrimore Admin — C28 component catalogue and adoption governance

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-04.** C01 is approved and locked; C28 owner approval is pending.

Professional-blue operations components, cyan evidence guidance and steel/slate review surfaces.

[Ten-board gallery](../../../../../docs/design-system/COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_BOARDS_2026-10-04.md) · [Codebase/domain map](../../../../../docs/design-system/COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_DOMAIN_MAP_2026-10-04.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Admin root uses its own AdminTheme with Material button/card/input theming while screens mix inline Material structures and shared feedback helpers. SupportCaseDetailScreen calls SnackbarHelper.showError/showSuccess; this is source-confirmed helper use, not whole-screen canonical adoption. No standalone developer component-catalogue entry point was located in the scanned Admin lib tree. Shared CustomButton uses generic AppColors rather than automatically following AdminTheme.

## Target direction

Catalogue operations control variants and context-heavy record composition, then map every review screen/branch to the intended admin-owned API and evidence. Preserve permissions, server-confirmed actions and private evidence. A future admin folder in agrimore_ui is an ownership target, not an existing folder or completed refactor.

| Panel | Domain specimen |
| --- | --- |
| Operations action variants | Panel "Action variants": labelled "Primary", "Secondary", "Text action" each "Open details"; professional-blue filled, outlined and text-only specimens. Cyan note "Document review actions by priority". |
| Review state examples | Panel "State examples": independent rows "Ready" with Open details, "Loading" static progress icon plus "Loading case details…", "Unavailable" disabled Open details with "Action unavailable in this example"; caption "Independent examples". Cyan note "Keep state and permissions distinct". No real denial, approval or resolved case. |
| Review composition | Panel "Case composition": title "Support case details", body "Review the available context.", neutral document icon; primary "Open case details", secondary "Back". External annotation "Record + context + actions", "Target composition". No case ID, user evidence, account or audit outcome. |
| Operations source evidence | Panel "Adoption evidence": documentation record "Support case" with "SnackbarHelper"; rows "Source use located", "Render review pending"; proposed steps "Component", "Screen state", "Rendered evidence", "Review decision". Cyan note "Helper usage is not whole-screen adoption"; caption "Source trace / Target review record". No fake success toast, passed coverage percentage, approved account or resolved case. |

Preservation and gaps:

- A themed Material control can be valid canonical composition if its contract is documented; wrapper presence alone is not the adoption criterion.
- Feedback-helper use does not prove caller copy is sanitized or entire case workflow is redesigned.
- Generic shared primary colors and AdminTheme can disagree; approved C01 identity needs explicit migration rather than assuming inheritance.
- Tables/details/dialogs need their own branch/keyboard/viewport evidence before a screen is marked verified.

## Light

![Agrimore Admin C28 light](agrimore-admin-component-catalogue-adoption-governance-light.png)

## Dark

![Agrimore Admin C28 dark](agrimore-admin-component-catalogue-adoption-governance-dark.png)

