# Agrimore — C17 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-board gallery](DIALOGS_SHEETS_DISCARD_PROTECTION_BOARDS_2026-10-03.md) · [Locked C01 identity](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and evidence limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 eligible source files / 271,604 lines** scanned across all five app lib trees, agrimore_ui/core/services and functions/src. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Focused semantic reads covered shared modal helpers, Seller confirmation/dirty guard/sheet frame, stock save and store choice, cart-mode consent, quote editing, Delivery draft resume/reset and problem report, Associate payout forms/cancellation and Admin note/link mutation lifecycle. Broad static inventory plus focused review does not mean every line was semantically audited or every screen rendered. Functions/services were inventoried for data/auth context; no backend behavior or live state was validated.

Marker counts include comments and are not unique screens/components or defect counts. Custom route editors, nonstandard dirty signals and wrapper dismissal policies are undercounted. PopScope includes auth/offer/root-navigation guards, not solely unsaved edits; dirty-marker counts include comments and localisation. Zero named markers do not prove there is no route guard anywhere. A zero marker count does not prove feature absence. Observations describe the local source snapshot; implementation can continue in another chat.

| Scope | native_dialog | native_sheet | shared_dialog | seller_confirm | delivery_confirm | pop_guard | dirty_marker | dismiss_policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 87 | 2 | 3 | 0 | 0 | 0 | 0 | 1 |
| delivery | 3 | 15 | 0 | 0 | 12 | 3 | 2 | 6 |
| employee | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| marketplace | 23 | 23 | 8 | 0 | 0 | 3 | 2 | 8 |
| seller | 1 | 8 | 0 | 12 | 0 | 13 | 48 | 2 |
| functions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| agrimore_ui | 9 | 1 | 0 | 0 | 0 | 1 | 0 | 5 |

## Existing infrastructure and reuse

DialogHelper is the verified shared modal anchor. Seller sellerConfirm, SellerDiscardGuard, showSellerSheet and SellerSheetFrame already exist in seller_feedback.dart; Delivery showDeliveryConfirmDialog/showDeliverySheet exist in delivery_feedback.dart. Reuse and adapt these equivalents rather than create another helper. The old UIUX guide lists packages/agrimore_ui/lib/widgets/common/confirmation_dialog.dart, but fresh rg inventory did not find that file; this task does not pretend it is a current component. Historical emerald-only styling, localisation counts and modal inventory are not current authority over approved C01 identities. No runtime helper or widget was added.

Verified infrastructure anchors:

- [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)
- [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart)
- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)

## Shared target modal contract

1. Modal consent is explicit: true authorizes the named action; false/null/back/scrim never authorizes deletion, cancellation or draft reset.
2. One focused task per sheet, accurate title/context/consequence, a safe labelled alternative and distinct destructive wording. No generic Yes/No for consequential actions.
3. Track dirty state against the confirmed initial baseline, including reverted edits and optional fields. Unchanged idle editors exit directly; dirty editors ask once.
4. Back, close, keyboard escape, scrim, drag and navigation through the editor use one serialized guard; repeated attempts do not stack dialogs.
5. Keep editing restores the editor and appropriate focus. Discard affects only that unsent local payload, not existing remote records, pending requests or recovery journals.
6. Draft persistence is domain-specific: only Delivery registration has evidenced resumable draft storage here. No invented Save draft or sensitive payout-value persistence.
7. Freeze captured payload and block duplicate submission while pending. Leaving UI is not canceling an in-flight server operation; use a bounded lifecycle and reconcile outcome.
8. Known failure keeps safe editor input and inline reason; unknown outcome checks authoritative state before retry. Reuse supported request identity/version checks according to the action.
9. Close/clear dirty only after the applicable authoritative success; modal pop itself is not saved, approved, paid, delivered or order placed.
10. Scroll body and sticky footer fit safe areas/keyboard/text scaling; actions remain reachable. Show modal focus containment, labelled close/dismiss and opener focus restoration in runtime verification.
11. Use existing DialogHelper/Seller/Delivery equivalents and C01 locked per-app tokens; extend canonical lifecycle instead of duplicating helpers.
12. Cancellation defaults to the least destructive path. Reduced motion, route semantics, native modal accessibility and contrast need rendered/AT checks; raster proposals do not certify them.

## Editor exit state policy

