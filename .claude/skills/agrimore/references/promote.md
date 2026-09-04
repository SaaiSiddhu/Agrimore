# `promote` mode — `staging` ← `develop`, `main` ← `staging` (fast-forward only, owner's word)

Promotion is a **git fast-forward**; the push is the outward-facing act and the owner's; what reaches
users is a **`firebase deploy` the owner runs** and a **Play release the owner publishes** — the skill
never does either. The loop never promotes. A promotion request without the owner's word in the
**same message** produces the plan and the question, nothing else.

## 1. Why fast-forward only

The SHA that passed the emulator sweep on `develop` is the SHA that reaches `staging`; the SHA that
sat on `staging` is the SHA that reaches `main`. No merge commit, no direct commit, no cherry-pick on
`staging`/`main` — a hotfix goes phase branch → `develop` → promotion like everything else, faster.
If `git merge-base --is-ancestor <target> <source>` is false, the promotion is refused and the
divergence is a finding.

## 2. Preconditions

| Target | Must be true (by command) |
|---|---|
| `staging` ← `develop` | every phase merged since the last promotion is `E2E_DEVELOP` in `state.json` · `scripts/gate.sh --full --emulator` on the `develop` tip (fresh emulator, all suites, five-app analyze, functions build): no red that is not an attributed ambient red · ledger rows `MERGED_DEVELOP` with SHAs filled · no open P0 in `security.md` §9 introduced since the last promotion · **D-STAGING**: this sweep IS staging until a second Firebase project exists — `staging` never points at `agrimore-66a4e` · owner's word |
| `main` ← `staging` | `staging` == the SHA recorded in `## Promotions` · the deploy handover (§4) prepared for that SHA with every function named and every rule's client-compatibility stated · `INDEX_SYNC` 0 would-delete · `FUNCTIONS_DEPLOY_READINESS` (`verify_secrets.js` exit 0, orphans listed, generation changes flagged) · release evidence recorded · owner's word |

## 3. Procedure (`scripts/promote.sh <staging|main> [--push]`)

```
1  source=develop|staging  target=staging|main
2  git worktree list | grep -w "\[$target\]"           # if a worktree holds the target: ff INSIDE it with merge --ff-only
3  git merge-base --is-ancestor "$target" "$source" || refuse ("target has commits not in source")
4  git fetch . "$source:$target"                        # ff-only by construction; refuses if the target is checked out anywhere
5  git log --oneline "$target@{1}".."$target"           # what moved — quote it in the report
6  --push (only after the owner's word, AGRIMORE_PROMOTE_CONFIRM=<target> set in that same turn):
   git push origin "$target"   — the machine's credential is Edynox-hq (no write access); expect the
   owner to run the printed command themselves. Never `git push --all`. Never push a phase branch.
7  ledger: append a row to ## Promotions (date · target · source SHA · pushed · owner's word quoted · sweep/deploy handed over)
   on develop as a bookkeeping commit; state.json: promotions[] entry
```

## 4. The Firebase handover checklist (prepared by the skill, executed by the owner — never run here)

Run from the worktree that holds the promoted SHA. Every command below is **read-only** except the
`firebase deploy` lines, which are **printed, never executed**.

1. **Functions build + secrets gate**: `cd functions && npm run build` (exit 0) ·
   `node scripts/verify_secrets.js` (exit 0 — five Secret Manager secrets present, `functions/.env`
   complete). Read the exit code from a file, never through a pipe.
2. **Functions reconciliation**: `firebase functions:list --project agrimore-66a4e > before.txt`.
   Compute source-only (to create), live-and-source (to update), live-only (**orphans — never
   named, never deleted**). For each function to update, compare generation: a v1 → v2 change of a
   live function **cannot deploy in place** ("Upgrading from 1st Gen to 2nd Gen is not yet
   supported") — it needs `functions:delete` + redeploy = an outage window = **owner decision**,
   done one function at a time, least critical first (2026-09-03 precedent).
3. **Rules**: the full rules sweep passed on the emulator for this SHA. For each tightened rule,
   name the released app build that already satisfies it (Play adoption tail) — a rules deploy is
   all-or-nothing and on 2026-08-31 it removed ordering for pre-1.0.7 clients by owner decision.
   `storage.rules` has no suite; read the diff.
4. **Indexes**: `firebase firestore:indexes --project agrimore-66a4e` diffed against
   `firestore.indexes.json` by (collectionGroup, fields): would-delete must be 0; list would-create.
   `firebase.json` declares `"indexes"` (it did not until 2026-09-03 — a deploy silently no-op'd).
5. **Hosting** (only if a web build changed): `flutter build web` in the app; the site name from
   `firebase.json` (`agrimore-66a4e` marketplace · `agrimore-66a4e-bb1da` admin ·
   `agrimore-delivery-partner` · `agrimore-seller-app`).
6. **Print the exact commands, in order, functions first when a rule depends on a function:**
   ```
   firebase deploy --only functions:<name1>,functions:<name2> --project agrimore-66a4e
   firebase deploy --only firestore:rules --project agrimore-66a4e
   firebase deploy --only firestore:indexes --project agrimore-66a4e
   firebase deploy --only hosting:<site> --project agrimore-66a4e
   ```
   and the post-deploy read-only verification the owner (or the next `status` call) runs:
   `firebase functions:list` count/generation before vs after (nothing created or deleted beyond the
   named set; orphans still present) · `firebase firestore:indexes` re-read until `[READY]` · the
   specific itemised `Successful update/create operation.` lines, not the summary.
7. **Play**: a client change reaches users only through a release — `pubspec.yaml` version
   `1.0.<n>+YYYYMMDDnn` (strictly above the last published code), `upload-key.jks` from the owner's
   backup at `apps/marketplace/android/upload-key.jks`, `flutter build appbundle --release`, verify
   the merged manifest's `versionCode`. Owner-only; the skill can build a debug APK for testing.

## 5. Production (`main`)

Everything in §4 against the `main` SHA, plus: a rollback plan naming the previous `main` SHA and,
for rules, the previous rules file kept outside `/tmp` (the 2026-08-31 rollback copy lived in `/tmp`
and does not survive a reboot); the `Promotions` row carrying the deploy commands handed over and,
once the owner reports back, the `functions:list` before/after evidence.

## 6. Report

```
PROMOTE — <target> ← <source>
moved: <from>..<to> (<n> commits, listed)   ff check: ok   worktree holding target: none|<path>
preconditions: table (each with the command and result)   emulator sweep: <gate table path>
push: NOT DONE — command printed for the owner | done after the owner's word (quoted)
deploy handover: functions to create [..] · to update [..] (generation changes flagged) · orphans untouched [6] · rules (client compat stated) · indexes (would-create n / would-delete 0) · hosting sites
ledger Promotions row: line <n>, commit <sha>
```
