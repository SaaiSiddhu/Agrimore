#!/usr/bin/env bash
# promote.sh — fast-forward-only promotion: staging ← develop, main ← staging. Never pushes without an explicit confirmation
# variable set by the session AFTER the owner's word in the same message. Never deploys. See references/promote.md.
# Usage: bash .claude/skills/agrimore/scripts/promote.sh <staging|main> [--push]
#   --push requires AGRIMORE_PROMOTE_CONFIRM=<target> in the environment (set it only after the owner's word).
#   The machine's GitHub credential (gh: Edynox-hq) has no write access to SRIESWARAN01/Agrimore-Full-Project —
#   expect the push to be run by the owner from the printed command.
set -uo pipefail
T="${1:-}"; PUSH=0; [ "${2:-}" = "--push" ] && PUSH=1
case "$T" in staging) SRC=develop;; main) SRC=staging;; *) sed -n '2,7p' "$0"; exit 2;; esac
R="$(git rev-parse --show-toplevel)"; fail() { echo "ABORT: $*" >&2; exit 1; }
for b in "$SRC" "$T"; do git -C "$R" show-ref --verify --quiet "refs/heads/$b" || fail "branch $b missing"; done
HOLDER="$(git -C "$R" worktree list | grep -w "\[$T\]" | awk '{print $1}' || true)"
git -C "$R" merge-base --is-ancestor "$T" "$SRC" || fail "$T has commits that are not in $SRC — promotion must be a fast-forward; investigate the divergence"
FROM="$(git -C "$R" rev-parse "$T")"; TO="$(git -C "$R" rev-parse "$SRC")"
if [ "$FROM" = "$TO" ]; then echo "$T already at $SRC ($TO)"; else
  echo "--- $T will move $(git -C "$R" rev-parse --short "$FROM") → $(git -C "$R" rev-parse --short "$TO"):"; git -C "$R" log --oneline "$FROM".."$TO" | head -60
  if [ -n "$HOLDER" ]; then echo "worktree $HOLDER holds $T — fast-forwarding inside it"; git -C "$HOLDER" merge --ff-only "$SRC" || fail "ff-only merge failed inside $HOLDER"
  else git -C "$R" fetch . "$SRC:$T" || fail "ff update refused"; fi
  echo "$T now at $(git -C "$R" rev-parse --short "$T")"
fi
echo "--- deploy handover reminder (promote.md §4): functions by explicit name · rules client-compat · indexes live diff · NEVER run here"
if [ $PUSH = 1 ]; then
  [ "${AGRIMORE_PROMOTE_CONFIRM:-}" = "$T" ] || fail "AGRIMORE_PROMOTE_CONFIRM=$T is not set — the owner's word for THIS promotion is required in the same message"
  echo "pushing origin $T (no hooks exist in this repository)"
  git -C "$R" push origin "$T" || { echo "push failed — expected when the machine credential lacks write access; the owner runs: git -C $R push origin $T"; exit 1; }
  echo "pushed. Record the Promotions row (date · target · source SHA · pushed · owner's word · sweep/deploy handed over)."
else echo "push NOT done. After the owner's word: AGRIMORE_PROMOTE_CONFIRM=$T bash $0 $T --push   — or the owner runs: git -C $R push origin $T"; fi
