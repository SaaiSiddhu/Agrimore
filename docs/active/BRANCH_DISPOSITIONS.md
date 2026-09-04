# Branch Dispositions — the repository fact

**Created by phase GOV-3 on 2026-09-04** (branch `agrimore/gov3-agrimore-skill-and-branch-model`,
from `main` = `c8f6f30`). This file exists because, until today, every decision about what should
happen to a branch in this repository lived only in one CTO session's private memory, and sessions
do not share memory. Four or more concurrent sessions have edited this checkout at once
(`agrimore-concurrency-incidents` in CTO memory: seven incidents, one materially false commit
message), always colliding on `firestore.rules` and `functions/src/index.ts`. A row here is the
only way a second session can discover that a phase is already claimed.

**This file is the authority on branch disposition. Session memory is not.** Operating rules:
`.claude/skills/agrimore/references/{merge,promote}.md`; validator:
`node scripts/governance/validate-branch-dispositions.mjs` (warnings only, exit 0 — read them).

## The rules

- **A branch absent from this file has NO disposition and MUST NOT be merged.** Absence is not
  neutral. Find out before merging.
- **Only the owner changes a disposition.** A session may ADD a row for a branch it just created
  and may move its OWN row `ACTIVE` → `MERGED_DEVELOP` in the bookkeeping commit after the merge.
  A session never changes another branch's `Status` cell — not even to correct it. Flag and ask.
- **CLAIM BEFORE YOU START — the row is a lock, not a receipt.** See the claim protocol.
- **Phase branches merge into `develop`, never into `main`.** `develop` is the integration branch
  (local end-to-end on the Firebase emulator suite). `staging` and `main` move only by
  fast-forward promotion with the owner's word in the same message, recorded in `## Promotions`.
  A merge commit or a direct commit on `staging`/`main` is a defect.
- **Nothing here authorises `firebase deploy`.** Promotion is a git event. Deploying to
  `agrimore-66a4e` (live, real users) is the owner's own action, always with explicit function
  names; the skill prints the command and stops.

## Claim protocol — read this before creating a branch

1. **Collision check, three sources, every time:** `git worktree list` · `git branch --list
   'agrimore/*'` · this file's `ACTIVE` rows, read for topic overlap (not just branch name). A
   claim row on an unmerged branch is invisible from `develop` — that is why all three are needed.