| State | Presentation / exit | Data boundary |
| --- | --- | --- |
| Idle / unchanged | Close directly and restore opener focus | No needless discard prompt; compare to confirmed baseline |
| Dirty local editor | One Keep editing / Discard confirmation for all exit paths | Discard only unsent local editor payload |
| Explicit consequential action | Specific title, consequence, safe alternative and action verb | Only explicit true consents; false/null preserves state |
| Submitting | Freeze captured payload, disable duplicate action, explain pending state | Exiting UI is not cancellation of a server operation; bounded lifecycle |
| Known failure | Keep editor and safe inline error | Retain entered values; retry only with supported action identity |
| Unknown result / timeout | Check authoritative operation state before resubmitting | Do not issue blind replacement mutation or claim failure means nothing happened |
| Confirmed success | Clear dirty and close deliberately; destination owns feedback | No discard prompt after successful save; submission is not approval/payment |
| Entity/account change | Invalidate stale responses and protect access boundaries | Do not carry sensitive editor values into another account |

## Domain consent boundaries

| App specimen | Local edit / discard | Consequential operation |
| --- | --- | --- |
| Marketplace | Unsent RFQ quantity/notes; no saved-draft implementation claimed | Cart-mode consent clears cart; RFQ submission does not place order |
| Seller | Changed stock field; extend existing discard guard | Stock persistence confirmed before close; store-state choice distinct from write |
| Delivery | Unsent report fields versus evidenced local registration draft | Start over is explicit local reset; report close does not resolve exception or complete delivery |
| Sales Associate | Unsubmitted payout edits; no sensitive disk draft proposed | Cancel pending review is separate callable; submit for review is not approved/effective/paid |
| Admin | Unsent note payload retained through submission | Unlink removes relationship only; versioned unlink distinct from idempotent note request |

## Source findings and migration priority

| Area | Verified local evidence | Target correction |
| --- | --- | --- |
| Shared | DialogHelper confirmation returns bool?; sheet defaults dismissible/draggable and fixed AppColors.surface; input closes before returned value is acted on | Keep explicit result semantics, theme adaptation and editor lifecycle; do not treat modal pop as confirmation |
| Marketplace | Cart caller checks confirmed!=true before clear. RFQ controllers/insets/submitting exist but no dirty guard in inspected file | Protect exits and unknown result, retain failures, safe error mapping and destination-owned feedback |
| Seller | Guard exists; no explicit guard-dialog lock. Schedule guard disabled during saving. Stock editor saves internally but lacks dirty guard | Reuse guard with separate dirty/pending policy and serialized exit decision; no stale pop after successful save |
| Delivery | Confirm helper coalesces null to false; _checkForDraft clears on false; report keeps one request ID, but note editable while pending and no dirty guard | Dismiss resume prompt keeps draft; explicit Start over consent; freeze report payload and protect exits |
| Associate | Payout editor is page with busy buttons but no dirty guard in inspected file; existing cancellation immediately calls server | Mark sheet proposed, protect local edits, confirm cancellation consequence; distinguish first-time setup and review submission |
| Admin | Note dialog closes before addSupportCaseNote; stable note payload request identity exists. Unlink checks true and sends expectedVersion | Retain editor on failure, safe validation/error and conflict recovery; relationship-only consequence remains exact |

## Agrimore Marketplace

**Current implementation snapshot:** confirmCartModeSwitch shows a clear-cart consequence and only clears after confirmed==true. RequestQuoteSheet owns quantity/price/notes controllers, keyboard inset padding and a disabled submitting button; it closes after createRfq returns but has no explicit dirty/PopScope guard in the inspected file. Success messaging uses the popped sheet context. Its failure path uses provider error, which can contain callable e.message.

**Target:** Preserve explicit mode-switch consent. Add consistent close/back/drag/scrim protection to an edited quote sheet, retain edits on safe failure and own outcome messaging on the destination. Sheet dismiss is never consent to clear a cart or send a quote.

**Domain character:** Professional-green buyer dialogs, warm-gold consequences, natural-stone scrims and rounded quote-request sheets.

