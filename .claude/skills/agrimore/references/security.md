# `security` lane — marketplace security and financial-integrity review

**Mandate.** Every change that touches the surface list in §2 gets this lane before VERIFY. The lane
produces findings with severity, evidence and a fix; it never signs off from reading a passing
compile. A verified P0 (live-user money, account takeover, data loss) outranks every feature phase —
say so and stop feature work. **Facts below were measured 2026-09-04 at `main` = `c8f6f30`.
Re-measure before quoting.**

**Never reproduce a secret value.** Cite the path and the key name, say what is exposed, require
rotation. Secret inventory (names only): Secret Manager — `OTP_ENCRYPTION_KEY`, `RAZORPAY_KEY_SECRET`,
`RAZORPAY_WEBHOOK_SECRET`, `RESEND_API_KEY`, `TWOFACTOR_API_KEY` (bound per function via
`defineSecret`/`runWith({secrets})`; local copies in untracked `functions/.secret.local`); plain config
`functions/.env` — `PHONE_OTP_SMS_ENABLED`, `RAZORPAY_KEY_ID`, `RESEND_FROM_EMAIL`; client `.env` (22
`FIREBASE_*`/`GOOGLE_MAPS_API_KEY`/`RAZORPAY_KEY_ID`, no longer a Flutter asset, nothing reads it);
`_env` at the root = the un-stripped 30-key file (untracked, ignored, never open it); the keystore
backup zip; `google-services.json` ×2; `firebase_options.dart` ×3 (Google client keys, not secrets).

## 1. Trust boundaries and identity universes

| Universe | Credential | Verified by | Authority |
|---|---|---|---|
| Customer (`apps/marketplace`) | **phone OTP only** — `sendPhoneOTP`/`verifyPhoneOTP` (v1 `onRequest`, CORS `*`, custom token; CSPRNG 6-digit, SHA-256 hash + AES-GCM copy for voice redelivery, caps 10/day) — base URL hardcoded to production at `packages/agrimore_services/lib/auth/auth_service.dart:334` | Firebase Auth; `users/{uid}` created by `verifyPhoneOTP` with `role:'user'`, `profileCompleted:false` | claims minted by `functions/src/admin/roleClaims.ts` (`syncUserRoleClaims` onWrite) |
| Admin (`apps/admin`) | email + password (`auth_screen.dart`), Google sign-in | `role:'admin'` in `users/{uid}` → `admin:true` claim; rules `isAdmin()` = claim OR `hasRole('admin')` OR Firestore-doc fallback | only `setUserRole` (admin-only, source-only, UNDEPLOYED) or a console edit + the deployed `refreshUserRoleClaims` can grant it; the `create_admin.js` bootstrap was deleted by SEC-1 (A-1) |
| Seller / Delivery partner | email + password; self-apply writes `status:'pending'` | `sellers/{uid}` / `delivery_partners/{uid}` `.status == 'approved'` set by admin only (value-guarded rules) → `seller`/`delivery_partner` claims | `createSellerByAdmin` (throws `already-exists`, never resets a password) |
| Sales Associate (`apps/employee`, role `employee`) | phone OTP (self-applied) or email + password (admin-created, `createEmployeeByAdmin` attaches `phoneNumber`) | `employees/{uid}.status == 'approved'` + the seven onboarding fields are CF-only; ₹500 onboarding gate cleared = paid OR waived AND not refunded | `syncEmployeeRoleClaims`; commission via `payEmployeeCommissionOnDelivery` only |
| Cloud Functions | Admin SDK — **bypasses every rule**; therefore every callable re-derives authorization itself (`request.auth`, claim-first then Firestore-role fallback) | `functions/src/**` | the real trust boundary for money |
| Razorpay | HMAC-SHA256 over `orderId\|paymentId` with `RAZORPAY_KEY_SECRET` + live `GET /v1/payments/{id}` `status == 'captured'` (`customer/payment.ts`, `customer/wallet.ts`); webhook raw-body HMAC + `timingSafeEqual` + `webhook_events` idempotency (`employee/razorpayOnboardingWebhook.ts`) | server only; the client receives `keyId` from `createRazorpayOrder` | `verified_payments/{paymentId}` bound to `userId`, consumed once |
| Storage | `storage.rules`: token-only role checks (`request.auth.token.admin/seller/delivery_partner/employee`), `isValidFileSize()` (<10 MB), `isImage()`; default `allow read, write: if false` | per-path blocks | no doc-fallback here — a user whose claim was never minted cannot upload even if their Firestore role says so |
| App Check | activated in all five apps' `main.dart` (`app_check_service.dart`), **monitoring only** — zero `enforceAppCheck` in `functions/src` | — | flipping enforcement = owner decision (D-APPCHECK) |

