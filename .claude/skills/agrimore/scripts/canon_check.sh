#!/usr/bin/env bash
# canon_check.sh — the zero-literal rule for AgriMore Workspace screens
# (docs/design-system/SELLER_APP_CANONICAL_ADR.md §6, Appendix A).
#
# Usage (from the repository root):
#   canon_check.sh <dir>                 report every hit as `path:line  RULE`; exit 1 on any hit (strict)
#   canon_check.sh --ratchet <dir>       exit 1 only if the TOTAL exceeds the baseline recorded in
#                                        canon_baseline.txt for <dir> (debt may shrink, never grow)
#   canon_check.sh --count <dir>         print per-rule counts and the total; always exit 0
#
# Generated localisation code (lib/l10n/**) is excluded. The Workspace system itself
# (packages/agrimore_ui/lib/workspace/**) is where literals legitimately live and is never scanned.
# bash 3.2 compatible (no associative arrays).
set -u

MODE=strict
case "${1:-}" in
  --ratchet) MODE=ratchet; shift ;;
  --count)   MODE=count; shift ;;
esac
DIR="${1:-}"
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: canon_check.sh [--ratchet|--count] <dir>"; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
BASELINE_FILE="$HERE/canon_baseline.txt"

RULES="COLOR SPACING RADIUS TYPE MOTION ICONS SHADOW STRINGS FORMAT THEME FEEDBACK"
pattern() {
  case "$1" in
    COLOR)    echo 'Color\(0x|Colors\.[a-zA-Z]' ;;
    # a literal is a number standing alone (after ( , : or space) — never the digits inside a token name like WsSpace.s16
    SPACING)  echo 'EdgeInsets\.[a-zA-Z]+\([^)]*[(,: ][0-9]*[1-9][0-9.]*[,) ]|EdgeInsets\.[a-zA-Z]+\([0-9]*[1-9]|SizedBox\((height|width): *[0-9]*[1-9]|Gap\([0-9]*[1-9]' ;;
    RADIUS)   echo 'BorderRadius\.(circular|all)\([0-9]*[1-9]|Radius\.circular\([0-9]*[1-9]' ;;
    TYPE)     echo 'TextStyle\(|fontSize: *[0-9]|fontWeight: *FontWeight\.|letterSpacing: *-?[0-9]' ;;
    MOTION)   echo 'Duration\((milli)?seconds: *[1-9]|Curves\.' ;;
    ICONS)    echo '(^|[^A-Za-z])Icons\.|FontAwesomeIcons\.|CupertinoIcons\.' ;;
    SHADOW)   echo 'BoxShadow\(' ;;
    STRINGS)  echo "Text\\( *['\"]|(label|hintText|labelText|title|message|tooltip): *['\"]" ;;
    FORMAT)   echo 'NumberFormat\(|DateFormat\(' ;;
    THEME)    echo 'ThemeData\(' ;;
    FEEDBACK) echo 'SnackBar\(|SnackbarHelper\.|AlertDialog\(' ;;
  esac
}

hits() { # hits <rule> -> "path:line:text" lines
  local p; p="$(pattern "$1")"
  grep -rnE --include='*.dart' "$p" "$DIR" 2>/dev/null \
    | grep -v '/l10n/' \
    | grep -vE '^[^:]+:[0-9]+: *//' \
    | { [ "$1" = COLOR ] && grep -vE 'Colors\.transparent[^A-Za-z]*$|Colors\.transparent[,;) ]' || cat; }
}

TOTAL=0
REPORT=""
for r in $RULES; do
  n=$(hits "$r" | wc -l | tr -d ' ')
  TOTAL=$((TOTAL + n))
  REPORT="$REPORT$(printf '%-9s %5s' "$r" "$n")
"
  if [ "$MODE" = strict ] && [ "$n" -gt 0 ]; then
    hits "$r" | cut -d: -f1,2 | sed "s/\$/  $r/"
  fi
done

printf '%s' "$REPORT"
echo "TOTAL     $TOTAL  ($DIR)"

case "$MODE" in
  count) exit 0 ;;
  strict) [ "$TOTAL" -eq 0 ] && exit 0 || exit 1 ;;
  ratchet)
    BASE=$(grep -E "^$DIR " "$BASELINE_FILE" 2>/dev/null | awk '{print $2}' | head -1)
    if [ -z "$BASE" ]; then echo "no baseline for $DIR in $BASELINE_FILE"; exit 1; fi
    if [ "$TOTAL" -gt "$BASE" ]; then
      echo "FAIL: $TOTAL literal hits > baseline $BASE — new literals were added to $DIR"
      exit 1
    fi
    echo "ratchet ok: $TOTAL <= baseline $BASE"
    [ "$TOTAL" -lt "$BASE" ] && echo "note: debt shrank — lower the baseline in canon_baseline.txt to $TOTAL"
    exit 0 ;;
esac
