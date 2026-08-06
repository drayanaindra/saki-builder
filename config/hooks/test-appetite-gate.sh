#!/usr/bin/env bash
# test-appetite-gate.sh — /saki-builder:pickup Phase 1.5 must route an over-appetite PRD to the
# Senior-PM recut on the SCOPE SIGNAL ITSELF, without waiting for prd-review's sentinel (plan I7).
#
# Mirrors the comparison documented in pickup Phase 1.5. The caps are OWNED by
# config/skills/prd/SKILL.md:412-413 (small ≤2 · medium ≤4 · large ≤7) — pickup cites them, and so
# does this mirror. If those caps change, this file changes with them.
#
# Fail-open is load-bearing: a gate that cannot read its band must PROCEED, never RECUT.

set -u
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() {
	if [ "$2" = "$3" ]; then pass=$((pass + 1))
	else fail=$((fail + 1)); printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"; fi
}

gate() { # gate <prd-path> -> RECUT|PROCEED
	local prd="$1" band cap slices
	band="$(grep -oiE '\*\*Appetite:?\*\*[^|]*\b(small|medium|large)\b' "$prd" 2>/dev/null |
		grep -oiE '\b(small|medium|large)\b' | head -1 | tr '[:upper:]' '[:lower:]')"
	case "$band" in
		small) cap=2 ;; medium) cap=4 ;; large) cap=7 ;;
		*) echo PROCEED; return ;;   # band absent or not comparable → fail-open
	esac
	# grep -c prints 0 AND exits 1 on no-match, so `|| echo 0` would yield "0\n0".
	slices="$(grep -cE '^### Slice [0-9]+' "$prd" 2>/dev/null)"; slices=${slices:-0}
	[ "$slices" -eq 0 ] && { echo PROCEED; return; }   # no §8 to read → fail-open
	[ "$slices" -gt "$cap" ] && echo RECUT || echo PROCEED
}

N=0
mk() { # mk <band-text> <n-slices> -> path
	# NOT mktemp: BSD/macOS mktemp requires the X's to END the template, so "prd.XXXX.md" fails.
	N=$((N + 1))
	local f="$TMP/prd-$N.md"
	printf '# PRD\n\n## 6. Appetite\n**Appetite:** %s\n\n## 8. Vertical Slices\n' "$1" > "$f"
	local i=1; while [ "$i" -le "$2" ]; do printf '### Slice %d — thing %d\n' "$i" "$i" >> "$f"; i=$((i+1)); done
	echo "$f"
}

check "1 small, 3 slices → over"        RECUT   "$(gate "$(mk 'small — a day' 3)")"
check "2 medium, 6 slices → over"       RECUT   "$(gate "$(mk 'medium — a few days' 6)")"
check "3 large, 9 slices → over"        RECUT   "$(gate "$(mk 'large — a week+' 9)")"
check "4 small, 2 slices → at cap"      PROCEED "$(gate "$(mk 'small — a day' 2)")"
check "5 medium, 4 slices → at cap"     PROCEED "$(gate "$(mk 'medium — a few days' 4)")"
check "6 large, 7 slices → at cap"      PROCEED "$(gate "$(mk 'large — a week+' 7)")"
check "7 non-band appetite → fail-open" PROCEED "$(gate "$(mk '~3 days' 9)")"
check "8 no slices section → fail-open" PROCEED "$(gate "$(mk 'medium — a few days' 0)")"

echo "appetite-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