## 2. Surface list — what triggers this lane (`scripts/surface.sh` encodes it)

```
firestore.rules  storage.rules  firestore.indexes.json  firebase.json  .firebaserc
functions/**                      (src, package.json, .env.example, .secret.local.example, scripts/*)
packages/agrimore_services/lib/{auth,payment,firebase,database}/**    packages/agrimore_core/lib/config/**
packages/agrimore_core/lib/models/{user,wallet,wallet_transaction,order,employee,product_credit_*,benefit_*}_model.dart
apps/*/lib/providers/*{auth,wallet,order,cart,payment,employee,product_credit}*   apps/*/lib/services/**
apps/*/lib/screens/**/{checkout,cart,wallet,auth,onboarding,employee}/**
apps/*/pubspec.yaml  packages/*/pubspec.yaml  (assets + dependency bumps)
apps/*/android/app/build.gradle.kts  apps/*/android/app/src/main/AndroidManifest.xml  apps/*/web/index.html
.env.example  functions/.env.example  functions/.secret.local.example  .gitignore  .claude/**  .github/**
```

## 3. The request path (what is and is not a control)

Client → Firebase Auth (phone OTP custom token, or email/password) → **either** a direct Firestore
read/write evaluated by `firestore.rules` (`isAdmin()`, `isSeller()`, … with `get()` fallbacks; rules
are **additive** — a narrower `match` never restricts a broader one, which is why every CF-only
collection is top-level, never under `settings/`) **or** a callable/HTTPS Cloud Function that runs
with the Admin SDK. Nothing in between: no API gateway, no App Check enforcement, no rate limiter
except the OTP caps and `onboarding_rate_limits`. So the two controls are the rules file and the
function bodies, and a function that trusts a client field is a hole regardless of the rules.

## 4. Invariant catalogue — what enforces it, what proves it, how to probe it

