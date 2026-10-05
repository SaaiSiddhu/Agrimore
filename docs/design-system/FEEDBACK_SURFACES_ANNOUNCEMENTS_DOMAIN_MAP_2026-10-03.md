# Agrimore — C16 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-board gallery](FEEDBACK_SURFACES_ANNOUNCEMENTS_BOARDS_2026-10-03.md) · [Locked C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and evidence limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 eligible source files / 271,604 lines** scanned across all five app lib trees, agrimore_ui/core/services and functions/src. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Focused semantic reads covered shared helpers, Seller/Delivery feedback primitives, RFQ confirmation/navigation, stock save, store pause/resume, proof retry lifecycle, payout-review/cancel, notification/clipboard feedback and support/finance notices. Broad static inventory plus focused review does not mean every line was semantically audited or every screen rendered. Functions/services were inventoried for data/auth context; no backend behavior or live state was validated.

Marker counts include comments and are not unique screens/components or defect counts. Custom overlays, plain Containers, renamed wrappers and framework-native accessibility behavior are undercounted. Absence of an explicit liveRegion does not prove a SnackBar is silent. Marketing banners are not operational notices. A zero marker count does not prove feature absence. Observations describe the local source snapshot; implementation can continue in another chat.

| Scope | native_snackbar | shared_helper | seller_toast | delivery_toast | banner | live_region | announce | replace_clear |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 48 | 225 | 0 | 0 | 0 | 0 | 0 | 0 |
| delivery | 1 | 0 | 0 | 40 | 19 | 3 | 0 | 1 |
| employee | 14 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| marketplace | 55 | 48 | 0 | 0 | 1 | 0 | 0 | 2 |
| seller | 1 | 0 | 43 | 0 | 54 | 10 | 15 | 1 |
| functions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 8 | 2 | 0 | 0 | 0 | 1 | 0 | 3 |

## Existing infrastructure and reuse

SnackbarHelper and DialogHelper are the shared anchors; SellerToast/SellerBanner and DeliveryToast/DeliveryBanner are existing app equivalents, not permission to add duplicate helpers. Future runtime changes should adapt canonical semantics and per-app tokens. No new widget or helper is implemented by this image task. The older repository feedback guide predates current Seller/Delivery localisation and brand systems; its historical counts and emerald-only styling are superseded by fresh source evidence and approved C01 owner identities. Safe-copy, authoritative-confirmation and reuse rules still apply.

Verified helper anchors:

- [snackbar_helper.dart](../../packages/agrimore_ui/lib/widgets/snackbar_helper.dart)
- [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)
- [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart)
- [seller_banner.dart](../../apps/seller/lib/design_system/components/seller_banner.dart)
- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)
- [delivery_banner.dart](../../apps/delivery/lib/design_system/components/delivery_banner.dart)

## Shared target feedback contract

1. A toast confirms a short nonessential event; it is not the sole location for unresolved errors, restrictions or review state.
2. Inline notices belong to their affected form/record/action, preserve entered data and use safe reason-specific copy.
3. Persistent banners remain while their condition applies. Dismiss only when a supported nonessential notice may be hidden; do not resolve a condition by dismissal.
4. Toast, inline error and persistent condition are independent examples. Do not present contradictory success and failure as one live outcome.
5. Confirm the authoritative operation outcome before success. Local cart update, proof upload, review submission and case action have distinct scopes.
6. No fictional Undo, blind mutation Retry or instant approval/paid/order completion. Unknown outcome requires reconciliation before retry.
7. One in-flight action per scope, disabled labelled pending control, no duplicate taps; clear progress in finally/unmount/account change.
8. Use the existing shared helper or documented app equivalent. Future adoption should adapt canonical semantics rather than create duplicate helper classes.
9. Announcements are meaningful, concise, coalesced by event/entity revision and ordinarily polite. Inspect native SnackBar semantics before wrapping another live region.
10. Keep focus in context; announcements do not steal focus. Validation focus follows C10; route focus follows C07. Label dismiss/recovery controls and exclude decorative icon semantics.
11. Timeouts must allow reading and assistive use; actionable notices need accessible duration policy. Reduced motion uses static feedback; haptics are supplementary.
12. Use C01 locked app identity and status pairs; text/icon/action convey meaning beyond color. Check rendered light/dark, contrast, scaling, localisation and platform AT later.