| Panel | Specimen |
| --- | --- |
| Confirmation | Small centered dialog on a softly dimmed neutral specimen backdrop. Title "Switch order mode?". Body "Continuing clears the current cart. Orders cannot mix retail and B2B items." Two labelled OUTLINED actions "Keep cart" in app-primary and "Clear cart and continue" in semantic danger. Gold board note "Explicit consent before clearing". No cart contents, totals, or order-confirmed claims. |
| Editable sheet | Bottom-anchored rounded sheet titled "Request a quote", small caption "Form excerpt / Sample" and labelled close X. Fields "Quantity" and "Notes (optional)" with values deliberately omitted, small annotation "Values omitted in this specimen". OUTLINED "Cancel" and green PRIMARY "Send request". Clear scrolling body and footer separated from a simple labelled keyboard-clearance strip, not a detailed keyboard. Gold note "One focused task". |
| Discard protection | Dialog title "Discard quote edits?", body "Only unsent edits will be removed." Actions OUTLINED "Keep editing" in app-primary and "Discard edits" in semantic danger. Board annotation "Back / close / drag / scrim use one guard". No save-draft button or claim that a draft is already persisted. |
| Submission recovery | Two independent examples explicitly labelled "Pending variant" and "Failed variant". Pending disabled outlined control with spinner and "Sending request". Failed inline message "Request couldn’t be sent" and helper "Your edits are still here." Gold board note "Check outcome before resubmitting". No live success, percentages or blind Retry button. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Gaps and invariants:

- A dirty form needs one serialized confirmation across every exit path; current RFQ file does not implement it.
- Idle Cancel closes the edit; Discard removes unsent local edits only, never a submitted RFQ or checkout recovery journal.
- Submitting disables duplicate sends and edited payload changes; unknown result requires outcome reconciliation before retry.
- Keep safe field errors and keyboard clearance; no raw callable messages or torn-down context toast.

Source anchors:

- [market_mode_provider.dart](../../apps/marketplace/lib/providers/market_mode_provider.dart)
- [request_quote_sheet.dart](../../apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart)
- [rfq_provider.dart](../../apps/marketplace/lib/providers/rfq_provider.dart)
- [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)

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

**Current implementation snapshot:** sellerConfirm/sellerConfirmDiscard provide named route/header semantics, consequence copy and responsive action layout. SellerDiscardGuard uses PopScope; StoreSchedule uses dirty && !saving and clears dirty after confirmed save. showSellerSheet supports safe areas, keyboard-aware frame, close, scrim/drag through isDismissible. StockSheet saves inside the sheet, retains failure/input and pops true only after onSave returns true, but has no dirty/PopScope guard. Store-status sheet returns a choice; the profile caller performs the mutation afterward.

**Target:** Reuse existing guard and sheet/confirmation equivalents, extending lifecycle deliberately. Protect changed stock edits and pending saves; clear dirty only after confirmation. A separate pause-ordering confirmation makes the existing store-state consequence explicit without claiming that its modal is currently implemented.

**Domain character:** Compact blue-teal merchant confirmations, copper consequences, cool-neutral stock sheets and operational sticky footers.

| Panel | Specimen |
| --- | --- |
| Confirmation | Centered modal "Pause ordering?". Body "Customers cannot place orders while your store is paused." OUTLINED "Keep store open" in blue-teal and PRIMARY "Pause ordering" in blue-teal. Copper board note "Separate store-status example" and "Confirm before updating". No dates, pause durations, inventory change or already-paused success. |
| Editable sheet | Compact bottom sheet titled "Update stock", labelled close X, neutral product context "Sample product", field "Stock quantity" with no numeric value and small "Values omitted in this specimen". OUTLINED "Cancel" and blue-teal PRIMARY "Save stock". Scrolling body plus sticky actions with a labelled keyboard-clearance strip. No price, counts or quantity chips. |
| Discard protection | Dialog "Discard stock edit?", body "Your unsaved stock edit will be removed." OUTLINED blue-teal "Keep editing" and OUTLINED danger "Discard edit". Copper board note "Extend the existing discard guard". Do not invent product deletion or remote Undo. |
| Submission recovery | Separate "Pending variant" with disabled outlined spinner control "Saving stock" and "Failed variant" notice "Stock couldn’t be saved" with helper "Keep the entered value". Copper note "Close only after confirmed save". No stock numbers, optimistic saved tick or additional Retry mutation. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Gaps and invariants:

