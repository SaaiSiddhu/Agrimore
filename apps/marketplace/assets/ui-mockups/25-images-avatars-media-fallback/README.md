# Agrimore Marketplace — C25 images, avatars and media fallback

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C25 owner approval is pending.

Professional-green catalogue frames, warm-gold crop/recovery guidance and natural-stone avatar surfaces.

[Ten-board gallery](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

UnifiedProductCard uses web Image.network versus native CachedNetworkImage with cover crop; missing and failed URLs share one icon placeholder, loading uses spinner. Category/cart/search media use separate widgets. Profile handles data:image base64 separately and network errors fall back to bundled avatar; decoded memory error handling is incomplete. EditProfile stages selected photo/removal and uploads on Save, with opening-owner checks; uploaded URL is then persisted through profile update.

## Target direction

Keep catalogue product identity readable outside stable media frames; distinct missing/loading/failed states. Full product detail inspection can contain the image while catalogue cover is deliberate. Maintain neutral avatar fallback and local-preview versus saved-profile distinction; crop is a rendering target, not a new crop editor.

| Panel | Domain specimen |
| --- | --- |
| Catalogue sizing and crop | Panel "Catalogue images": square generic unbranded tomato-crate PHOTO specimen labelled "Catalogue crop / cover", adjacent wide neutral frame with same entire crate photo labelled "Detail view / contain". Small "Synthetic image examples". Keep crate edges visible in contain; no price/title/stock/purchase UI. Gold note "Crop for discovery; preserve detail for inspection". |
| Stable media states | Panel "Image states": three SAME-SIZE square tiles labelled "Loading image", "No image", "Could not load image". Skeleton, simple image icon, image-off icon respectively. Failure has outlined "Retry image". Gold note "Image failure does not change availability". |
| Avatar fallbacks | Panel "Profile avatar": three circular equal frames, neutral generic silhouette labelled "Default avatar", skeleton circle labelled "Loading photo", silhouette labelled "Photo unavailable". No portrait/name/account. Gold note "Keep the same frame through every state". |
| Supported profile upload | Panel "Profile photo": local preview of generic abstract avatar icon labelled "Selected photo / not saved"; below separate indeterminate state "Uploading photo…" and isolated error "Could not upload photo" with secondary "Try again". External note "Apply only after profile save confirms". No saved/success badge, upload product action, removal-success or server claim. |

Preservation and gaps:

- Missing image is not product unavailable/out of stock. Current product missing/failed placeholders are visually merged.
- Profile display data-URI branch is not a shared decoder; malformed/oversized/decoded bytes need deliberate fallback and limits.
- Profile upload/storage completion precedes metadata save; failed profile save must not claim photo applied. Existing opening-owner guards remain.
- Do not add product upload to shopper catalogue; only own profile photo upload is supported here.

## Light

![Agrimore Marketplace C25 light](agrimore-marketplace-images-avatars-media-fallback-light.png)

## Dark

![Agrimore Marketplace C25 dark](agrimore-marketplace-images-avatars-media-fallback-dark.png)

