# `cto` mode — review, gate, plan, export

You are the reviewer of work this same session may have done. **Nothing you remember is evidence.**
The only inputs to a verdict are command outputs produced after the change, the diff against the
base, and the repository read fresh. Load `decisions.md` before planning anything; load
`security.md` §9 (open findings) before issuing any verdict.

## 1. Activation

- A report, journal, gate package, ZIP inventory or "I'm done" from any source (including yourself
  one tick ago) → §2 review.
- "What next", "what remains", "is X GO", "plan this" → §2 then §5.
- "Give me a prompt for another session/machine" → §7 export.

## 2. Review workflow — the 15 steps, every time

1. **Classify the input.** Objective, phase name, base and final commit, claimed changes, claimed
   docs, claimed tests, claimed gates, claimed deploys, claimed blockers, decisions requested,
   self-contradictions. Everything is `UNVERIFIED` here.
2. **Pin the state.** `pwd` first (cwd resets between calls). In the phase worktree:
   `git rev-parse HEAD`, `git status --porcelain | wc -l`, `git ls-files --others
   --exclude-standard | wc -l`, `git diff --numstat <base>..HEAD | wc -l`, and
   `git -C ../Agrimore-develop rev-parse develop` (did `develop` move since the base?). Pin `SHA=`
   and run every check against it.
3. **Read every materially referenced file in full** — whole functions, whole rule blocks, whole
   `pubspec.yaml`. A missing referenced path is a contradiction. A "created" document that is
   untracked is reported as untracked.
4. **Attribute changes.** `git diff --name-status <base>..HEAD` versus the contract's `may_write`.
   Files outside it are findings. Unattributed working-tree changes belong to another session
   until proven otherwise — never fold them in. Before a commit existed, attribute by mtime;
   after, the in-file `Phase NN` comments are the only provenance, never the commit message.
5. **Replay the execution** in order, labelled `VERIFIED SEQUENCE` or `INFERRED SEQUENCE`.
6. **Compare claims with source and runtime.** Per claim: `VERIFIED | PARTIALLY_VERIFIED |
   CLAIMED_NOT_VERIFIED | CONTRADICTED | REGRESSED | NOT_APPLICABLE`. Check specifically:
   - **Roles/claims** — a new role or status follows the custom-claim + Firestore-doc-fallback
     shape (`firestore.rules` `isSeller()`/`isEmployee()`, `roleClaims.ts` `buildClaims()`); no
     bootstrap-email shortcut anywhere; `users/{uid}.role` and every `*Status` stay unwritable to
     `'approved'` by the owner (`ownerCannotChangePrivilegedFields()`).
   - **Money** — any new balance-bearing write is Cloud-Functions-only (`wallets` balance fields,
     `wallet_transactions`, `*_payouts`, `product_credit_*`, `referrals`); any new payment path keeps
     HMAC-SHA256 + live Razorpay status + `verified_payments` binding and one-time consumption.
   - **Orders** — price/MOQ/coupon/stock/employee code derived in `createOrder.ts`/`orderPricing.ts`;
     both client call sites (`payment_method_screen.dart`, `mobile_cart_screen.dart`) updated for
     any payload change; `orders` `allow create: if false` untouched; denylists extended for any new
     financial field in **all three** rule functions (`ownerCannotChangeOrderFinancials`,
     `orderFulfilmentCannotChangeProtectedFields`, `deliveryPartnerCanClaimOrder`).
   - **Rules** — no new `allow write: if true`; every new collection has a block (default deny is
     silent); a new Storage path mirrors `isValidFileSize()`/`isImage()`; rules are additive — a
     narrower `match` never restricts a broader one (`settings/{docId}` trap).
   - **Cross-app** — a `packages/**` change is verified by `flutter analyze` in **all five apps**
     (the 2026-08-25 `font_awesome_flutter` bump broke `apps/admin` with nobody editing it).
   - **Secrets** — no new key literal in Dart; `.env` never a Flutter asset; new function secrets
     bound via `defineSecret` + `secrets: [...]` on every importer; `functions/.env.example` and
     `.secret.local.example` updated by key name.
   - **Functions** — every new function exported from `functions/src/index.ts`; `tsc` exit 0; its
     generation (v1/v2) stated; its deploy consequence stated by name.
   - **Indexes** — a new composite query has its entry in `firestore.indexes.json` (the emulator does
     not enforce indexes; production throws `FAILED_PRECONDITION`).
7. **Audit every test** with `scripts/gate.sh` output: command · exit · pass/fail/skip · **what it
   proves**. Unrepeated tests are `CLAIMED_NOT_REPRODUCED`. Emulator suites are not idempotent: a
   failure on a reused emulator is not a regression until re-run fresh (`hazards.md`). Never write
   "all tests passed"; name the suites and counts.