## Surface selection

| Situation | Surface | Lifetime and recovery |
| --- | --- | --- |
| Short confirmed event | Toast | Brief and readable; essential outcome remains reflected in record/state; accessibility duration policy |
| Invalid field or failed action | Inline notice/error | Persist near affected input/action; preserve values; safe reason; no blind mutation replay |
| Paused store / pending proof / review / partial coverage | Persistent banner | Condition-owned visibility, supported domain action only; dismissal does not resolve state |
| Routine meaningful outcome | Polite accessible update | Once per event/revision; do not add a duplicate native SnackBar announcement |
| Blocking immediate error | Scoped error with appropriate announcement priority | Urgency decided by task relevance, not merely red/warning tone |
| Progress | Pending action or scoped progress notice | Never immortal toast; disabled labelled action, cancellation/timeout/finally/unmount lifecycle |

## Confirmation and action boundaries

| App specimen | Confirmed scope | Persistent condition / supported action |
| --- | --- | --- |
| Marketplace quote toast | createRfq response returned request ID; not accepted quote or order | Store paused: buyer may browse, cannot resume store |
| Seller stock toast | Stock sheet returned saved==true in same user scope | Paused store: existing Resume handler; pending guard and confirmation required |
| Delivery proof toast | saveDeliveryProof returned true; photo upload only | Pending photo: retry upload, never confirmDelivery again; expiry/missing file distinct |
| Sales Associate review toast | requestEmployeePayoutChange completed; not approved/effective/paid | payoutChangePending: existing Cancel Request, not dismiss or approval |
| Admin case toast | Support callable completed; not whole-case resolution or money certification | Incomplete scan: keep covered-scope/reason notice beside findings, no invented fix button |

## Source findings and migration priority

| Area | Verified evidence | Target correction |
| --- | --- | --- |
| Shared helper | Fixed status colors/text; showLoading duration 365 days; only explicit hide/clear ends it; some paths queue snackbars | App-token adaptation, bounded lifecycle, queue replacement/coalescing, timeout and unmount cleanup |
| Marketplace | RFQ success after await but shown on popped sheet context; quote validation uses snackbar; cart local update returns bool with unawaited persistence and some callers ignore bool | Destination messenger; field-scoped validation; separate local/sync/server outcome and inspect bool |
| Seller | Footer offset, replacement, close, liveRegion, reduced-motion noAnimation already exist; banner announce opt-in | Preserve strengths; verify native semantics interaction; coalesce per event; do not pretend proposal requires a new helper |
| Delivery | Warning/danger banner automatically liveRegion; persistent proof retry guarded per ID and upload-only | Test repeated rebuild announcements; preserve proof/completion distinction and local retention |
| Associate | Review toast promises approval; notifications error contains $e; clipboard write unawaited before success | Safe copy; truthful review status; await clipboard; dedupe announcement and mutation feedback |
| Admin | Support error can use e.message; incomplete finance warning persists with reasons | Safe reason mapping, scoped action notices, neutral themed coverage warning; no All clear from incomplete read |

## Agrimore Marketplace

**Current implementation snapshot:** RequestQuoteSheet validates quantity/price via warning snackbars, awaits RfqProvider.createRfq, then pops the sheet, shows success with the old context and navigates to RFQ detail. The provider awaits the callable and returns its rfqId. BusinessProfileScreen has a persistent paused-store MaterialBanner with no actions. CartProvider.addItem returns local success while authenticated persistence is unawaited; inspected UnifiedProductCard success feedback ignores the bool result.

**Target:** Destination-owned confirmed quote-request toast, field-scoped actionable validation and a non-dismissible buyer-facing store restriction. Separate local cart update from server sync/order confirmation. Announce the confirmed event once without competing with destination focus.

**Domain character:** Professional-green buyer feedback with warm-gold context and natural-stone storefront surfaces.

