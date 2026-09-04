#!/usr/bin/env bash
# merge-develop.sh — merge a VERIFIED phase branch into develop INSIDE the develop worktree, with every guard from
# references/merge.md. Stops before the commit (inspection window) unless --commit is given; resumes an open window.
# Never touches any other worktree. Never pushes. Never deploys.
# Usage: bash .claude/skills/agrimore/scripts/merge-develop.sh <branch> [--commit] [--develop-worktree <path>]
set -uo pipefail
BRANCH="${1:-}"; [ -n "$BRANCH" ] || { sed -n '2,5p' "$0"; exit 2; }; shift
COMMIT=0; D="${AGRIMORE_DEVELOP_WORKTREE:-/Users/saai_siddharth/Projects/Clients/Agrimore-develop}"
while [ $# -gt 0 ]; do case "$1" in --commit) COMMIT=1;; --develop-worktree) D="$2"; shift;; *) echo "unknown flag $1" >&2; exit 2;; esac; shift; done
fail() { echo "ABORT: $*" >&2; exit 1; }
RETIRED='^(Agrimore-main/|legacy_archive/|apk-output/|\.firebase/|functions/src/customer/cartSplitting\.ts$|functions/(scripts/)?fix_admin\.js$|packages/agrimore_core/lib/config/(env_config|razorpay_config)\.dart$)'
[ -d "$D/.git" ] || [ -f "$D/.git" ] || fail "develop worktree not found at $D (git worktree add $D develop)"
[ "$(git -C "$D" rev-parse --abbrev-ref HEAD)" = "develop" ] || fail "$D does not hold develop"
[ "$(git -C "$D" worktree list | grep -c '\[develop\]')" = "1" ] || fail "develop is checked out in more than one worktree"
git -C "$D" show-ref --verify --quiet "refs/heads/$BRANCH" || fail "branch $BRANCH does not exist"
RESUME=0
if MH="$(git -C "$D" rev-parse -q --verify MERGE_HEAD 2>/dev/null)"; then
  [ "$MH" = "$(git -C "$D" rev-parse "$BRANCH")" ] || fail "a merge of a DIFFERENT commit ($MH) is in progress in $D — finish or abort it first"
  RESUME=1; echo "resuming the open inspection window for $BRANCH"
else
  [ "$(git -C "$D" status --porcelain | wc -l | tr -d ' ')" = "0" ] || fail "develop worktree is dirty — attribute it first"
  [ "$(git -C "$D" ls-files --others --exclude-standard | wc -l | tr -d ' ')" = "0" ] || fail "develop worktree has untracked files"
fi
if git -C "$D" merge-base --is-ancestor "$BRANCH" develop; then echo "note: $BRANCH is already contained in develop"; exit 0; fi
PRE="$(git -C "$D" rev-parse HEAD)"; BASE="$(git -C "$D" merge-base develop "$BRANCH")"   # with a merge in progress HEAD is still the pre-merge tip
echo "develop=$PRE  base=$BASE  branch tip=$(git -C "$D" rev-parse --short "$BRANCH")"
echo "--- commits to merge:"; git -C "$D" log --oneline "$BASE".."$BRANCH" | head -40
echo "--- overlap (files changed on BOTH sides since base; suites must run on the RESULT if non-empty):"
comm -12 <(git -C "$D" diff --name-only "$BASE"..develop | sort) <(git -C "$D" diff --name-only "$BASE".."$BRANCH" | sort) | tee /tmp/agrimore-merge-overlap.txt
grep -q 'docs/active/BRANCH_DISPOSITIONS.md' /tmp/agrimore-merge-overlap.txt && echo "note: the ledger is on both sides — union rows, then confirm the row count moved by exactly the phase's rows"
grep -qE '^(firestore\.rules|functions/src/index\.ts)$' /tmp/agrimore-merge-overlap.txt && echo "WARNING: a historical collision file is on both sides — run the rules/functions suites on the result before --commit"
if [ $RESUME = 1 ]; then :; elif ! git -C "$D" merge --no-ff --no-commit "$BRANCH" >/tmp/agrimore-merge.log 2>&1; then
  echo "--- merge has conflicts (resolve ONLY inside the phase's files, then re-run with --commit):"; git -C "$D" diff --name-only --diff-filter=U; exit 3
fi
echo "--- staged result (uncommitted):"; git -C "$D" diff --cached --name-status | head -60
[ "$(git -C "$D" diff --name-only --diff-filter=U | wc -l | tr -d ' ')" = "0" ] || fail "unresolved conflicts remain"
[ "$(git -C "$D" rev-parse refs/heads/develop)" = "$PRE" ] || fail "refs/heads/develop moved during the merge ($PRE → $(git -C "$D" rev-parse refs/heads/develop)); git -C $D merge --abort and retry"
if [ $COMMIT = 0 ]; then echo "inspection window open — verify, then: bash $0 $BRANCH --commit   (or: git -C $D merge --abort)"; exit 0; fi
git -C "$D" commit -q -m "Merge branch '$BRANCH' into develop" || fail "commit failed"
M="$(git -C "$D" rev-parse HEAD)"; echo "merge commit: $M"
echo "--- first-parent diff (must be within the phase's files + ledger):"; git -C "$D" diff --name-status "$PRE" "$M" | head -80
RES="$(git -C "$D" ls-tree -r "$M" --name-only | grep -cE "$RETIRED" || true)"
[ "$RES" = "0" ] || echo "WARNING: resurrection check found $RES retired paths in the result tree — investigate before anything else"
echo "resurrection check: $RES"
git -C "$D" reflog show develop -1
echo "author/committer: $(git -C "$D" log -1 --format='%an <%ae> | %cn <%ce>')"
echo "next: suites on $M if overlap was non-empty or packages/** moved (five-app analyze) · ledger bookkeeping commit (ACTIVE → MERGED_DEVELOP, Merged into = $M) · worktree disposition · deploy consequence carried forward · NO push (owner pushes)"