| # | Invariant | Enforced by | Proven by | Probe |
|---|---|---|---|---|
| I1 | A role is granted only server-side. `users/{uid}.role`, `isAdmin`, `isSeller`, `sellerId`, `permissions` are blanket-blocked from owner writes; `*Status` can never become `'approved'` by an owner write; no bootstrap-email shortcut anywhere | `firestore.rules` `ownerCannotChangePrivilegedFields()`, `newUserCreateHasNoPrivilegedFields()`; `roleClaims.ts` (no email list); `notifications.ts` `requireAdmin()` read-only; `AdminAccessConfig` defaults to empty | `phase14_rules_test.js` (27), `phase6_admin_bootstrap_test.js`, `phase15_set_user_role_test.js` | as owner: `update users/{me} {role:'admin'}` → denied; grep the three legacy emails → hints/comments only; `node scripts/phase23_deploy_bundle_guard_test.js` → no credential ships in the bundle |
| I2 | Approval is admin-only for sellers, delivery partners and associates; self-apply writes `pending`/`commissionRate:0` only | `ownerCannotApproveSellerStatus()`, `ownerCannotApproveDeliveryStatus()`, `ownerCannotApproveEmployeeStatusOrCommission()`, `ownerCannotSetOnboardingFields()` | `phase14_rules_test.js`, `phase16a_onboarding_rules_test.js` | owner `update employees/{me} {status:'approved'}` → denied; `{status:'pending'}` → allowed |
| I3 | Balance-bearing state is Cloud-Functions-only: `wallets` balance fields, `wallet_transactions`, `wallet_topups`, `seller_payouts`, `employee_payouts`, `referrals`, `coupon_redemptions`, `verified_payments`, `razorpay_orders`, `product_credit_ledger/balances/holds`, `benefit_*` | rules blocks (`allow create: if false` / `write: if false`); `walletBalanceFieldsAreZero()`, `ownerCannotChangeWalletBalanceFields()`; `wallet_provider.dart` has ONE write (zero-balance `.set`) | `phase9_wallet_rules_test.js`, `phaseB_rules_test.js`, `phaseD_rules_test.js`, `phaseD1_fulfilment_rules_test.js` | owner `update wallets/{me} {balance:999999}` → denied; `delete` → denied |
| I4 | No payment-provider secret in any client; `.env` is never a Flutter asset; server secrets bound per function | `pubspec.yaml` ×5 (no `- .env`), `defineSecret` in `payment.ts` + `secrets:[…]` on every importer, `runWith({secrets})` on v1 OTP/email functions | `phase19_client_secret_guard_test.js` (15), `phase18_secret_binding_test.js`; `unzip -l <aab> \| grep flutter_assets/.env` empty | grep `keySecret\|key_secret\|RAZORPAY_KEY_SECRET` in `*.dart` → 0 |
| I5 | A payment counts only after HMAC + live `captured` + `verified_payments` bound to the caller, and is consumed exactly once (`consumedByOrderId` XOR `consumedByOnboardingFor`) | `payment.ts`, `wallet.ts` `verifyWalletTopup`, `createOrder.ts` trust block, `employee/activationCore.ts` | `phase5c_payment_test.js` (6), `phase14_payment_replay_test.js` (6), `phase17_payment_consumption_test.js` (7), `phase9_wallet_topup_test.js` (4) | replay a consumed `razorpayPaymentId` → `failed-precondition`; another user's payment → denied |
| I6 | Orders are created only by `createOrder` (rules `allow create: if false`); price, B2B price/MOQ, stock, coupon, delivery/tax ceilings, associate code, profile completion are server-derived; owner can only cancel; fulfilment writes cannot touch the 20-field denylist | `createOrder.ts`, `orderPricing.ts`, three rule functions on `orders` | `phase5b_*`, `phase7_cart_checkout`, `phase8_b2b_cart`, `phase15_order_integrity` (6), `phase15_rules`, `phase16d1/16d2_*`, `phaseD_rules` | direct `orders` create → denied; owner `update {total:1}` → denied; seller `update {deliveryPartnerId}` → denied |
| I7 | Commission pays only on the transition into delivered/completed, once (`commissionPaid`), never client-side, never at a guessed rate (unresolved → `commission_exceptions`, retryable) | `customer/employeeCommission.ts` `resolveCommissionRate()` | `phase16d1_commission_test.js`, `phase16d2_attribution_test.js` (18) | seed an order with `employeeUid` and no rate → exception doc, `commissionPaid:false` |
| I8 | Product Credit: ledger append-only, projection CF-only, hold settles in full or not at all, reversal re-derives from the transaction snapshot, compliance gate re-read inside `createOrder`'s transaction, the four money flags are hard-blocked from `true` | `productCreditLedger.ts`, `productCreditHold.ts`, `productCreditReversal.ts`, `complianceGate.ts`, rules | `phaseA_*` (19), `phaseB_*` (30), `phaseC_*` (29), `phaseD*_*` | `setBenefitFeatureFlag PRINCIPAL_INTAKE_ENABLED:true` → refused even when approved |
| I9 | OTP: CSPRNG, hash-only comparison, 30 s cooldown, 10/day, no enumeration (`userExists` removed; forgot-password returns `true` on `USER_NOT_FOUND`); fixed `123456` gone from source and production | `common/sendPhoneOTP.ts`, `verifyPhoneOTP.ts`, `sendEmailOTP.ts`, `verifyEmailOTP.ts`; `apps/employee` `EmployeeAuthProvider.sendPasswordReset` | `phase14_phone_otp_test.js`, `phase16_phone_otp_test.js` (13), `phase22_channel_config_test.js` (10), `phase15_email_otp_test.js` (5) | `grep -rn 123456 functions/src` → 0 |
| I10 | Storage: every path explicit, images checked, default deny | `storage.rules` | `phase24_storage_rules_test.js` — 14 blocks, 64 scenarios, positive AND negative per block (SEC-3, 2026-09-04) | `firebase emulators:exec --only storage "node scripts/phase24_storage_rules_test.js"`. **The suite proves what the rules DO, not what they should do:** four scenarios are labelled `OBSERVED-PERMISSIVE` and are open findings A-16/A-17. "images checked" is NOT universally true — `chat/**` and the three `*_documents/**` paths accept any contentType by design or by gap |
| I11 | Transacting requires a completed profile server-side | `createOrder.ts`, `verifyWalletTopup`, `redeemReferralCode`, `completeUserProfile.ts` | `phase16_enforcement_test.js`, `phase16_profile_test.js` | order with `profileCompleted:false` → `failed-precondition` |
| I12 | Deploy safety: every function exported; deploy always `--only functions:<explicit names>`; indexes diffed live before deploy; rules deploy checked against the released app builds | `index.ts`; `promote.md` §4 | `firebase functions:list` reconciliation (48 live, 6 orphans, 16 undeployed at 2026-09-04); `firebase firestore:indexes` diff = 0 would-delete | `node -e "require('./lib/index.js')"` count vs list |
| I13 | Admin callables never overwrite an existing account's password | `createSellerByAdmin.ts`, `createEmployeeByAdmin.ts` throw `already-exists` | `phase14` review; `phase16d1_onboarding_coverage_test.js` | call with an existing email → `already-exists` |
| I14 | Account deletion cascades server-side (`deleteUserData`, deployed 2026-09-03); client never deletes `users/{uid}` directly | `customer/deleteUserData.ts`; `auth_service.dart` `deleteAccount()` calls the callable | `phase17_delete_user_data_test.js` (10/10, real Auth emulator) | pending order → refused; success path deletes the Auth user |

