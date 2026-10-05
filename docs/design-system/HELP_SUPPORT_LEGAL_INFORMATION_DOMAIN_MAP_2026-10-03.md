# Agrimore — C23 help, support and legal information: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C23 is not owner-approved; assets/docs only.

[Ten-board gallery](HELP_SUPPORT_LEGAL_INFORMATION_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: 7285db1207b2fa7219e2866a6c20de6334fc1ce5. 818 eligible files / 272044 source lines across five app lib trees, three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files were excluded. Fresh hashes and marker searches cover help/support, contact handoff, legal entries, request actions and case states. Focused semantic reads cover Marketplace older help/profile/settings/AI route and static legal screens; Seller FAQ/contact/policies; Delivery help/sheet/contact/form/list/status/model/backend and safety separation; Associate clipboard/help/FAQ; Admin settings placeholders versus real queue/case/model/server commands; shared public contact/policy configuration. Broad static inventory plus focused review is not semantic certification of every line or rendered screen.

Marker totals include comments/call sites and shared request IDs, not unique support widgets or defect counts. No live endpoint reachability, staffing, operating hours, legal approval, support ticket, contact action or production account was tested. Configured URLs and static policy copy are source evidence, not verified live/approved policy. Concurrent shared-checkout implementation is observed and preserved.

| Scope | help_support | contact_handoff | legal | request_action | case_state |
| --- | --- | --- | --- | --- | --- |
| admin | 18 | 18 | 2 | 92 | 19 |
| delivery | 25 | 28 | 4 | 48 | 18 |
| employee | 6 | 11 | 0 | 7 | 0 |
| marketplace | 5 | 23 | 12 | 66 | 0 |
| seller | 6 | 15 | 9 | 5 | 0 |
| functions | 18 | 0 | 0 | 146 | 29 |
| agrimore_core | 1 | 2 | 3 | 0 | 12 |
| agrimore_services | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 0 | 0 | 0 | 0 | 0 |

## Shared support target contract

1. Distinguish self-service FAQ, automated assistance, OS contact handoff, clipboard copy, server support ticket and admin case management; labels must match performed action.
2. Use documented configured contact sources, reconcile hardcoded conflicts and avoid sample endpoints. Configured is not verified reachable or staffed.
3. Phone/email app opening is not connection, sending, receipt or resolution. Check false returns and exceptions; provide readable recoverable failure.
4. Clipboard confirmation only after successful awaited write. Copy is not a phone/email launcher or contact event.
5. Keep search/filter/expand behavior functional or clearly proposed; missing FAQ matches are not support unavailability.
6. No fake ticket, bug report, live-agent availability, operating-hour/SLA, refund/settlement/fee or legal assurance from a static card.
7. Support requests use server identity/current owner and action payload; preserve idempotency and distinguish unchanged retry versus edited new request. Widget-lifetime IDs are not durable offline queues.
8. After upload/submit/read/confirmation, current account/session/entity/route ownership must still hold. Sensitive attachments are optional; removal UI does not certify deletion or secure storage.
9. Rider Submitted/Seen/Closed differs from administrative Open/In progress/Waiting/Resolved; workflow closure is not business settlement.
10. Routine help and emergency/safety actions remain separate. Dialer handoff does not notify support, share location or dispatch emergency help.
11. Policy entries require authoritative approved content/source/version; do not invent effective dates, consent state, compliance or blanket privacy guarantees. Internal versus external destination icons must reflect supported route.
12. Proposed legal entries for Delivery/Associate require confirmed destination; Admin settings placeholder help actions need real implementation. Do not clone every support feature across apps.
13. Readable headings, labelled external handoffs, target sizes, focus/announcements, text scaling and dark contrast require later runtime checks. Raster boards are target specimens, not certified live services.

## App-specific support capabilities

| App | Current support model | Current contact / policy behavior | Target emphasis |
| --- | --- | --- | --- |
| Marketplace | Inert older help screen; /support opens automated AI assistant | Profile/settings real mailto at hardcoded address; internal static terms/privacy screens | Functional help topics; label AI automated; reconcile contact source; confirm legal content/version |
| Seller | Searchable local FAQ, no ticket UI evidenced here | Configured tel/mailto/browser URLs; false launcher result ignored, exceptions logged | Preserve FAQ; honest handoff and visible launch failure; external legal indicators |
| Delivery | Server requests, persistent own list and Submitted/Seen/Closed detail | Configured call/email with launch failure; separate emergency sheet; no legal entry found here | Request acknowledgement and recovery; preserve safety boundary; legal access proposed |
| Sales Associate | Local FAQ/static-hours copy; no support ticket UI evidenced | Contact labels imply Call/Email but actions only copy; clipboard write not awaited; no legal entry here | Accurate Copy labels and acknowledged failure feedback; canonical FAQ review; legal access proposed |
| Admin | Admin-only operational support cases plus distinct rider support records | Settings copied/docs/bug success are snackbar-only placeholders; static legal dialog | Keep operational case/audit system separate; wire genuine internal help and confirmed legal sources |

## Contact and destination truth

| Action | What source evidence supports | What the UI must not infer |
| --- | --- | --- |
| Configured support values | AppConstants has phone/email and policy URLs; Seller/Delivery use them | Reachable/staffed contact, response time, live service or approved policy |
| Marketplace hardcoded mailto | Profile/settings launch real email composition; older HelpScreen has different sample inert contacts | That all support entry points already share one authoritative address |
| Phone/email launcher | OS application handoff can return false or throw | Call connected, email sent, staff notified, ticket created or issue resolved |
| Associate clipboard | Clipboard.setData invoked, snackbar shown before await | Phone app opened, contact reached or clipboard write definitely succeeded |
| Admin settings help | Only snackbar messages; no clipboard/guide launch/bug submission in inspected handlers | Copied contact, open documentation or submitted bug |
| AI assistant | Marketplace AIChatScreen and AI-service processUserMessage | Human agent, ticket tracking, human escalation or binding policy advice |
| Legal links | Marketplace internal screens; Seller configured browser URLs | Current approved text, effective date, consent or compliance certification |
| Delivery/Associate legal group | No entry evidenced in inspected help/profile surfaces | Implemented legal route or known browser/internal destination |

No contact endpoints are printed in the generated specimens. Channel labels and source references document genuine capabilities while avoiding copied sample phone/email values. Reconciliation of Marketplace hardcoded versus shared support configuration is an OPEN_DECISION for later implementation. No real contact was attempted.

## Domain-by-domain systems

### Agrimore Marketplace

**Current source:** Older HelpScreen search has no filter/controller handler; FAQ/shipping/payment/contact/privacy taps are comments only and include sample contacts. Profile/settings have real mailto support actions at a hardcoded .in address, distinct from shared AppConstants email. /support is AuthGuard AIChatScreen, an automated assistant, not a human ticket desk. TermsScreen/PrivacyPolicyScreen are internal static documents with hardcoded December 2024 dates and substantial policy assertions; presence is not proof these are current approved legal text.

**Target:** Propose functional topic discovery, preserve real email-app handoff with honest failure, label AI help automated, and show readable internal legal-document entries without inventing approved terms or dates.

| Panel | Domain specimen |
| --- | --- |
| Shopper help discovery | Card "Find help", EMPTY search field labelled "Search help", two neutral topic rows "Orders and delivery" and "Payments and returns" with outline icons/chevrons. Gold BOARD note "Search and topic routing proposed". No answers, counts or policy promise. |
| Email support handoff | Card "Contact support", PRIMARY "Open email app" and small "Compose your message in your email app." Separate SMALL failure specimen "Could not open the email app" with SECONDARY "Try again". Gold BOARD note "Opening an app does not send a message". No contact address, sent toast, ticket, human-agent availability or telephone action. |
| Automated help boundary | Card "Automated help", generic sparkle/chat outline icon, body "Ask the Agrimore assistant." SECONDARY "Open assistant". Gold BOARD note "Automated assistance / not a human support case". Empty chat preview, no human avatar, live agent, answer, refund/approval promise or escalation ticket. |
| Internal policy documents | Card "Legal information", two rows "Terms and conditions" and "Privacy policy", document outline icons, internal chevrons (NO external-link icon). Small "Read in the app". Gold BOARD note "Document text and version need confirmation". No actual legal paragraphs, date, accepted/consented tick or compliance badge. |

Preserve or resolve:

- Unify contact source deliberately: shared configured email and existing profile hardcoded address differ; no new sample endpoints.
- Older help search/topic/contact links are target fixes, not working features. AI assistance is not human escalation or case submission.
- Policy text/date must be reconciled with owner-approved documents; do not reproduce blanket liability/return/deletion assurances.

Sources:

- [apps/marketplace/lib/screens/user/help/help_screen.dart](../../apps/marketplace/lib/screens/user/help/help_screen.dart)
- [apps/marketplace/lib/screens/user/profile/profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart)
- [apps/marketplace/lib/screens/user/profile/settings_screen.dart](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart)
- [apps/marketplace/lib/app/routes.dart](../../apps/marketplace/lib/app/routes.dart)
- [apps/marketplace/lib/screens/chat/ai_chat_screen.dart](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart)
- [apps/marketplace/lib/screens/legal/terms_screen.dart](../../apps/marketplace/lib/screens/legal/terms_screen.dart)
- [apps/marketplace/lib/screens/legal/privacy_policy_screen.dart](../../apps/marketplace/lib/screens/legal/privacy_policy_screen.dart)
- [packages/agrimore_core/lib/constants/app_constants.dart](../../packages/agrimore_core/lib/constants/app_constants.dart)

### Agrimore Seller

**Current source:** Seller HelpScreen filters six local translated FAQs by question/answer, announces nonempty-query count and has empty result state. SellerSupportCard uses AppConstants tel/mailto external launcher; it awaits but ignores false results and only logs exceptions. SellerPoliciesScreen shows local rules and configured terms/privacy external URLs, similarly ignores false return. No merchant ticket submission/tracking UI evidenced in inspected help.

**Target:** Preserve searchable local FAQ and genuine phone/email handoffs; add visible launch failure/retry and truthful browser legal entries. Do not fabricate ticket tracking or send acknowledgement.

| Panel | Domain specimen |
| --- | --- |
| Merchant FAQ discovery | Card "Seller help", EMPTY "Search FAQs" field and two collapsed accordion rows "Orders and quotes" and "Payout account" with clear expand chevrons. Copper BOARD note "Search local questions and answers". No result counts, money, FAQ answer or guaranteed payout timing. |
| Configured contact actions | Card "Contact Agrimore", PRIMARY "Open phone app", SECONDARY "Open email app". Below "Continue in your phone or email app." Copper BOARD note "Configured contact / external handoff". No raw phone/email, live-chat icon, sent/connected confirmation or new ticket. |
| Contact launch recovery | Card "Could not open the phone app", body "Try opening it again." SECONDARY "Try again". Copper BOARD note "Visible failure feedback proposed". No app-opened/call-connected/copied/sent success tick. No different invented channel. |
| Merchant legal documents | Card "Policies and legal", two rows "Terms and conditions" and "Privacy policy", document icons and SMALL external-link symbols; "Opens in your browser". Copper BOARD note "Configured policy links / availability to verify". No raw URL, legal paragraph, dates, consent checkbox, refund/fee promise or compliant badge. |

Preserve or resolve:

- Launcher bool false and exceptions need readable feedback; opening phone/email is not call connection/message send.
- Shared contact values are configured in code, not validated live reachable by this task.
- External policy location is not proof approved/current content; do not invent operating hours or payout/refund SLA.

Sources:

- [apps/seller/lib/screens/account/help_screen.dart](../../apps/seller/lib/screens/account/help_screen.dart)
- [apps/seller/lib/screens/account/widgets/support_card.dart](../../apps/seller/lib/screens/account/widgets/support_card.dart)
- [apps/seller/lib/screens/account/policies_screen.dart](../../apps/seller/lib/screens/account/policies_screen.dart)
- [packages/agrimore_core/lib/constants/app_constants.dart](../../packages/agrimore_core/lib/constants/app_constants.dart)

### Agrimore Delivery

**Current source:** Help screen/home sheet expose delivery issue, earnings/payouts, account/documents topics, My requests, support call and separate emergency sheet. Profile has configured phone/email launcher with false/exception feedback. SubmitSupportRequestScreen validates message, optional uploaded photo and reuses widget-lifetime request ID; no related-order/statement picker ships. Request list persists server tickets, newest client sort, explicit loading/error/retry/empty; detail has Submitted/Seen/Closed and closure note. Backend permits registered suspended riders, server identity and idempotent existing-ticket return; existing ID replay does not compare changed payload. Client submit/upload uses mounted checks, not explicit owner/episode tickets. No legal entry found in inspected help/profile surfaces.

**Target:** Preserve real support request/list/status flow and separate immediate-safety entry from routine support. Add ownership/payload-aware retry discipline and proposed legal entries tied to confirmed documents; no new chat, SLA or automatic emergency dispatch.

| Panel | Domain specimen |
| --- | --- |
| Rider support request | Card "Request support", category row "Delivery issue", EMPTY multiline field labelled "Message", SECONDARY "Add attachment"; DISABLED neutral "Submit request", explanation "Add a message before submitting". Orange BOARD note "Registered rider request / server acknowledgement". No attachment photograph/name, ID, related-record picker or success. |
| Request tracking vocabulary | Card "My support requests", generic request row "Delivery issue", EMPTY message skeleton, secondary "View request". Separate neutral legend labelled "Status vocabulary" with "Submitted", "Seen", "Closed" (NO ticks or progressing timeline). Orange BOARD note "Request state is not a delivery or payout outcome". No real status/date/ID/count/closure claim. |
| Routine and urgent help | Card "Contact support", SECONDARY "Open phone app" and "Open email app". Separate burgundy-outline row "Emergency help"; small "Routine support and urgent safety are separate". Orange BOARD note "Handoff does not alert anyone". No emergency number, call-connected/sent/location-shared claim or panic animation. |
| Rider legal information | Card "Legal information", two document rows "Terms and conditions" and "Privacy policy". Orange BOARD note "Proposed legal entry / confirm policy source". No external-versus-internal destination icon or body claim until source confirmed; no dates, consent, compliance, retention or insurance promise. |

Preserve or resolve:

- Widget-lifetime retry ID is not disk draft/queue. Backend existing-ID replay returns prior ticket without checking edited payload; changed request needs deliberate new-action policy.
- Attachment uploads happen on pick; remove UI does not prove server file deleted. Do not promise protected storage or automatic cleanup.
- Seen/Closed do not mean delivery completed, payout settled or incident resolved. Emergency dialer handoff is not location sharing/alert sent.
- Legal entries are proposed here; related record picker is not implemented and must not appear as live control.

Sources:

- [apps/delivery/lib/screens/support/help_support_screen.dart](../../apps/delivery/lib/screens/support/help_support_screen.dart)
- [apps/delivery/lib/screens/support/help_sheet.dart](../../apps/delivery/lib/screens/support/help_sheet.dart)
- [apps/delivery/lib/screens/support/submit_support_request_screen.dart](../../apps/delivery/lib/screens/support/submit_support_request_screen.dart)
- [apps/delivery/lib/screens/support/my_support_requests_screen.dart](../../apps/delivery/lib/screens/support/my_support_requests_screen.dart)
- [apps/delivery/lib/screens/support/support_request_status_screen.dart](../../apps/delivery/lib/screens/support/support_request_status_screen.dart)
- [apps/delivery/lib/support/rider_support.dart](../../apps/delivery/lib/support/rider_support.dart)
- [apps/delivery/lib/account/support_card.dart](../../apps/delivery/lib/account/support_card.dart)
- [apps/delivery/lib/safety/emergency_sheet.dart](../../apps/delivery/lib/safety/emergency_sheet.dart)
- [functions/src/delivery/riderSupport.ts](../../functions/src/delivery/riderSupport.ts)
- [packages/agrimore_core/lib/constants/app_constants.dart](../../packages/agrimore_core/lib/constants/app_constants.dart)

### Agrimore Sales Associate

**Current source:** Associate HelpSupportScreen local FAQ and static operating-hours card. Contact cards labelled Call/Email actually only copy configured values; no dialer/email launcher. Clipboard.setData is not awaited before copied snackbar. FAQ has hardcoded onboarding fee and unconditional attribution/payout claims; these must not become current product/financial policy merely from text. No support-ticket journey or legal links evidenced here.

**Target:** Use accurate Copy phone number/Copy email address labels and acknowledged/failed clipboard feedback; keep associate-specific FAQ categories without copied financial promises. Propose a legal-document group once source is confirmed; do not invent working call, human chat or payout case tracking.

| Panel | Domain specimen |
| --- | --- |
| Associate help topics | Card "Associate help", two collapsed FAQ rows "Order attribution" and "Payout account changes" with outline icons/expand chevrons. Indigo BOARD note "Domain answers need canonical review". No fee/commission/balance, full answer, fixed support hours or availability badge. |
| Honest clipboard contacts | Card "Support contact details", PRIMARY "Copy phone number", SECONDARY "Copy email address". Below "Paste into your phone or email app." Indigo BOARD note "Copy only / no call or message sent". No phone/email values, fake live chat or direct Call button. |
| Clipboard failure recovery | Card "Could not copy contact details", body "Try copying again." SECONDARY "Try again". Indigo BOARD note "Proposed feedback after clipboard result". No Copied checkmark/toast without successful operation; no ticket submission/status or new contact. |
| Associate policy access | Card "Legal information", two document rows "Terms and conditions" and "Privacy policy". Indigo BOARD note "Proposed legal entry / confirm policy source". No browser/internal destination assertion yet, accepted-consent tick, hardcoded fee, compliance/privacy/earning guarantee or date. |

Preserve or resolve:

- Copy is not calling, email composition or sending. Await actual clipboard success before announcing it.
- Hours are static copy, not verified live support availability; omit operating-hour/SLA promises from boards.
- Fee/commission/payout FAQ text needs canonical domain review before reuse; no hardcoded financial amount or eligibility guarantee.

Sources:

- [apps/employee/lib/screens/support/help_support_screen.dart](../../apps/employee/lib/screens/support/help_support_screen.dart)
- [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [packages/agrimore_core/lib/constants/app_constants.dart](../../packages/agrimore_core/lib/constants/app_constants.dart)

### Agrimore Admin

**Current source:** Real SupportQueueScreen filters all/status or mine (not composed mine+status) and opens/create cases; detail uses admin-only callables for assignment/status/note/resolve/reopen/link. Server optimistic version checks for changes, dedicated resolution summary, atomic command events, payload-aware idempotency for create/note; client caller mostly mounted/busy checks, raw callable messages remain. Settings help Email copied has no Clipboard call; Documentation only snackbar; Bug report submitted is unconditional success without submission. Settings legal dialog contains static unverified terms/privacy assurances. Rider-ticket admin management is a distinct operational record system, not identical support_cases status.

**Target:** Design operational queue/case review separately from internal administrator help. Preserve real case records/audit mutations; propose genuine internal contact/guide actions and readable failure, and confirmed policy sources without fabricated bug submission.

| Panel | Domain specimen |
| --- | --- |
| Operational support queue | Card "Support queue", two filter chips "All" selected and "My cases" unselected, EMPTY neutral case rows, PRIMARY "Create case". Cyan BOARD note "Administrative cases / authorised access". No actor names, IDs, case count, customer contact or inbox receipt. |
| Case review and activity | Card "Case workspace", EMPTY case-title skeleton, SECONDARY "View case"; separate neutral legend labelled "Case status vocabulary": "Open", "In progress", "Waiting", "Resolved". Cyan BOARD note "Case resolution is not financial settlement". No current resolved checkmark, real note, audit timestamp, refund, payment action or rider-status substitution. |
| Genuine internal help | Card "Administrator help", SECONDARY "Open email app", neutral outline row "Administrator guide". Cyan BOARD note "Proposed genuine actions / settings placeholders today". No raw URL/email, Bug report submitted, copied/sent toast, live contact or guaranteed guide availability. |
| Administrative legal reference | Card "Legal reference", two document rows "Terms and conditions" and "Privacy policy". Cyan BOARD note "Confirm authoritative documents and version". No real legal clauses/date, compliance/encryption/sharing guarantee, accepted consent, fabricated external destination or legal-signoff badge. |

Preserve or resolve:

- Support-case resolution is workflow state, not refund, payout, delivery completion or recipient communication.
- Queue filter mine versus status is mutually selected; do not claim combined filter without implementation.
- Settings contact/documentation/bug actions are placeholders; target actions must open/copy/submit only when actually wired.
- Rider Submitted/Seen/Closed differs from admin Open/In progress/Waiting/Resolved; do not merge schemas or expose admin-only case notes to other apps.

Sources:

- [apps/admin/lib/screens/admin/support/support_queue_screen.dart](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart)
- [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [apps/admin/lib/screens/admin/support/support_case_constants.dart](../../apps/admin/lib/screens/admin/support/support_case_constants.dart)
- [apps/admin/lib/screens/admin/settings/admin_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart)
- [apps/admin/lib/screens/admin/delivery/rider_support_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart)
- [functions/src/admin/supportCases.ts](../../functions/src/admin/supportCases.ts)
- [functions/src/delivery/riderSupport.ts](../../functions/src/delivery/riderSupport.ts)

## Support request and case semantics

| System | Observed state/action | Implementation boundary |
| --- | --- | --- |
| Rider request | Submitted / Seen / Closed with server timestamps and closure note | Request workflow only; Closed is not delivery completion/payout settlement |
| Rider retry | Fixed widget-lifetime request ID; backend existing ID returns existing ticket | Same logical retry preserves ID; changed message/category requires explicit new-action handling; no persisted offline queue claimed |
| Rider attachment | Optional photo uploaded on pick, path submitted; removal clears local field | No deletion/cleanup/security guarantee or related-record picker invented |
| Rider access | Server authenticates and requires registered rider, including suspended rider | No promise every gated app route is reachable while restricted; keep help access consistent with app access presentation |
| Admin case | Open / In progress / Waiting / Resolved; dedicated resolve summary; reopen command | Case workflow does not execute refund/payment or notify affected user merely by existing |
| Admin mutations | Admin-only callable authorization, version checks, payload-aware create/note IDs and atomic events | Preserve server authority; add current owner/route feedback and readable error mapping in client |
| Admin versus rider | Admin support_cases and rider_support_tickets are separate records/vocabularies | Link and review only allowed records; do not globally relabel or expose private internal notes |
| Routine versus safety | Delivery help sheet has separate emergency sheet/report paths | OS dialer handoff is not emergency alert, location sharing or dispatch guarantee |

The generated request/case states are neutral vocabulary specimens. No real request was submitted, marked seen, closed, resolved, assigned or linked. Delivery empty request form deliberately disables Submit request and explains the missing message. Routine contact launch failure and clipboard failure are independent Storybook examples, not actual operations that failed in this task.

## Legal presentation scope

C23 designs access and reading hierarchy only. Static December 2024 labels, existing legal paragraphs, fee statements, operating hours and privacy/encryption assertions were not adopted as approved policy. Delivery/Associate legal entries are proposed and require confirmed source/routes; Admin authoritative documents/version remain to confirm. Seller external indicators and Marketplace internal indicators follow inspected implementations. No invented terms, return deadlines, refund entitlement, liability, legal compliance, data retention, consent or approved-date claims appear in these assets. This is design documentation, not legal advice or legal approval.

## Future implementation verification

- Every help entry point opens the intended domain action: topic/search filter, FAQ expand, assistant, OS phone/email handoff, clipboard, own request list, case workspace or policy document. No inert control or mislabelled action.
- Configured contacts versus hardcoded conflicts; invalid URI, false launch, thrown exception, unavailable app, canceled OS composition and route return. No success before actual supported acknowledgement; launching does not send/connect.
- Await clipboard write, failure/duplicate taps/current route and accessible feedback; no copied toast after failure/account replacement. Admin placeholder contact/docs/bug actions need real destinations and submission service before success copy.
- FAQ empty query/no match, local translated question/answer matching, text scale/focus and canonical domain answer review. Remove stale hardcoded fees, unconditional payout/attribution promises and unverified support availability.
- Rider request message/category validation, optional attachment upload/cancel/remove/failure, same payload replay after lost response versus edited payload, duplicate-submit guard, owner change during upload/submit and current-route acknowledgement. No invented related-record picker, persistence or offline queue.
- Rider list/loading/empty/error retry, missing/forbidden ticket unavailable, valid timestamps and owned by-ID navigation; Submitted/Seen/Closed vocabulary and closure note source. No ticket closure becomes business outcome. Suspended registered support access must agree with app gating.
- Admin authorization, version mismatch, assign/status/resolve/reopen/note/link commands, real actor/record permissions, payload-aware retry and atomic audit event. Raw callable errors need readable mapping; old-owner feedback must be suppressed. Case notes remain internal.
- Policy route versus browser indicator, confirmed authoritative document/version, missing/unreachable/unknown source, large-text reading and state restoration. No fake acceptance, last-updated date or invented compliance promise.
- Safety/routine separation, dialer launch failure/cancel and supported incident-report acknowledgement; no notified/location-sent claim from opening a sheet/phone app. No real emergency call is made by asset verification.
- All five light/dark systems with narrow/wide layouts, labelled targets, focus restoration, screen-reader headings/announcements, reduced motion and actual TalkBack/VoiceOver. Raster assets do not certify contrast/accessibility/routing/security or service availability.
- Later runtime implementation needs targeted meaningful tests and applicable analyzers. This design task ran no Flutter runtime/emulator/analyzer, live contact, clipboard, ticket mutation, production support action or legal-policy certification.

## Delivery scope and design review

27 new files: ten PNGs, five per-app README/prompts/manifest sets and two master documents. C01–C22 and repeated existing C16 are preserved. C23 is provisional, owner approval pending. Classifier: docs; voluntary UIUX/feedback review covers locked identities, genuine action labels, truthful support states and legal-source boundaries.

Only this task’s design assets/docs are written. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption by this task. Concurrent shared-checkout implementation is observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset integrity check

First post-packaging validation snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs. PNG chunk checksums, copied-output hashes, 11 exact prompt blocks, reference-input hashes, approved C01 token metadata and 91 local document links passed. Exactly 27 new repository files; all 945 earlier design files remained byte-for-byte intact.

Delivery light had one focused copy refinement to remove a misleading phone-handoff explanation and use generic request status definitions; its dark board references that selected refinement. Sales Associate dark was retried after an earlier preview lacked a usable saved artifact; the final successful image and exact prompt are recorded. All ten selected images received visual review.

Snapshot HEAD: f88101beab79e2181013af45e61c0898782b14a0; inventory HEAD: 7285db1207b2fa7219e2866a6c20de6334fc1ce5; branch: agrimore/foundation-f3c-distance-delivery-pricing. No indexed source changes were observed between inventory and packaging. No additional indexed source changes were observed during this first packaging/check snapshot. Platform configuration hashes matched the inventory. This records a point in time, not a guarantee that the other chat or HEAD stops advancing.

Scope: design assets/docs only. Integrity checks and visual review do not certify pixel-exact tokens, runtime rendering, accessibility, security, contact reachability, support availability, message sending, request resolution or legal approval. C23 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.
