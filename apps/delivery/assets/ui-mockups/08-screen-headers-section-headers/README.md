# Agrimore Delivery — C08 screen headers and section headers

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Black/white with burgundy and burnt orange support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-delivery-screen-headers-section-headers-light.png) |
| Dark | [Open dark](agrimore-delivery-screen-headers-section-headers-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/SCREEN_HEADERS_SECTION_HEADERS_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/SCREEN_HEADERS_SECTION_HEADERS_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

HomeAppBar is duty control plus Emergency, Help and Inbox, with Offline/Online bound to confirmed state and a busy spinner during changes. Current supplementary circles are intentionally 40px by earlier owner request. DeliveryAppBar has 56/64px heights and single-line title/subtitle. Active order screens use AppBar with order number and local _Section headings for progress, customer, address, items, payment and proof.

## Target direction

Keep duty chrome distinct from delivery task chrome. Status identifies real duty/task state; a header is never an accept/complete action. Keep Emergency immediately identifiable. A proposed 48px invisible hit region may preserve the owner's 40px visual circles, pending later implementation review.

| Panel | Specimen intent |
| --- | --- |
| 01 · Duty & task chrome | Home chrome specimen: neutral outlined duty pill 'Offline' with toggle off. Three restrained circle actions, visibly labeled beneath 'Emergency', 'Help', 'Inbox'; Emergency glyph burnt orange. Below chrome, page title 'Home'. Task specimen below: Back arrow, title 'Active delivery', subtitle 'Current assignment'. Main controls black/white, no online green celebration. |
| 02 · Delivery sections | Clear stacked section headers 'Delivery address' with small location outline glyph and quiet action 'View map'; subtitle 'Destination details'. Second quiet heading 'Delivery progress' with no action. Burgundy is a restrained secondary accent. |
| 03 · Truthful duty status | Two separate specimen chips 'Offline' neutral/info with power icon; 'Changing availability...' neutral/info with spinner. Caption 'Confirm state before updating label'. No success check, ETA, customer name, order number or proof-of-delivery claim. |
| 04 · Field readability | Large-text title across two lines 'Delivery address / and customer instructions'; subtitle 'Read before arrival'; outlined 'More options' moved to a separate lower row. Footer note 'Keep Emergency reachable · allow text to grow'. |

Source gaps and preservation rules:

- Source honors confirmed duty state and busy state; preserve this behavior exactly.
- Fixed title/subtitle heights need scale and long-translation testing.
- 48px invisible hit regions are a proposed interaction enhancement; do not silently reverse the prior owner decision for 40px visual circles.
- Future task title may use authorized order number when loaded; illustrations avoid IDs and customer data.

Use one accessible page heading, 4px title/subtitle gap, quieter section headings, 24px section rhythm and scale-aware height. Proposed actions have minimum 48px hit regions; required task titles wrap and crowded actions move below. Delivery retains its existing 40px visual-circle decision, with larger invisible hit regions proposed. Actual text scaling, translations, accessibility and layout must be verified in later implementation. Synthetic status examples are not financial, duty or delivery confirmation.

## Light

![Agrimore Delivery C08 light](agrimore-delivery-screen-headers-section-headers-light.png)

## Dark

![Agrimore Delivery C08 dark](agrimore-delivery-screen-headers-section-headers-dark.png)

