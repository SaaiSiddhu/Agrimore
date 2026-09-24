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

**Delivery fee schedule — D-DELIVERY-FEE (2026-09-07, resolves the row in §6):** per-seller, and each
seller picks their own fee shape (flat / slab / distance) for their own orders — the owner's own
answer explicitly listed all four shapes plus "ALL" then, on clarification, chose the broadest
option over a single-shape default. This is the largest of the four shapes offered; scope a phase
accordingly (a seller-side fee-schedule config screen, a schema for per-seller fee rules, and the
`createOrder.ts`/`orderPricing.ts`/`quoteOrderWithCredit` read path — `createOrder.ts` remains the
single most collision-prone file in this codebase, so this phase needs the same care RFQ-3 took to
avoid touching its own transaction shape carelessly).

**Referral payout timing — D-REFERRAL-TIMING (2026-09-07, resolves FIX-15B):** a referral payout
happens only after the referred user's first delivered order, not immediately on redemption (today's
behaviour). `wallet.ts:532`'s `isCompleted: false` field, currently write-only and never read,
becomes load-bearing: the redeemer's own first delivered order must flip it and pay the referrer at
that point, not at redemption time. Redemption itself is unaffected; only WHEN the referrer's payout
fires changes.

**Seller AI-connect funding — D-SELLER-AI-FUNDING (2026-09-07, resolves AI-4):** sellers fund the
₹50 AI-connect activation fee via a direct Razorpay charge at connect time, mirroring
`createAssociateOnboardingPayment.ts`'s own ₹500 Sales Associate onboarding fee pattern exactly — not
a wallet debit (apps/seller has no wallet system and none is being built for this). `connectAiProvider`
(AI-1) currently debits `wallets/{uid}.balance` unconditionally; the seller-side connect flow needs
its own Razorpay order-creation + verification path (or a seller-specific variant of
`connectAiProvider`) rather than reusing that debit, since sellers have no such balance to debit from.

**Seller AI-connect fee platform restriction — D-SELLER-AI-WEB-ONLY (2026-09-08, resolves AI-4C, answered via AskUserQuestion):** the ₹50 seller AI activation fee's Razorpay checkout is web-only on apps/seller, mirroring the Sales Associate onboarding fee's own D2 (Play-safety, external-payment-steering) restriction exactly — same `kIsWeb`-gated screen, same `openCheckoutForExistingOrder` pattern via `dart:js_interop` (no `razorpay_flutter` package needed at all, since D-SELLER-AI-FUNDING above already established the payment shape mirrors `createAssociateOnboardingPayment.ts`'s own existing-order flow, not a fresh client-side order creation). AI-4's own claim-time scoping never explicitly resolved this platform question; AI-4C's own investigation surfaced it fresh (the seller AI fee needs a NEW payment sheet per activation, unlike AI-3's customer-side flow which debits an existing wallet and never opens Razorpay at all) and the owner chose the cautious, precedent-matching option over asserting a B2B/merchant-tool exemption this codebase has no authority to claim on its own.

**Seller AI bespoke analytical tools — D-AI4D2-SCOPE (2026-09-08, resolves AI-4D-2, answered via
`AskUserQuestion`):** **stock prediction** reuses the existing low-stock threshold
(`setLowStockThreshold`, FIX-9) rather than a new order-velocity forecast — surface `currentStock` vs.
that threshold, never assert a specific days-until-stockout number. The owner chose the safest option
over a genuine forecasting heuristic, matching this session's own reasoning that a wrong prediction
shown confidently to a seller is worse than not having the feature. **Pricing insights** surfaces the
seller's own price history only — no cross-seller/category-average aggregation, and no new tool
computing one; this is the narrowest of the three options offered (the other two were a new
cross-seller aggregation query, or no new tool at all and letting Gemini reason freely from the
existing product/order tools). Both answers narrow AI-4D-2's own scope considerably: the low-stock
option needs `getMySellerProducts`/`getMySellerProductDetails` (already shipped, AI-4D) to also
surface `lowStockThreshold` alongside `stock` — a small addition to the client-side tool-dispatch layer
(`apps/seller/lib/providers/seller_ai_chat_provider.dart`), not a new backend tool at all; the pricing
answer likely needs NO new tool whatsoever, since the same two existing tools already return
`salePrice`/`originalPrice`. Re-scope AI-4D-2's own contract fresh at claim time against this — it may
turn out to need no `functions/**` change at all, contradicting its own original `may_write` guess.