## 5. Gate battery (what `scripts/gate.sh --security` runs, and what each proves)

| Command | Proves | Does NOT prove |
|---|---|---|
| `cd functions && npm run build` | the TS compiles; `lib/` is fresh for the Node suites | behaviour |
| `node scripts/phase19_client_secret_guard_test.js` | no `.env` asset, no secret name in Dart, no `AIza` literal outside the allowlist, env files carry no forbidden key names | secrets in provider dashboards; a key hidden in a file named `firebase_options.dart` (allowlist is by basename) |
| `node scripts/phase18_secret_binding_test.js` | every function that reads a secret declares it | runtime resolution |
| `node scripts/phase23_deploy_bundle_guard_test.js` | no credential ships in the functions bundle: the A-1 file is gone, `functions/scripts` is in the `ignore` list, and no `.js/.ts` under `functions/` assigns a string literal to a pass/password/passwd/pwd/secret/token/credential/apikey-named const or object property (any indentation, one documented allowlist entry) | whether firebase-tools actually excludes the directory at upload time — never observed, because rule 4 bars every `firebase deploy`, dry-run included |
| `node scripts/phase16b4_fee_truthfulness_test.js` | fee copy/interpolation logic | rendered text (needs `phase16b4_fee_single_source_test.js` on the emulator) |
| `--emulator`: `firebase emulators:exec --only firestore,functions,auth "node scripts/<suite>.js"` per suite, fresh emulator | I1–I9, I11, I13, I14 at the rules engine / callable level | production posture (nothing here touches `agrimore-66a4e`); composite-index requirements (the emulator does not enforce them) |
| `node scripts/verify_secrets.js` (`--secrets`, cloud metadata read) | the five secrets exist in Secret Manager and `functions/.env` is complete | the values are correct |

**Non-vacuity rule:** before crediting any "0 offenders" sweep or a rules suite, plant one offender /
flip one assertion and watch it fail. Before crediting an emulator suite, confirm it printed scenario
counts on a **fresh** emulator (`hazards.md`: suites are not idempotent).

## 6. Review procedure by change type

- **`firestore.rules`**: which helper changed and whether it is value-guarded or a blanket denylist
  (both patterns exist, chosen for reasons written in the comments — keep the reason); every new
  financial field in all three order denylists; new collection = own top-level block with a
  positive-control scenario; `isAdmin()` stays unrestricted only where the comment says so; a rule
  that tightens a client write names the app build that already satisfies it (a rules deploy is
  all-or-nothing and broke pre-1.0.7 ordering on 2026-08-31 by owner decision).
