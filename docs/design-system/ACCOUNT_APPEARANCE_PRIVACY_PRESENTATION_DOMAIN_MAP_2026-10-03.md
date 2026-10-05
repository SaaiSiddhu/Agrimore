# Agrimore — C22 account, appearance and privacy presentation: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** C01 is APPROVED_LOCKED. C22 is not owner-approved; assets/docs only.

[Ten-board gallery](ACCOUNT_APPEARANCE_PRIVACY_PRESENTATION_BOARDS_2026-10-03.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: 7285db1207b2fa7219e2866a6c20de6334fc1ce5. 818 eligible files / 272067 source lines across five app lib trees, three package lib trees and functions/src. Generated Dart, firebase_options and credential/secret-named files were excluded. Fresh inventory hashes and marker searches cover appearance, masking/obscurity, account actions, privacy and session ownership. Focused semantic reads cover every app account/profile/settings and appearance providers, Seller masks, Delivery account backend/refusals, Associate payout editing, Admin guarded logout/privacy copy, Marketplace guarded deletion and shared AuthService/server deletion. Broad static inventory plus focused review is not semantic certification of every line or rendered screen. No real account or stored secrets were read.

Marker totals include comments/call sites, not unique components or defect counts. Shared-checkout implementation may advance source/HEAD during this asset task; changes are observed and preserved.

| Scope | appearance | sensitive | account_actions | privacy | ownership |
| --- | --- | --- | --- | --- | --- |
| admin | 19 | 20 | 16 | 6 | 36 |
| delivery | 16 | 21 | 23 | 9 | 32 |
| employee | 20 | 7 | 6 | 3 | 0 |
| marketplace | 79 | 7 | 10 | 17 | 18 |
| seller | 17 | 15 | 11 | 9 | 0 |
| functions | 0 | 3 | 10 | 0 | 12 |
| agrimore_core | 0 | 0 | 0 | 1 | 0 |
| agrimore_services | 2 | 2 | 7 | 0 | 5 |
| agrimore_ui | 0 | 6 | 0 | 0 | 0 |

## Shared account target contract

1. Identity must come from current account/role sources; loading, missing and failure are not a fabricated name, avatar, verified status or access grant.
2. Separate public/business identity, private contact, authentication credentials and financial destination details by app domain.
3. Masking minimizes display exposure; it is not encryption, storage security, access authorization or a privacy compliance guarantee. Do not mask inaccessible data and then claim permission is safe.
4. Owned editing may require actual raw values; summary masking is distinct from explicit editing and reviewed destination/identity changes. Avoid invented reveal/copy/security controls.
5. Appearance follows supported provider modes. Marketplace/Admin two states; Seller/Delivery/Associate three. Associate selector and Admin binding are proposed UI work.
6. System mode is a preference, resolved brightness follows the OS. Explicit Light/Dark boards select their matching mode, not System.
7. Current preferences are local device storage, not account/server/cloud sync. Applied state and persistence success are separate; errors need truthful feedback.
8. Recheck captured account/session/entity/route ownership after confirmations and asynchronous results. Preserve existing Delivery/Admin guards and Marketplace deletion guards.
9. Sign-out, account deletion, credential change and cache/data clearing are separate actions with different outcomes. No all-devices logout or canceled-in-flight promise.
10. Deletion review/acknowledgement is not eligibility. Refusal, unknown outcome, partial failure and confirmed completion remain distinct. Server business/retention policy governs deletion.
11. Only Marketplace/Delivery deletion entries are evidenced in these screens. Do not add identical seller/associate/admin self-delete controls merely for visual consistency.
12. Do not reproduce unverified encryption/sharing/verification/MFA/biometric/privacy compliance or complete-erasure claims. No real or synthetic PII/credential values in specimens.
13. Accessible selected labels and full targets, clear consequence text, focus restoration and status announcements need runtime validation; generated boards do not certify accessibility/security.

## Theme capability and persistence

| App | Current provider / UI | C22 direction |
| --- | --- | --- |
| Marketplace | Boolean Light/Dark, actual settings provider toggle and local preferences | Keep two modes; selected board matches explicit mode; no System or cloud sync |
| Seller | System/Light/Dark selector and local seller.themeMode; applies/notifies before save; errors logged | Preserve three choices; persistence feedback distinct from applied state |
| Delivery | System/Light/Dark AppearanceScope, delivery.appearance local preference; notify before awaited save | Preserve three choices; catch/report save failure later; no server sync |
| Sales Associate | Provider defaults System, sa_theme_mode supports three; profile exposes only Dark Mode switch; save errors swallowed | Proposed selector exposes existing System capability; save failures need visible recovery |
| Admin | Provider persisted boolean Light/Dark; settings _darkMode switch only setState plus snackbar | Proposed binding to actual provider; two supported modes; no fake saved toast |

System is preference, resolved brightness is device-dependent. Every light board explicitly selects Light; every dark board selects Dark. Device preference persistence is not account-scoped cloud sync. Save ordering, failure, rapid consecutive changes and owner changes require implementation checks before guarantees.

## Domain-by-domain account systems

### Agrimore Marketplace

**Current source:** Profile loads account name/email/phone/photo; phone is readable. Settings uses the actual bool ThemeProvider and persisted Light/Dark preference, no System mode. Profile logout clears cart then calls FirebaseAuth directly after confirmation, without the owned provider path or a captured episode in this caller. DeleteAccountScreen already captures owner/episode, invalidates replacement sessions, gates acknowledgement/submitting and maps callable refusal versus unknown failure. Shared AuthService now delegates deletion to deleteUserData; do not describe an obsolete client-side deletion flow.

**Target:** Keep two supported appearance choices. Separate contact editing, appearance and private summaries; propose masked summary values and owned/busy sign-out feedback. Preserve guarded deletion review and authoritative refusal handling.

| Panel | Domain specimen |
| --- | --- |
| Shopper identity | Card "Your account", generic outline person avatar, EMPTY name skeleton, labels "Contact details" and "Saved addresses" with neutral empty rows; SECONDARY "Edit profile". No name, photo, initials, phone, email or address. Gold board note "Identity follows the signed-in account". |
| Appearance | Card "Appearance", TWO labelled choices "Light" and "Dark" only. Select the board theme exactly. Below "On this device". Gold note "Two supported modes". No System choice, sync claim or saved toast. |
| Sensitive summaries | Card "Contact summary", rows "Phone" and "Email", values ONLY "••••••••". SECONDARY "Edit contact details". Gold BOARD note "Proposed masked summary". No eye/reveal toggle or pretend secure-storage guarantee. |
| Account actions | Card "Account actions", PRIMARY "Sign out"; separate neutral outlined row "Review account deletion" and small "Review requirements before continuing". Gold BOARD note "Separate actions / current account only". No Delete now, success, signed-out confirmation or irreversible-action checkmark. |

Preserve or resolve:

- Light/Dark only; do not invent working System mode or cross-device theme sync.
- Profile contact masking and logout owner/episode guard are proposals; preserve existing guarded deletion form.
- Deletion callable refuses balances, active orders and pending payouts; review does not certify eligibility or erase every financial/history record.

Sources:

- [apps/marketplace/lib/screens/user/profile/profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart)
- [apps/marketplace/lib/screens/user/profile/settings_screen.dart](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart)
- [apps/marketplace/lib/screens/user/profile/delete_account_screen.dart](../../apps/marketplace/lib/screens/user/profile/delete_account_screen.dart)
- [apps/marketplace/lib/providers/theme_provider.dart](../../apps/marketplace/lib/providers/theme_provider.dart)
- [apps/marketplace/lib/providers/auth_provider.dart](../../apps/marketplace/lib/providers/auth_provider.dart)
- [packages/agrimore_services/lib/auth/auth_service.dart](../../packages/agrimore_services/lib/auth/auth_service.dart)
- [functions/src/customer/deleteUserData.ts](../../functions/src/customer/deleteUserData.ts)

### Agrimore Seller

**Current source:** Seller profile separates storefront/business identity and payout details. SellerFormat masks phone, bank account and UPI summary (partial disclosure still exists); payout read failure is distinct from unavailable details. SellerSettingsProvider exposes/persists System/Light/Dark, applies before saving and catches/logs persistence failure. Profile sign-out confirms then calls auth without an explicit opening owner/epoch recheck in this caller. No seller account-deletion entry evidenced in these screens.

**Target:** Preserve business versus private-account distinction, three appearance choices and masked payout summary. Add truthful preference persistence and guarded sign-out; no copied Marketplace deletion feature.

| Panel | Domain specimen |
| --- | --- |
| Store and account identity | Card "Store profile", generic outline storefront icon, EMPTY store-name skeleton, small neutral "Business details" label. SECONDARY "Edit business details". Copper BOARD note "Storefront and private contact are separate". No store name/address/photo/verified badge. |
| Appearance | Card "Appearance", THREE labelled choices "System", "Light", "Dark". Select the board theme exactly, System unselected. Below "On this device". Copper note "System follows device appearance". No saved/cloud-sync claim. |
| Private payout summary | Card "Payout details", two rows "Bank account" and "UPI", values ONLY "••••••••". SECONDARY "Review payout details". Copper BOARD note "Masked summary / controlled editing". No bank name/digits/UPI handle/verified badge/eye control. |
| Merchant account actions | Card "Sign out of this account?", body "Return to sign-in on this device." SECONDARY "Keep working" and PRIMARY "Sign out". Copper BOARD note "Confirm current account before dispatch". No deletion action or success result. |

Preserve or resolve:

- Masking is display minimization, not encryption; current masks retain some characters.
- Applied appearance is not proof disk persistence; surface save failure separately.
- Only sign-out action evidenced here; do not invent seller self-delete or verified payout-owner claims.

Sources:

- [apps/seller/lib/screens/profile/seller_profile_screen.dart](../../apps/seller/lib/screens/profile/seller_profile_screen.dart)
- [apps/seller/lib/screens/account/settings_screen.dart](../../apps/seller/lib/screens/account/settings_screen.dart)
- [apps/seller/lib/providers/seller_settings_provider.dart](../../apps/seller/lib/providers/seller_settings_provider.dart)
- [apps/seller/lib/design_system/format/seller_format.dart](../../apps/seller/lib/design_system/format/seller_format.dart)

### Agrimore Delivery

**Current source:** Rider profile has real System/Light/Dark AppearanceScope. Bank tail and Aadhaar are masked, but inspected UPI summary is raw; maskTail returns short strings unchanged. Contact changes differ from reviewed identity/document changes. Sign-out/deletion callers capture owner/session and recheck after confirmation. Deletion proactively blocks active deliveries and held cash/unsettled earnings; server also refuses pending/on-hold statements. Local missing account data does not certify eligibility. Backend retains financial/safety records and leaves incident-retention policy open.

**Target:** Preserve session guards, distinguish contact edits from reviewed identity changes, mask UPI summary and show evidenced blocked deletion with domain recovery. Unknown eligibility remains unknown; no all-data-erased promise.

| Panel | Domain specimen |
| --- | --- |
| Rider identity | Card "Rider profile", generic person outline icon, EMPTY name skeleton, small label "Contact details"; SECONDARY "Edit contact details". Orange BOARD note "Identity changes use a separate review". No rider initials/phone/vehicle/verified badge/document photo. |
| Appearance | Card "Appearance", THREE choices "System", "Light", "Dark". Select matching board theme only. Below "On this device"; orange note "System follows device appearance". Use black selected light / off-white selected dark with dark inverse text. |
| Sensitive rider summaries | Card "Private details", rows "Identity document" and "UPI", values ONLY "••••••••". Small burgundy contextual label "Sensitive information". Orange BOARD note "UPI masking proposed". No IDs/digits/document photograph/eye control or all-private assurance. |
| Protected account actions | Card "Account deletion unavailable", body "Finish the assigned delivery before continuing." SECONDARY "View delivery". Below a separate outline "Sign out" action. Orange BOARD note "Illustrative active-delivery refusal". Burgundy is context, no Delete now, eligibility/success/paid/erasure checkmark. |

Preserve or resolve:

- UPI masking is a target fix, not already implemented. No identity document photo or identifier on these boards.
- Server deletion refusal remains authoritative; active deliveries, cash and pay requirements differ.
- No complete-erasure, privacy-policy compliance, document verification or payout completion guarantees.

Sources:

- [apps/delivery/lib/screens/profile/rider_profile_screen.dart](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart)
- [apps/delivery/lib/design_system/theme/delivery_theme.dart](../../apps/delivery/lib/design_system/theme/delivery_theme.dart)
- [apps/delivery/lib/account/rider_account.dart](../../apps/delivery/lib/account/rider_account.dart)
- [functions/src/delivery/riderAccountDeletion.ts](../../functions/src/delivery/riderAccountDeletion.ts)
- [functions/src/customer/deleteUserData.ts](../../functions/src/customer/deleteUserData.ts)

### Agrimore Sales Associate

**Current source:** Associate profile masks phone but renders email; appearance UI only offers Dark Mode switch. ThemeProvider already supports/persists System/Light/Dark, applies before saving and swallows persistence errors. Profile sign-out has mounted/navigator checks but no explicit captured opening owner/session/route recheck in this caller. Payout form legitimately edits owned raw bank/UPI values and requests approved destination changes; saving does not verify ownership. No self-delete UI evidenced.

**Target:** Expose existing three-mode capability with a proposed selector, keep masked summaries separate from intentional payout editing/review, and add owner-scoped sign-out protection. Do not invent payout approval, commission values or account deletion.

| Panel | Domain specimen |
| --- | --- |
| Associate identity | Card "Associate profile", generic person outline icon, EMPTY name skeleton, label "Contact details"; SECONDARY "Edit profile". Indigo BOARD note "Signed-in associate identity". No initials/email/phone/commission rate/approved-role badge. |
| Appearance | Card "Appearance", THREE choices "System", "Light", "Dark", select matching board theme. Below "On this device". Indigo BOARD note "Proposed selector / existing three-mode provider". No cloud-sync/saved assertion. |
| Payout privacy and review | Card "Payout account", rows "Bank account" and "UPI", values ONLY "••••••••". SECONDARY "Review payout details". Indigo BOARD note "Masked summary / changes need review". No amount/account digits/UPI/payee/approval/checkmark/eye toggle. |
| Associate account actions | Card "Sign out of this account?", body "Return to sign-in on this device." SECONDARY "Keep working" and PRIMARY "Sign out". Indigo BOARD note "Current account / guarded confirmation". No Delete account, earnings loss assertion, signed-out success or operation-cancellation promise. |

Preserve or resolve:

- Three-choice selector is proposed UI exposing existing provider capability.
- Masked summary does not replace necessary access-controlled raw editing. Payout change review is not verified ownership.
- Local theme persistence failure needs honest feedback; no cloud sync or server account-setting claim.

Sources:

- [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [apps/employee/lib/providers/theme_provider.dart](../../apps/employee/lib/providers/theme_provider.dart)
- [apps/employee/lib/screens/wallet/payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart)
- [apps/employee/lib/utils/sa_formatters.dart](../../apps/employee/lib/utils/sa_formatters.dart)

### Agrimore Admin

**Current source:** Admin profile reads user name/email with hardcoded fallbacks; do not copy fallback identity into examples. Provider supports persisted bool Light/Dark. Settings Dark Mode switch only changes local _darkMode plus snackbar, not actual ThemeProvider. Logout already captures owner/version/route, guards in-flight and navigation, and shows truthful failure. Password editing is obscured and owned. Settings privacy dialog contains unsupported blanket encryption/sharing assurances; cache action shows success without a verified clear. No self-delete UI evidenced; MFA presentation is not live enrollment.

**Target:** Bind two-mode appearance to actual provider, separate account/credentials/privacy information, retain existing strong logout guards and remove unverified privacy/cache/security success promises from target copy.

| Panel | Domain specimen |
| --- | --- |
| Administrator identity | Card "Administrator account", generic outline person icon, EMPTY name skeleton, label "Account details"; SECONDARY "Review account". Cyan BOARD note "Identity from current authorised account". No fabricated admin name/email/role badge/privilege toggle. |
| Appearance | Card "Appearance", TWO choices "Light", "Dark" only, select matching board theme. Below "On this device". Cyan BOARD note "Proposed binding to actual theme provider". No System option, saved toast or cloud-sync promise. |
| Credentials and privacy | Card "Account security", row "Password" with ONLY "••••••••"; SECONDARY "Change password"; separate neutral text row "Privacy information". Cyan BOARD note "No unverified security assurance". No MFA/biometric/verified/encrypted badge, eye control or legal compliance guarantee. |
| Guarded administrator sign-out | Card "Sign out of this account?", body "Return to sign-in on this device." SECONDARY "Stay signed in" and PRIMARY "Sign out". Cyan BOARD note "Preserve account, session and route checks". No admin self-delete, success tick, all-devices logout, clearance or cache-erased claim. |

Preserve or resolve:

- Admin two-choice appearance binding is a target fix; local success snackbar does not prove theme application/persistence.
- No new MFA/biometric enrollment, role elevation, self-delete, all-devices sign-out or complete cache erasure.
- Privacy copy must reflect actual policy and verified processing; obscured password text is not an encryption/security audit.

Sources:

- [apps/admin/lib/screens/admin/settings/admin_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart)
- [apps/admin/lib/providers/theme_provider.dart](../../apps/admin/lib/providers/theme_provider.dart)
- [apps/admin/lib/providers/auth_provider.dart](../../apps/admin/lib/providers/auth_provider.dart)

## Privacy and action boundaries

| Boundary | Observed source | Target interpretation |
| --- | --- | --- |
| Marketplace summaries | Profile phone/email readable; deletion already owned/guarded | Masked summary proposed; keep legitimate owned contact editing and existing guarded deletion |
| Seller masks | Phone last digits, account tail, UPI partial handle/domain remain visible | Partial display mask is not encryption; boards use pure bullets to avoid inventing PII |
| Delivery sensitive data | Bank/Aadhaar masks, short maskTail returns raw; UPI summary raw | UPI masking target; document/identity changes separate review; no photo/ID specimen |
| Associate payout | Own raw bank/UPI editing and approval request; profile email readable | Masked summary distinct from controlled editing; no ownership-verified claim |
| Admin privacy/security | Password obscurity, unsupported blanket privacy dialog assurances; MFA not live enrollment | Privacy information must match verified policy; no new MFA/compliance/encryption claim |
| Sign-out ownership | Delivery/Admin strong owner/route checks; Marketplace profile direct FirebaseAuth; Seller/Associate caller no explicit opening epoch guard | Preserve strong guards; propose captured owner/episode/busy checks for remaining callers |
| Account deletion | Marketplace/Delivery entries evidenced; shared callable handles domain prerequisites/teardown | Review or refusal is not eligibility or completion; no cloned seller/associate/admin delete action |
| Retention and erasure | Deletion retains records by domain; rider financial/safety records retained and incident-retention decision remains open | No all-data-erased claim. Real policy and completed server outcome must precede user assurance |

No biography, contact, identifier, bank/UPI value, document photo, credential, financial amount, commission rate or real/synthetic person appears on these boards. Generic outline avatars and neutral skeletons represent unknown identity. Pure bullet strings are masking specimens. No operation was executed: confirmations, deletion review and illustrative active-delivery refusal are independent design states. A mask is not an access-control boundary.

## Future implementation verification

- Identity loading/failure/missing fields and account replacement; no fallback personal identity, role escalation or stale profile. Refresh follows current owner only.
- Local theme load/set/restart, System brightness changes, explicit Light/Dark choice, rapid toggles, persistence failure and per-device scope. Admin actual provider binding and Associate selector need real implementation. Applied appearance is separate from confirmed storage write.
- Sensitive summary/access-controlled edit separation, short/malformed mask values, screen-reader exposure, logs/screenshots/cache paths where actually supported; do not claim broader privacy protection from a visual mask. Delivery UPI raw-summary fix and Associate email masking require deliberate domain decisions.
- Logout duplicate taps, confirmation left open across account/episode/route changes, delayed provider sign-out, failure and replacement-owner navigation. Preserve Admin/Delivery ownership and Marketplace deletion guards; do not clear another account cart or route. Sign-out does not promise all-device logout or business-operation cancellation.
- Deletion active orders, wallet/cash/earnings/pending statement prerequisites, unavailable reads, refusal reasons, recent-auth when required by supported flow, failed/partial/unknown outcomes and retained financial/safety records. Server authority remains required; local preview cannot certify eligibility or erasure.
- Reviewed identity/payout change versus simple contact edit; pending/cancel/error feedback follows current owner. Saving raw editing values does not verify ownership or approval.
- Password obscurity/owned credential forms and policy links: do not introduce fake MFA, biometric enrollment, cache-cleared confirmation or blanket encryption/sharing/compliance assurances.
- Narrow/wide layouts, text scaling, selected-state labels beyond color, labelled targets, focus restoration, announcements, reduced motion and actual TalkBack/VoiceOver. Raster assets do not certify contrast/accessibility/security.
- Later runtime edits require targeted meaningful tests and applicable app analyzers. No live auth, account deletion, OTP, preference write, Flutter runtime/emulator/analyzer or security/privacy certification was performed by this design task.

## Delivery scope and design review

27 new files: ten PNGs, five per-app README/prompts/manifest sets and two master documents. C01–C21 and repeated existing C16 remain preserved. C22 is provisional, owner approval pending. Classifier: docs; voluntary UIUX/feedback review covers locked identities, supported appearance, truthful sensitive summaries and domain account-action boundaries.

Only this task’s design assets/docs are written. No runtime/auth/backend/pubspec, branch/index/commit/deployment change or other-chat interruption by this task. Concurrent shared-checkout source is observed and preserved. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent source changes since inventory: apps/marketplace/lib/providers/order_provider.dart.

## Asset integrity check

First post-packaging validation snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs; PNG chunk checksums, copied-output hashes, ten exact prompt blocks, reference-input hashes, approved C01 token metadata and 82 local document links passed. Exactly 27 new repository files; all 918 earlier design files remained byte-for-byte intact. No refinements were needed after visual review.

Snapshot HEAD: 7285db1207b2fa7219e2866a6c20de6334fc1ce5; branch: agrimore/foundation-f3c-distance-delivery-pricing. Shared implementation changed apps/marketplace/lib/providers/order_provider.dart between inventory and packaging; that source was observed and preserved. No additional indexed source or platform-config changes were observed during this first packaging/check snapshot. This records a point in time, not a guarantee that the other chat or HEAD stops advancing.

Scope: design assets/docs only. Integrity checks and visual review do not certify pixel-exact tokens, runtime rendering, accessibility, privacy/security, theme persistence, authentication, deletion or backend business outcomes. C22 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.