- SellerDiscardGuard has no explicit one-dialog-in-flight guard in the inspected implementation; test repeated back/close attempts.
- StoreSchedule passes hasChanges=false while saving, which permits leaving during an in-flight save; pending exit needs a separate policy.
- StockSheet close/scrim/drag and changed input are not guarded by the shared dirty wrapper today.
- Confirming a store-status choice closes the sheet before profile persistence; do not render chosen state as saved while the write is pending.

Source anchors:

- [seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart)
- [store_schedule.dart](../../apps/seller/lib/screens/account/store_schedule.dart)
- [store_status.dart](../../apps/seller/lib/screens/account/store_status.dart)
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

**Current implementation snapshot:** DeliveryConfirmDialog returns result ?? false and has default dialog dismissal. Registration _confirmStartOver clears local draft/staged files only after explicit true; _checkForDraft instead clears draft for any false result, including dialog dismissal. ProblemReportSheet retains reason/note on failure, closes only after backend.report returns, blocks duplicate sends and reuses one request ID per sheet. Note TextField is not disabled during sending. Modal entry has default scrim/drag dismissal and no explicit dirty guard.

**Target:** Separate local application draft reset from unsent delivery-report edits and submitted delivery work. Resume prompt dismissal keeps the saved draft; Start over is explicit consent. Report sheet protects dirty/pending state, freezes its submitted payload and reconciles uncertain outcome before reusing retry identity.

**Domain character:** High-contrast black/white field sheets, burgundy local-discard warnings, burnt-orange task scope and large labelled controls.

| Panel | Specimen |
| --- | --- |
| Confirmation | Centered danger dialog "Discard saved application?". Body "Clears the local draft and staged documents." Actions OUTLINED black/white "Keep draft" and OUTLINED burgundy "Start over". Burnt-orange board annotation "Local draft only". No withdrawal of a submitted application, submitted status, personal document image or real application ID. |
| Editable sheet | Bottom sheet "Report delivery problem", small "After-pickup form excerpt / Sample", labelled close X. Reason picker showing "Vehicle issue", empty "Notes" field, annotation "Values omitted in this specimen". OUTLINED "Cancel" and black/white PRIMARY "Send report". Footer above labelled keyboard clearance. No location, customer/address/phone, IDs or delivery outcome. |
| Discard protection | Dialog "Discard report edits?", body "Only your unsent report edits will be removed." OUTLINED black/white "Keep editing" and OUTLINED burgundy "Discard edits". Orange board note "Existing submitted reports stay unchanged". Do not confuse it with application reset, proof-photo recovery or delivery cancellation. |
| Submission recovery | Explicit independent "Pending variant" spinner disabled outlined "Sending report" and "Failed variant" burgundy notice "Report couldn’t be sent", helper "Your reason and notes are still here." Orange note "Check outcome before retry". No automatic Retry, new report IDs, success/delivered/payment badges or progress percentage. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Gaps and invariants:

- _checkForDraft treats false/null dismissal as Start over; target keeps draft on cancellation/back/scrim and asks explicitly before reset.
- Default confirm dialog return false is safe for explicit discard confirmation but not when a caller interprets false as consent to clear.
- Report note stays editable while location acquisition/submission runs; freeze captured payload while pending.
- No report dirty-route guard is evident; local discard never closes a submitted exception or reconfirms delivery.
- Retain existing same-request recovery identity; changed payload and unknown outcome need deliberate handling, not a blind new report.

Source anchors:

- [delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart)
- [rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart)
- [delivery_problem_panel.dart](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart)

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

**Current implementation snapshot:** PayoutAccountScreen is a full page with Bank/UPI edit forms, validated controllers, requestEmployeePayoutChange and _isSaving loading buttons. No PopScope/dirty guard is present in the inspected file. Existing pending-change card has Cancel Request calling cancelEmployeePayoutChange directly and only reports cancellation after await. Submission awaits the request but current copy promises admin approval. Profile already uses shared DialogHelper for confirmations.

**Target:** Illustrate a clearly proposed payout-detail sheet with protected unsubmitted edits and truthful submit-for-review lifecycle. Pending-review cancellation is a separate explicit server action, never a local discard or dialog close. Current details continue only if already configured.

**Domain character:** Premium royal-blue review-request sheets, indigo scope guidance and calm pearl/slate modal surfaces.