- **`storage.rules`**: mirror `isValidFileSize()`/`isImage()`; token-only checks; default deny intact.
- **Cloud Functions**: `request.auth` first; claim-first admin check; all reads before writes in one
  transaction; idempotency anchor doc; `HttpsError` codes/messages stable; secrets declared; export
  added; generation stated (a v1→v2 change of a live function means delete+recreate = downtime =
  owner decision); scheduled functions idempotent; nothing under `functions/scripts/` carries a
  credential (the bundle ships that directory).
- **Shared models (`packages/agrimore_core`)**: four-part pattern; `toJson()` is the live Firestore
  write path (`Timestamp` stays `Timestamp` — never ISO strings there); a new money field → rules
  denylists + `OrderModel`/`WalletModel` consumers in all five apps; five-app analyze.
- **App screens**: no direct write to a CF-only collection; money-path methods (`_placeOrder`,
  `_createOrderInFirestore`, `_createSellerScopedOrders`) diffed byte-for-byte when a screen is
  refactored; both `createOrder` call sites; no `err.toString()` to a user; no credential prompt.
- **`pubspec.yaml` bumps**: a shared-package bump compiles in all five apps (`font_awesome_flutter
  ^11.0.0` broke `apps/admin` without anyone touching it); `pubspec.lock`'s `sdks:` block is the
  real floor, not `environment:`; never re-add `- .env`; never add a payment SDK or `url_launcher`
  to `apps/employee` (Play-safety decision, `decisions.md` §3).
- **Indexes**: `firebase firestore:indexes` live diff; 0 would-delete; a new composite query has its
  entry in the same commit.
- **Android config**: `build.gradle.kts` carries keystore passwords in a tracked file (A-4) — never
  add another credential; `tools:node="remove"` for `AD_ID` stays; `targetSdk` bumps are owner-confirmed.
- **Env / example files**: key names only; `FORBIDDEN_ENV_NAMES` in the guard test is a superset of
  the Secret Manager names + `SMTP_*` + `GEMINI_API_KEY`; never weaken it.

## 7. Adversarial probes (emulator only; never against `agrimore-66a4e`)

```bash
# 0. Fresh emulator, JDK 21, ports free (never stop another session's emulator)
export JAVA_HOME=/opt/homebrew/opt/openjdk@21; lsof -nP -iTCP:8080 -sTCP:LISTEN && echo "8080 HELD — stop"
# A. Rules probe skeleton (mirror functions/scripts/phase5b_rules_test.js): initializeTestEnvironment({projectId:"agrimore-66a4e",
#    firestore:{rules, host:"127.0.0.1", port:8080}}) → withSecurityRulesDisabled to seed → authenticatedContext(uid) → assertFails/assertSucceeds
cd functions && npm run build && firebase emulators:exec --only firestore,functions,auth "node scripts/phase14_rules_test.js"
# B. Callable probe (v2): const wrapped = fft.wrap(require('./lib/index.js').createOrder); await wrapped({data:{...}, auth:{uid}})
#    (v1 callables take (data, {auth}) — phase17_delete_user_data_test.js precedent; set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099)
# C. Secrets in the bundle (after a build)
unzip -l apps/marketplace/build/app/outputs/bundle/release/app-release.aab | grep -c 'flutter_assets/.env'   # must be 0
grep -rnoE "AIza[A-Za-z0-9_-]{30,}" apps packages --include='*.dart' | grep -v firebase_options.dart | sed -E 's/AIza.*/AIza<redacted>/'
# D. Functions reconciliation (read-only)
firebase functions:list --project agrimore-66a4e > /tmp/fl.txt; node -e "console.log(Object.keys(require('./lib/index.js')).sort().join('\n'))" > /tmp/src.txt
# E. Index drift (read-only)
firebase firestore:indexes --project agrimore-66a4e > /tmp/live-indexes.json   # diff by (collectionGroup, fields) against firestore.indexes.json
# F. Direct balance write → denied (phase9_wallet_rules_test.js scenario 3);  G. self-promotion → denied (phase14 scenario 1)
```

## 8. Threat checklist (map each finding to one)

- **Spoofing**: custom-token minting paths (`verifyPhoneOTP`, `verifyEmailOTP`); email enumeration;
  associate code self-attribution; webhook body `notes.userId` trusted (it is not — cross-checked).
- **Tampering**: client-supplied `deliveryCharge`/`tax` (capped ₹1000, A-6); `after` snapshot trust in
  triggers (fixed for reversal, mirrored in commission); index-less queries; `status` vs `orderStatus`.
