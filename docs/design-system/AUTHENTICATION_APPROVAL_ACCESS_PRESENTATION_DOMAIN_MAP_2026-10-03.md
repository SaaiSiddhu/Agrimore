# Agrimore — C18 authentication, approval and access presentation: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C18 is not owner-approved and does not alter runtime authentication or authorization.

[Ten-board gallery](AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: a803a9d1866477ac621be50a9a3d3de1a2fa0800. 818 eligible files / 271696 source lines across five app lib trees, three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files were excluded. Files were hashed and indexed; focused semantic reads covered authentication providers, actual sign-in/OTP/reset screens, app gates/routers, pending and restricted screens, shared AuthService and role-claim/role-change boundaries. This does not mean every line was semantically audited or every screen rendered. Backend/services are static context, not live authorization or security certification.

Marker counts include comments/calls and are neither unique components nor defect counts. Missing named markers do not prove feature absence. All findings below are local-source observations, not live-user status. Concurrent implementation may advance HEAD and source while this design task runs.

| Scope | email_signin | phone_verification | google_identity | password_reset | access_status | session_ownership |
| --- | --- | --- | --- | --- | --- | --- |
| admin | 3 | 0 | 3 | 3 | 50 | 24 |
| delivery | 1 | 0 | 0 | 6 | 23 | 25 |
| employee | 1 | 11 | 0 | 3 | 8 | 13 |
| marketplace | 2 | 14 | 8 | 2 | 7 | 38 |
| seller | 3 | 6 | 2 | 3 | 37 | 10 |
| functions | 0 | 44 | 3 | 0 | 35 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 6 | 0 |
| agrimore_services | 2 | 12 | 7 | 2 | 4 | 21 |
| agrimore_ui | 0 | 0 | 0 | 0 | 0 | 0 |

## Shared target access contract

1. Authenticate identity separately from profile completion, app-role membership and approval status. Authentication never self-approves operational access.
2. Use only existing app authentication methods. Do not invent MFA, forced email verification, invitation, admin self-registration or phone OTP for Delivery/Admin.
3. Represent signed out, identity verification, checking access, incomplete profile, pending review, rejected, suspended/deactivated, denied role and failed access read separately where supported.
4. Indeterminate checking never claims an approval percentage or ETA. Failed lookup means unknown access, not confirmed rejection, suspension or missing application.
5. Pending review explains the affected workspace, supported actions and no guaranteed result. Refresh is a read; resubmission is a distinct permitted mutation.
6. Suspension is not pending, rejection, sign-in lockout or offline status. Show safe reason only if authorised and present; do not invent appeal or unlock actions.
7. Only existing rejection/pending correction paths can expose application editing. Suspended/deactivated users cannot regain work access by editing locally.
8. Verification fields omit sensitive sample values. Runtime handles paste/autofill, secure password visibility semantics, change-number, safe errors and server-governed resend/cooldown.
9. Async operations retain account/route ownership, block duplicate taps and ignore stale results after sign-out or account change. No old-user profile or protected-shell flash.
10. Accessible headings, labelled inputs/actions, live checking/error announcements and focus recovery are target requirements needing rendered AT tests; raster is not proof.
11. Return to an authorised intended destination only after the actual profile and access checks. Back never grants access or silently submits an application.
12. Reuse shared AuthService and existing app gate/feedback/design equivalents; migrate presentation deliberately without weakening backend/rules authorization.

## Per-app methods and access boundaries

| App | Identity methods in inspected screens | Separate app access requirement | Supported review/restriction actions |
| --- | --- | --- | --- |
| Marketplace | Phone OTP; Google resolution with phone-linking when needed | Profile completion at cold-start and post-auth; protected-feature gate; no normal buyer approval queue | Phone change/resend under availability; profile completion; feature sign-in/back |
| Seller | Phone OTP; Google resolution; email/password alternative and password reset | SellerAccess decisions from user/seller/application records, including legacy approval cases | Pending: Check status/support/sign-out; rejected: reopen correction; suspended: support/sign-out |
| Delivery | Email/password; password-reset email | Rider profile, delivery-partner role and operable KYC; read failure and missing registration distinct | Pending/rejected: edit application; suspended/deactivated: no resubmit; support/sign-out |
| Sales Associate | Phone OTP; email/password and password reset | Employee role plus employees record and approved status | Pending/suspended: Contact Support/sign-out; no new in-app Apply or Check status action |
| Admin | Email/password; Google; password-reset email | Admin role after owned user-profile read; non-admin is refused and signed out | Existing sign-in after denial; proposed read retry calls restoreSession, never role mutation |

## State presentation policy

| State | User presentation | Boundary |
| --- | --- | --- |
| Signed out | Supported credentials/provider options; explicit input labels | No privileged content or forced new authentication method |
| Phone verification | Code input, safe error, change-number and server-allowed resend | Only apps with actual OTP; no code/phone samples or fabricated timer |
| Checking access | Indeterminate labelled progress; hide restricted workspace | Identity success is not role approval; no fake completion percentage |
| Profile incomplete | Explain required profile task and continue through real form | Marketplace profile completion is not merchant review |
| Pending review | Explain affected workspace; supported status read/edit/help/sign-out | No approval guarantee, ETA, earning promise or duplicate application |
| Rejected | Safe reason when authorised; existing correction path only | Distinct from suspension and failed lookup; no invented appeal |
| Suspended/deactivated | Explain unavailable work; existing help/sign-out | No self-unlock, go online, edit-to-activate or operational CTA |
| Role denied | Safe refusal; existing sign-in/other-account route | Admin non-role refused; no Apply/Invite/Approve action invented |
| Access read failed | Explain account check unavailable with proposed safe read recovery | Unknown state is not absent application, rejection or suspension |
| Sign-in temporarily throttled | Safe availability explanation from actual response | Not a suspended account; no invented timer or unblock mechanism |

## Verified presentation gaps

| Area | Current local evidence | Target presentation |
| --- | --- | --- |
| Marketplace | AuthWrapper and PostAuthRouter are separate profile-completion checkpoints. AuthGuard is mobile passthrough/web gate; AuthGate protects individual features | Preserve checkpoints and route-specific behavior; normal buyer has no approval state; verify protected destination and return behavior |
| Seller | Access-read exception sets network error and SellerAccess.noApplication | Distinct unresolved access/read recovery; do not encourage application creation from unknown status |
| Delivery | ProfileUnavailable is separate from missing records; canResubmit only pending/rejected | Keep unavailable lookup distinct from review; suspended/deactivated cannot edit-to-unlock |
| Associate | Gate matches display strings for suspended/pending; provider treats other non-approved statuses as pending; copy promises immediate activation | Propose typed access presentation preserving authorization; avoid invented rejected-state mapping or immediate activation/earnings promise |
| Admin | Non-admin profile refused and signed out; profile read failure has separate error; restoreSession exists | Role-denial and failed-read recovery separate. Try again is a proposed presentation for existing read, not current screenshot or provisioning |
| Shared | AuthService owns email, Google and phone flows; custom role claims are separate from UI checks | Reuse canonical auth/gate/feedback equivalents; no new helper or app-role folder implementation in this assets task |

## Agrimore Marketplace

**Current implementation:** LoginScreen has phone entry/OTP entry and Google linked-identity resolution, including phone verification for an unlinked Google identity. AuthWrapper and PostAuthRouter separately enforce profile completion at cold start and immediate post-auth routing. AuthGate wraps individual protected features; AuthGuard is web-only and mobile passthrough. Public landing and the unguarded main-route entry exist, but this is not proof of unrestricted anonymous purchase or identical guest flows on every platform. Seller/associate application approval in the buyer app belongs to those roles, not normal shopper access.

**Target:** Illustrate phone/Google sign-in, genuine phone-code verification, profile completion and a protected-feature sign-in prompt. Do not add buyer approval or suspension workflow without authoritative support. Preserve session ownership and the intended destination without promising a currently implemented return-to-feature route.

**Domain design:** Welcoming professional-green buyer forms, warm-gold guidance, natural-stone surfaces and generous rounded profile cards.

| Panel | Specimen |
| --- | --- |
| Sign-in | Card title "Sign in to Agrimore", empty "Mobile number" field, green PRIMARY "Send code", OUTLINED "Continue with Google". Small warm-gold note "Google may require phone verification". No email/password form, guest button or shopper approval badge. |
| Phone verification | Card "Verify your mobile", six EMPTY code boxes, no phone/code values. PRIMARY "Verify code", OUTLINED "Change number". Small separate Failed variant notice "Code not accepted" / "Check the code and try again." Resend code appears as a secondary text option with note "When available"; no fabricated countdown or channel promise. |
| Profile completion | Card "Complete your profile", small "Form excerpt", EMPTY "Name" field, PRIMARY "Continue". Natural-stone notice "Finish your profile to continue"; warm-gold board annotation "Profile completion, not approval". No invented submitted/approved state or claim this excerpt includes every required field. |
| Protected feature | Protected-feature card "Sign in to view your orders", lock icon, body "Your order history is available after sign-in." PRIMARY "Sign in", OUTLINED "Back". Separate gold annotation "Protected action / not an approval queue". Do not depict shopper suspension, seller KYC or a confirmed order. |

Gaps and preserved boundaries:

- Keep phone verification distinct from profile completion and role applications; normal buyer access does not require seller approval.
- Profile form is an excerpt, not the complete required-field contract. Current cold-start and immediate routing checkpoints must stay consistent.
- Public/guest behavior is route/platform-specific; no new Continue as guest button is invented.
- Use safe verification failure/rate-limit copy, backend-allowed resend and clear change-number action; never render test codes or real phone values.
- Return-to-intended-feature behavior needs explicit implementation verification; current feature redirect argument alone is not proof of automatic return.

Source anchors:

- [login_screen.dart](../../apps/marketplace/lib/screens/auth/login_screen.dart)
- [auth_wrapper.dart](../../apps/marketplace/lib/screens/auth/auth_wrapper.dart)
- [post_auth_router.dart](../../apps/marketplace/lib/screens/auth/post_auth_router.dart)
- [auth_guard.dart](../../apps/marketplace/lib/screens/auth/auth_guard.dart)
- [auth_gate.dart](../../apps/marketplace/lib/widgets/auth_gate.dart)
- [routes.dart](../../apps/marketplace/lib/app/routes.dart)
- [auth_provider.dart](../../apps/marketplace/lib/providers/auth_provider.dart)

Scanned screen families (file counts, not unique screen count):

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

**Current implementation:** SellerSignInScreen owns phone-code entry, Google phone-linking and email alternative. SellerAccess maps signedOut/loading/noApplication/draft/pending/rejected/suspended/approved to distinct routes. ApplicationStatusScreen has Check status, support and sign-out. Rejected accounts can reopenAfterRejection; suspended accounts have support/sign-out, not Fix and resubmit. Access-read exceptions set network error but route to noApplication; that read-failure presentation needs a distinct recovery state. resolveSellerAccess permits legacy seller role with null status, so the target cannot claim every current seller passed an explicit review.

**Target:** Preserve existing sign-in options and access decisions while separating unresolved read failure from genuinely missing application. Show pending application without ETA or guaranteed approval; suspension does not offer application resubmission. Rejected correction is a separate existing path, not a suspension unlock.

**Domain design:** Compact blue-teal merchant identity panels, copper application context, cool-neutral review surfaces and clear operational restriction cards.

| Panel | Specimen |
| --- | --- |
| Sign-in | Card "Seller sign-in", EMPTY "Mobile number", PRIMARY "Send code", OUTLINED "Continue with Google", text action "Use email instead". Copper note "One identity, separate seller access". Do not invent admin invitation or forced email verification. |
| Phone verification | Card "Verify your mobile", six EMPTY code boxes, PRIMARY "Verify code", OUTLINED "Change number". Small notice "Phone verification does not approve your application"; separate Failed variant "Code not accepted". No phone values, code digits or timer. |
| Application review | Application card "Application under review", labelled steps "Submitted" with check, "Under review" highlighted, "Approval decision" upcoming neutral hollow marker (NOT checked). PRIMARY "Check status", OUTLINED "Contact support", text "Sign out". Copper guidance "Review does not guarantee approval". No date, percentage, approval promise or submit-again. |
| Suspension | Restriction card "Seller account suspended", shield-alert icon and semantic warning notice "Your seller workspace is unavailable." OUTLINED "Contact support" and "Sign out". Copper annotation "Suspension is separate from rejection". Small distinct text note "Rejected application: Fix and resubmit is a separate flow" without a resubmit button in suspended card. No unblock, reopen store, order-taking or self-approval action. |

Gaps and preserved boundaries:

- Failed access lookup currently selects noApplication; target should retain uncertainty and an explicit retry rather than imply application absence.
- Pending Check status refresh is a read, not approve or submit again; polling must be bounded and session-owned.
- Fix and resubmit is rejected-only and remains subject to existing callable conditions; never offer it for suspended.
- Legacy approval resolution is current source behavior, not owner-approved new authorization policy.
- Keep OTP identity proof separate from application status and merchant workspace permission.

Source anchors:

- [seller_auth_provider.dart](../../apps/seller/lib/providers/seller_auth_provider.dart)
- [app.dart](../../apps/seller/lib/app/app.dart)
- [seller_sign_in_screen.dart](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart)
- [email_sign_in_screen.dart](../../apps/seller/lib/screens/auth/email_sign_in_screen.dart)
- [application_status_screen.dart](../../apps/seller/lib/screens/auth/application_status_screen.dart)
- [account_restricted_screen.dart](../../apps/seller/lib/screens/auth/account_restricted_screen.dart)

Scanned screen families (file counts, not unique screen count):

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

**Current implementation:** DeliveryLoginScreen signs in with email/password and has a password-reset sheet. DeliveryAuthProvider distinguishes missing registration, profileUnavailable, wrong role, approved-operable and blocked KYC states. PendingApprovalScreen presents pending/rejected/suspended/deactivated; canResubmit is only pending/rejected. The screen includes support/sign-out and separately protected account deletion. No phone-OTP sign-in was found in the inspected login. Suspension is not the same as offline status or document-change request pending review.

**Target:** Present credentials, account verification/read checking, pending rider application and suspended work access as distinct states. Preserve approved-only operations; missing profile and failed profile read get different guidance. Application editing never activates a rider or clears a suspension.

**Domain design:** High-contrast black/white rider credential forms, burgundy restriction cues, burnt-orange field guidance and large task-ready controls.

| Panel | Specimen |
| --- | --- |
| Sign-in | Card "Rider sign-in", EMPTY "Email" and "Password" fields, labelled eye icon "Show password", black PRIMARY "Sign in", secondary text "Forgot password?". Orange annotation "Email and password". No Google, phone-code field or MFA. |
| Account verification | Card "Checking rider access", indeterminate spinner, text "Checking your rider profile and account status." Distinct Failed variant "Account check unavailable" with safe helper "This does not mean your application was rejected." Board-only orange annotation "Read failure is not a review decision"; NO OTP or resend action, NO percentage and NO completed tick. |
| Application review | Card "Application under review", small "Pending" status, explanation "Your rider application is awaiting review. Delivery work is unavailable." PRIMARY "Edit application", OUTLINED "Contact support", text "Sign out". Orange note "Editing does not activate access". No Check status button absent this screen, approval ETA, earnings or online toggle. |
| Suspension | Card "Rider account suspended", burgundy shield-alert and message "Delivery work is unavailable for this account." OUTLINED "Contact support" and "Sign out". Orange note "Application editing is unavailable in this state". Do not render reason values, restore access, go online, edit/resubmit, delivery assignment or account deletion as recovery. |

Gaps and preserved boundaries:

- Keep email/password sign-in and existing reset mechanism; do not invent phone OTP, Google or MFA.
- ProfileUnavailable is an access-read problem, not pending or suspended. Target indeterminate account-check panel is proposed visual presentation, not a new verification provider.
- Pending/rejected may edit application; suspended/deactivated may not. Do not expose edit or resubmit inside the suspension specimen.
- Online/offline availability, account KYC and document/identity-change review remain separate domains.
- Human reason text must be safe, authorised and session-owned; specimens omit actual reasons, names and identity documents.

Source anchors:

- [auth_provider.dart](../../apps/delivery/lib/providers/auth_provider.dart)
- [app.dart](../../apps/delivery/lib/app/app.dart)
- [login_screen.dart](../../apps/delivery/lib/screens/auth/login_screen.dart)
- [pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart)
- [auth_copy.dart](../../apps/delivery/lib/auth/auth_copy.dart)
- [rider_account_source.dart](../../apps/delivery/lib/auth/rider_account_source.dart)

Scanned screen families (file counts, not unique screen count):

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

**Current implementation:** LoginScreen supports phone-code and email/password modes, with ForgotPasswordScreen. AssociateOtpScreen verifies phone through shared auth service. EmployeeAuthProvider authenticates identity then requires employee role and an employees record: suspended is explicit, any other non-approved status currently becomes pending. Missing/non-associate profile is refused. App AuthGate chooses suspension before pending via error-string contains, then approved workspace. Pending/suspended screens have Contact Support and Sign Out; pending has no evidenced refresh action and copy currently promises immediate activation.

**Target:** Present phone or email sign-in, genuine code verification, associate review and suspension without earning/activation guarantees. Use a future typed access state rather than parsing display text; pending remains separate from absent profile or failed access lookup. Do not imply successful OTP means approved associate.

**Domain design:** Premium royal-blue associate forms, indigo jurisdiction-review context, pearl/slate cards and restrained status hierarchy.

| Panel | Specimen |
| --- | --- |
| Sign-in | Card "Sales Associate sign-in", compact mode labels "Mobile" active / "Email" inactive, EMPTY "Mobile number", royal-blue PRIMARY "Send code". Indigo note "Email and password also supported". No Google or new application button. |
| Phone verification | Card "Verify your mobile", six EMPTY code boxes, PRIMARY "Verify code", OUTLINED "Change number". Small Failed variant "Code not accepted" with "Check the code and try again." Indigo annotation "Identity verification does not grant associate access". No code digits, phone value, counter or approval tick. |
| Associate review | Card "Application pending approval", explanation "Your associate details and jurisdiction are under review. Workspace access awaits an approval decision." OUTLINED "Contact support" and "Sign out". Indigo annotation "Review has no promised completion time". No Check status, resubmit, approval promise, code activation or Start earning CTA. |
| Suspension | Card "Associate account suspended", shield-alert and semantic error notice "Your associate workspace is unavailable." OUTLINED "Contact support" and "Sign out". Indigo annotation "Suspension is distinct from pending review". No restore access, earn/share code, appeal-submitted status, new application, fee or payout controls. |

Gaps and preserved boundaries:

- Error-string routing and every non-approved status collapsing to pending require a bounded typed presentation migration, preserving existing authorisation.
- Do not add Check status, Apply here or resubmit actions where not currently supported; application is reached from the customer app.
- Replace immediate-activation promise with truthful review copy; no commission, payout, approval or earning guarantees.
- Phone OTP comes before role approval; unregistered identity receives a distinct refusal, not a fake pending application.
- Support contacts exist but boards omit real email/phone and show only supported Help Support destination.

Source anchors:

- [auth_provider.dart](../../apps/employee/lib/providers/auth_provider.dart)
- [app.dart](../../apps/employee/lib/app/app.dart)
- [login_screen.dart](../../apps/employee/lib/screens/auth/login_screen.dart)
- [associate_otp_screen.dart](../../apps/employee/lib/screens/auth/associate_otp_screen.dart)
- [forgot_password_screen.dart](../../apps/employee/lib/screens/auth/forgot_password_screen.dart)
- [pending_approval_screen.dart](../../apps/employee/lib/screens/auth/pending_approval_screen.dart)
- [suspended_screen.dart](../../apps/employee/lib/screens/auth/suspended_screen.dart)

Scanned screen families (file counts, not unique screen count):

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

**Current implementation:** AuthScreen supports email/password and Google plus password-reset email. AuthProvider loads user profile and explicitly refuses non-admin role, clearing currentUser and signing out. Profile read failure has separate safe error and restoreSession method; app router reacts to provider and checks admin before protected routes. isLocked is a temporary sign-in-attempt state, not app-account suspension. No dedicated Admin application approval, phone OTP, MFA, invitation or self-provisioning flow was found in inspected gate.

**Target:** Show credentials, profile/access checking, role denial and recoverable account-read failure. Admin does not share merchant review or associate pending workflow. Do not invent admin approval queue, suspended badge, self-unlock, invite, OTP or MFA. Retry profile lookup uses the existing restoreSession method as a proposed consistent presentation action.

**Domain design:** Professional-blue controlled-entry forms, cyan role explanations, steel/slate status rows and precise refusal copy.

| Panel | Specimen |
| --- | --- |
| Sign-in | Card "Admin sign-in", EMPTY "Email" and "Password", labelled eye "Show password", professional-blue PRIMARY "Sign in", OUTLINED "Continue with Google", text "Forgot password?". Cyan note "Admin role required". No sign-up/invite/MFA/phone field. |
| Access verification | Card "Checking admin access", indeterminate spinner and text "Checking your account and admin role." No filled check, percentage or work data. Cyan annotation "Sign-in is not permission". No OTP boxes, resend, admin application or approval queue. |
| Role restriction | Card "Admin access denied", shield icon and safe semantic error "This account cannot access the admin app." OUTLINED "Sign in with another account" routed to existing sign-in after refusal. Cyan note "No self-service role approval". No Apply for access, approve, invite, unlock, suspension badge or support endpoint. |
| Read recovery | Separate recovery card "Account check unavailable", safe notice "We could not load your account. Access remains restricted." PRIMARY "Try again", small caption "Proposed recovery action" and cyan note "Checks account access only". Distinct from Role restriction; no state-changing request, admin role assignment or success badge. |

Gaps and preserved boundaries:

- AuthScreen maps role refusal safely; retain this and backend/rules protection. A design board cannot certify authorization.
- Distinguish wrong credentials, sign-in-attempt throttling, non-admin role and access-read failure; no false Admin suspended status.
- Proposed Try again for account lookup must call existing restoreSession under current session ownership; it must never change role.
- Existing Google sign-in is supported; no fabricated second-factor challenge or self-registration.
- Return paths and router initialization need future rendered tests; no privileged screen may flash while access is unresolved.

Source anchors:

- [auth_provider.dart](../../apps/admin/lib/providers/auth_provider.dart)
- [auth_screen.dart](../../apps/admin/lib/screens/auth/auth_screen.dart)
- [app_router.dart](../../apps/admin/lib/app/app_router.dart)
- [auth_service.dart](../../packages/agrimore_services/lib/auth/auth_service.dart)
- [roleClaims.ts](../../functions/src/admin/roleClaims.ts)
- [setUserRole.ts](../../functions/src/admin/setUserRole.ts)

Scanned screen families (file counts, not unique screen count):

| Family | Files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Reuse and authority

Use the existing shared AuthService, app-specific auth providers/gates and existing canonical feedback/form primitives. The old UIUX/feedback guides contain historical emerald-only styling, widget and localisation counts; C01 locked per-app identities and fresh source reads govern this proposal. No duplicate helper or widget has been implemented. Account-level suspension, review of an identity/document change, store availability and phone credential proof remain separate. Client presentation does not replace backend/rules authorization.

## Future implementation verification

- Render supported sign-in modes on phone/wide layouts, light/dark, keyboard and large text. Verify labels, eye-button semantics, autofill/paste, six-code input focus and safe first-error announcement with TalkBack/VoiceOver.
- Sign-out/account-switch/unmount during each await, slow/unavailable profile read, lost response, duplicate taps, stale Google result, canceled provider flow, changed phone and resend rate limit. Do not render old account data or privileged-shell flashes.
- Test cold-start and post-auth profile completion, protected deep links, intended return destination and Back. Marketplace guest/public routes are platform-specific; no unrestricted anonymous purchase is claimed.
- Seller: signedOut/loading/noApplication/draft/pending/rejected/suspended/approved plus network failure. Retry is a read, not a new application. Preserve legacy resolver cases until an authorised policy migration. Reopen is rejected-only.
- Delivery: missing user/partner records versus failed read, wrong role, approved versus pending/rejected/suspended/deactivated, mid-shift restriction and separate offline/document-review states. Edit application only where canResubmit allows it; never activate by editing locally.
- Associate: missing/non-associate profile, missing employees record, read failure, pending, approved and suspended. Typed presentation replaces string routing only in a future bounded migration. No unsupported Check status or in-app self-application action.
- Admin: correct/wrong credentials, Google cancellation, non-admin refusal, null/failed user profile, temporary sign-in throttling, successful role read and restoreSession retry. No admin approval/suspension/MFA workflow is assumed. Role refusal remains separate from account-read failure.
- Existing server/rules and custom-claim access checks need emulator tests if later changed. No authentication calls, OTP sends, live accounts, emulator, app runtime/analyzer or security/accessibility certification occurred in this design task.

## Delivery scope and design review

27 new files: ten images, five app README/prompts/manifest sets, two master documents. C01–C17 remain preserved. C18 is provisional, not owner-approved. Exact image prompts are user-requested asset provenance, not exported implementation-worker prompts. Surface classifier: docs; voluntary UIUX/feedback design review covered locked identities, truthful access copy, supported actions, neutral dark surfaces and proposed accessibility/lifecycle requirements. Asset checks do not validate runtime behavior.

No app/package/runtime/pubspec/auth/backend changes, branch/index/commit actions, deploy or other-chat interruption by this task. Independent implementation may change shared checkout source or HEAD; observed changes are recorded without reverting. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/providers/product_credit_provider.dart, apps/marketplace/lib/providers/rfq_provider.dart.

## Artifact verification evidence

The C18 asset validator passed after packaging: ten valid PNGs in five light/dark pairs, 27 declared new files, 13 exact initial/refinement prompt blocks with input/output hashes, 91 local document links, and all 810 earlier design files preserved byte-for-byte. Each PNG matches its selected generated source; PNG chunk CRCs and dimensions were checked. C01 APPROVED_LOCKED reference hashes, palette/status metadata, typography, spacing, radius and border metadata were verified for all ten variants. Raster color, geometry, accessibility and auth behavior remain unverified by these asset checks.

Fresh static inventory: 818 eligible source files / 271,696 lines at `a803a9d1866477ac621be50a9a3d3de1a2fa0800`. Validation observed HEAD `453a432e844174fcf90517744457ec85dada375c` on `agrimore/foundation-f3c-distance-delivery-pricing`. Concurrent changes before packaging were observed in `apps/marketplace/lib/providers/product_credit_provider.dart` and `apps/marketplace/lib/providers/rfq_provider.dart`; this task preserved them. The first post-packaging validation observed no changes in the 818 inventoried source files relative to the packaging baseline. A subsequent validation after adding this evidence observed another concurrent change in apps/marketplace/lib/providers/rfq_provider.dart. The ten hashed platform configurations matched inventory. These are recorded snapshots; this task did not edit those source files. These observations do not imply a frozen checkout or repo-wide runtime verification.

Visual review selected one Seller light refinement to remove a sample phone value and label verification variants, plus Admin light/dark refinements to retain one password-visibility control. Initial outputs and exact refinement provenance are recorded; selected PNG bytes were copied without image editing. Built-in image_gen was used. No runtime auth/provider/router/backend implementation, live calls, deployment, commits or other-chat interruption by this task.