| Panel | Specimen |
| --- | --- |
| Confirmation | Centered confirmation "Cancel review request?". Body "Withdraws the pending details change. Current details, if set, stay in use." OUTLINED royal-blue "Keep request" and OUTLINED semantic-danger "Cancel request". Indigo board note "Pending request only". No approval/rejection/paid state or automatic cancellation on dismiss. |
| Editable sheet | Bottom sheet "Edit payout details", small "Proposed sheet / Form excerpt", labelled close X. "Payout method" picker showing "Bank transfer" and empty "Account holder" field; annotation "Values omitted in this specimen". OUTLINED "Cancel" and royal-blue PRIMARY "Submit for review". Footer above labelled keyboard clearance. No names, bank/UPI/account numbers, amounts or claim this form excerpt contains all required fields. |
| Discard protection | Dialog "Discard payout edits?", body "Only unsubmitted edits will be removed." OUTLINED royal-blue "Keep editing" and OUTLINED danger "Discard edits". Indigo board note "Current details and pending requests stay unchanged". No server Cancel request in this local-discard specimen. |
| Submission recovery | Explicit separate "Pending variant" disabled outlined spinner "Submitting for review" and "Failed variant" safe notice "Submission unavailable", helper "Your edits are still here." Indigo annotation "Check request status before resubmitting". No Approved/paid badge, blind Retry or review promise. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Gaps and invariants:

- Sheet layout is a proposal; current payout editor is a page. Keep ownership/auth and existing form validations when adapting it.
- Add local dirty guard across every exit path; do not persist sensitive payout form values to disk by default.
- Cancel Request needs a proposed consequence confirmation, existing callable conditions and pending protection.
- Submission is not approved/effective/paid; unknown outcome is checked before repeat submission.
- Keep current-destination copy conditional for first-time setup; never fabricate details, balance or review date.

Source anchors:

- [payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart)
- [profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)
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

**Current implementation snapshot:** Support unlink dialog explicitly says only the case relationship is removed and linked record unchanged; caller checks confirmed==true and passes expectedVersion to unlinkSupportCaseRecord. _promptForText returns input and closes its dialog before _addNote calls addSupportCaseNote. _noteRequestIds.forPayload(text) provides stable mutation identity. Input prompt has autofocus and a silent minimum-length gate, but no dirty guard or retained editor on backend failure. Shared DialogHelper has themed confirmation/input/sheet primitives but some fixed light styles.

**Target:** Preserve precise link-removal scope and action-specific server checks. Proposed note sheet keeps editor ownership through submission, retains input on failure and protects local draft dismissal. Note request identity differs from versioned link mutation; unknown action outcome must be reconciled before repeating.

**Domain character:** Professional-blue operational dialogs, cyan scope explanations, steel/slate dense form surfaces and precise destructive consequences.

| Panel | Specimen |
| --- | --- |
| Confirmation | Centered modal "Remove this link?". Body "Only the case relationship is removed. The linked record stays unchanged." OUTLINED professional-blue "Keep link" and OUTLINED danger "Remove link". Cyan board note "Relationship only / not record deletion". No case/record IDs, delete record action or preconfirmed removal. |
| Editable sheet | Compact bottom sheet "Add case note", caption "Proposed sheet / Sample", labelled close X. A multiline "Note" field with values omitted and small "Values omitted in this specimen". OUTLINED "Cancel" and professional-blue PRIMARY "Add note". Scrolling body/footer boundary and keyboard-clearance strip. Cyan annotation "Keep editor until confirmation". No actual notes, assignees or identifiers. |
| Discard protection | Dialog "Discard note edits?", body "Only unsent note edits will be removed. The case will not be changed." OUTLINED professional-blue "Keep editing" and OUTLINED danger "Discard note". Cyan board note "One decision for every exit path". No case deletion/resolution, server cancellation or Undo. |
| Submission recovery | Independent "Pending variant" disabled outlined spinner "Adding note" and "Failed variant" safe notice "Note couldn’t be added", helper "Your note is still here." Cyan board annotation "Check outcome before resubmitting". No silent editor closure, extra Retry mutation, Case resolved/paid badge or request IDs. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Gaps and invariants:

