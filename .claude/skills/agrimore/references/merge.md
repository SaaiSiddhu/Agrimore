# `merge` mode — integrate a VERIFIED phase into `develop`

`develop` is the only merge target for phase branches. `staging` and `main` never receive merge
commits (`promote.md`). Every merge happens **inside the worktree that holds `develop`**
(`/Users/saai_siddharth/Projects/Clients/Agrimore-develop`), never by moving a ref from outside, never
in the primary checkout (`Projects/Clients/Agrimore`, which holds `main`).

## 1. Preconditions (all verified by command, none by memory)

1. Phase state is `VERIFIED` in `state.json`: gate table captured after the last commit (five-app
   analyze if `packages/**` moved); every attached lane `PASS`/`PASS_WITH_FINDINGS`; no `BLOCKING`.
2. The ledger row exists on the branch with `Status` = `ACTIVE` and a `Why` that matches what was
   built. Its `SHA` cell will be filled in the bookkeeping commit — never leave `N/A — pending` behind.
3. `git -C ../Agrimore-develop status --porcelain | wc -l` = 0 and
   `git -C ../Agrimore-develop ls-files --others --exclude-standard | wc -l` = 0.
4. `git -C ../Agrimore-develop rev-parse --abbrev-ref HEAD` = `develop` and `git worktree list` shows
   exactly one `[develop]`.
5. Collision re-check: another `ACTIVE` row or branch with the same scope merged since the base?
   `git log --oneline <base>..develop` read in full.
6. Deploy consequence of the phase is written in the ledger `Why` (functions by name / rules /
   indexes / NONE) so the promotion step can hand it over.

## 2. Procedure (`scripts/merge-develop.sh <branch>` does steps 1–7 and stops before commit)

```
1  D=../Agrimore-develop; PRE=$(git -C "$D" rev-parse HEAD)                      # pin the pre-merge tip
2  BASE=$(git -C "$D" merge-base develop <branch>)
   comm -12 <(git -C "$D" diff --name-only "$BASE"..develop | sort) \
           <(git -C "$D" diff --name-only "$BASE".."<branch>" | sort)            # overlap → suites must run on the RESULT
3  git -C "$D" merge --no-ff --no-commit <branch>                                  # inspection window
4  conflicts: resolve ONLY inside the phase's own files; for the ledger, union rows and confirm the
   row count changed by exactly the rows the phase added; firestore.rules / functions/src/index.ts
   conflicts mean two phases touched the collision files — re-run the affected suites on the result
5  [ "$(git -C "$D" rev-parse refs/heads/develop)" = "$PRE" ] || abort            # the ref did not move under you
6  git -C "$D" commit -m "Merge branch '<branch>' into develop"
7  M=$(git -C "$D" rev-parse HEAD)
   git -C "$D" diff --name-status "$PRE" "$M"                                       # must be ⊆ phase files (+ ledger)
   git -C "$D" ls-tree -r "$M" --name-only | grep -cE '^(Agrimore-main/|legacy_archive/|apk-output/|\.firebase/|functions/src/customer/cartSplitting\.ts$|functions/(scripts/)?fix_admin\.js$|packages/agrimore_core/lib/config/(env_config|razorpay_config)\.dart$)'   # must be 0
   git -C "$D" reflog show develop -1                                               # reads "commit (merge)"
8  overlap non-empty, or the phase touched packages/** → gate.sh on the merge result in the develop worktree (five apps)
9  ledger bookkeeping commit on develop: Status ACTIVE → MERGED_DEVELOP, SHA = branch tip, Merged into = $M —
   `docs(repo): record <ID> merged into develop as <M>`
10 worktree disposition (§4). Never push develop unless run.md config says so — and even then, only with the owner's standing word.
```

A merge that fails any check is undone with `git -C "$D" merge --abort` (before commit) — never with
`reset --hard` after commit; after commit, re-merge on top with the correction and report both SHAs.

**Resurrection check rationale:** the nested layout (`Agrimore-main/`), `legacy_archive/` (282 files,
deleted 2026-08-24), the committed build artefacts, `cartSplitting.ts` (the order bypass), both
`fix_admin.js` copies and the two deleted config files must never come back through an old branch —
`merge-base --is-ancestor` says yes for a branch that predates a deletion and resurrects it anyway.

## 3. The ledger — `docs/active/BRANCH_DISPOSITIONS.md`

Seven columns: `Branch | SHA | Status | Decided | Decided by | Why | Merged into`. Rules that already
bit someone in this repository's history:

- **The row is the claim; write it as the first commit.** Name the files you expect to touch.
- **Never change another branch's `Status` cell** — flag and ask.
- Status tokens: `ENVIRONMENT` · `ACTIVE` · `MERGED_DEVELOP` (contained in `develop`; `Merged into` =
  merge SHA) · `MERGED` (legacy: contained in `main`) · `PRESERVED_REFERENCE` (never merge without a
  new owner decision) · `SUPERSEDED_BY:<branch>` · `ARCHIVED_TAG:<tag>`.
- Promotions are recorded in the ledger's `## Promotions` table (date · target · source SHA · pushed ·
  owner's word quoted · emulator sweep / deploy handed over), not per row.
- `node scripts/governance/validate-branch-dispositions.mjs` re-derives facts from git: every live
  branch has a row; recorded SHAs match tips (environment rows exempt); `MERGED_DEVELOP` rows are
  ancestors of `develop`; `PRESERVED_REFERENCE` rows are ancestors of neither; `staging`/`main` ⊆
  `develop` and `main` ⊆ `staging`. Exit code is always 0 — read the warnings.

## 4. Worktree lifecycle — the merge is not done until the desk is cleared

Four preconditions, then the porcelain command, in the same session that merged:
```
git merge-base --is-ancestor <branch> develop            # contained
git -C <wt> status --porcelain | wc -l                   # 0
git -C <wt> ls-files --others --exclude-standard | wc -l # 0 (untracked = STOP: archive outside the repo first, verify, then proceed)
git worktree remove <wt> && git worktree prune           # never rm -rf; refusing on dirty is a safety feature
```
`df -h /` before and after (a worktree with `node_modules` + five `.dart_tool`s is ~1 GB). Never
delete the merged branch ref. Never remove the primary checkout, `Agrimore-develop`, or any worktree
holding an in-flight phase. The one pre-existing prunable record (`claude/bold-spence-01813b`, old
nested path) is the owner's to prune (D-PRUNE). A merge phase that leaves its worktree standing is
`PARTIAL`.

## 5. Report

```
MERGE — <phase>
develop before: <PRE>  after: <M>   merge-base: <BASE>   overlap files: <n> (list)   suites run on the result: …
first-parent diff: <n> files, all within phase scope (or: exceptions listed)   resurrection check: 0
ledger: row line <n> → MERGED_DEVELOP, bookkeeping commit <sha>   validator warnings: <n> (listed)
worktree: <path> removed (preconditions 4/4) · df before/after   push develop: no (owner pushes)
deploy consequence carried forward: <functions by name / rules / indexes / NONE>
```