| Panel | Specimen |
| --- | --- |
| Transient toast | Floating neutral branded toast with small success icon, text "Quote request sent", quiet caption "Sample confirmed response". Board note "Show on the destination". No Undo or action claiming acceptance/order placement. |
| Inline notice | Compact quote form excerpt, empty field labelled "Quantity" and error icon/message "Enter a valid quantity". Notice heading "Check quantity". Board note "Keep entered details". No sample numeric quantity, prices, or hidden-field error. |
| Persistent banner | Storefront notice with pause icon, heading "Store paused", body "This store is not taking orders right now. You can still browse." Small board note "Keep visible while paused". No dismiss X, Resume, or invented recovery link. |
| Accessible updates | Explicitly labelled "Announcement design". A small speaker-outline row with quoted text "Quote request sent". Two simple rule rows "Announce once" and "Keep destination focus". Warm-gold annotation "Polite update / no duplicate announcement". This is a design annotation, not a screen-reader transcript. |

Gaps and invariants:

- Move the toast to a valid destination messenger after navigation; avoid torn-down sheet context.
- Inline validation preserves entered values and links to the invalid field; show the error there rather than relying on an expiring snackbar.
- Paused-store feedback must not offer buyer Resume controls; browsing remains available.
- Cart local success is not server-saved or order-placed; callers must inspect false results and map persistence failure safely.
- Framework-native SnackBar announcement must be checked before adding a second live-region wrapper.
- RfqProvider.createRfq exposes e.message as provider error; quote-sheet failure uses that text. Map known reasons to safe copy rather than show raw callable messages.

Source anchors:

