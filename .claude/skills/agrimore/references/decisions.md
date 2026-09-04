# Decisions to protect — owner-made, locked, superseded, and open

Read before writing any phase contract. Classification tags are binding. Where a document in the
repository contradicts a newer verified decision here, keep the newer decision and record the
supersession — never silently reopen a closed question. **Authority order:** `CLAUDE.md` → this
file → the two memory directories (`…-Clients-Agrimore/memory/` current; `…-Agrimore-Full-Project/
memory/` archive, 20 topic files). `CURRENT` facts were measured 2026-09-04 at `main` = `c8f6f30`.

## 1. Identity, repository, branch model — OWNER_DECISION 2026-09-04

- Product: **Agrimore** — "AgriMore — Empowering Farmers, Connecting Markets": an India-focused
  (Tamil Nadu) agricultural marketplace; INR; Razorpay + COD; a retail (B2C) marketplace with a
  toggleable B2B mode and a Sales Associate commission programme; a Customer Product Benefit
  Program (Product Credit) built but flag-gated off. Firebase project `agrimore-66a4e`, live.
- Root: `/Users/saai_siddharth/Projects/Clients/Agrimore`, **flat** (D-ROOT: the owner flattened
  the nested `Agrimore-main/` layout at `c8f6f30` and moved `.git` here; the 2026-08-24 "keep the
  nesting" decision is SUPERSEDED). Copies under `Projects/Clients/Clone/` are history.
- Remote: `https://github.com/SRIESWARAN01/Agrimore-Full-Project` (public; `master` at `0ea1e53`).
  The owner pushes; the machine's `gh` login is `Edynox-hq` and has no write access.
- Commit identity (D-ID): **`Agrimore <agrimorein@gmail.com>`**, author and committer, repo-local
  config, **no `Co-Authored-By` trailers** (46 exist historically; history is not rewritten).
- Branch model (D-BRANCH): `master` renamed to `main`; `develop` = integration + local end-to-end;
  `staging` = pre-production; promotion fast-forward only with the owner's word. D-STAGING: until a
  second Firebase project exists, `staging` = the branch plus a full emulator sweep; it never points
  at `agrimore-66a4e`. D-HOME: the skill is tracked at `.claude/skills/agrimore/`. D-LEDGER:
  `docs/active/BRANCH_DISPOSITIONS.md` is the only registry — no `PROMPTS.md`, no execution ledger.
- D-UIUX: the uiux lane enforces consistency through `packages/agrimore_ui`; brand/marketing is HOLD.
- Deploy authority (standing, 2026-08-25 →): **never `firebase deploy` without the owner's word for
  that specific deploy in the same conversation; functions always by explicit name.** The agent
  never deploys under this skill at all — it hands the command over.

## 2. Surfaces — VERIFIED_REPOSITORY_FACT

```
apps/marketplace   customer app (B2C + B2B toggle; phone-OTP login; Play 1.0.7 live, 1.0.8 unreleased; web build real)
apps/admin         admin panel (email/Google login; GoRouter; parallel theme set in lib/app/themes/)
apps/seller        seller app (MVP; inline theme)             apps/delivery   delivery-partner app (MVP; inline theme)
apps/employee      Sales Associate app (11–12 files; phone-OTP or email login; dashboard/orders/wallet/payouts; never released)
packages/agrimore_core · agrimore_services · agrimore_ui      functions/ (58 exports)   firestore.rules · storage.rules · indexes
```
The FULL_AUDIT doc's `apps/marketplace-web` does not exist; the MASTER_ARCHITECTURE doc's
`warehouses`/`inventory` collections are TARGET/PROVISIONAL, not CURRENT (no such rules blocks).

## 3. Locked product decisions (do not re-litigate)

**B2B / Employee (2026-08-25):** self-apply + admin-direct onboarding mirroring sellers · commission
credited only on the delivered/completed transition, idempotent · a cart is fully B2C or fully B2B ·
no "verified business" gate — the associate code is what is validated · `orderMode` (B2C/B2B) is a
separate field from `orderType` (subscription cadence) · employees reuse `wallets`/`wallet_transactions`.

**Sales Associate onboarding fee (2026-08-30, CTO-made under owner delegation, owner-ratified):**
user-facing term "Sales Associate", internal identifiers unchanged · the ₹500 payment surface lives
in `apps/marketplace` **web only** — Android/iOS binaries carry no in-app purchase flow, only
informational copy plus an external pointer (Play policy; the mobile wording is a protected surface;
never add a payment SDK or `url_launcher` to `apps/employee`) · refunds are record-only (never the
Razorpay refund API) · associates will place orders for customers AND customer-entered attribution
stays (the first is not built; "book orders" was declined 2026-09-03) · commission extends to retail
orders with an `employeeUid` · never guess a rate (`commission_exceptions`) · B2C never blocks a sale
on a bad code; B2B hard-fails.

**Customer Product Benefit Program (2026-08-30):** Case A ("money in, returned at maturity") is the
locked structure — a deposit in substance under the BUDS Act 2019, so written legal clearance is
required before any principal-intake/return code ships; `PRINCIPAL_INTAKE_ENABLED`,
`PRINCIPAL_RETURN_ENABLED`, `COMPOUNDING_ENABLED`, `CASH_REDEMPTION_ENABLED` are hard-blocked from
`true`; the compliance gate is server-side and load-bearing; credit and cash are never summed;
Product Credit is its own ledger, never `wallets.balance`. Phases A–E built; all flags `false` in
production; nothing enrolled.

**Deploy decisions taken (all owner-authorised in conversation):** rules deployed in full 2026-08-31
knowing pre-1.0.7 clients lose ordering · the six money-path functions moved Gen1→Gen2 by
delete+recreate, one at a time, 2026-09-03 · `deleteUserData` and the 8 onboarding functions
deployed 2026-09-03 · `createEmployeeByAdmin` phone-linking deployed 2026-09-03 · associates seeing
customer PII on attributed orders accepted 2026-09-02 · `splitCartIntoOrders` and
`resetUserPassword` deleted from production 2026-08-30.

## 4. Superseded assumptions — must not return

- The nested `Agrimore-Full-Project/Agrimore-main/` root, and "the owner declined flattening" —
  flattened at `c8f6f30`. `.firebaserc` "only in Agrimore-main" — it is at the root now.
- "Four apps" — five (`apps/employee` exists since Phase 4). "B2B/Employee is 100% unimplemented"
  — implemented, committed (`f3270c5` →), backend live.
- "No tests / no test suite" — 3 Dart test files + 55 emulator suites + 3 no-emulator guards.
- "Phone OTP is `123456`" / "nothing is deployed" — closed in production 2026-09-02.
- "Android emulator unavailable" — the harness simulator tool was gated off on 2026-08-30, but
  `flutter run` on AVD `Pixel_8_API_35` worked on 2026-09-03; iOS remains unavailable.
- `master` as the production branch name; the `.local` commit identity.
- `legacy_archive/` as a reference (deleted 2026-08-24); `cartSplitting.ts` (deleted, and its live
  function deleted); `fix_admin.js` (deleted `8fd06b2`); `env_config.dart`/`razorpay_config.dart`
  (deleted); `- .env` as a Flutter asset (removed Phase 19).
- `font_awesome_flutter` below `^11.0.0` (reopens the `IconData final class` crash).
- Treating `AGRIMORE_MULTIVENDOR_ARCHITECTURE.md` or `AGRIMORE_FULL_AUDIT.md` as current.
- "Uncomment the location filter in `database_service.dart`" — that line filters a field
  (`location`) the schema no longer uses; 62 of 64 live products carried no location on 2026-08-26.
- "Orphan functions are disposable" — `subscriptionChecker` and the greeting jobs succeed daily and
  push real notifications; source is unrecoverable.
- "`firebase deploy --only firestore:indexes` is a no-op/safe" — it was silently a no-op until
  `firebase.json` gained `"indexes"` on 2026-09-03; now it is real and must be preceded by the live diff.
- Serialising dates as ISO strings in `ProductModel.toJson()` — that method is the live Firestore
  write path; the fix belongs in the cache layer only.

## 5. Owner decisions ledger (dated)

2026-08-24 delete `legacy_archive/` · 2026-08-25 B2B/Employee plan, Phase 5c next, deploy of
`createOrder` + rules · 2026-08-26 hold the rules deploy for wallet lockdown (Play tail) · 2026-08-27
Play release 1.0.7, push declined "for now" · 2026-08-30 Case A, surgical wallet rules deploy,
delete `splitCartIntoOrders`, fee module decisions delegated to the CTO · 2026-08-31 full rules
deploy accepted with its consequence · 2026-09-02 OTP functions deploy, PII position accepted ·
2026-09-03 Gen2 delete+recreate, onboarding-fee and `deleteUserData` deploys, credentials "already
rotated", `targetSdk 36` bump confirmed as theirs, "book orders" declined · 2026-09-04 flattening,
D-ID, D-BRANCH, D-UIUX, D-STAGING, D-HOME, D-LEDGER.

## 6. Open owner decisions (do not resolve silently)

| ID | Question | Safe default while open |
|---|---|---|
| D-PRUNE | `git worktree prune` the stale `claude/bold-spence-01813b` record and delete that branch? | leave both; the row records it as `MERGED` |
| D-CREATE-ADMIN | delete/move `functions/scripts/create_admin.js` (hardcoded admin credential in the deploy bundle) and rotate that account | treat as P1 (A-1); the next security phase removes it; owner rotates |
| D-REPO-VISIBILITY | make `SRIESWARAN01/Agrimore-Full-Project` private (A-2) | never add CI secrets while public |
| D-ADMIN-ACCOUNT | is `admin@agrimore.com` still live under the exposed password (A-3)? | owner console check |
| D-ORPHANS | keep or delete the 6 orphan functions (product decision — greetings, retries, `subscriptionChecker`) | keep; never name them in a deploy |
| D-NODE20 | plan the Node 20 → 22 runtime move for 31 functions before 2026-10-30 | a dedicated phase; deploy by explicit names |
| D-STAGING-PROJECT | create a staging Firebase project? | `staging` = branch + emulator sweep |
| D-APPCHECK | flip App Check to enforcement (`enforceAppCheck`) after a debug-mode activation log exists? | monitoring only |
| D-LOCATION-BACKFILL | backfill product locations or adopt "no location = visible everywhere" before any server-side filter | no server filter |
| D-MININSTANCES | warm-capacity budget for hot-path callables (all `minInstances: 0`) | 0 |
| D-DELIVERY-FEE | a server-side delivery/tax schedule (today client-supplied under ₹1000) | keep the ceiling; flag A-6 |
| D-ADMIN-ORDER-TRUST | restrict `isAdmin()` writes to product-credit fields on `orders` (A-9) | unchanged; recorded |
| D-KEYSTORE-PASSWORDS | move gradle signing passwords to a gitignored `key.properties` (A-4) | do not add more |
| D-PHONE-WRITE | close the client-side `users.phone` write path (A-7) | leave; `changePhoneNumber` is the verified path (undeployed) |
| D-PLAY-RELEASE | release marketplace 1.0.8 (`2026090102`) and the first `apps/employee` build | owner-only; pre-1.0.7 users cannot order meanwhile (A-14) |
| D-DLT | complete TRAI DLT registration so SMS OTP can replace voice (`PHONE_OTP_SMS_ENABLED`) | voice-primary stays |
| D-ASSOCIATE-SETTINGS | create `settings/associate_onboarding`, `settings/commission.employeeRetailRate`, and the Razorpay webhook URL for `razorpayOnboardingWebhook` | the flow fails closed; nothing pays |
| D-DASHBOARD-SPEC | the "25-item associate dashboard spec" exists nowhere — supply it or drop it | do not invent it |
| D-UNDEPLOYED-16 | when to deploy the 16 source-only functions (benefit program, `setUserRole`, `changeEmail/PhoneNumber`, quote/hold/reversal) | none are needed while the flags are off; `setUserRole` is the only admin tool for roles |
