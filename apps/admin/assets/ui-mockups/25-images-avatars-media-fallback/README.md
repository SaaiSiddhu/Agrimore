# Agrimore Admin — C25 images, avatars and media fallback

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C25 owner approval is pending.

Professional-blue content thumbnails and dense evidence frames, cyan crop/attachment guidance with steel/slate fallbacks.

[Ten-board gallery](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/IMAGES_AVATARS_MEDIA_FALLBACK_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

ImageUploader supports single/multi selection and per-upload snapshot progress, URL insertion, removal and storageFolder; selection uploads immediately and parent save is separate. Batch failures are logged/skipped and only successful URLs appended; raw error text is shown in some paths, progress listen/mounted issues remain. Banner/category/storefront dialogs use differing aspect ratios. Support evidence accepts images/PDF, write-once storage path and callable finalize; retry checks object existence before reupload then reuses requestId. Evidence view reads bytes with Image.memory error fallback. User/rider avatar views mix NetworkImage/CircleAvatar and error fallback coverage.

## Target direction

Separate catalogue crop/banner safe framing from contain-style evidence inspection. Neutral account avatars carry no approval meaning. Distinguish selected/uploading/storage completion/attached/parent save; per-file failure recovery and sanitized messages, preserving existing evidence finalize retry identity.

| Panel | Domain specimen |
| --- | --- |
| Content framing | Panel "Content images": square synthetic unbranded produce-crate PHOTO "Product / square"; wide synthetic farm panorama "Banner / wide". Cyan note "Preserve subject and safe crop areas". Small "Synthetic image examples". No CMS publish success or actual record. |
| Evidence and file fallback | Panel "Evidence preview": blank document-outline rectangle "Image evidence / contain", separate neutral PDF-outline "PDF attachment"; same-size failed-image frame "Could not load preview". Secondary outlined "Try again". Cyan note "No preview does not mean no attachment". No actual document/QR/name/case details or download/export. |
| Per-file upload recovery | Panel "Upload states": same-size tiles "Selected / not saved", "Uploading…" with indeterminate spinner and "Upload failed" with secondary "Retry upload". Cyan note "Handle each file; keep the remaining selection". No fabricated percent/count/all-success/attached label. |
| Avatar and finalize boundary | Panel "Identity and attachment": equal circular person-outline and "AD" samples labelled "Default avatar" and "Synthetic initials"; separate status text "Awaiting attachment confirmation / example state", outlined "Retry attachment". Cyan note "Storage completion is not record save"; tiny "Attachment does not resolve a case". No verified check/real portrait/admin authority badge. |

Preservation and gaps:

- Content URL stored in dialog is not published/saved record until parent save confirms.
- Batch partial success should identify failed selections, retain order and avoid claiming every file uploaded.
- Support evidence retry is existing-object/finalize aware; do not blindly create a new storage object on each retry.
- Image/PDF attachment is not case resolution; avatar photo is not verified identity; no live document contents in assets.

## Light

![Agrimore Admin C25 light](agrimore-admin-images-avatars-media-fallback-light.png)

## Dark

![Agrimore Admin C25 dark](agrimore-admin-images-avatars-media-fallback-dark.png)