- Current note prompt closes before backend action; failed input is not retained in an open modal. Target retains/reopens the same safe payload deliberately.
- The input minimum-length rejection is silent; future inline validation follows C10, with no arbitrary new validation rules.
- No explicit dirty/PopScope guard in this prompt; Back/scrim/close must use the same local-discard decision.
- Unlink consent never authorizes record deletion; preserve expectedVersion and conflict recovery separately from note idempotency.
- No raw callable messages, duplicate dialogs or automatic success on modal close; no live case details/IDs in boards.

Source anchors:

- [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [dialog_helper.dart](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)

Scanned screen families (file counts, not unique screen counts):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Unchanged form, changed form, edits reverted to baseline, server refresh during editing, multiple close/back taps, nested modal and route/entity/account changes. Only one discard decision at a time.
- Every exit path: Android/predictive back, iOS gesture behavior, toolbar back, close X, Escape, scrim tap, sheet drag and deliberate route navigation. Verify actual callbacks; source comments are not platform proof. Keep editing restores field/opener focus; no unintentional dirty pop.
- Pending submission: freeze captured payload, block duplicate actions, handle timeout/unmount/navigation; no blanket canPop=true merely because saving. Avoid infinite blocking or claims that UI exit cancels backend work.
- Known failure retains values and safe inline error. Unknown outcome reconciles before replay; action-specific request identity, changed-payload handling and expectedVersion conflicts remain distinct. Confirmed success clears dirty before close.
- Cart clear consent cannot follow cancelled dialog; quote editor close never submits RFQ or discards checkout journal. No Save draft feature invented.
- Seller stock sheet close/scrim/drag and schedule-save exit; guard prompt cannot recur after confirmed save. Store-status choice is not a persisted store state.
- Delivery resume-dialog dismissal keeps saved draft; explicit Start over cleans only owned local draft/staged files. Unsent report discard does not resolve existing report, reconfirm delivery or alter proof-retry journal.
- Associate local discard leaves current destination and pending requests unchanged; explicit cancellation awaits callable. First-time setup has no fabricated current account. Sheet is proposed, not a current implementation screenshot.
- Admin note is retained on failed write; supported request identity avoids duplicates after lost reply. Removing case link never deletes linked record or resolves case.
- Render light/dark, narrow/wide, keyboard-safe sticky actions, scrolling long form, long translations/text scaling, semantic route/title, labelled close and safe focus order, actual TalkBack/VoiceOver containment/restore and reduced-motion transition. Raster cannot certify these.
- Future canonical helper changes require all five app analyzers and rendered verification. No live-account, emulator or runtime accessibility testing was performed for these design assets.

## Delivery scope and design lanes

27 new repository files: ten PNGs, five per-app README/prompts/manifest sets, two master documents. Earlier C01–C16 files are preserved. C17 is provisional; no owner approval inferred. User explicitly requested image-prompt provenance; prompts.md records image generation, not an exported implementation-worker prompt.

UIUX/feedback design review covers app identities, consequence accuracy, explicit consent, supported local/server boundaries, safe copy, modal/dirty/pending lifecycle proposals and neutral dark surfaces. Classifier lane: docs; UIUX/feedback design review voluntarily attached. Runtime gates are not applicable evidence for assets-only delivery; no Flutter analysis/emulator/live-account/runtime-accessibility checks were performed. No Dart/TypeScript/runtime source, pubspec registration, staging/commit/branch changes, deploy or other-chat interruption by this task. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: functions/src/delivery/riderMoney.ts.

## Asset verification

**PASS — asset and document integrity only.** Ten selected PNGs form five light/dark pairs. PNG headers, dimensions, chunk CRCs, copied bytes and SHA-256 hashes verified; C01 palette/status/type/spacing/radius/border metadata matches the approved locks exactly. 13 exact generation/refinement prompt blocks and 80 local document links verified. All 783 earlier design files, including C16, remain byte-identical. All selected boards were visually reviewed.

The source inventory was captured at HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33 (817 eligible source files / 271,604 lines). Concurrent work advanced HEAD to 15291767d80f99a209b9aac11c8665dc217be17c and changed `functions/src/delivery/riderMoney.ts` before packaging; that file is outside the focused C17 modal sources. These changes were observed and preserved, not modified or reverted by this design task. No inventoried source changed during packaging, and the ten observed platform configs remain unchanged since inventory. Branch remains `agrimore/foundation-f3c-distance-delivery-pricing`. No runtime, assistive-technology or pixel-exact raster certification is implied.
