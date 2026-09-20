# `worker` mode — implement one bounded phase

You execute exactly one phase contract (SKILL §2.2). No contract → write one first (`cto.md` §5)
and show it; a described problem without a request to change is `status`, not `worker`.

## 1. Preflight (all of it, every phase)

1. `pwd`. **Which Agrimore** (SKILL §1 step 0). Since 2026-09-20 `Projects/Clients/Agrimore` is the
   only worktree and holds `develop`; it is a legitimate place to work. Never work with `main` or
   `staging` checked out — `gate.sh` refuses on the branch.
2. **Re-read the integration tip**: `git rev-parse --short develop` (add `-C <worktree>` only if you
   made one) and compare with the contract's `base`. If it moved, rebase the plan, not the branch —
   note the delta.
3. **Collision check**: `git worktree list`, `git branch --list 'agrimore/*'`, ledger `ACTIVE` rows read
   for topic overlap. Overlap → STOP and report.
4. **Worktree is optional but recommended** (it keeps the single folder's standing WIP out of your
   build). If you skip it, create the branch in place and keep the phase's files disjoint from the
   dirty paths. To make one: `git -C <root> worktree add ../Agrimore-<slug> -b agrimore/<id>-<slug>
   <base>` (never send its output to `/dev/null`; use `git -C`, never `cd`-then-trust). Then:
   `cd functions && npm ci --no-audit --no-fund` · `flutter pub get` in `packages/agrimore_core`,
   `agrimore_services`, `agrimore_ui`, `apps/marketplace`, `admin`, `seller`, `delivery`, `employee`.
   Afterwards `git status --porcelain` must still be 0 (a changed `pubspec.lock` is a finding).
5. **Identity**: `git config user.name` = `Agrimore`, `user.email` = `agrimorein@gmail.com`
   (repo-local; shared by every worktree).
6. **Claim row = first commit** (`merge.md` §3): `Status` = `ACTIVE`, `Why` names the files you expect
   to touch and the collision check you ran, `Merged into` = `N/A — pending`. Commit as
   `docs(repo): claim phase <ID> — <slug>` using `git add <ledger> && git commit -m "…" -- <ledger>`
   in ONE shell command. `git show --stat HEAD`.
7. **Baseline the gates on the untouched branch**: `bash .claude/skills/agrimore/scripts/gate.sh
   --baseline` (records the ambient counts so the phase's delta is measurable — `hazards.md` lists
   the known ones: analyze 517/616/65/33/0 issues, 0 errors, at `c8f6f30`).
8. Read every file in the contract's `files to read` list **in full** — whole functions, whole rule
   blocks, whole `pubspec.yaml`. Then read the callers of anything you will change (both `createOrder`
   call sites; every `.snapshots()` consumer of a collection you touch).
9. Local run needs that git does not carry (`hazards.md` §Run): `apps/<app>/android/app/google-services.json`
   (reconstruct per app, package name must match `applicationId`), `apps/<app>/android/app/debug.keystore`
   (copy of `~/.android/debug.keystore`), `functions/.env` + `functions/.secret.local` for the emulator
   (copy from the single folder at `Projects/Clients/Agrimore`, never commit, never print).

## 2. Implementation discipline

- Touch only `may_write`. Anything else you discover goes into the report as a finding.
- **Mirror existing patterns by exact path.** New rule block → copy the shape of the closest sibling
  (`employee_payouts` mirrors `seller_payouts`; a new CF-only collection mirrors `wallet_topups`;
  a value-guard mirrors `ownerCannotApproveSellerStatus()`; a blanket denylist mirrors
  `ownerCannotSetOnboardingFields()`). New callable → `onCall({ minInstances: 0, memory: "256MiB",
  secrets: [...] })` like `payment.ts`; new trigger → v1 like `employeeCommission.ts`; idempotency
  anchor doc like `wallet_topups/{paymentId}`; all reads before all writes inside one
  `runTransaction`. New model field → the four-part pattern (constructor / `toMap` / `fromMap` /
  `copyWith`) used by `ProductModel`'s location fields. Admin nav item → appended at the END of
  `admin_shell.dart`'s `_navItems` (indices are hardcoded elsewhere).
- **Rules are additive.** Never place a CF-only document under `settings/` (admin-writable there).
  Every new financial field goes into all three order denylists. Every new collection gets a block.
- **Security invariants** (`security.md` §4) are preserved by construction: roles from claims;
  balances via Cloud Functions; payment verified server-side and consumed once; prices derived from
  `products`; no secret in Dart; no `.env` asset; fail closed.
- **Canonical UI** (`uiux.md`): reuse `agrimore_ui` theme/colors/widgets where an equivalent exists;
  a new widget duplicating an existing one is a stop condition. **Feedback** (`feedback.md`): the
  moment anything renders a message, use `SnackbarHelper`/`DialogHelper`/`ConfirmationDialog`/
  `EmptyStateWidget`/`ErrorView` unless the screen's own established pattern is documented.
- **Two `createOrder` call sites.** Any payload change updates `payment_method_screen.dart` and
  `mobile_cart_screen.dart` both. `orderMode` (B2C/B2B) ≠ `orderType` (One Time/Auto Delivery).
  `status` mirrors `orderStatus`; the seller panel writes only `status`.
