#!/usr/bin/env bash
# surface.sh — classify changed files into review lanes. Deterministic; the router must not "judge" this.
# Usage: bash .claude/skills/agrimore/scripts/surface.sh [<base>] [<head>]     (defaults: develop..HEAD)
#        bash .claude/skills/agrimore/scripts/surface.sh --files <path-list-file>   (one path per line, e.g. a contract's may_write)
# Output: one line per file "<lane[,lane]>\t<path>" then "LANES: <space-separated>" (empty → LANES: none).
# Lanes: security · rules · functions · shared (packages/** → five-app analyze) · uiux · feedback · tests · indexes · config · docs · skill · ci
set -uo pipefail
if [ "${1:-}" = "--files" ]; then FILES="$(cat "$2")"; else
  BASE="${1:-develop}"; HEAD="${2:-HEAD}"; FILES="$(git diff --name-only "$BASE".."$HEAD" 2>/dev/null || git diff --name-only "$BASE" "$HEAD")"; fi
LANES=""   # bash 3.2 on macOS: no associative arrays
lane() { case " $LANES " in *" $1 "*) ;; *) LANES="$LANES $1";; esac; }
add() { out="${out:+$out,}$1"; lane "$1"; }
while IFS= read -r f; do [ -z "$f" ] && continue; out=""
  case "$f" in
    firestore.rules|storage.rules) add rules; add security;;
    firestore.indexes.json) add indexes; add security;;
    firebase.json|.firebaserc) add config; add security;;
  esac
  case "$f" in
    functions/src/*) add functions; add security;;
    functions/package.json|functions/package-lock.json|functions/tsconfig.json|functions/.env.example|functions/.secret.local.example) add functions; add security;;
    functions/scripts/*_test.js) add tests;;
    functions/scripts/*) add functions; add security;;
  esac
  case "$f" in
    packages/agrimore_services/lib/auth/*|packages/agrimore_services/lib/payment/*|packages/agrimore_services/lib/firebase/*|packages/agrimore_services/lib/database/*|\
    packages/agrimore_core/lib/config/*|\
    packages/agrimore_core/lib/models/user_model.dart|packages/agrimore_core/lib/models/wallet_model.dart|packages/agrimore_core/lib/models/wallet_transaction_model.dart|\
    packages/agrimore_core/lib/models/order_model.dart|packages/agrimore_core/lib/models/employee_model.dart|packages/agrimore_core/lib/models/product_credit_*|packages/agrimore_core/lib/models/benefit_*|\
    apps/*/lib/providers/*auth*|apps/*/lib/providers/*wallet*|apps/*/lib/providers/*order*|apps/*/lib/providers/*cart*|apps/*/lib/providers/*payment*|apps/*/lib/providers/*employee*|apps/*/lib/providers/*credit*|\
    apps/*/lib/services/*|apps/*/lib/screens/*/checkout/*|apps/*/lib/screens/*/cart/*|apps/*/lib/screens/*/wallet/*|apps/*/lib/screens/auth/*|apps/*/lib/screens/*/onboarding/*|apps/*/lib/screens/employee/*|\
    apps/*/pubspec.yaml|packages/*/pubspec.yaml|apps/*/android/app/build.gradle.kts|apps/*/android/app/src/main/AndroidManifest.xml|apps/*/web/index.html|\
    .env.example|.gitignore|.github/*|.claude/settings*.json)
      add security;;
  esac
  case "$f" in
    packages/*) add shared;;   # any shared-package change → flutter analyze in ALL FIVE apps
  esac
  case "$f" in
    packages/agrimore_ui/*|apps/*/lib/screens/*|apps/*/lib/widgets/*|apps/*/lib/app/themes/*|apps/*/lib/app/app.dart) add uiux;;
  esac
  case "$f" in
    *.dart) case "$f" in *_test.dart) ;; apps/*/lib/screens/*|apps/*/lib/widgets/*|packages/agrimore_ui/lib/widgets/*) add feedback;; esac;;
  esac
  case "$f" in
    apps/*/test/*|*_test.dart) add tests;;
  esac
  case "$f" in
    .claude/skills/*|scripts/governance/*) add skill;;
    .github/*) add ci;;
  esac
  case "$f" in
    docs/*|*.md) add docs;;
  esac
  printf '%s\t%s\n' "${out:-none}" "$f"
done <<< "$FILES"
echo "LANES:${LANES:- none}"