**Sales Associate commission — three money-policy decisions resolved 2026-09-07 (FIX-4B, findings
N-9/N-29/N-27):**
- **D-COMMISSION-REVERSAL (N-9):** when a delivered order paying commission is later cancelled/
  reversed, claw the commission back by debiting the associate's wallet balance directly — the
  balance CAN go negative as a result (not floored at 0, not a compensating ledger-only entry).
- **D-COMMISSION-BASE (N-29):** commission is computed on the goods subtotal only, excluding
  delivery charge and tax — changes what every associate earns under already-configured rates going
  forward (not retroactive to commission already paid).
- **D-PAYOUT-MIXED-CATEGORY (N-27):** a seller payout on a mixed-category order uses a weighted
  average of each item's own category commission rate, not the first item's category rate alone.

**CORS origin narrowing — D-CORS-ORIGINS (2026-09-07, resolves FIX-12B):** leave the wildcard (`*`)
CORS origin on `sendPhoneOTP`/`sendEmailOTP` for now. The owner does not currently have the exact
Hosting custom-domain mapping in hand to narrow it safely, and getting it wrong risks breaking OTP
login for real customers on the live production web app; the exposure is accepted a while longer
rather than guessed at. Reopen this once the real domain list is available.

**Ten-collection rules coverage — D-COLLECTION-COVERAGE (2026-09-08, resolves FIX-6B, answered via
`AskUserQuestion`):** ALL ten collections are KEPT — every one gets a proper `firestore.rules` block
rather than any client code being deleted: `subscriptions` (backs Auto-Delivery; also read by the
live, source-less `subscriptionChecker` function — that function's own separate fate is still
D-ORPHANS, unresolved), `sellerRequests`, `scratchCards`, `transactions` (owner should double-check
this isn't an unintentional duplicate of the already-covered `wallet_transactions` — flagged, not
resolved, by this decision), `recent_searches`, `trending_searches`, `masterProducts`, `centers`,
`product_price_mappings`, `subscription_plans`. No client-code deletion workstream applies to this
phase at all now — WS3 (write rules blocks) is the entire remaining scope, WS4 (delete dead code) is
moot.

**Business Profile scope — D-BUSINESS-PROFILE-SCOPE (2026-09-07, resolves BUSINESS-NETWORK-1):**
the "Social" tier — buyers can follow a seller and receive a notification when that seller lists a
new product. This is the largest of the four scope options offered (beyond it: business hours,
certifications, a name+description+product-list page) and needs its own notification-fan-out design
(a `followers` sub-collection or equivalent, a trigger on new-product-create that notifies followers)
— treat it as a multi-workstream phase, not a single bounded slice, and re-derive the actual current
shape of `product_details_screen.dart`/the notification pipeline fresh at claim time rather than
trusting this summary's own phrasing.