- [request_quote_sheet.dart](../../apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart)
- [rfq_provider.dart](../../apps/marketplace/lib/providers/rfq_provider.dart)
- [business_profile_screen.dart](../../apps/marketplace/lib/screens/business/business_profile_screen.dart)
- [cart_provider.dart](../../apps/marketplace/lib/providers/cart_provider.dart)
- [unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| auth | 9 |
| business | 3 |
| chat | 11 |
| employee | 7 |
| landing | 1 |
| legal | 2 |
| not_found_screen.dart | 1 |
| onboarding | 1 |
| seller | 1 |
| splash | 1 |
| user/cart | 9 |
| user/categories | 2 |
| user/checkout | 7 |
| user/flash_sale | 1 |
| user/help | 1 |
| user/home | 27 |
| user/main_screen.dart | 1 |
| user/notifications | 1 |
| user/offers | 1 |
| user/orders | 15 |
| user/profile | 9 |
| user/rewards | 1 |
| user/rfq | 3 |
| user/search | 3 |
| user/settings | 1 |
| user/shop | 20 |
| user/subscriptions | 2 |
| user/wallet | 9 |
| user/wishlist | 5 |

## Agrimore Seller

**Current implementation snapshot:** SellerToast replaces the current snackbar, offsets above SellerStickyFooter, provides close/action affordances, explicit liveRegion, excluded decorative icon and noAnimation for reduced motion. SellerBanner supports optional announce and dismiss callbacks. Stock success appears only when saved==true and the same user remains active. The stock sheet already includes a local error banner. Profile shows a paused-store warning banner wired to _resume.

**Target:** Reuse existing toast/banner primitives with C01 tokens; keep stock errors in the sheet and the paused-store condition persistent. Resume is a deliberate existing mutation with pending guard and confirmed outcome, not a toast dismissal. Coalesce announcements per action/entity revision.

**Domain character:** Blue-teal operational feedback, copper guidance, compact cool-neutral surfaces and footer-aware floating toasts.

| Panel | Specimen |
| --- | --- |
| Transient toast | Floating blue-teal neutral-surface toast "Stock updated" with success icon and labelled "Dismiss" secondary text control. Caption "Sample confirmed response". Small note "Above sticky actions". Do not show stock numbers or Undo. |
| Inline notice | Stock-sheet notice with error icon, heading "Stock couldn’t be saved", body "Your entered value is still here." Nearby empty field labelled "Stock quantity". Small note "Review before resubmitting". No automatic Retry mutation or cleared input. |
| Persistent banner | Warning banner "Store paused", body "Ordering is paused for your store." OUTLINED blue-teal action "Resume store". Copper board note "Wait for confirmation before clearing". No fake countdown, end date or dismiss X. |
| Accessible updates | Explicit "Announcement design" area. Quoted sample "Stock updated" with small speaker icon. Rule rows "One update per saved change", "Keep focus in context", "Reduced motion: static feedback". Copper annotation "Announce only meaningful changes". |

Gaps and invariants:

- Explicit SellerToast liveRegion plus platform snackbar semantics requires real assistive-tech duplicate checks.
- SellerBanner announce is opt-in; repeated rebuilds should not repeat identical notices.
- Persistent store-state changes survive toast expiration; do not dismiss an unresolved pause just to clear the screen.
- Resume/stock retry must reconcile server outcome and block duplicates; no fictional Undo or blind mutation retry.
- Profile _resume awaits Firestore confirmation but has no explicit in-flight guard in the inspected handler; the proposed banner action needs duplicate-tap protection.

Source anchors:

- [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart)
- [seller_banner.dart](../../apps/seller/lib/design_system/components/seller_banner.dart)
- [seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [seller_profile_screen.dart](../../apps/seller/lib/screens/profile/seller_profile_screen.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| account | 8 |
| ai | 1 |
| auth | 6 |
| home | 4 |
| insights | 3 |
| notifications | 2 |
| onboarding | 10 |
| orders | 6 |
| payments | 3 |
| posts | 2 |
| products | 6 |
| profile | 5 |
| reviews | 2 |
| rfq | 7 |
| search | 2 |
| shell | 1 |
| storefront | 2 |

## Agrimore Delivery

**Current implementation snapshot:** DeliveryToast replaces current snackbar and uses tone pairs; no explicit reduced-motion or liveRegion wrapper appears in that function. DeliveryBanner makes warning/danger live regions automatically. PendingProofBanner persists local proof entries and guards each retry; it retries saveDeliveryProof only, never confirmDelivery. Successful upload clears/discards the pending entry; failure retains it. Expired/missing photo paths allow explicit local dismissal.

**Target:** Persistent proof-photo recovery with independent idle/pending examples, truthful photo-only confirmation and safe inline upload failure. Announce only newly meaningful conditions, not every banner rebuild. Preserve existing completion versus proof distinction without fabricating a delivered outcome on the board.

**Domain character:** High-contrast black/white field feedback, burgundy error context, burnt-orange recovery guidance and generous labelled actions.

| Panel | Specimen |
| --- | --- |
| Transient toast | High-contrast neutral toast "Proof photo saved" with small success icon. Caption "Sample confirmed upload" and note "Photo confirmation only". No Delivered tick, earnings, payment claim or Undo. |
| Inline notice | Burgundy error notice "Proof upload failed", body "The photo still needs to be attached." Burnt-orange board annotation "Keep pending proof". No delivered/paid status and no disappearing error timer. |
| Persistent banner | Persistent warning banner "Proof photo not saved", body "Retry to attach the pending photo." Generous OUTLINED black/white action "Retry photo upload". Separate small pending variant "Uploading photo" with spinner and disabled outlined action. Board note "Retry upload only". No dismiss X on recoverable entry. |
| Accessible updates | Explicit "Announcement design" section. Quoted text "Proof photo saved" with speaker icon. Rules "Announce outcome once", "Keep action focus", "No repeated warning on rebuild". Orange supporting note "Static feedback in reduced motion". |

Gaps and invariants:

- Proof retry must not reconfirm delivery or imply payment/settlement.
- Automatic warning liveRegion needs coalescing across dashboard rebuilds; test native toast semantics before adding another wrapper.
- Keep cached pending entry while upload fails; expiry/missing file and dismissal are separate reasons.
- One retry in flight per proof; disable the same action during upload, preserve accessible label/focus.

Source anchors:

- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)
- [delivery_banner.dart](../../apps/delivery/lib/design_system/components/delivery_banner.dart)
- [pending_proof_banner.dart](../../apps/delivery/lib/screens/home/pending_proof_banner.dart)
- [app_en.arb](../../apps/delivery/lib/l10n/app_en.arb)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| auth | 3 |
| history | 2 |
| home | 6 |
| inbox | 1 |
| money | 3 |
| offers | 1 |
| orders | 4 |
| profile | 3 |
| settings | 1 |
| support | 5 |

## Agrimore Sales Associate

**Current implementation snapshot:** PayoutAccountScreen awaits requestEmployeePayoutChange before its submitted-for-review snackbar; wallet payoutChangePending replaces the form with a persistent pending card and existing Cancel Request handler. Current success wording says an admin will approve it, although review may reject. Notification batch success waits for commit but failure embeds $e. HelpSupportScreen announces copied immediately without awaiting Clipboard.setData.

**Target:** Truthful submission toast, safe local refusal/failure notices and a persistent review banner. Submission is not approval, an effective payout destination or money paid. Retain existing supported cancel-request behavior with pending protection; cancel is a mutation, not dismiss.

**Domain character:** Premium royal-blue relationship and payout-review feedback, indigo pending context with pearl/slate surfaces.

| Panel | Specimen |
| --- | --- |
| Transient toast | Royal-blue neutral-surface floating toast "Payout details submitted for review", small receipt/check icon. Caption "Sample confirmed submission". Indigo note "Submitted does not mean approved". No Paid badge or promise. |
| Inline notice | Safe error notice "Request couldn’t be submitted", body "Review your details before trying again." Empty field labelled "Payout method" with no account/UPI/bank values. Note "Keep entered details". No unconditional Retry or raw exception. |
| Persistent banner | Indigo context banner "Payout details awaiting review", body "Current payout details, if set, still apply until approval." OUTLINED royal-blue action "Cancel request". Board annotation "Explicit cancellation / not dismiss". No approve control, guaranteed date or false balance. |
| Accessible updates | Explicit "Announcement design" section. Quoted text "Request submitted for review" with speaker icon. Rules "Announce once", "Keep focus in context", "Do not announce approval". Indigo supporting note "Review state stays visible". |

Gaps and invariants:

- Replace approval promise with pending-review wording; approval/rejection remain independent confirmed outcomes.
- Map notification/other exceptions to safe copy; no raw platform strings or account details.
- Clipboard success must follow completed write rather than fire immediately.
- Cancel Request requires its existing backend checks and busy state; announcement coalescing and focus restoration are proposed.
- Pending-review copy covers both replacement and first-time payout setup: an existing destination continues only if one was already configured.

Source anchors:

- [payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart)
- [notifications_screen.dart](../../apps/employee/lib/screens/notifications/notifications_screen.dart)
- [help_support_screen.dart](../../apps/employee/lib/screens/support/help_support_screen.dart)
- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| auth | 5 |
| home | 1 |
| notifications | 1 |
| orders | 2 |
| profile | 2 |
| shell | 1 |
| support | 1 |
| wallet | 6 |

## Agrimore Admin

**Current implementation snapshot:** SupportCaseDetail _call waits for the callable before success and refreshes activity. FirebaseFunctionsException feedback can expose e.message; generic catch is safe. Finance reconciliation already persists scan coverage and an incomplete warning with reasons, separate from findings. Shared SnackbarHelper handles status/custom/action/loading; some paths queue bars, loading uses a 365-day duration requiring explicit hide/clear.

**Target:** Concise confirmed case-action toast, safe inline scoped action failure, and persistent incomplete-scan warning. A toast never certifies case resolution or complete finance coverage. Prioritize actionable feedback, prevent stale/queued repeats, and distinguish urgent errors from routine polite updates.

**Domain character:** Professional-blue operational feedback, cyan context cues and dense steel/slate information surfaces.

| Panel | Specimen |
| --- | --- |
| Transient toast | Compact neutral professional-blue toast "Case updated" with success icon. Caption "Sample confirmed action". Cyan board note "Confirmed case action only". No Resolved/Approved/paid inference or Undo. |
| Inline notice | Inline safe error "Case update failed", body "Review the case before submitting again." Small labelled context "Support case / Sample". Cyan note "Other sections remain available". No stack trace, server message, case IDs or blind Retry. |
| Persistent banner | Persistent warning "Scan coverage incomplete", body "Some records were not checked. Review the covered scope." Small cyan context "Read-only reconciliation". No dismiss X or invented action button; the surrounding view owns coverage details. No All clear, scanned counts, timestamps or fake full coverage. |
| Accessible updates | Explicit "Announcement design" section. Speaker icon and quote "Case updated". Rules "One confirmed update", "Keep operator focus", "Prioritize blocking errors". Cyan supporting note "Coalesce repeated notices". No automatic assertive readout for every banner. |

Gaps and invariants:

- Map callable exceptions to safe operator-facing reasons; do not expose raw server messages.
- Incomplete scan must remain visible alongside findings; no All clear or zero findings inferred from incomplete coverage.
- Shared helper lifecycle needs timeout/cancel/unmount policy instead of immortal progress snackbar.
- No blind replay of administrative mutations, fictional Undo, or assertion that case action certifies money.

Source anchors:

- [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart)
- [snackbar_helper.dart](../../packages/agrimore_ui/lib/widgets/snackbar_helper.dart)
- [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Confirmed success, false result, exception, unknown timeout, expired auth and late response after route/account change. No optimistic server-success claims or blind mutation replay.
- Toast destination messenger survives navigation; replace/coalesce without stale queues; overlapping operations retain scope. No unrelated confirmation overwrites essential error.
- Inline errors keep entered values and remain discoverable at text scale; field linking/focus follows C10 and does not rely on an expiring toast.
- Condition lifecycle: paused/resumed store, pending/uploaded/expired/missing proof, pending/approved/rejected/cancelled payout change, incomplete/complete new finance scan. Never hide unresolved state by dismissal alone.
- Existing Resume, proof retry and Cancel Request require pending duplicate protection and authoritative confirmation. No invented Undo or administrative Retry mutations.
- Flutter semantics inspection plus actual TalkBack/VoiceOver: one concise announcement, native SnackBar duplication, update coalescing across rebuilds, focus retention/route restoration, urgency, localised dismiss/recovery labels and decorative icon exclusion. Raster is not evidence of these behaviors.
- Accessible reading duration, keyboard/sticky-footer/safe-area clearance, text scaling/long translations, light/dark contrast, touch targets and reduced-motion static feedback. Haptics must remain supplementary.
- Future canonical shared-helper migration requires all five app analyzers and rendered checks. No runtime tests or live accounts were used for this asset-only delivery.

## Delivery scope and design lanes

27 new repository files: ten PNGs, five per-app README/prompts/manifest sets, two master documents. Earlier C01–C15 files are preserved. C16 is provisional; no owner approval inferred. User explicitly requested image-prompt provenance; prompts.md records image generation, not an exported implementation-worker prompt.

UIUX/feedback design review covers app identities, authoritative scope, safe copy, toast/inline/persistent distinction, supported actions, proposed accessible announcements and neutral dark surfaces. Classifier lane: docs; UIUX/feedback design review voluntarily attached. Runtime gates are not applicable evidence for assets-only delivery; no Flutter analysis/emulator/live-account/runtime-accessibility checks were performed. No Dart/TypeScript/runtime source, pubspec registration, staging/commit/branch changes, deploy or other-chat interruption by this task. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset verification

**PASS — asset and document integrity only.** Ten selected PNGs form five light/dark pairs. PNG headers, dimensions, chunk CRCs, byte copies and SHA-256 hashes verified; C01 palettes, status colors, typography, spacing, radii and border metadata match the approved locks exactly. Seventeen exact generation/refinement prompt blocks and 86 local document links verified. All 756 earlier design files remain byte-identical. The 817 inventoried source files and ten observed Android/iOS configs remain unchanged across packaging; Git HEAD and branch remain unchanged. All selected images were visually reviewed. No runtime, assistive-technology or pixel-exact raster certification is implied.
