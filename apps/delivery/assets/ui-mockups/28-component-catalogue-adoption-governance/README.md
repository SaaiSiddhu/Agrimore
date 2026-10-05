# Agrimore Delivery — C28 component catalogue and adoption governance

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-04.** C01 is approved and locked; C28 owner approval is pending.

Monochrome rider catalogue with burnt-orange state guidance and burgundy review context.

[Ten-board gallery](../../../../../docs/design-system/COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_BOARDS_2026-10-04.md) · [Codebase/domain map](../../../../../docs/design-system/COMPONENT_CATALOGUE_ADOPTION_GOVERNANCE_DOMAIN_MAP_2026-10-04.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Delivery owns app-local design_system library with button, card, field, banner, layout, list, route/media and state families. DeliveryButton declares primary/secondary/tonal/ghost/danger and sizes sm/md/lg with loading aliases; its actual labels are capped, so comments about universal 200% wrapping are not runtime proof. ActiveOrderScreen uses DeliveryButton and DeliveryBanner; profile uses DeliveryCard. Design-system tests exist but were not executed for C28.

## Target direction

Catalogue rider action/state contracts and instruction composition with correct C01 monochrome primary and orange/burgundy support. Source mapping must distinguish route/offer/task/proof/verification branches and preserve operational/server state. Trace plus rendered evidence is required for later adoption.

| Panel | Domain specimen |
| --- | --- |
| Rider action variants | Panel "Action variants": labelled "Primary", "Secondary", "Quiet action" each "Review instructions"; monochrome filled, outlined and text-only. Orange note "Keep the main rider action unmistakable". Quiet action is target ghost-style sample, not a new variant claim. |
| Rider state examples | Panel "State examples": independent rows "Ready" with Review instructions, "Loading" static neutral progress icon and "Loading task details…", "Unavailable" disabled Review instructions with "Action unavailable in this example". Caption "Independent examples"; orange note "Show state without implying completion". No location/route/ETA outcome. |
| Instruction composition | Panel "Task composition": heading "Pickup instructions", readable text "Review the collection instructions before continuing."; primary "Review instructions", secondary "Help". External annotation "Instruction card + context + actions", "Target composition". No actual pickup, route, phone/address or emergency action. |
| Rider source evidence | Panel "Adoption evidence": documentation record "Active order" with "DeliveryButton"; rows "Source use located", "Render review pending"; proposed steps "Component", "Screen state", "Rendered evidence", "Review decision"; burgundy note "Review task states and safe recovery separately"; caption "Source trace / Target review record". No delivery/approval/verified test result. |

Preservation and gaps:

- Do not equate Delivery barrel comments about orange primary with the approved C01 monochrome target identity.
- Read loading examples do not imply a delivery-confirmation, proof upload or command was completed.
- Focus/large-label limits and size/target behavior need actual state/device tests, not source comments alone.
- A shared delivery package folder is a future migration target; existing app-local imports must be transitioned deliberately.

## Light

![Agrimore Delivery C28 light](agrimore-delivery-component-catalogue-adoption-governance-light.png)

## Dark

![Agrimore Delivery C28 dark](agrimore-delivery-component-catalogue-adoption-governance-dark.png)