**Business Profile shape — D-BUSINESS-PROFILE-SHAPE (2026-09-08, resolves the three open questions
BUSINESS-NETWORK-1's own claim-time investigation raised, answered via `AskUserQuestion`):** a
content feed IS in scope for this phase (not carried over from a broader draft — a deliberate
widening of D-BUSINESS-PROFILE-SCOPE above). A seller's post may contain text, an image, and/or a
tag/link to one of their own existing products (all three, not a single fixed shape) — image posts
need `storage.rules` coverage and an upload UI; product-tag posts deep-link into the existing
catalog. New-product-follow notifications (and, by extension, feed posts) go out on BOTH channels:
in-app (a notifications surface inside `apps/marketplace`) AND push (reusing the existing
`sendBroadcastNotification`/`sendNotificationToUser` functions), not one or the other. This
materially grows the phase beyond its original "Social tier" framing — expect a scope split at claim
time (e.g. profile+follow+notify as one slice, the feed/post-authoring UI as a following one),
mirroring how AI-1/AI-2/AI-3 and AI-4/AI-4B/AI-4C/AI-4D were each split.

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
D-ID, D-BRANCH, D-UIUX, D-STAGING, D-HOME, D-LEDGER · 2026-09-07 D-DELIVERY-FEE (per-seller,
per-seller-chosen shape), D-REFERRAL-TIMING (pay on first delivered order), D-SELLER-AI-FUNDING
(direct Razorpay charge, not a wallet debit), D-COMMISSION-REVERSAL (debit wallet directly, can go
negative), D-COMMISSION-BASE (goods subtotal only), D-PAYOUT-MIXED-CATEGORY (weighted average by
category), D-CORS-ORIGINS (leave wildcard for now), D-BUSINESS-PROFILE-SCOPE (Social tier: follow +
new-product notifications) — all answered via `AskUserQuestion` in the running session, not
inferred. FIX-5B's own question (has a `confirmDelivery`-using `apps/delivery` build been released
and adopted?) got "not sure / need to check" — still genuinely open, not decided.
2026-09-08 D-COLLECTION-COVERAGE (all ten FIX-6B collections kept, none deleted),
D-BUSINESS-PROFILE-SHAPE (feed in scope; posts carry text/image/product-tag; notifications go both
in-app and push) — both answered via `AskUserQuestion`. FIX-5B's own question was answered with a
concrete fact this time, not "not sure": the live `com.agrimore.delivery` Play Store build was last
updated **May 6**, well before `confirmDelivery` was even added (2026-09-05) — so no released build
uses it yet. FIX-5B stays genuinely blocked; this needs re-checking once a new `apps/delivery` build
actually ships.
2026-09-08 D-SELLER-AI-WEB-ONLY (the ₹50 seller AI activation fee's Razorpay checkout is web-only,
mirroring the Sales Associate onboarding fee's own D2 Play-safety restriction) — answered via
`AskUserQuestion`, resolves a platform question AI-4's own claim never settled.
2026-09-08 D-AI4D2-SCOPE (stock prediction reuses the existing low-stock threshold, not a new
forecast; pricing insights surfaces the seller's own price history only, no cross-seller aggregation)
— answered via `AskUserQuestion` at session-stop, when AI-4D-2 was the only decision-blocked phase
with no independent work left; unblocks AI-4D-2 for the next tick.

### D-DEBUG-MOCK-OTP — OWNER_DECISION 2026-09-23 (chat)

Mock OTP on the LIVE project for debug builds, any number. Offered three
options (debug+allowlist recommended / debug any number / emulator only) with
the risk stated; owner chose "Debug builds, any number". Implemented by SEC-P0b:
sendPhoneOTP skips delivery and returns the code when `debugMock === true` (sent
only by kDebugMode builds) or the number is on the auth_test_mode allowlist.
ACCEPTED RISK: the flag is an unverifiable client claim — anyone can call the
endpoint with it and sign in as any user. Revisit before any public launch.
Supersedes 7dfeb0d's unconditional `testMode = true` (which also hit release builds).

### D-DLV-DISPATCH · D-DLV-NO-TAKER · D-DLV-LIST · D-DLV-ALERT — OWNER_DECISION 2026-09-23 (AskUserQuestion)

Rider dispatch for the delivery-app redesign (programme `agrimore-delivery-redesign`). Asked with a
recommended option each; answers recorded verbatim in intent:
- **D-DLV-DISPATCH** — offer a packed order to the **3 nearest** eligible riders at a time, 30 s per
  offer, widening 5 → 8 → 12 km; first to accept wins. (Chosen over broadcast-to-all and one-at-a-time.)
- **D-DLV-NO-TAKER** — **both**: after the third wave flag the order for admin (`delivery_dispatch.
  needsAdmin`) **and** keep re-offering every 2 min until a rider accepts or an admin assigns.
- **D-DLV-LIST** — the rider app's platform-wide "Available Orders" list is **replaced** by offers;
  customer phone/address stay hidden until a rider accepts.
- **D-DLV-ALERT** — **both**, "as like Zomato/Swiggy": a loud high-priority notification on its own
  `delivery_offers` channel **and** a full-screen ringing alert over the lock screen. The owner
  accepted that Google Play restricts full-screen intents to calling/alarm apps on Android 14+: the
  Play Console declaration is the owner's, per release.

Implemented server-side by DLV-2A (`functions/src/delivery/dispatch.ts`); the app side is DLV-2B.

### D-DLV-BG · D-DLV-GEOFENCE · D-DLV-ETA · D-DLV-OTPLOCK — OWNER_DECISION 2026-09-23 (AskUserQuestion, plan DLV-3)

Live tracking for the delivery-app redesign. Each asked with a recommended option; the owner took the
recommendation every time:
- **D-DLV-BG** — while a rider is **online**, location keeps flowing with the app in the background, via a
  persistent "You're online" foreground-service notification (Zomato/Swiggy style). Not limited to active
  orders; not foreground-only. The Play Console foreground-service (location) declaration is the owner's.
- **D-DLV-GEOFENCE** — "Arrived at store" / "Picked up" / "Delivered" are **never blocked** on distance; a tap
  more than **300 m** from the store/customer (or from a mocked location) is recorded and shown to admin.
- **D-DLV-ETA** — the customer's ETA is a **free, stage-aware estimate** (road factor × straight line at an
  average bike speed; rider→store→customer before pickup). No Google Routes billing.
- **D-DLV-OTPLOCK** — proved 2026-09-23 on the rules emulator: the assigned rider can write `delivered`
  directly, skipping pickup and the OTP; the released Play rider build marks delivery exactly that way. The
  rules lock (rider status writes only via callables) is **release-gated**: phase DLV-3D, only after the
  owner confirms the new rider app is released and adopted. Never lock it earlier — it breaks the live app.

DLV-3A (rider location), DLV-3B (customer tracking), DLV-3C (server-checked steps), DLV-3D (the lock).

**D-DLV-BG-CLOSE — OWNER_DECISION 2026-09-23 (AskUserQuestion, during DLV-3A).** The DLV-3A device run showed
geolocator's foreground service stops when the app's activity is destroyed (Back on the home screen, swipe from
Recents, OS reclaim) — the plugin disposes its stream when its Flutter engine detaches. Chosen: **handle Back now**
(while online, Back moves the app to the background instead of closing it) and make **surviving swipe-away** its own
phase (a native location service independent of the Flutter screen) **before the Play release**. Meanwhile a
swipe-away fails safe: the server takes the rider offline after 15 min and pushes them.

### D-DLV-NATIVE-LOC · D-DLV-BGLOC-ALWAYS · D-DLV-BATTERY — OWNER_DECISION 2026-09-23 (AskUserQuestion, plan DLV-3A2)

- **D-DLV-NATIVE-LOC** — location while online is sent by a **native Kotlin foreground service** (fused location,
  writes Firestore as the signed-in rider), not a Flutter background plugin. Independent of the Flutter screen.
- **D-DLV-BGLOC-ALWAYS** — riders are asked for **"Allow all the time"** (ACCESS_BACKGROUND_LOCATION) so the service
  restarts after Android kills the app. The owner accepts the Play background-location declaration, demo video and
  review risk. (Chosen over the recommended while-in-use-only.) A rider who declines can still go online.
- **D-DLV-BATTERY** — a **one-time guide** that opens the phone's settings for the app (battery / autostart); no
  REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission.

Implemented by DLV-3A2 (RiderLocationService.kt).

### D-DLV-ROUTES — OWNER_DECISION 2026-09-23 (AskUserQuestion, during DLV-3B)

The owner asked for road-following routes and a Zomato/Swiggy-style tracking screen. Chosen: **Google Routes API**
(two-wheeler, traffic-aware), called **only from the server** (`refreshDeliveryRoute`, key in the
`GOOGLE_ROUTES_API_KEY` secret) — re-routed on the first fix, at pickup, when the rider strays > 150 m, or every
5 min, never within 20 s, at most 30 per order (~6–10 calls per order; 35,000 free calls/month on the India Pro tier,
then ~$3 per 1,000). **Partly supersedes D-DLV-ETA**: when a fresh route matches the stage the ETA counts its
traffic-aware duration down; the free straight-line estimate remains the fallback. Owner action: enable the Routes
API, create a server key restricted to it, `firebase functions:secrets:set GOOGLE_ROUTES_API_KEY`. Also asked: the map
disappears once delivered (a receipt view instead).
Extended the same day (owner: the rider must get the route too, 'exactly like Zomato/Swiggy'): the **rider app draws
the same `delivery_tasks/{id}.route`** on its active-order screen and hands turn-by-turn to **Google Maps in
two-wheeler mode** (`google.navigation:q=lat,lng&mode=l`) — Agrimore does not build its own voice navigation.
The rider app's Maps SDK key comes from `key.properties` (`mapsApiKey`), never tracked.

### D-DLV-RIDERALLOW — OWNER_DECISION 2026-09-23 (AskUserQuestion, plan DLV-3C)

A rider may no longer set `cancelled` or move an order backwards — closed NOW in DLV-3C with a rules allow-list
(forward rider steps only; nothing on a finished order), because the released rider app never writes either. The
direct `delivered` write stays until DLV-3D (D-DLV-OTPLOCK). Rider steps and "Seller not ready" go through
`advanceDeliveryStep` / `releaseDeliveryOrder`; a step more than 300 m from its place, on a mocked location or with
no location is flagged for admin, never refused (D-DLV-GEOFENCE).

### D-DLV-PAY / D-DLV-COD / D-DLV-PAYOUT / D-DLV-BANK — OWNER_DECISIONS 2026-09-23 (AskUserQuestion, plan DLV-4)

- **D-DLV-PAY** rider pay per delivered order = base + per-km of the store→customer road distance + waiting beyond
  10 min at the store, computed on the server at delivery (never from the customer's delivery charge); admin-set rates
  in `settings/rider_pay`, seeded ₹25 base, ₹6/km, ₹1/min, 25 km cap; the offer shows an estimate.
- **D-DLV-COD** COD cash a rider holds is netted from the weekly payout; at or over the cash limit (seed ₹2,000) the
  rider gets no COD offers until admin records a deposit.
- **D-DLV-PAYOUT** weekly statements (Monday 00:30 IST); admin pays by bank/UPI and records the reference, as for
  sellers. RazorpayX instant payouts are a later phase.
- **D-DLV-BANK** riders request bank-detail changes; admin approves or rejects; a statement waits while one is pending.

### D-SELLER-OWN-DS — OWNER_DECISION 2026-09-24 (chat, phase SELLER-REDESIGN-1)

Owner: *"seller app should be canonical but not to make canonical other apps also,.. seller app should have its
own desgin system , and other apps should have its own system,."* The seller app's design system (tokens, theme,
typography, icons, formatting, components) lives inside `apps/seller/lib/design_system/`; the shared
`packages/agrimore_ui` Workspace system keeps serving the Sales Associate and Delivery apps and is not changed for
the seller. Supersedes ADR-S01/S02/S06/S07 and the uiux lane's "reuse `agrimore_ui` first / ZERO_NEW_WIDGETS" rule
**for `apps/seller` only**; the zero-literal rule (ADR-S04) still applies there, with `lib/design_system/` as the
seller's "system itself" (canon_check skips it, like `lib/l10n/`).

## 6. Open owner decisions (do not resolve silently)

| ID | Question | Safe default while open |
|---|---|---|
| D-PRUNE | Delete the `claude/bold-spence-01813b` BRANCH? (The stale worktree RECORD is already gone: `merge.md` §4's disposition command carried a bare `git worktree prune`, which pruned it during the SEC-1 merge on 2026-09-04. SEC-2 removed that bare prune — see `merge.md` §4.) | leave the branch; its tip `0ea1e53` is an ancestor of `main`, and the ledger row records it as `MERGED` |
| D-CREATE-ADMIN | **Rotate that admin account's password.** (The code half is DONE: phase SEC-1 deleted `functions/scripts/create_admin.js` on 2026-09-04 and excluded `functions/scripts` from the deploy bundle.) | STILL OPEN — P1. Deletion does not invalidate the credential: it stays valid in Auth, in git history, and in already-uploaded source archives. Only the owner can rotate it. A-1 is CLOSED IN CODE, OPEN IN PRODUCTION. |
| D-REPO-VISIBILITY | make `SRIESWARAN01/Agrimore-Full-Project` private (A-2) | never add CI secrets while public |
| D-ADMIN-ACCOUNT | is `admin@agrimore.com` still live under the exposed password (A-3)? | owner console check |
| D-ORPHANS | keep or delete the 6 orphan functions (product decision — greetings, retries, `subscriptionChecker`) | keep; never name them in a deploy |
| D-NODE20 | **When to run the prepared Node 22 deploy** (deadline 2026-10-30). The code half is DONE: SEC-4 moved both runtime declarations to `nodejs22` and produced the exact 31-name command. | STILL OPEN — the owner runs the deploy. It is an in-place runtime bump (no gen change, no delete+recreate, no outage window); the 6 orphans are already `nodejs22` and must never be named. |
| D-STAGING-PROJECT | create a staging Firebase project? | `staging` = branch + emulator sweep |
| D-APPCHECK | flip App Check to enforcement (`enforceAppCheck`) after a debug-mode activation log exists? | monitoring only |
| D-LOCATION-BACKFILL | backfill product locations or adopt "no location = visible everywhere" before any server-side filter | no server filter |
| D-MININSTANCES | warm-capacity budget for hot-path callables (all `minInstances: 0`) | 0 |
| D-ADMIN-ORDER-TRUST | restrict `isAdmin()` writes to product-credit fields on `orders` (A-9) | unchanged; recorded |
| D-KEYSTORE-PASSWORDS | move gradle signing passwords to a gitignored `key.properties` (A-4) | do not add more |
| D-PHONE-WRITE | close the client-side `users.phone` write path (A-7) | leave; `changePhoneNumber` is the verified path (undeployed) |
| D-PLAY-RELEASE | release marketplace 1.0.8 (`2026090102`) and the first `apps/employee` build | owner-only; pre-1.0.7 users cannot order meanwhile (A-14) |
| D-DLT | complete TRAI DLT registration so SMS OTP can replace voice (`PHONE_OTP_SMS_ENABLED`) | voice-primary stays |
| D-ASSOCIATE-SETTINGS | create `settings/associate_onboarding`, `settings/commission.employeeRetailRate`, and the Razorpay webhook URL for `razorpayOnboardingWebhook` | the flow fails closed; nothing pays |
| D-DASHBOARD-SPEC | the "25-item associate dashboard spec" exists nowhere — supply it or drop it | do not invent it |
| D-UNDEPLOYED-16 | when to deploy the 16 source-only functions (benefit program, `setUserRole`, `changeEmail/PhoneNumber`, quote/hold/reversal) | none are needed while the flags are off; `setUserRole` is the only admin tool for roles |
