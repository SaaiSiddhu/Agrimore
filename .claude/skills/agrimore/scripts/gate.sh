#!/usr/bin/env bash
# gate.sh — the deterministic gate battery for /agrimore. Prints a table (name | exit | seconds | first failure line)
# and writes every log under $AGRIMORE_GATE_OUT (default /tmp/agrimore-gate/<branch>-<sha>-<ts>/).
#
# Built ONLY from commands that exist in this repository (measured 2026-09-04 at c8f6f30):
#   cd functions && npm run build                       tsc
#   (cd apps/<app> && flutter analyze)                  ×5 — PASS = zero `error •` lines (the tool exits 1 on info lints)
#   node scripts/phase19_client_secret_guard_test.js    no emulator   (client secret exposure guard, 15 checks)
#   node scripts/phase18_secret_binding_test.js         no emulator   (Secret Manager bindings)
#   node scripts/phase16b4_fee_truthfulness_test.js     no emulator   (fee copy logic, 54 checks)
#   node scripts/phase23_deploy_bundle_guard_test.js    no emulator   (no credential in the deploy bundle, 5 checks)
#   node scripts/phaseDLV1A_delivery_states_test.js     no emulator   (TS delivery states vs the shared fixture — the Dart/TS parity guard)
#   (cd packages/agrimore_core && flutter test)         --full        (Dart delivery enums vs the same fixture)
#   (cd apps/delivery && flutter test)                  --full        (rider offers: model, refusal wording, offer screen)
#   node scripts/governance/validate-branch-dispositions.mjs   ledger vs git (warnings; exit 0 always — we count "warning(s)")
#   (cd apps/marketplace && flutter test)               --full        (the only Dart suite)
#   firebase emulators:exec --only <set> --project agrimore-66a4e "cd functions && node scripts/<suite>.js"   --emulator, one FRESH emulator per suite
#     <set> is per suite: a *storage* suite gets `storage` (port 9199), every other suite gets `firestore,functions,auth`
#   node scripts/verify_secrets.js                      --secrets     (cloud METADATA read; deploy gate)
#
# Usage: bash .claude/skills/agrimore/scripts/gate.sh [--quick|--baseline|--full] [--emulator] [--emulator-suites a,b] [--secrets] [--apps a,b]
#   (default)   functions build · analyze ×5 · the three no-emulator guards · ledger validator
#   --quick     functions build · analyze ×5
#   --baseline  same as default, labelled BASELINE (run on the untouched branch before building)
#   --full      default + flutter test (apps/marketplace)
#   --emulator  + every functions/scripts/phase*_test.js (or --emulator-suites list) on a fresh emulator each; needs JDK 21 and free ports
#   --secrets   + verify_secrets.js (reads Secret Manager metadata for agrimore-66a4e; never a value)
#   --apps      restrict analyze to a comma list (five is the rule whenever packages/** moved — say so if you restrict)
#
# Rules encoded here (see references/hazards.md):
#  - runs from a git worktree root; refuses whenever `main` or `staging` is the checked-out branch
#    (they are promotion targets, never build surfaces) unless AGRIMORE_ALLOW_PROTECTED=1
#  - never deploys, never deletes a function, never writes to agrimore-66a4e, never starts an emulator on a held port
#  - exit code = number of failed checks (0 = all green); ambient reds still count — attribute them in the report
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || { echo "gate.sh: not inside a git worktree" >&2; exit 2; }
# GOV-5: the guard is on the CHECKED-OUT BRANCH, not on a path. Before the 2026-09-20 single-folder
# consolidation this refused one hard-coded directory because that directory held `main`; the repo is
# one worktree now and that folder holds `develop`, so the path check refused every legitimate gate.
# The property actually worth protecting never changed: `main` and `staging` are promotion targets that
# move only by fast-forward, so nothing should be built, tested or mutated while one of them is out.
GATE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo DETACHED)"
case "$GATE_BRANCH" in
  main|staging)
    if [ "${AGRIMORE_ALLOW_PROTECTED:-${AGRIMORE_ALLOW_PRIMARY:-0}}" != "1" ]; then
      echo "gate.sh: refusing to run with '$GATE_BRANCH' checked out — main/staging are promotion targets, never build surfaces." >&2
      echo "         switch to develop or a phase branch, or set AGRIMORE_ALLOW_PROTECTED=1 to override." >&2
      exit 2
    fi
    echo "gate.sh: WARNING — running with protected branch '$GATE_BRANCH' checked out (override in effect)" >&2;;