- **Repudiation**: `auth_logs`/`auth_events` bound to the caller; `compliance_audit_log` append-only.
- **Information disclosure**: `users` read is owner/admin; `settings/*` is world-readable (never put a
  secret or compliance note there); associates see full customer PII on attributed orders (A-8,
  owner-accepted); public GitHub history (A-2).
- **Denial of service**: OTP caps; unbounded `.snapshots()` listeners (bounded in employee app,
  audit pending elsewhere); `MAX_SENDS_PER_DAY` 10 keeps voice bounded.
- **Elevation**: Firestore-doc fallback in `isAdmin()` (safe only because `role` is unwritable);
  admin unrestricted on `orders` update (A-9); the `create_admin.js` credential in the deploy
  bundle (A-1 — removed from the tree by SEC-1; the credential itself still needs owner rotation).

## 9. Open findings register (verified 2026-09-04 at `c8f6f30`; each needs an owner)

| ID | Finding | Evidence | Severity |
|---|---|---|---|
| A-1 | ~~`functions/scripts/create_admin.js` hardcodes an admin email + password (line 6) and calls `updateUser({password})`; `firebase.json` functions `ignore` does not exclude `scripts/`, so it ships inside **every** functions deploy bundle (same class as the deleted `fix_admin.js`)~~ **CLOSED IN CODE** by phase SEC-1 (2026-09-04): file deleted, `scripts` added to the functions `ignore` list, and `phase23_deploy_bundle_guard_test.js` fails if either regresses. | file read; `firebase.json` ignore list; `phase23_deploy_bundle_guard_test.js` | **P1 — STILL OPEN FOR THE OWNER.** Deletion does not invalidate the credential: it remains valid in Auth, in git history, and in already-uploaded source archives. The owner must **rotate that account's password** (D-CREATE-ADMIN) — that is the actual mitigation, and the ignore-list change only takes effect on the next functions deploy. |
| A-2 | Remote `SRIESWARAN01/Agrimore-Full-Project` is **public**; history contains `fix_admin.js` (at `a47eaec`, an ancestor of `origin/master`), the old Gemini key (`c024b3e`), keystore passwords in `build.gradle.kts` | `gh repo view … isPrivate:false` | **P1** — make private (owner); credentials already rotated/revoked per owner |
| A-3 | Whether `admin@agrimore.com` is still a live Auth account under the exposed password | owner-only console check | P1 (owner) |
| A-4 | Release keystore `storePassword`/`keyPassword` in tracked `apps/marketplace/android/app/build.gradle.kts` (no `.jks` tracked) | M-7 | P2 — `key.properties` pattern (gitignored already) |
| A-5 | 6 live functions with no source anywhere (`subscriptionChecker` load-bearing for recurring orders) | `functions:list` vs `lib/index.js` | process — never bare `--only functions` |
| A-6 | `deliveryCharge`/`tax` client-supplied under a ₹1000 ceiling; live for COD via `mobile_cart_screen.dart` | `orderPricing.ts` | P2 — needs a server fee schedule (owner: D-DELIVERY-FEE) |
| A-7 | `mobile_number_screen.dart` writes `users.phone` client-side with no OTP (rules comment leaves `phone` unblocked for it) | `firestore.rules` comment in `ownerCannotChangePrivilegedFields()` | P2 |
| A-8 | Associates read full customer PII incl. GPS on attributed orders | rules `employeeUid` read branch; owner accepted 2026-09-02 | recorded |
| A-9 | `isAdmin()` unrestricted on `orders` update — an admin client can set `productCreditApplied` and mint credit on the next cancellation | `firestore.rules` orders update | owner decision (D-ADMIN-ORDER-TRUST) |
| A-10 | ~~`storage.rules` has no emulator suite~~ **CLOSED** by SEC-3 (2026-09-04): `phase24_storage_rules_test.js` covers all 14 match blocks with 64 scenarios, wired into `gate.sh --emulator`, and `firebase.json` gained the storage emulator (9199) that made a suite possible at all. The other half — `functions/scripts/` bundled into deploys — was closed by SEC-1. | `phase24_storage_rules_test.js`; `gate.sh` emu row | **CLOSED.** Writing the suite surfaced A-16 and A-17 below; closing A-10 does not close those. |
| A-11 | 31 live functions on `nodejs20` (decommissioned **2026-10-30**) | `functions:list` at 2026-09-04: 31 nodejs20 / 17 nodejs22 | **PREPARED, NOT DEPLOYED** by SEC-4 (2026-09-04): both runtime declarations now say `nodejs22` (`firebase.json` `functions[0].runtime` AND `functions/package.json` `engines.node` — they are two separate declarations and both had to move). All 31 have source; all 6 orphans are already `nodejs22`, so the deadline and the no-source problem do not overlap. It is an in-place runtime bump, not gen1→gen2. **Still OPEN until the owner deploys** — the exact 31-name command is in the ledger row for `agrimore/sec4-node22-runtime`. |
| A-12 | `sponsored_banners`/`campaigns` update/delete rules compare `resource.data.sellerId` to `users/{uid}.sellerId`, a field never written anywhere → sellers can never update their own | Phase 15 report; rules lines | P3 (functional) |
| A-13 | Google Maps key in the Android manifest — restriction to package + SHA-1 unverified in GCP | M-8 | owner check |
| A-14 | Play 1.0.8 (`2026090102`) unreleased; since the 2026-08-31 rules deploy, pre-1.0.7 clients cannot place orders or redeem referrals; the `apps/employee` build has never been released | `pubspec.yaml`, memory | owner action (D-PLAY-RELEASE) |
| A-15 | App Check is monitoring-only; `sendPhoneOTP`/`verifyPhoneOTP` are open `onRequest` with CORS `*` (rate-capped) | `functions/src/common/*.ts` | owner decision (D-APPCHECK) |
| A-16 | `chat/{threadId}/{fileName}` in `storage.rules`: read AND write gate only on `isAuthenticated()`, so any signed-in user can read any thread's attachments and write into any thread; the write has no `isImage()`, so an arbitrary contentType is accepted | `phase24_storage_rules_test.js` — three `OBSERVED-PERMISSIVE` scenarios pass on the emulator (SEC-3, 2026-09-04) | **P2** — cross-conversation PII exposure plus unrestricted upload. Fixing needs its own phase: a storage-rules tightening is a live rules deploy and carries B2B_PHASE_SEQUENCING (which released client satisfies the new rule). |
| A-17 | `delivery_proofs/{fileName}` in `storage.rules`: read gates only on `isAuthenticated()`, so any signed-in user can read every delivery-proof photo; those photos routinely carry addresses and customer detail | `phase24_storage_rules_test.js` — one `OBSERVED-PERMISSIVE` scenario passes on the emulator (SEC-3, 2026-09-04) | **P2** — same phase and same sequencing caveat as A-16. |
| A-18 | `isEmployee()` is defined in `storage.rules` but referenced by no `match` block (dead helper) | grep: one occurrence, the definition itself | P4 — cosmetic; remove it in whatever phase next edits `storage.rules`, never on its own. |
| A-19 | `functions/package.json` `scripts.deploy` was `npm run build && firebase deploy --only functions` — a BARE `--only functions`, the exact form that offers to DELETE the 6 live functions with no source | file read during SEC-4 | **CLOSED by SEC-4** (2026-09-04): the script is removed and replaced by a self-documenting key naming the 6 orphans and the correct explicit-name form. Nothing invoked it. |

## 10. Reporting

```
SECURITY LANE — <phase>
Verdict: PASS | PASS_WITH_FINDINGS | BLOCKING
Findings (most severe first): ID · severity (P0/P1/P2/P3) · invariant (I#) · threat class · path:line · evidence (command + output) · fix · suite that will catch a regression
Probes run: command · result · what it proves (emulator only)
Gates run: from gate.sh table (exit codes; first failure by name; ambient reds attributed)
Deploy consequence: exact `firebase deploy --only …` by name, or NONE — never run
Not verified: explicit list
Owner decisions: from decisions.md §6 touched by this change
```

`BLOCKING` = any P0, any new P1 without a mitigation in the same phase, any invariant I1–I14 weakened,
any secret value found in the diff, any client write path to a CF-only collection, any bare
`--only functions` or `functions:delete` in a script or doc, any `.env` asset line.