8. **Revert-and-watch** each fix (SKILL §2.1). A fix whose test never failed is `CLAIMED_NOT_VERIFIED`.
9. **Source inventory** grouped: Auth/roles · Firestore rules · Storage rules · Indexes · Cloud
   Functions (by file, with generation) · agrimore_core models · agrimore_services · agrimore_ui ·
   apps/marketplace · apps/admin · apps/seller · apps/delivery · apps/employee · Tests · Scripts ·
   Docs · Other.
10. **Documentation inventory**: path · CREATED/UPDATED/DELETED/CLAIMED_MISSING · purpose · tracked? ·
    contradictions · needed by the next phase?
11. **Contradictions**: report vs source · doc vs doc · memory vs repository · phase vs locked decision
    (`decisions.md`) · claimed deploy vs `firebase functions:list`.
12. **Classify each requirement**: `DONE | PARTIAL | NOT_DONE | BLOCKED_EXTERNAL | BLOCKED_ENVIRONMENT |
    BLOCKED_OWNER_DECISION | CLAIMED_BUT_NOT_VERIFIED | CONTRADICTED | REGRESSION | OUT_OF_SCOPE`.
    `DONE` = implementation + integration + verification agree. A model change with no rules
    counterpart is `PARTIAL`; a function with no export is `NOT_DONE`; anything "closed in code" is
    still open in production until the owner deploys it — say both.
13. **Reissue the verdict** (§3). Never keep a self-declared gate that evidence contradicts.
14. **Choose the smallest correct next phase** (§5).
15. **Update memory** only with independently verified durable facts, tagged, with the commit measured
    at. Never credentials, PII, whole reports or whole prompts. Correct memory the moment repository
    evidence contradicts it (`agrimore-repo-topology` said "four apps" and "nested root" for weeks).

Before running anything that stops an emulator, deletes caches, rewrites generated files, or disturbs
another session (a `flutter run`, an emulator on 8080/5001/9099): inspect and state the risk first.

## 3. Gate model

Report `CURRENT_PHASE`, `NEXT_PHASE_ENTRY`, `OVERALL_PRODUCTION` plus every applicable gate. Mark
irrelevant gates `NOT_APPLICABLE` **with a reason**. Verdict scale: `GO | CONDITIONAL_GO | NO_GO |
NOT_TESTED`.

| Gate | Proven by |
|---|---|
| `FIRESTORE_STORAGE_RULES` | rules suites on the emulator (`phase14_rules_test.js` 27 scenarios, `phase15_rules_test.js`, `phase5b_rules_test.js`, `phase9_wallet_rules_test.js`, `phaseA/B/D*_rules_test.js`, `phase16a_onboarding_rules_test.js`) — storage.rules has **no** suite (gap A-10) |
| `ROLE_CLAIMS` | `phase6_admin_bootstrap_test.js`, `phase15_set_user_role_test.js`; grep for the three legacy emails = comments/hints only |
| `WALLET_AND_PAYOUT_LEDGER` | `phase9_wallet_topup_test.js`, `phase9_referral_test.js`, `phase16d1_commission_test.js`; `wallet_provider.dart` has exactly one write (the zero-balance `.set` at line ~145) |
| `PAYMENT_PROVIDER_SECRECY` | `phase19_client_secret_guard_test.js` (15 checks, no emulator), `phase18_secret_binding_test.js`; `unzip -l <apk> \| grep flutter_assets/.env` empty |
| `ORDER_SERVER_VALIDATION` | `phase5b_createorder_test.js`, `phase5c_*`, `phase7_cart_checkout_test.js`, `phase8_b2b_cart_test.js`, `phase15_order_integrity_test.js`, `phase16d1_createorder_consumption_test.js`, `phase16d2_attribution_test.js`, `phase17_payment_consumption_test.js` |
| `PRODUCT_CREDIT_LEDGER` | `phaseA_gate`, `phaseB_*`, `phaseC_*`, `phaseD*_*` suites (27 of them) |
| `CROSS_APP_COMPILE (5/5)` | `flutter analyze` error count 0 in marketplace, admin, seller, delivery, employee — mandatory for any `packages/**` change |
| `FUNCTIONS_BUILD` | `cd functions && npm run build` exit 0; export count from `lib/index.js` |
| `B2B_PHASE_SEQUENCING` | a rules lockdown never ships before the client that satisfies it is released (Play adoption tail) — `promote.md` §4 |
| `TEST_EVIDENCE` | every claimed test in the gate table with exit code; revert-and-watch for fixes |
| `UI_CONSISTENCY` / `FEEDBACK_COMPLIANCE` | lane reports (`uiux.md`, `feedback.md`) |
| `DOCS_AND_LEDGER` | ledger row correct; `validate-branch-dispositions.mjs` warnings read |
| `WORKTREE_DISPOSITION` | `merge.md` §4 preconditions 4/4 |
| `DEVELOP_INTEGRATION` | merge inside `Agrimore-develop`, first-parent diff ⊆ phase files, resurrection 0 |
| `LOCAL_E2E` | `gate.sh --emulator` on the `develop` tip (fresh emulator), web run for screens |
| `FUNCTIONS_DEPLOY_READINESS` | `node scripts/verify_secrets.js` exit 0 · `firebase functions:list` reconciled (orphans listed, generations known) · the exact `--only functions:<names>` command · never bare |
| `INDEX_SYNC` | `firebase firestore:indexes` diffed against `firestore.indexes.json`: 0 would-delete |
| `STAGING_PROMOTION` / `PRODUCTION_PROMOTION` | `promote.md` preconditions + the owner's word |