esac
cd "$ROOT"
MODE=default; EMU=0; SECRETS=0; APPS="marketplace admin seller delivery employee"; SUITES=""
while [ $# -gt 0 ]; do case "$1" in
  --quick) MODE=quick;; --baseline) MODE=baseline;; --full) MODE=full;;
  --emulator) EMU=1;; --emulator-suites) SUITES="$(echo "$2" | tr ',' ' ')"; EMU=1; shift;;
  --secrets) SECRETS=1;; --apps) APPS="$(echo "$2" | tr ',' ' ')"; shift;;
  -h|--help) sed -n '2,30p' "$0"; exit 0;;
  *) echo "gate.sh: unknown flag $1" >&2; exit 2;; esac; shift; done
BRANCH="$(git rev-parse --abbrev-ref HEAD)"; SHA="$(git rev-parse --short HEAD)"; TS="$(date +%Y%m%d-%H%M%S)"
OUT="${AGRIMORE_GATE_OUT:-/tmp/agrimore-gate/$(echo "$BRANCH" | tr '/' '_')-$SHA-$TS}"; mkdir -p "$OUT"
[ -d functions/node_modules ] || echo "WARNING: functions/node_modules missing — run: cd functions && npm ci"
for a in $APPS; do [ -f "apps/$a/.dart_tool/package_config.json" ] || echo "WARNING: apps/$a has no package_config — run flutter pub get there first"; done
echo "gate.sh mode=$MODE emulator=$EMU secrets=$SECRETS apps=[$APPS] root=$ROOT branch=$BRANCH sha=$SHA dirty=$(git status --porcelain | wc -l | tr -d ' ') untracked=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
echo "logs → $OUT"
FAILS=0; ROWS=()
row() { ROWS+=("$(printf '%-42s | %4s | %5ss | %s' "$1" "$2" "$3" "$4")"); printf '  %-42s exit=%s (%ss)%s\n' "$1" "$2" "$3" "${4:+  $4}"; }
run() { # run <name> <command…>   PASS = exit 0
  local name="$1"; shift; local log="$OUT/$(echo "$name" | tr ' /:' '___').log"; local start=$SECONDS
  ( "$@" ) >"$log" 2>&1; local rc=$?; local secs=$((SECONDS-start)); local first=""
  if [ $rc -ne 0 ]; then first="$(grep -E 'FAIL|✗|❌|Error|error TS[0-9]+|MISSING|failed' "$log" | grep -vE '0 failed|✅|PASSED' | head -1 | cut -c1-110 || true)"; FAILS=$((FAILS+1)); fi
  row "$name" "$rc" "$secs" "$first"
}
analyze() { # analyze <app>   PASS = zero error lines (flutter analyze exits 1 on info/warning by design)
  local app="$1"; local log="$OUT/analyze_$app.log"; local start=$SECONDS
  ( cd "apps/$app" && flutter analyze ) >"$log" 2>&1; local rc=$?; local secs=$((SECONDS-start))
  local e w i; e=$(grep -cE '^ *error •' "$log"); w=$(grep -cE '^ *warning •' "$log"); i=$(grep -cE '^ *info •' "$log")
  local verdict=0; [ "$e" -eq 0 ] || verdict=1
  local first=""; [ "$e" -eq 0 ] || first="$(grep -E '^ *error •' "$log" | head -1 | cut -c1-110)"
  [ $verdict -eq 0 ] || FAILS=$((FAILS+1))
  row "analyze:$app" "$verdict" "$secs" "errors=$e warnings=$w infos=$i (tool exit $rc)${first:+ — $first}"
}
# ---- core
run functions:build            bash -c 'cd functions && npm run build'
for a in $APPS; do analyze "$a"; done
if [ "$MODE" != quick ]; then
  run guard:client-secrets     bash -c 'cd functions && node scripts/phase19_client_secret_guard_test.js'
  run guard:secret-bindings    bash -c 'cd functions && node scripts/phase18_secret_binding_test.js'
  run guard:fee-truthfulness   bash -c 'cd functions && node scripts/phase16b4_fee_truthfulness_test.js'
  run guard:deploy-bundle      bash -c 'cd functions && node scripts/phase23_deploy_bundle_guard_test.js'
  run guard:delivery-states    bash -c 'cd functions && node scripts/phaseDLV1A_delivery_states_test.js'
  # UI-TEAL-0: zero-literal ratchet (ADR §6) — literal debt may shrink, never grow
  run canon:seller             bash .claude/skills/agrimore/scripts/canon_check.sh --ratchet apps/seller/lib
  run canon:employee           bash .claude/skills/agrimore/scripts/canon_check.sh --ratchet apps/employee/lib
  # the validator always exits 0 — count its warnings as the signal
  VLOG="$OUT/ledger_validator.log"; node scripts/governance/validate-branch-dispositions.mjs >"$VLOG" 2>&1; VW=$(grep -c '•' "$VLOG" || true)
  row "ledger:validate" "0" "0" "warnings=$VW$( [ "$VW" -gt 0 ] && echo " — $(grep -m1 '•' "$VLOG" | cut -c1-100)" )"
