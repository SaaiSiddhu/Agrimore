#!/usr/bin/env bash
# merge-develop.sh — merge a VERIFIED phase branch into develop INSIDE the develop worktree, with every guard from
# references/merge.md. Stops before the commit (inspection window) unless --commit is given; resumes an open window.
# Never touches any other worktree. Never pushes. Never deploys.
# Usage: bash .claude/skills/agrimore/scripts/merge-develop.sh <branch> [--commit] [--develop-worktree <path>]
set -uo pipefail
BRANCH="${1:-}"; [ -n "$BRANCH" ] || { sed -n '2,5p' "$0"; exit 2; }; shift
# GOV-5: since the 2026-09-20 single-folder consolidation there is normally ONE worktree and it holds
# `develop`, so resolve to whichever worktree actually has develop out and fall back to the repo root.
# The legacy ../Agrimore-develop path still wins when it exists; AGRIMORE_DEVELOP_WORKTREE wins over both.
COMMIT=0
if [ -n "${AGRIMORE_DEVELOP_WORKTREE:-}" ]; then D="$AGRIMORE_DEVELOP_WORKTREE"
elif [ -d "/Users/saai_siddharth/Projects/Clients/Agrimore-develop" ]; then D="/Users/saai_siddharth/Projects/Clients/Agrimore-develop"
else
  D="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/develop$/{print w; exit}')"
  [ -n "$D" ] || D="$(git rev-parse --show-toplevel 2>/dev/null)"
fi
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
  # GOV-5: this used to demand a spotless worktree. That is unsatisfiable now — the single folder
  # carries owner-sanctioned WIP indefinitely — and it was always a proxy for the property that
  # actually matters: the merge must not touch a file with uncommitted local changes. Git itself
  # refuses that case, but failing HERE names the offending paths instead of leaving a half-merge.
  # Untracked paths count too: an incoming file that already exists untracked would be clobbered.
  MB="$(git -C "$D" merge-base develop "$BRANCH")" || fail "cannot compute merge-base of develop and $BRANCH"
  git -C "$D" diff --name-only "$MB".."$BRANCH" | sort -u > /tmp/agrimore-merge-incoming.txt
  git -C "$D" status --porcelain | sed 's/^...//; s/.* -> //' | sort -u > /tmp/agrimore-merge-dirty.txt
  CLASH="$(comm -12 /tmp/agrimore-merge-incoming.txt /tmp/agrimore-merge-dirty.txt)"
  if [ -n "$CLASH" ]; then
    echo "--- files this merge touches that also have uncommitted local changes:" >&2
    echo "$CLASH" | sed 's/^/    /' >&2
    fail "commit, move aside or attribute the paths above before merging (AGRIMORE_STRICT_CLEAN=1 restores the old all-or-nothing check)"
  fi
  if [ "${AGRIMORE_STRICT_CLEAN:-0}" = "1" ]; then
    [ "$(git -C "$D" status --porcelain | wc -l | tr -d ' ')" = "0" ] || fail "AGRIMORE_STRICT_CLEAN=1 and $D is dirty"
  fi
  DIRTY_N="$(git -C "$D" status --porcelain | wc -l | tr -d ' ')"
  [ "$DIRTY_N" = "0" ] || echo "note: $DIRTY_N uncommitted path(s) present, NONE overlapping this merge — they are left untouched (verify after: git status)"
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
