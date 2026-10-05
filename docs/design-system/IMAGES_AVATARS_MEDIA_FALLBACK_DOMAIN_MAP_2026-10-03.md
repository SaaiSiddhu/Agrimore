# Agrimore — C25 images, avatars and media fallback: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED; C25 owner approval pending. Assets/docs only.

[Ten-board gallery](IMAGES_AVATARS_MEDIA_FALLBACK_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: aed38d713a0c285a75d2cbfcff81a3698ba5dacd. 818 eligible files / 272187 source lines across all five app lib trees, all three package lib trees and functions/src. Generated Dart, firebase_options and secret/credential-named files excluded. Fresh hashes and media marker searches cover image loaders, avatars, fallback/crop, selection/uploads and domain attachment handlers. Focused semantic reads cover actual product/cart/profile images, Seller media components/editor/storefront/posts/onboarding, Delivery avatar/document/proof/support flows and recovery, Associate profile/text-only detail/logo, Admin content uploader and write-once support evidence, StorageService, storage.rules and relevant backend metadata/finalize checks. Broad static inventory is not a semantic read of every line or rendered-screen audit.

Marker totals include comments and call sites, not unique components or defect counts. No real object, photo, person, document, order, upload, support case or production account was read or written. Storage/backend source establishes code boundaries only; deployed behavior was not verified. Shared-checkout source changes are observed and preserved.

| Scope | image_loader | avatar | media_fallback | upload | domain_media |
| --- | --- | --- | --- | --- | --- |
| admin | 44 | 18 | 62 | 40 | 1 |
| delivery | 4 | 5 | 9 | 23 | 23 |
| employee | 1 | 3 | 7 | 0 | 0 |
| marketplace | 86 | 6 | 165 | 11 | 0 |
| seller | 5 | 13 | 20 | 13 | 2 |
| functions | 0 | 0 | 8 | 1 | 2 |
| agrimore_core | 0 | 1 | 0 | 0 | 0 |
| agrimore_services | 0 | 0 | 0 | 2 | 0 |
| agrimore_ui | 2 | 0 | 4 | 0 | 0 |

## Shared media target contract

1. Stable reserved frames across loading, missing and failed media; keep record name/status/actions usable when a thumbnail fails.
2. Fit is deliberate: cover for catalogue/cover images with safe focal area, contain for detailed inspection/evidence; never stretch or crop identity detail. Ratios/sizes on boards are target examples, not a new crop editor.
3. Missing URL, network/decode failure, local preview, loading, permission failure and unsupported format are distinct; sanitized errors and meaningful retry only when the supported handler exists.
4. Neutral avatars use owned photo only when the app actually renders it, then initials/generic role fallback; empty names and unicode graphemes need tests. No avatar alone signals verified identity.
5. Useful image labels complement surrounding text; decorative repeated media is excluded from semantics. Announce async state change accessibly and keep controls comfortable with focus labels.
6. Local selection is not upload; upload is not attached record, parent save, published catalogue, document approval or delivery completion.
7. Progress only when measured; otherwise indeterminate. Cancel/retry/resume/offline queues are not invented across apps.
8. Maintain selected draft and per-file failure context where supported; preserve owner/generation across late upload/results and authenticated caches; no cross-account stale preview.
9. File validation is path/domain-specific; picker extensions/quality/MIME metadata do not prove valid decodable safe bytes. Client feedback must align with backend/storage limits without promising a universal accepted format.
10. Public catalogue media is separate from owned avatars/private documents/proof/support evidence. No raw tokens/storage paths or actual IDs in UI; no private-document fake assets.
11. Removal from a form, removing a record reference and deleting a Storage object differ; preserve existing asset until replacement/save confirmed and define orphan cleanup later.
12. Synthetic photos, monograms and placeholder evidence only; no live person, store, identity document, order, status, upload progress or actual file operation represented.

## Current components and gaps

| Layer | Observed source | Target boundary |
| --- | --- | --- |
| Shared UI | The older workflow names packages/agrimore_ui/lib/widgets/common/network_image_widget.dart; that file/class is absent in this checkout. Shared sticky photo/brand assets exist | Reconcile actual package inventory before canonical implementation; do not create an equivalent duplicate based only on stale docs |
| Marketplace | UnifiedProductCard web Image.network/native cache, cover crop, same missing/error fallback; profile data URI special case and asset fallback | Distinguish absent versus load failure, preserve layout and validate decode; retries are proposed surface behavior |
| SellerImage/Avatar | Network cache/skeleton/no-image/image-off, optional semantics, local bytes; logo → initials → store icon | Reuse existing components, add local decode/error and safe semantic/initials handling later |
| DeliveryDocUploadTile/Avatar | Tile four states; ready uses check/verified icon. Avatar accepts imageUrl but displays initials | Uploaded does not mean verified; imageUrl parameter is not photo rendering adoption |
| Associate | Profile initials; order-detail item rows are text/amounts, no remote image; bundled login logo fallback | Record icons and asset state gallery are target proposals. No picker/upload in employee/lib |
| Admin ImageUploader | Single/multi picks, snapshot progress, parent URL list callbacks, separate save; partial batch failure logged/skipped | Keep per-file selection/failure; sanitize errors, protect late results/listeners, distinguish upload from parent save |
| Admin support evidence | Image/PDF storage, fixed request identity, object-existence-aware retry and callable attach finalize; memory preview fallback | Storage completion is not attachment, attachment is not case resolution; keep write-once/finalize behavior |

## Domain-by-domain systems

### Agrimore Marketplace

**Current source:** UnifiedProductCard uses web Image.network versus native CachedNetworkImage with cover crop; missing and failed URLs share one icon placeholder, loading uses spinner. Category/cart/search media use separate widgets. Profile handles data:image base64 separately and network errors fall back to bundled avatar; decoded memory error handling is incomplete. EditProfile stages selected photo/removal and uploads on Save, with opening-owner checks; uploaded URL is then persisted through profile update.

**Target:** Keep catalogue product identity readable outside stable media frames; distinct missing/loading/failed states. Full product detail inspection can contain the image while catalogue cover is deliberate. Maintain neutral avatar fallback and local-preview versus saved-profile distinction; crop is a rendering target, not a new crop editor.

| Panel | Domain specimen |
| --- | --- |
| Catalogue sizing and crop | Panel "Catalogue images": square generic unbranded tomato-crate PHOTO specimen labelled "Catalogue crop / cover", adjacent wide neutral frame with same entire crate photo labelled "Detail view / contain". Small "Synthetic image examples". Keep crate edges visible in contain; no price/title/stock/purchase UI. Gold note "Crop for discovery; preserve detail for inspection". |
| Stable media states | Panel "Image states": three SAME-SIZE square tiles labelled "Loading image", "No image", "Could not load image". Skeleton, simple image icon, image-off icon respectively. Failure has outlined "Retry image". Gold note "Image failure does not change availability". |
| Avatar fallbacks | Panel "Profile avatar": three circular equal frames, neutral generic silhouette labelled "Default avatar", skeleton circle labelled "Loading photo", silhouette labelled "Photo unavailable". No portrait/name/account. Gold note "Keep the same frame through every state". |
| Supported profile upload | Panel "Profile photo": local preview of generic abstract avatar icon labelled "Selected photo / not saved"; below separate indeterminate state "Uploading photo…" and isolated error "Could not upload photo" with secondary "Try again". External note "Apply only after profile save confirms". No saved/success badge, upload product action, removal-success or server claim. |

Preserve or resolve:

- Missing image is not product unavailable/out of stock. Current product missing/failed placeholders are visually merged.
- Profile display data-URI branch is not a shared decoder; malformed/oversized/decoded bytes need deliberate fallback and limits.
- Profile upload/storage completion precedes metadata save; failed profile save must not claim photo applied. Existing opening-owner guards remain.
- Do not add product upload to shopper catalogue; only own profile photo upload is supported here.

Sources:

- [apps/marketplace/lib/widgets/product/unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart)
- [apps/marketplace/lib/screens/user/profile/profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart)
- [apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart)

### Agrimore Seller

**Current source:** SellerImage supports fixed frames, cover fit, cached network skeleton/missing/failed, optional semanticLabel and local bytes; local Image.memory lacks an errorBuilder. SellerAvatar uses logo then initials/store icon and excludes its semantics. SellerPhotoTile defines empty/uploading/uploaded/failed but actual adoption differs. Product editor selects one photo and uploads during save; storefront uploads immediately then saves draft metadata separately. Posts select a local image before create; onboarding document upload writes storage then saveDraft.

**Target:** Reuse SellerImage/Avatar/PhotoTile with clear state captions; product/store/logo/media have deliberate square/circle/wide slots. Retain local preview and draft when upload/save fails, distinguish storage receipt from published product/storefront or accepted documents.

| Panel | Domain specimen |
| --- | --- |
| Merchant media shapes | Panel "Catalogue and storefront": square generic unbranded seed-sack PHOTO labelled "Product / square"; wide synthetic field PHOTO labelled "Store cover / wide"; circle store-outline icon labelled "Store logo / circle". Copper note "Fit follows the media role". No real store/brand/price. |
| Fallback chain | Panel "Image and logo fallback": equal square skeleton "Loading", square image-outline "No photo", square image-off "Load failed". Below two same-size circles "AS" labelled "Synthetic initials" and store icon labelled "Store fallback". Copper note "Keep layout stable; name stays in the row". |
| Local versus uploaded | Panel "Product photo draft": seed-sack local-preview tile "Selected photo / not saved"; separate tile with neutral indeterminate spinner "Uploading photo…". Copper note "Local preview is not a published product". No uploaded tick, percentages, batch count or product-save success. |
| Recover without losing draft | Panel "Upload recovery": neutral photo outline with "Could not upload photo", secondary blue-teal outlined "Try again", secondary "Choose another photo". Copper note "Keep draft / apply only after save confirms"; small "Document upload is not approval". No KYC document, saved/verified/approved badge, actual details. |

Preserve or resolve:

- Network media loading and error frames exist; local decode, avatar grapheme-safe initials and semantics need tests.
- Product single-photo editor, post and storefront upload timing differ; do not claim one global multi-upload flow.
- Storefront new URL is still draft until save succeeds; storage upload is not publication.
- Uploaded documents do not mean approved; do not display private document thumbnails in public catalogue.

Sources:

- [apps/seller/lib/design_system/components/seller_media.dart](../../apps/seller/lib/design_system/components/seller_media.dart)
- [apps/seller/lib/screens/home/add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart)
- [apps/seller/lib/screens/storefront/storefront_editor_screen.dart](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart)
- [apps/seller/lib/screens/posts/create_post_screen.dart](../../apps/seller/lib/screens/posts/create_post_screen.dart)
- [apps/seller/lib/screens/onboarding/steps/documents_step.dart](../../apps/seller/lib/screens/onboarding/steps/documents_step.dart)
- [apps/seller/lib/providers/seller_application_provider.dart](../../apps/seller/lib/providers/seller_application_provider.dart)

### Agrimore Delivery

**Current source:** DeliveryDocUploadTile has empty/uploading/ready/error but ready uses verified/check icons even though Uploaded is only upload state. DeliveryAvatar accepts imageUrl but renders initials only. Rider profile uses generic rider avatar separate from KYC. Document View resolves stored URL/path with loading/error, submit replacement uploads then callable records separate submission. Active order camera proof is staged durably before confirmation; saveDeliveryProof uploads and attaches after delivery confirmation with retry and separate pending-proof recovery. Support single image uploads immediately on pick.

**Target:** Use high-contrast action/readable frames, never crop document inspection; generic document placeholders protect sample identity. Distinguish selected, uploading, not attached and submitted-for-review states; do not equate an uploaded file with delivery completion or identity approval. Preserve proof recovery only for existing supported flow.

| Panel | Domain specimen |
| --- | --- |
| Capture frame | Panel "Proof photo preview": wide generic closed delivery-crate PHOTO labelled "Selected photo / not attached". Black/white secondary "Retake photo". Orange note "Preview does not confirm delivery". Small "Synthetic photo example". No order/address/person/GPS/complete status. |
| Private document media | Panel "Document inspection": wide tallish neutral blank document-outline frame labelled "Private document preview", "Full image / contain"; beside two small equal placeholders "Loading document", "Could not load document" with secondary "Try again". Burgundy small "Sensitive information". Orange note "Never crop identification details". NO real/fake ID, QR, face, name, signature or thumbnail details. |
| Upload and attachment states | Panel "Photo handoff": empty camera tile "No photo selected"; separate spinner tile "Uploading photo…"; separate error row "Photo not attached" with secondary "Retry attachment". Orange note "Upload and record attachment are separate". No percent/tick/success/delivery completion or universal resume guarantee. |
| Rider avatar and review boundary | Panel "Rider avatar": circle neutral rider silhouette "Default rider avatar"; circle "R" caption "Synthetic initials"; below generic document-outline "Submitted for review / example state". Burgundy note "Document upload is not identity approval"; footer small "Avatar stays separate from documents". No verified check, licence photo, portrait or supported avatar upload claim. |

Preserve or resolve:

- Avatar imageUrl is currently unused; do not imply rider photo upload/display works from that prop.
- KYC remains separate from profile avatar, app approval and delivery proof. Uploaded badge should not imply verified.
- Proof staged locally is not yet attached; confirmation and proof attachment are separate outcomes.
- Durable recovery exists for proof photos, not universally for support/document uploads. Do not promise offline auto-sync or unrestricted retry.

Sources:

- [apps/delivery/lib/design_system/components/delivery_media.dart](../../apps/delivery/lib/design_system/components/delivery_media.dart)
- [apps/delivery/lib/design_system/components/delivery_list.dart](../../apps/delivery/lib/design_system/components/delivery_list.dart)
- [apps/delivery/lib/screens/profile/rider_profile_screen.dart](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart)
- [apps/delivery/lib/screens/profile/document_submission_screen.dart](../../apps/delivery/lib/screens/profile/document_submission_screen.dart)
- [apps/delivery/lib/identity/rider_document_review.dart](../../apps/delivery/lib/identity/rider_document_review.dart)
- [apps/delivery/lib/screens/orders/active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)
- [apps/delivery/lib/delivery/delivery_problems.dart](../../apps/delivery/lib/delivery/delivery_problems.dart)
- [apps/delivery/lib/delivery/proof_photo_recovery.dart](../../apps/delivery/lib/delivery/proof_photo_recovery.dart)
- [apps/delivery/lib/screens/support/submit_support_request_screen.dart](../../apps/delivery/lib/screens/support/submit_support_request_screen.dart)

### Agrimore Sales Associate

**Current source:** Profile builds a 56px initials circle from account name. Order-detail item rows render text and amounts without remote product photos; proposed bag/package icons are supplementary target media; no picker/storage upload found anywhere in employee/lib. Login uses bundled logo with errorBuilder; other decorative assets and icon states vary. Models can carry shared photoUrl but that is not implemented media upload adoption in this app.

**Target:** Build around current initials identity, legible attributed-record icons and reliable bundled decorative media. Distinct loaded/loading/failed asset examples are proposed; do not invent product gallery, avatar camera action or document upload in Sales Associate.

| Panel | Domain specimen |
| --- | --- |
| Initials identity | Panel "Associate identity": two circular samples "AS" and generic person outline captioned "Synthetic initials" and "Empty-name fallback"; size labels "Compact / 40 px" and "Profile / 56 px" outside samples. Indigo note "Name and role remain readable beside the avatar". No real person/name/photo. |
| Attributed-record media | Panel "Record icons": two text-row skeletons with blue outlined bag/package icons inside same neutral square frame. Captions "Order item icon" and "Record placeholder". Indigo note "Text identifies the record; media is supplementary". No product photograph/price/commission/order status. |
| Bundled asset resilience | Panel "Asset states": same-size tiles generic leaf/bag symbol "Asset example", skeleton "Loading example", image-off "Asset unavailable". Indigo note "Keep the layout stable when an asset fails". No actual company-logo redesign or button implying unsupported reload. |
| Supported media scope | Panel "Media actions": neutral person and image-outline symbols with clear text "Profile uses initials" / "No photo upload in this app". Small "Current supported scope"; indigo note "New upload controls require a supported flow". No Add photo, camera/gallery/retry upload, identity document, offline queue or photo success state. |

Preserve or resolve:

- No ImagePicker/putData/putFile evidence in employee/lib; proposed uploads need a future bounded implementation.
- Initials need empty/unicode/grapheme and large-text review; keep accessible identity label on containing row.
- Order icon absence is not an order error or lack of sales; media is supplementary to text.
- Raster placeholder/loading/failed examples are target design, not proof all these states are currently exposed.

Sources:

- [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [apps/employee/lib/screens/orders/order_detail_screen.dart](../../apps/employee/lib/screens/orders/order_detail_screen.dart)
- [apps/employee/lib/screens/auth/login_screen.dart](../../apps/employee/lib/screens/auth/login_screen.dart)
- [apps/employee/lib/screens/home/dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart)

### Agrimore Admin

**Current source:** ImageUploader supports single/multi selection and per-upload snapshot progress, URL insertion, removal and storageFolder; selection uploads immediately and parent save is separate. Batch failures are logged/skipped and only successful URLs appended; raw error text is shown in some paths, progress listen/mounted issues remain. Banner/category/storefront dialogs use differing aspect ratios. Support evidence accepts images/PDF, write-once storage path and callable finalize; retry checks object existence before reupload then reuses requestId. Evidence view reads bytes with Image.memory error fallback. User/rider avatar views mix NetworkImage/CircleAvatar and error fallback coverage.

**Target:** Separate catalogue crop/banner safe framing from contain-style evidence inspection. Neutral account avatars carry no approval meaning. Distinguish selected/uploading/storage completion/attached/parent save; per-file failure recovery and sanitized messages, preserving existing evidence finalize retry identity.

| Panel | Domain specimen |
| --- | --- |
| Content framing | Panel "Content images": square synthetic unbranded produce-crate PHOTO "Product / square"; wide synthetic farm panorama "Banner / wide". Cyan note "Preserve subject and safe crop areas". Small "Synthetic image examples". No CMS publish success or actual record. |
| Evidence and file fallback | Panel "Evidence preview": blank document-outline rectangle "Image evidence / contain", separate neutral PDF-outline "PDF attachment"; same-size failed-image frame "Could not load preview". Secondary outlined "Try again". Cyan note "No preview does not mean no attachment". No actual document/QR/name/case details or download/export. |
| Per-file upload recovery | Panel "Upload states": same-size tiles "Selected / not saved", "Uploading…" with indeterminate spinner and "Upload failed" with secondary "Retry upload". Cyan note "Handle each file; keep the remaining selection". No fabricated percent/count/all-success/attached label. |
| Avatar and finalize boundary | Panel "Identity and attachment": equal circular person-outline and "AD" samples labelled "Default avatar" and "Synthetic initials"; separate status text "Awaiting attachment confirmation / example state", outlined "Retry attachment". Cyan note "Storage completion is not record save"; tiny "Attachment does not resolve a case". No verified check/real portrait/admin authority badge. |

Preserve or resolve:

- Content URL stored in dialog is not published/saved record until parent save confirms.
- Batch partial success should identify failed selections, retain order and avoid claiming every file uploaded.
- Support evidence retry is existing-object/finalize aware; do not blindly create a new storage object on each retry.
- Image/PDF attachment is not case resolution; avatar photo is not verified identity; no live document contents in assets.

Sources:

- [apps/admin/lib/screens/admin/products/widgets/image_uploader.dart](../../apps/admin/lib/screens/admin/products/widgets/image_uploader.dart)
- [apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart](../../apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart)
- [apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart)
- [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [apps/admin/lib/screens/admin/users/widgets/user_card.dart](../../apps/admin/lib/screens/admin/users/widgets/user_card.dart)
- [apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart)

## Upload/record boundaries

| Flow | Observed handoff | Design implication |
| --- | --- | --- |
| Marketplace own profile | Pick local image; upload during Save with opening-owner checks; profile metadata save afterwards; removal explicitly staged | Selected/uploaded is not applied profile; preserve owner checks and draft on failure |
| Seller product/post | Local selection before product save/post creation; single-photo product editor upload | Do not imply arbitrary multi-upload or published outcome |
| Seller storefront | Pick triggers upload; resulting URL stays in draft; Save updates seller record | Storage receipt is not storefront publication |
| Seller onboarding document | Storage upload then application save of path; later submit/approval separate | No uploaded-is-approved icon; documents are not public catalogue media |
| Delivery proof | Camera bytes staged durably before confirm; upload/attach after confirmed delivery; pending proof store/recovery separate | Do not reconfirm delivery merely to retry a photo; supported recovery is proof-specific |
| Delivery replacement document | Camera for selfie/gallery others; staging then submitDocumentReplacement; separate submission review | Uploading, submitted for review and approved remain distinct |
| Delivery support attachment | Single image uploaded on pick before request submission | Do not promise draft attachment persistence across restart/offline queue |
| Admin catalogue/banner | Upload immediately in editor; parent callbacks/save later; batch successes appended separately | Per-file recovery and parent save confirmation; no all-files success assumption |
| Admin case evidence | Pick creates requestId; retry keeps pending file/id, checks existing object then calls attachSupportCaseEvidence | No repeated overwrite/new attachment on lost finalize acknowledgement |

## Framing and specimen rules

Square catalogue tiles may cover-crop with stable focal area. Store covers/banners are wide and logo/avatar frames circular; these specimens do not prescribe one aspect ratio for all existing media. Full product/evidence/document inspection should contain the image, preserve readable edges and offer zoom where implemented. Marketplace contain detail and the unified state gallery are targets; Delivery private document viewer already uses InteractiveViewer. Actual media pixels should retain natural color in dark mode while surrounding surfaces follow locked near-black/grey tokens.

Loading/missing/failure placeholders reserve dimensions and keep text/actions available. No-image does not imply product unavailable, order missing or evidence unattached. A retry preview request differs from retry upload, finalize attachment and changing the selected file; handlers require separate domain semantics. A spinner is indeterminate unless actual bytes/total provide progress. No universal upload cancel/resume/crop editor/offline auto-sync promise is introduced. Sales Associate has no current upload control.

All photographs are generated generic unbranded produce/seed/field/crate examples. Avatar samples are silhouette/store outlines or explicitly synthetic AS/R/AD monograms; private documents/evidence use blank document icons, never fake KYC, names, numbers, portraits, signatures or QR codes. Example states are independent specimens, not live operations. No successful save/upload/approval/publication/delivery/case outcome is claimed.

## File policy and private media

StorageService uses image/jpeg metadata for file/byte upload without proving bytes are JPEG, and its users/<uid>/profile nested helper differs from the one-segment users/<uid>/<fileName> rule and actual Marketplace uploader. Actual path/MIME/size restrictions vary; generic rule helper uses a strict size bound rather than the older onboarding comment’s inclusive wording. Picker imageQuality/maxWidth do not establish a safe type or final payload size. Align actual paths and backend checks before showing accepted-type/size helper text; the boards deliberately omit invented limits.

Admin support evidence source additionally checks object identity/generation and recognized header signatures, while inspected rider document/proof checks use source metadata/size; these are not interchangeable or a universal decoding/security certification. Existing storage rules distinguish public catalogue/storefront, owned avatar and private documents/support/proof. Reading source does not prove live deployment. Display placeholders/blur/masks do not supply authorization, revoke a download token, encrypt cached bytes or prevent cross-account cache retention.

Preserve opening/current owner across pick, upload and metadata save; dispose progress subscriptions and ignore late results. Replacements should keep old referenced media until supported save confirms; form removal, reference removal, object deletion and orphan cleanup need separate contracts. Admin ImageUploader currently may delete the Storage object when removing a URL before parent save, which needs later reconciliation. No deletion or migration was performed here.

Additional source references:

- [packages/agrimore_services/lib/storage/storage_service.dart](../../packages/agrimore_services/lib/storage/storage_service.dart)
- [storage.rules](../../storage.rules)
- [functions/src/delivery/riderExceptions.ts](../../functions/src/delivery/riderExceptions.ts)
- [functions/src/delivery/riderDocumentReview.ts](../../functions/src/delivery/riderDocumentReview.ts)
- [functions/src/admin/supportCases.ts](../../functions/src/admin/supportCases.ts)

## Future implementation verification

- Empty URL versus malformed URI/data URI versus network denied/offline/404 versus invalid decoded bytes; local/web/native cache/load paths with stable frames and sanitized copy.
- Cover/contain crop, focal area, EXIF orientation, very large/tall/wide images, empty/broken assets and actual document zoom without clipped identification detail.
- Local selection cancellation preserves draft; picker errors explain recovery; MIME/extension/payload/size match actual domain constraints. Picker compression settings are not acceptance promises.
- Known progress versus indeterminate, zero/unknown totalBytes, disposal/listener cleanup, upload failure and parent-save failure, partial batches, replacement/remove discard and orphan cleanup.
- Owner changes/logout during pick/upload/finalize prevent stale UI/metadata application and private preview cache reuse. Current Marketplace owner guards remain.
- Proof staging/restart recovery and attachment retry remain separate from confirmDelivery; expiry/reassigned owner/current route checks use actual backend behavior. Do not generalize proof persistence to documents/support.
- Seller document upload/application save/submit/review, Delivery document replacement/review, Admin write-once evidence upload/lost finalize acknowledgement/retry and generation-aware authorized preview.
- Sales Associate has no upload until a real supported flow exists. Empty/unicode names need safe initials; proposed icons never imply the item failed.
- Avatar image/decorative semantics, identity in surrounding text, meaningful image labels, upload status announcements, focus/touch areas, long captions and text scaling across light/dark phone/web.
- Meaningful widget/domain tests and analyzers during later runtime changes. No runtime/emulator/analyzer/backend/live-data/upload/privacy/accessibility verification performed by this assets task.

## Scope and design review

27 new files: ten PNGs, five README/prompts/manifest sets and two master documents. C01–C24 and repeated C16 remain intact; C25 is provisional, owner approval pending. Classifier: docs. Voluntary UIUX/feedback review covers locked identities, synthetic media, app-specific supported scope, stable states and honest upload/save/approval boundaries. Raster boards are not rendered-app tests or pixel-exact/contrast/accessibility certification.

Only new design assets/docs written. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption by this task. Concurrent shared-checkout changes are observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/screens/user/orders/rate_order_screen.dart.

## Asset integrity check

First post-packaging validation snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs. PNG chunk checksums, copied-output hashes, 12 exact prompt blocks, reference-input hashes, approved C01 token metadata and 93 local document links passed. Exactly 27 new repository files; all 999 earlier design files remained byte-for-byte intact.

All ten selected images received visual review for media sizing/crop, avatars, loading/missing/failed frames, independent upload/attachment examples and light/dark identity. Delivery light had one focused refinement removing an extraneous placeholder button; Delivery dark references that selected refinement. Admin dark had one focused refinement correcting its initials circle to the locked pale-primary/dark-inverse pair. Photographs/monograms are synthetic; document/evidence samples are blank icons, not real private data.

Snapshot HEAD: 6c676fcc0a7acca85b7798bf9b1e5bc65794c249; inventory HEAD: aed38d713a0c285a75d2cbfcff81a3698ba5dacd; branch: agrimore/foundation-f3c-distance-delivery-pricing. Indexed source changes between inventory and packaging were observed and preserved: apps/marketplace/lib/screens/user/orders/rate_order_screen.dart. No additional indexed source changes were observed during this first packaging/check snapshot. Platform configuration hashes matched the inventory. This records a point in time, not a guarantee that the other chat or HEAD stops advancing.

Scope: design assets/docs only. Integrity checks and visual review do not certify pixel-exact tokens, runtime rendering, accessibility, decoding/upload/attachment behavior, storage policy, privacy or identity approval. C25 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.
