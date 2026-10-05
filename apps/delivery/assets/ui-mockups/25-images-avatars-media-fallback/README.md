# Agrimore Delivery — C25 images, avatars and media fallback

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C25 owner approval is pending.

Black/white field media, burgundy private-document context and burnt-orange capture/recovery guidance.

[Ten-board gallery](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

DeliveryDocUploadTile has empty/uploading/ready/error but ready uses verified/check icons even though Uploaded is only upload state. DeliveryAvatar accepts imageUrl but renders initials only. Rider profile uses generic rider avatar separate from KYC. Document View resolves stored URL/path with loading/error, submit replacement uploads then callable records separate submission. Active order camera proof is staged durably before confirmation; saveDeliveryProof uploads and attaches after delivery confirmation with retry and separate pending-proof recovery. Support single image uploads immediately on pick.

## Target direction

Use high-contrast action/readable frames, never crop document inspection; generic document placeholders protect sample identity. Distinguish selected, uploading, not attached and submitted-for-review states; do not equate an uploaded file with delivery completion or identity approval. Preserve proof recovery only for existing supported flow.

| Panel | Domain specimen |
| --- | --- |
| Capture frame | Panel "Proof photo preview": wide generic closed delivery-crate PHOTO labelled "Selected photo / not attached". Black/white secondary "Retake photo". Orange note "Preview does not confirm delivery". Small "Synthetic photo example". No order/address/person/GPS/complete status. |
| Private document media | Panel "Document inspection": wide tallish neutral blank document-outline frame labelled "Private document preview", "Full image / contain"; beside two small equal placeholders "Loading document", "Could not load document" with secondary "Try again". Burgundy small "Sensitive information". Orange note "Never crop identification details". NO real/fake ID, QR, face, name, signature or thumbnail details. |
| Upload and attachment states | Panel "Photo handoff": empty camera tile "No photo selected"; separate spinner tile "Uploading photo…"; separate error row "Photo not attached" with secondary "Retry attachment". Orange note "Upload and record attachment are separate". No percent/tick/success/delivery completion or universal resume guarantee. |
| Rider avatar and review boundary | Panel "Rider avatar": circle neutral rider silhouette "Default rider avatar"; circle "R" caption "Synthetic initials"; below generic document-outline "Submitted for review / example state". Burgundy note "Document upload is not identity approval"; footer small "Avatar stays separate from documents". No verified check, licence photo, portrait or supported avatar upload claim. |

Preservation and gaps:

- Avatar imageUrl is currently unused; do not imply rider photo upload/display works from that prop.
- KYC remains separate from profile avatar, app approval and delivery proof. Uploaded badge should not imply verified.
- Proof staged locally is not yet attached; confirmation and proof attachment are separate outcomes.
- Durable recovery exists for proof photos, not universally for support/document uploads. Do not promise offline auto-sync or unrestricted retry.

## Light

![Agrimore Delivery C25 light](agrimore-delivery-images-avatars-media-fallback-light.png)

## Dark

![Agrimore Delivery C25 dark](agrimore-delivery-images-avatars-media-fallback-dark.png)