fi
if [ "$MODE" = full ]; then
  run test:marketplace         bash -c 'cd apps/marketplace && flutter test'
  run test:agrimore_ui         bash -c 'cd packages/agrimore_ui && flutter test'
  run test:employee            bash -c 'cd apps/employee && flutter test'
  run test:agrimore_core       bash -c 'cd packages/agrimore_core && flutter test'
  run test:delivery            bash -c 'cd apps/delivery && flutter test'
fi
if [ $SECRETS = 1 ]; then
  run secrets:verify           bash -c 'cd functions && node scripts/verify_secrets.js'
fi
if [ $EMU = 1 ]; then
  export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"; export PATH="$JAVA_HOME/bin:$PATH"
  HELD=""; for p in 8080 5001 9099 4000 9199; do lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1 && HELD="$HELD $p"; done   # 9199 = storage (SEC-3)
  if [ -n "$HELD" ]; then
    row "emulator:suites" "SKIP" "0" "ports$HELD held by another process — never stop it; re-run when free"
  elif ! "$JAVA_HOME/bin/java" -version >/dev/null 2>&1; then
    row "emulator:suites" "SKIP" "0" "no JDK at $JAVA_HOME (needs 21)"
  else
    [ -f functions/.secret.local ] || echo "note: functions/.secret.local absent — provider-dependent suites (phase16_phone_otp, phase16_email_transport, phase22_channel_config, phase14_phone_otp) will report the DISABLED state; attribute, do not chase"
    [ -n "$SUITES" ] || SUITES="$(ls functions/scripts | grep -E '^phase.*_test\.js$' | sed 's/\.js$//' | tr '\n' ' ')"
    for s in $SUITES; do
      # SEC-3: the emulator set is per suite. phase24_storage_rules_test drives the
      # STORAGE rules engine and needs --only storage; every other suite needs
      # firestore,functions,auth. Booting a storage suite without the storage
      # emulator fails at connect time, which reads like a rules regression and is
      # not one — hence the split rather than one union list (a union would also
      # boot emulators each suite does not need).
      #
      # FIX-11 amendment: phase24 now ALSO cross-reads Firestore
      # (firestore.get() in storage.rules' chat/delivery_proofs blocks), so
      # it needs both emulators. Matched by exact name, not widened to
      # *storage*, so a future storage-only suite doesn't silently inherit
      # an emulator it doesn't need.
      #
      # FIX-GATE-1 amendment: phase48_business_posts_test (BUSINESS-NETWORK-2)
      # is the same combined shape — Section A drives firestore.rules' own
      # business_posts collection, Section B drives storage.rules' own
      # business_posts/{fileName} path — so it needs both emulators too.
      # Added to this same case arm rather than widening the wildcard, for
      # the identical reason phase24 stayed exact-matched above.
      #
      # SELLER-ORDERS-1 amendment: phaseSAUTH1B_submit_application_test checks
      # that KYC photos really exist in Storage (bucket.file().exists()) — it
      # needs both emulators; without storage it fails with ECONNREFUSED 9199.
      case "$s" in
        phase24_storage_rules_test|phase48_business_posts_test|phaseSAUTH1B_submit_application_test) EMU_ONLY="storage,firestore";;
        *storage*)                                              EMU_ONLY="storage";;
        *)                                                       EMU_ONLY="firestore,functions,auth";;
      esac
      run "emu:$s" bash -c "firebase emulators:exec --only $EMU_ONLY --project agrimore-66a4e \"cd functions && node scripts/$s.js\""
    done
  fi
fi
{
  echo "GATE TABLE  mode=$MODE  branch=$BRANCH  sha=$SHA  at=$TS  failed=$FAILS"
  printf '%-42s | %4s | %6s | %s\n' name exit secs "first failure / counts"; printf '%s\n' "${ROWS[@]}"
} | tee "$OUT/summary.txt"
echo "summary → $OUT/summary.txt"
exit $FAILS