- **Functions**: export from `index.ts`; declare secrets on every importer; keep `HttpsError` codes
  and messages stable (suites assert exact strings); state the generation; never a bare rate literal
  (`resolveCommissionRate` precedent); scripts under `functions/scripts/` ship inside every deploy
  bundle — never put a credential there.
- **Indexes**: a new composite query gets its `firestore.indexes.json` entry in the same commit; the
  emulator will not tell you.
- **Deploy consequence**: every commit message that changes rules, functions or indexes states it
  (`deploy: functions:<name>` / `deploy: firestore:rules` / `deploy: none`).
- Keep the ledger `Why` cell growing; commit ledger edits immediately.

## 3. Testing discipline

- For each fix: reproduce **before** (the suite fails or the probe shows the defect), fix, the same
  suite passes after. Record both outputs. A test that never failed proves nothing.
- Node suites: `cd functions && npm run build && node scripts/<suite>.js` **as ONE command as the last
  action before committing** (a suite against a stale `lib/` proved nothing twice). Emulator suites
  run under `firebase emulators:exec --only firestore,functions,auth "node scripts/<suite>.js"` with
  `JAVA_HOME=/opt/homebrew/opt/openjdk@21`; ports 8080/5001/9099 must be free (`lsof -nP -iTCP:8080
  -sTCP:LISTEN`) — never stop another session's emulator. Suites are not idempotent: a sweep needs a
  fresh emulator.
- Rules changes: add or extend a `@firebase/rules-unit-testing` scenario with BOTH the denied exploit
  and the allowed legitimate write (positive control). A rules suite that only asserts `assertFails`
  is vacuous.
- Callable changes: `firebase-functions-test` — v2 `wrapV2` takes ONE `{data, auth}` object; v1 `wrap`
  takes `(data, {auth})`. Set `FIREBASE_AUTH_EMULATOR_HOST` when the callable ends in `admin.auth()`.
- Dart: `cd apps/marketplace && flutter test` (the only suite; "Test directory not found" means your
  cwd reset). A new provider test uses `setupFirebaseCoreMocks()` and the optional `databaseService`
  seam (`product_provider_test.dart` precedent).
- `scripts/gate.sh` after the **last** commit; keep the table. Compare with the baseline; every new
  red is yours until attributed. `packages/**` touched → five apps, no exceptions.
- If the phase touches an app screen: run it (AVD `Pixel_8_API_35` via `flutter run`, or web via
  `.claude/launch.json` `marketplace-web` in the browser preview) and record what you saw. Screens
  behind `AuthGuard` need a real phone-OTP login that hits **production** functions
  (`auth_service.dart:334` hardcodes the base URL) and burns a real 2Factor credit — do not do that
  to look at a layout; use a throwaway preview entry point (deleted afterwards) and say so.

## 4. Commits

- Small, typed: `type(scope): subject` ≤100 chars; types `feat|fix|chore|build|docs|refactor|perf|
  test|revert|security`; scopes `rules|functions|core|services|ui|marketplace|admin|seller|delivery|
  employee|repo|skill|docs|indexes`. No hooks enforce this — you do.
- No `Co-Authored-By`. `git show --stat HEAD` after each commit. Never stage a file you did not change
  for this phase; `git status --porcelain` before `git add`; `add` + `commit` in one shell command;
  never `git add -A`.
- Never commit `_env`, `.env`, `functions/.env`, `functions/.secret.local`, `google-services.json`,
  `*.jks`, `key.properties`, the backup zip, `build/`, `functions/lib/`, `.dart_tool/`.

## 5. Completion report (chat; exact paths, never pasted documents)

```
WORKER COMPLETION REPORT — <phase>
A. Execution mode (SINGLE AGENT · subagents NO · delegation NO · background NO · worktrees NO · workflows NO)
B. Starting branch/commit (and develop tip at start)      C. Final branch/commit
D. Pre-existing working-tree state and proof it was preserved
E. Files created   F. Files updated   G. Files deleted   H. Docs created/updated (path · purpose)
I. Firestore/Storage rules changes (exact rule blocks added/changed; positive + negative scenario names)
J. Cloud Functions added/changed (file · generation v1/v2 · exported from index.ts · secrets bound)
K. Data model changes (package/model · four-part pattern) · index entries added
L. Which of the FIVE apps were touched, and flutter analyze error/warning/info for ALL FIVE when packages/** moved
M. Commands executed   N. Exit codes   O. Passed   P. Failed   Q. Skipped   R. Timed out
S. What each test actually proves (and what it does not)   T. Remaining work   U. Blockers
V. Owner decisions required   W. Security caveats (security.md I-ids and §9 ids touched)
X. Deploy consequence — exact `firebase deploy --only …` by name, or NONE; Play release needed or not
Y. Worktree disposition — path · branch · `merge-base --is-ancestor <branch> develop` · porcelain count at removal ·
   `git worktree remove` result · `prune` run · df -h before/after — or "N/A — no merge in scope"
Z. Gate recommendation (never GO on your own word) · findings outside scope (path:line) · "I did not verify …" statements
```

A report that omits failures is worse than no report.
