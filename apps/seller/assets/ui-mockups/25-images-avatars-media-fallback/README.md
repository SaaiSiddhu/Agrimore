# Agrimore Seller — C25 images, avatars and media fallback

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C25 owner approval is pending.

Blue-teal catalogue and storefront media, copper upload/draft guidance and cool-neutral fallback frames.

[Ten-board gallery](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SellerImage supports fixed frames, cover fit, cached network skeleton/missing/failed, optional semanticLabel and local bytes; local Image.memory lacks an errorBuilder. SellerAvatar uses logo then initials/store icon and excludes its semantics. SellerPhotoTile defines empty/uploading/uploaded/failed but actual adoption differs. Product editor selects one photo and uploads during save; storefront uploads immediately then saves draft metadata separately. Posts select a local image before create; onboarding document upload writes storage then saveDraft.

## Target direction

Reuse SellerImage/Avatar/PhotoTile with clear state captions; product/store/logo/media have deliberate square/circle/wide slots. Retain local preview and draft when upload/save fails, distinguish storage receipt from published product/storefront or accepted documents.

| Panel | Domain specimen |
| --- | --- |
| Merchant media shapes | Panel "Catalogue and storefront": square generic unbranded seed-sack PHOTO labelled "Product / square"; wide synthetic field PHOTO labelled "Store cover / wide"; circle store-outline icon labelled "Store logo / circle". Copper note "Fit follows the media role". No real store/brand/price. |
| Fallback chain | Panel "Image and logo fallback": equal square skeleton "Loading", square image-outline "No photo", square image-off "Load failed". Below two same-size circles "AS" labelled "Synthetic initials" and store icon labelled "Store fallback". Copper note "Keep layout stable; name stays in the row". |
| Local versus uploaded | Panel "Product photo draft": seed-sack local-preview tile "Selected photo / not saved"; separate tile with neutral indeterminate spinner "Uploading photo…". Copper note "Local preview is not a published product". No uploaded tick, percentages, batch count or product-save success. |
| Recover without losing draft | Panel "Upload recovery": neutral photo outline with "Could not upload photo", secondary blue-teal outlined "Try again", secondary "Choose another photo". Copper note "Keep draft / apply only after save confirms"; small "Document upload is not approval". No KYC document, saved/verified/approved badge, actual details. |

Preservation and gaps:

- Network media loading and error frames exist; local decode, avatar grapheme-safe initials and semantics need tests.
- Product single-photo editor, post and storefront upload timing differ; do not claim one global multi-upload flow.
- Storefront new URL is still draft until save succeeds; storage upload is not publication.
- Uploaded documents do not mean approved; do not display private document thumbnails in public catalogue.

## Light

![Agrimore Seller C25 light](agrimore-seller-images-avatars-media-fallback-light.png)

## Dark

![Agrimore Seller C25 dark](agrimore-seller-images-avatars-media-fallback-dark.png)