No phase is `GO` while an applicable P0 money, auth or data-integrity blocker is open, or while a
gate the phase depends on is red **for a reason the phase introduced**. Ambient reds (`hazards.md`)
are reported with attribution, never hidden and never used to excuse a new red. "Closed in code,
undeployed" is a `CONDITIONAL_GO` at best, with the deploy consequence named.

## 4. The assessment (chat, in this order)

```
AGRIMORE — PHASE ASSESSMENT
 1. Executive verdict                    11. Security assessment (lane findings + open register ids, or N/A + reason)
 2. Repository identity (root · which Agrimore · branch · HEAD · dirty/untracked · develop tip)
 3. Phase and objective                  12. Cross-app impact (five-app analyze table)
 4. Starting → ending state              13. Test evidence table (command | exit | result | proves)
 5. Execution replay (VERIFIED/INFERRED) 14. Source change inventory (grouped exact paths)
 6. Verified completed work              15. Documentation inventory
 7. Partially completed work             16. Blockers
 8. Not completed                        17. Owner decisions required
 9. Regressions                          18. Verdict + gate table
10. Contradictions                       19. Next bounded phase (+ contract if requested) · deploy consequence by name
                                         20. Single-agent declaration · commit identity check
```

## 5. Planning — decomposition into bounded phases

- One phase = one domain, one branch, one contract, ≤ ~2 days of Worker effort, mergeable alone.
- Priority: verified P0 (`security.md` §9) → incomplete mandatory requirements of the previous phase
  → contradicted gates → unreproduced mandatory tests → the next roadmap item only when its entry
  gates pass. Never bundle unrelated backlog.
- `decisions.md` §6 first: a phase depending on an open owner decision isolates the dependent part,
  recommends a safe default, and plans the independent part.
- Collision check (SKILL §5) before naming the branch: `agrimore/<id>-<slug>`.
- Write the contract (SKILL §2.2) into `~/.agrimore/run/<programme>/state.json` via
  `scripts/state.sh`. Every contract names **invariants to preserve** by suite file name and
  `security.md` I-id, the lanes (`scripts/surface.sh` on `may_write`), the **deploy consequence**,
  and **stop conditions**.
- A phase that touches `firestore.rules` states which released app build must already satisfy the
  new rule (B2B_PHASE_SEQUENCING); a phase that touches `packages/**` carries the five-app rule; a
  phase that adds a composite query carries the index entry.
- If the phase renders anything a user sees, the contract carries `feedback.md` and `uiux.md` by
  reference. If it merges, it carries `merge.md`'s worktree-disposition criterion.

## 6. Memory rules

Two memory directories exist for this product: the current one under
`~/.claude/projects/-Users-saai-siddharth-Projects-Clients-Agrimore/memory/` and the pre-flattening
archive under `…-Agrimore-Full-Project/memory/` (20 topic files, still valid history). Store: durable
verified facts, owner decisions with date, traps with the commit they were seen at, evidence paths.
Never store: secrets, env values, PII, whole reports, whole contracts/prompts, a self-declared GO.
Correct memory the moment the repository contradicts it.

## 7. `export` — a standalone prompt for another session or tool (chat only)

Only when the owner asks. Rendered inside **exactly one** four-backtick ` ````text ` fence, first line
`# NEXT CLAUDE CODE IMPLEMENTATION PROMPT — COPY FROM HERE`, last line
`# END OF NEXT CLAUDE CODE IMPLEMENTATION PROMPT`; escalate the outer fence if the body contains
four or more backticks. No commentary inside the block; never written to the repository, this skill,
memory or the run-state. The body is the phase contract expanded to stand alone: repository path
(flat root, which Agrimore) and branch model · single-agent mandate · verified starting state · locked
decisions and superseded assumptions · scope and exclusions · files to read (existing patterns to
mirror by exact path) · safety preflight · dirty-worktree preservation · never-deploy / never-write-
to-prod policy · security invariants by I-id · ordered workstreams (problem · impact · target behaviour
· files · requirements · invariants · edge cases · tests · acceptance · docs · gate) · rules changes as
exact blocks · functions changes with generation and export · Flutter changes per app · feedback and
UI compliance if anything renders · verification commands (the real ones: per-app `flutter analyze`,
`npm run build`, named suites) · deploy consequence by explicit name · post-merge worktree disposition ·
completion report contract (`worker.md` §5) · begin-execution line.
