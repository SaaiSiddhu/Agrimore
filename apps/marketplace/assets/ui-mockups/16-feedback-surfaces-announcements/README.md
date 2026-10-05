# Agrimore Marketplace — C16 feedback surfaces and announcements

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C16 owner approval is pending.

Professional-green buyer feedback with warm-gold context and natural-stone storefront surfaces.

[Ten-board gallery](../../../../../docs/design-system/FEEDBACK_SURFACES_ANNOUNCEMENTS_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/FEEDBACK_SURFACES_ANNOUNCEMENTS_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

RequestQuoteSheet validates quantity/price via warning snackbars, awaits RfqProvider.createRfq, then pops the sheet, shows success with the old context and navigates to RFQ detail. The provider awaits the callable and returns its rfqId. BusinessProfileScreen has a persistent paused-store MaterialBanner with no actions. CartProvider.addItem returns local success while authenticated persistence is unawaited; inspected UnifiedProductCard success feedback ignores the bool result.

## Target direction

Destination-owned confirmed quote-request toast, field-scoped actionable validation and a non-dismissible buyer-facing store restriction. Separate local cart update from server sync/order confirmation. Announce the confirmed event once without competing with destination focus.

| Panel | Domain specimen |
| --- | --- |
| Transient toast | Floating neutral branded toast with small success icon, text "Quote request sent", quiet caption "Sample confirmed response". Board note "Show on the destination". No Undo or action claiming acceptance/order placement. |
| Inline notice | Compact quote form excerpt, empty field labelled "Quantity" and error icon/message "Enter a valid quantity". Notice heading "Check quantity". Board note "Keep entered details". No sample numeric quantity, prices, or hidden-field error. |
| Persistent banner | Storefront notice with pause icon, heading "Store paused", body "This store is not taking orders right now. You can still browse." Small board note "Keep visible while paused". No dismiss X, Resume, or invented recovery link. |
| Accessible updates | Explicitly labelled "Announcement design". A small speaker-outline row with quoted text "Quote request sent". Two simple rule rows "Announce once" and "Keep destination focus". Warm-gold annotation "Polite update / no duplicate announcement". This is a design annotation, not a screen-reader transcript. |

Preservation and gaps:

- Move the toast to a valid destination messenger after navigation; avoid torn-down sheet context.
- Inline validation preserves entered values and links to the invalid field; show the error there rather than relying on an expiring snackbar.
- Paused-store feedback must not offer buyer Resume controls; browsing remains available.
- Cart local success is not server-saved or order-placed; callers must inspect false results and map persistence failure safely.
- Framework-native SnackBar announcement must be checked before adding a second live-region wrapper.
- RfqProvider.createRfq exposes e.message as provider error; quote-sheet failure uses that text. Map known reasons to safe copy rather than show raw callable messages.

## Light

![Agrimore Marketplace C16 light](agrimore-marketplace-feedback-surfaces-announcements-light.png)

## Dark

![Agrimore Marketplace C16 dark](agrimore-marketplace-feedback-surfaces-announcements-dark.png)

