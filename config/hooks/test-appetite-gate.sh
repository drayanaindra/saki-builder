#!/usr/bin/env bash
# test-appetite-gate.sh — /saki-builder:pickup Phase 1.5 must route an over-appetite PRD to the
# Senior-PM recut on the SCOPE SIGNAL ITSELF, without waiting for prd-review's sentinel (plan I7).
#
# Mirrors the shipped bash in pickup Phase 1.5 VERBATIM. It reads the two machine-readable markers
# /saki-builder:prd emits (config/skills/prd/SKILL.md:483-484) — never the prose. An earlier version
# counted "### Slice N" headings and was INERT on all 5 real PRDs while double-counting §8+§9 into a
# false recut; the fixtures below pin both failure modes shut.
#
# Fail-open is load-bearing: a gate that cannot read its markers must PROCEED, never RECUT.

set -u
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() {
	if [ "$2" = "$3" ]; then pass=$((pass + 1))
	else fail=$((fail + 1)); printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"; fi
}

gate() { # gate <prd-path> -> RECUT|PROCEED
	local PRD="$1" BAND SLICES CAP
	BAND="$(grep -oE '^<!-- appetite: *(small|medium|large) *-->' "$PRD" 2>/dev/null | grep -oE '(small|medium|large)' | head -1)"
	SLICES="$(grep -oE '^<!-- slices: *[0-9]+ *-->' "$PRD" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
	case "$BAND" in small) CAP=2 ;; medium) CAP=4 ;; large) CAP=7 ;; *) CAP="" ;; esac
	[ -z "$CAP" ] && { echo PROCEED; return; }
	[ -z "$SLICES" ] && { echo PROCEED; return; }
	[ "$SLICES" -gt "$CAP" ] && echo RECUT || echo PROCEED
}

N=0
mk() { # mk <body> -> path   (BSD mktemp needs the X's last, so use a counter)
	N=$((N + 1)); local f="$TMP/prd-$N.md"; printf '%s' "$1" > "$f"; echo "$f"
}
prd() { # prd <slices-marker> <appetite-marker> [extra body]
	mk "<!-- slices: $1 -->
<!-- appetite: $2 -->
# PRD
${3:-}"
}

check "1 small, 3 slices → over"    RECUT   "$(gate "$(prd 3 small)")"
check "2 medium, 6 slices → over"   RECUT   "$(gate "$(prd 6 medium)")"
check "3 large, 9 slices → over"    RECUT   "$(gate "$(prd 9 large)")"
check "4 small, 2 slices → at cap"  PROCEED "$(gate "$(prd 2 small)")"
check "5 medium, 4 slices → at cap" PROCEED "$(gate "$(prd 4 medium)")"
check "6 large, 7 slices → at cap"  PROCEED "$(gate "$(prd 7 large)")"

# ── fail-open ────────────────────────────────────────────────────────────────
check "7 no appetite marker → fail-open" PROCEED "$(gate "$(mk '<!-- slices: 9 -->
# PRD')")"
check "8 no slices marker → fail-open"   PROCEED "$(gate "$(mk '<!-- appetite: small -->
# PRD')")"
check "9 non-band appetite → fail-open"  PROCEED "$(gate "$(mk '<!-- slices: 9 -->
<!-- appetite: ~3 days -->
# PRD')")"

# ── REGRESSION (reviewer HIGH): prose must never be mistaken for the marker ───
check "10 band word in prose does not RECUT" PROCEED \
	"$(gate "$(prd 5 large '**Appetite:** ~2 weeks — this is not a small- or medium-sized job')")"
check "11 fenced template band does not win" PROCEED \
	"$(gate "$(prd 3 large '```
<!-- appetite: small -->
```')")"

# ── REGRESSION (reviewer HIGH): §8+§9 heading repetition must not double-count ─
check "12 slice headings under both §8 and §9 do not inflate" PROCEED \
	"$(gate "$(prd 2 small '## 8. Vertical Slices
### Slice 1 — a
### Slice 2 — b
## 9. Acceptance Criteria per Slice
### Slice 1 — a
### Slice 2 — b')")"

# ── REGRESSION (reviewer HIGH): the gate must FIRE on the real corpus ─────────
REAL="$(cd "$(dirname "$0")/../.." && pwd)/tasks/prd-proto-first-loop-the-visual-gate-precedes-the-prd.md"
if [ -f "$REAL" ]; then
	check "13 real PRD (large, 6 slices) is readable → PROCEED not fail-open" PROCEED "$(gate "$REAL")"
	check "13b real PRD markers parse" "large 6" \
		"$(grep -oE '^<!-- appetite: *(small|medium|large) *-->' "$REAL" | grep -oE '(small|medium|large)') $(grep -oE '^<!-- slices: *[0-9]+ *-->' "$REAL" | grep -oE '[0-9]+')"
fi

echo "appetite-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
