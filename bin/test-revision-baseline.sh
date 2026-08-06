#!/usr/bin/env bash
# test-revision-baseline.sh — the baseline aggregator must count only what it can honestly count.
#
# The failure this guards is the one that got E1 rejected: a baseline number sourced from something
# that measures a different quantity, or from runs that never converged. Both understate the real
# cost in the flattering direction.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/revision-baseline.js"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
# Numeric-aware: JS serializes 2 (not 2.0) while python prints 2.0, so a string compare on a
# computed mean fails on formatting alone. Compare as numbers when both sides parse as numbers.
check() {
	local ok=0
	if [ "$2" = "$3" ]; then ok=1
	elif python3 -c "import sys
try: sys.exit(0 if float(sys.argv[1])==float(sys.argv[2]) else 1)
except ValueError: sys.exit(1)" "$2" "$3" 2>/dev/null; then ok=1; fi
	if [ "$ok" = 1 ]; then pass=$((pass + 1))
	else fail=$((fail + 1)); printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"; fi
}

# Build an isolated repo so the real tasks/ never influences the result.
mk() { # mk <name> -> a repo root with bin/revision-baseline.js reachable
	local d="$TMP/$1"; mkdir -p "$d/bin" "$d/tasks"; cp "$SCRIPT" "$d/bin/"; echo "$d"
}
run() { node "$1/bin/revision-baseline.js" --json; }
field() { python3 -c "import json,sys;d=json.load(sys.stdin);print(d[sys.argv[1]])" "$2"; }

# ── 1. a green run with a stamped header counts, and the header wins over the state file ──
d="$(mk stamped)"
printf '<!-- revision-passes: 3 -->\n# PRD\n' > "$d/tasks/prd-a.md"
printf '{"slug":"a","phase":"green","review":{"rounds":9,"verdict":"SHIP","blockers_fixed":9}}\n' > "$d/tasks/.prd-review-a-state.json"
out="$(run "$d")"
check "1 measured count"  1   "$(printf '%s' "$out" | field _ measured)"
check "1 header wins (3, not the state file's 9)" 3.0 "$(printf '%s' "$out" | field _ baseline)"

# ── 2. a run that never reached green is EXCLUDED — the load-bearing rule ──
d="$(mk notgreen)"
printf '<!-- revision-passes: 1 -->\n# PRD\n' > "$d/tasks/prd-b.md"
printf '{"slug":"b","phase":"blocked","review":{"rounds":1,"verdict":"DISCOVERY-FIRST","blockers_fixed":3}}\n' > "$d/tasks/.prd-review-b-state.json"
out="$(run "$d")"
check "2 non-green excluded"  0    "$(printf '%s' "$out" | field _ measured)"
check "2 baseline is null, not 1" None "$(printf '%s' "$out" | field _ baseline)"

# ── 3. state-file fallback: rounds count only when fixes were actually applied ──
d="$(mk fallback)"
printf '# PRD\n' > "$d/tasks/prd-c.md"
printf '{"slug":"c","phase":"green","review":{"rounds":2,"verdict":"SHIP","blockers_fixed":0}}\n' > "$d/tasks/.prd-review-c-state.json"
check "3 rounds with 0 fixes = 0 passes" 0.0 "$(run "$d" | field _ baseline)"

d="$(mk fallback2)"
printf '# PRD\n' > "$d/tasks/prd-d.md"
printf '{"slug":"d","phase":"green","review":{"rounds":2,"verdict":"SHIP","blockers_fixed":5}}\n' > "$d/tasks/.prd-review-d-state.json"
check "3b rounds with fixes = that many passes" 2.0 "$(run "$d" | field _ baseline)"

# ── 4. averaging across two green runs ──
d="$(mk avg)"
for n in 1 3; do
	printf '<!-- revision-passes: %s -->\n# PRD\n' "$n" > "$d/tasks/prd-e$n.md"
	printf '{"slug":"e%s","phase":"green","review":{"rounds":%s,"verdict":"SHIP","blockers_fixed":1}}\n' "$n" "$n" > "$d/tasks/.prd-review-e$n-state.json"
done
out="$(run "$d")"
check "4 n=2"          2   "$(printf '%s' "$out" | field _ measured)"
check "4 mean of 1,3"  2.0 "$(printf '%s' "$out" | field _ baseline)"

# ── 5. a review record is never mistaken for a PRD ──
d="$(mk reviewfile)"
printf '<!-- revision-passes: 5 -->\n# review\n' > "$d/tasks/prd-f-review.md"
check "5 -review.md is not counted as a PRD" 0 "$(run "$d" | field _ measured)"

# ── 6. empty repo → no crash, no fabricated baseline ──
d="$(mk empty)"
check "6 empty → measured 0"      0    "$(run "$d" | field _ measured)"
check "6 empty → baseline null"   None "$(run "$d" | field _ baseline)"

echo "revision-baseline: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