2. **Create the worktree from `main`** (or from `develop` once phases have landed there — the
   contract's `base` says which): `git worktree add ../Agrimore-<slug> -b agrimore/<id>-<slug> <base>`.
3. **The claim row is the FIRST commit on the branch.** `Status` = `ACTIVE`, `Why` names the files
   you expect to touch and the collision check you ran, `Merged into` = `N/A — pending`.
   Commit message: `docs(repo): claim phase <ID> — <slug>`. Verify with
   `git log -1 --format='%an <%ae> | %cn <%ce>'` (must be `Agrimore <agrimorein@gmail.com>`).
4. Keep the `Why` cell growing with findings; commit ledger edits immediately.
5. After the merge (inside the `develop` worktree): the bookkeeping commit sets your row to
   `MERGED_DEVELOP`, fills `SHA` with the branch tip and `Merged into` with the merge commit.

## Status tokens

| Token | Meaning |
| --- | --- |
| `ENVIRONMENT` | One of `develop` · `staging` · `main`. Moves only per the fast-forward model; its `SHA` cell is informational (re-measure), never a lock. |
| `ACTIVE` | In flight, owned by a running phase. No disposition decided yet — expected. |
| `MERGED_DEVELOP` | Contained in `develop`. `Merged into` names the `--no-ff` merge commit on `develop`. Reaches `staging`/`main` only through a promotion recorded below. |
| `MERGED` | Legacy: contained in `main` from before the branch model existed (the tip sits on `main`'s own history). |
| `PRESERVED_REFERENCE` | Deliberately **NOT** merged; kept as input to a named future phase. **NEVER merge without a new owner decision.** |
| `SUPERSEDED_BY:<branch>` | Replaced by `<branch>`. Do not merge this branch. |
| `ARCHIVED_TAG:<tag>` | Content preserved as tag `<tag>`; the branch may be deleted. |

## How this was seeded

From the live repository on 2026-09-04 at `main` = `c8f6f30` (`git branch -a -vv`, `git worktree
list`, `git merge-base --is-ancestor`), not from memory. `master` was renamed to `main` the same day
(OWNER_DECISION D-BRANCH); `develop` and `staging` were created at the same tip (re-level). The
remote `origin` (`SRIESWARAN01/Agrimore-Full-Project`, public) still has only `master` at `0ea1e53`,
64 commits behind — every push is the owner's action (the machine's GitHub credential is
`Edynox-hq`, which has no write access there).

## Branches

| Branch | SHA | Status | Decided | Decided by | Why | Merged into |
| --- | --- | --- | --- | --- | --- | --- |
| `main` | `c8f6f30` | `ENVIRONMENT` | 2026-09-04 | owner (D-BRANCH) | Production. Renamed from `master` 2026-09-04. Moves only by `merge --ff-only staging` with the owner's word. `origin/master` = `0ea1e53` is the last pushed state. | — |
| `develop` | `346d95e` | `ENVIRONMENT` | 2026-09-04 | owner (D-BRANCH) | Integration + local end-to-end (emulator suite). Receives `--no-ff` merges of phase branches inside the `Agrimore-develop` worktree only. Created by GOV-3 at the `main` tip. | — |
| `staging` | `c8f6f30` | `ENVIRONMENT` | 2026-09-04 | owner (D-BRANCH, D-STAGING) | Pre-production. Until a second Firebase project exists, `staging` = this branch + a full emulator regression sweep (`gate.sh --full --emulator`) — it never points at `agrimore-66a4e`. Moves only by `git fetch . develop:staging` after the sweep and the owner's word. Created by GOV-3 at the `main` tip. | — |
| `agrimore/gov3-agrimore-skill-and-branch-model` | `ab48691` | `MERGED_DEVELOP` | 2026-09-04 | session GOV-3 | Phase GOV-3: the single operating skill `/agrimore` and the develop → staging → main model. Files: `docs/active/BRANCH_DISPOSITIONS.md` (this row), `.claude/skills/agrimore/{SKILL.md,references/*.md,scripts/*.sh}`, `scripts/governance/validate-branch-dispositions.mjs`, `CLAUDE.md` (new, git root), `README.md` (one pointer line). Touches nothing under `apps/`, `packages/`, `functions/`, `*.rules`, `firebase.json`. Collision check 2026-09-04 17:17: worktrees = primary `[main]` + one prunable stale record; branches `agrimore/*` = none; `ACTIVE` rows = none (file did not exist). Merged 2026-09-04: first-parent diff = the 21 phase files, resurrection check 0, `gate.sh --full` at `ab48691` failed=0 (functions build · analyze ×5 errors 0 · 3 guards · `flutter test` 20/20). Deploy consequence: NONE. | `346d95e` |
| `claude/bold-spence-01813b` | `0ea1e53` | `MERGED` | 2026-09-04 | session GOV-3 (recorded, not decided) | Tip = `origin/master` = an ancestor of `main` (nothing unique). Its worktree record points at the old nested path `Agrimore-Full-Project/.claude/worktrees/bold-spence-01813b`, which no longer exists → `git worktree list` shows it `prunable`. Left untouched: `git worktree prune` and branch deletion are the owner's call (D-PRUNE). The directory still on disk under `Projects/Clients/Clone/` contains a stale copy of `fix_admin.js` and two `google-services (N).json` files — never commit from it. | — |
| `agrimore/sec1-remove-bundled-admin-credential` | `c48a748` | `MERGED_DEVELOP` | 2026-09-04 | session SEC-1 | Phase SEC-1: remove the hardcoded admin credential that ships inside every functions deploy bundle (finding A-1, P1). Verified at base `79bf0ac`: `functions/scripts/create_admin.js` lines 5-6 hold a real admin email + password and line 34 calls `updateUser({password})`, while `firebase.json` `functions[0].ignore` = [`node_modules`, `.git`, `firebase-debug.log`, `firebase-debug.*.log`, `*.local`] does not exclude `scripts/`. Same class as `fix_admin.js` (deleted in `8fd06b2`). Files expected: `docs/active/BRANCH_DISPOSITIONS.md` (this row), `functions/scripts/create_admin.js` (delete), `firebase.json` (one `ignore` entry), `functions/scripts/phase23_deploy_bundle_guard_test.js` (new no-emulator guard), `functions/src/admin/createSellerByAdmin.ts` + `functions/scripts/phase6_admin_bootstrap_test.js` (stale trust-model comments only, no assertion changes), `.claude/skills/agrimore/scripts/gate.sh` (one guard row), `.claude/skills/agrimore/references/security.md` (A-1/A-10 rows). Touches nothing under `apps/`, `packages/`, `*.rules`, `firestore.indexes.json`, or `functions/src/**` beyond one comment block. Collision check 2026-09-04 19:11: worktrees = primary `[main]` + `Agrimore-develop` + one prunable stale record; branches `agrimore/*` = `gov3-…` only (already `MERGED_DEVELOP`); `ACTIVE` rows = none. Deploy consequence: NONE required; the credential rotation is owner-only (D-CREATE-ADMIN) and is NOT done by this phase. Built 2026-09-04 in 4 commits (`48bcd56` claim, `f80d9ca` guard, `8361039` fix, `7189090` docs). Evidence at `7189090`: `gate.sh` failed=0 (functions build exit 0 · analyze ×5 errors 0, warnings 175/92/7/3/0 = the documented ambient baseline, no delta · 4 no-emulator guards · ledger validator warnings=0); `gate.sh --emulator` suites `phase6_admin_bootstrap_test`, `phase15_set_user_role_test`, `phase14_rules_test` all exit 0 on fresh emulators (I1/I13 intact). Reproduce-before: the guard failed 3 checks at `f80d9ca` against the unfixed tree. Revert-and-watch: reverting `8361039` returns the guard to exit 1; removing only the `scripts` ignore entry fails that check alone — tree restored clean both times. Scope: 8 files changed, all 8 inside `may_write`, 0 outside. Reconciliation unchanged: 48 live / 6 orphans / 16 undeployed / 58 exports. Findings left UNFIXED because they sit outside `may_write`: stale `create_admin.js` text at `SKILL.md:226`, `hazards.md:114`, `decisions.md:117`. Merged 2026-09-04: `--no-ff` inside the `Agrimore-develop` worktree, overlap 0 files, first-parent diff = exactly the 8 phase files, resurrection check 0; the merge result tree `fb674a6` is byte-identical to the gated tip `c48a748`, so that commit's `gate.sh` (failed=0) and its three emulator suites apply verbatim. | `86691b9` |

## Promotions

Fast-forward promotions between the three environment branches (`develop` → `staging` → `main`),
one row per promotion, newest last. The SHA promoted is the SHA that was tested on the source
branch; a promotion that is not a fast-forward is refused. Pushes happen only with the owner's
word in the same message, quoted here. There is no CI and no staging Firebase project, so the
last column records the local emulator sweep and the deploy command handed to the owner — never
a deploy the skill performed.

| Date | Target | Source SHA | Pushed | Owner's word | Emulator sweep / deploy handed over |
| --- | --- | --- | --- | --- | --- |
| 2026-09-04 | `develop` (re-level, creation) | `c8f6f30` (= `main`) | NO — push commands printed for the owner | "Rename master to main (Recommended)" + adoption of develop → staging → main (D-BRANCH, chat 2026-09-04) | one-time baseline, no sweep needed (identical tree) |
| 2026-09-04 | `staging` (re-level, creation) | `c8f6f30` (= `main`) | NO — push commands printed for the owner | same | same |
