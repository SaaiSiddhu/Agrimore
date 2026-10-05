# Agrimore Sales Associate — C25 images, avatars and media fallback

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C25 owner approval is pending.

Premium royal-blue initials and record icons, indigo asset-state context with pearl/slate quiet placeholders.

[Ten-board gallery](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Profile builds a 56px initials circle from account name. Order-detail item rows render text and amounts without remote product photos; proposed bag/package icons are supplementary target media; no picker/storage upload found anywhere in employee/lib. Login uses bundled logo with errorBuilder; other decorative assets and icon states vary. Models can carry shared photoUrl but that is not implemented media upload adoption in this app.

## Target direction

Build around current initials identity, legible attributed-record icons and reliable bundled decorative media. Distinct loaded/loading/failed asset examples are proposed; do not invent product gallery, avatar camera action or document upload in Sales Associate.

| Panel | Domain specimen |
| --- | --- |
| Initials identity | Panel "Associate identity": two circular samples "AS" and generic person outline captioned "Synthetic initials" and "Empty-name fallback"; size labels "Compact / 40 px" and "Profile / 56 px" outside samples. Indigo note "Name and role remain readable beside the avatar". No real person/name/photo. |
| Attributed-record media | Panel "Record icons": two text-row skeletons with blue outlined bag/package icons inside same neutral square frame. Captions "Order item icon" and "Record placeholder". Indigo note "Text identifies the record; media is supplementary". No product photograph/price/commission/order status. |
| Bundled asset resilience | Panel "Asset states": same-size tiles generic leaf/bag symbol "Asset example", skeleton "Loading example", image-off "Asset unavailable". Indigo note "Keep the layout stable when an asset fails". No actual company-logo redesign or button implying unsupported reload. |
| Supported media scope | Panel "Media actions": neutral person and image-outline symbols with clear text "Profile uses initials" / "No photo upload in this app". Small "Current supported scope"; indigo note "New upload controls require a supported flow". No Add photo, camera/gallery/retry upload, identity document, offline queue or photo success state. |

Preservation and gaps:

- No ImagePicker/putData/putFile evidence in employee/lib; proposed uploads need a future bounded implementation.
- Initials need empty/unicode/grapheme and large-text review; keep accessible identity label on containing row.
- Order icon absence is not an order error or lack of sales; media is supplementary to text.
- Raster placeholder/loading/failed examples are target design, not proof all these states are currently exposed.

## Light

![Agrimore Sales Associate C25 light](agrimore-sales-associate-images-avatars-media-fallback-light.png)

## Dark

![Agrimore Sales Associate C25 dark](agrimore-sales-associate-images-avatars-media-fallback-dark.png)

