#!/usr/bin/env bash
# test-lock-resolution.sh — /saki-builder:build GATE 1.5 must resolve the approval proof from EITHER
# the PRD marker or the gallery marker, and must still refuse when neither exists (plan I6, S1/S2).
#
# The function below mirrors the resolution block documented in config/skills/build/SKILL.md GATE 1.5.
# If that block changes, this file must change with it — that coupling is the point.

set -u
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() {
	if [ "$2" = "$3" ]; then pass=$((pass + 1))
	else fail=$((fail + 1)); printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"; fi
}

# The gate, mirroring config/skills/build/SKILL.md GATE 1.5 **verbatim**, including its path handling.
# Deliberately NOT parameterised on a root: the shipped block anchors on `git rev-parse --show-toplevel`,
# and an earlier version of this mirror took a $root argument — which made it structurally unable to
# catch a cwd-dependence bug in the real gate. The mirror must be able to fail the same way.
resolve() { # resolve <prd-path> -> LOCKED (…)|UNLOCKED   (run from anywhere)
	local PRD="$1" ROOT SLUG MARK
	ROOT="$(git -C "$(dirname "$PRD")" rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$PRD")")"
	SLUG="$(basename "$PRD" .md | sed 's/^prd-//')"
	MARK="$ROOT/tasks/proto-$SLUG/.prd-locked"
	if grep -qE '^<!-- prd-locked:' "$PRD" 2>/dev/null; then echo "LOCKED (prd marker)"
	elif [ -f "$MARK" ] && grep -qF "prd:$(basename "$PRD")" "$MARK"; then echo "LOCKED (gallery marker)"
	else echo UNLOCKED; fi
}

scenario() { # scenario <name> <prd-marker yes|no> <gallery yes|no|dir-only> [prd-basename] [cwd]
	local d; d="$(mktemp -d "$TMP/$1.XXXX")"; mkdir -p "$d/tasks"
	git -C "$d" init -q 2>/dev/null   # so `git rev-parse --show-toplevel` resolves, as it does in a real repo
	local name="${4:-prd-demo.md}" prd="$d/tasks/${4:-prd-demo.md}"
	{ [ "$2" = yes ] && printf '<!-- prd-locked: @me · 2026-08-06 · ui:tasks/proto-demo/ -->\n'; \
	  printf '# PRD\n## Vertical Slices\n'; } > "$prd"
	case "$3" in
		yes)      mkdir -p "$d/tasks/proto-demo"; printf '@me · 2026-08-06 · prd:prd-demo.md · ui:tasks/proto-demo/\n' > "$d/tasks/proto-demo/.prd-locked" ;;
		dir-only) mkdir -p "$d/tasks/proto-demo"; printf 'notes\n' > "$d/tasks/proto-demo/notes.md" ;;
	esac
	[ "$3" = no-prd-file ] && rm -f "$prd"
	if [ -n "${5:-}" ]; then mkdir -p "$d/$5"; ( cd "$d/$5" && resolve "$prd" ); else resolve "$prd"; fi
}

check "1 prd marker only"                "LOCKED (prd marker)"     "$(scenario prdonly  yes no)"
check "2 gallery marker only"            "LOCKED (gallery marker)" "$(scenario gallonly no  yes)"
check "3 both markers"                   "LOCKED (prd marker)"     "$(scenario both     yes yes)"
check "4 neither → still hard-stops"     UNLOCKED                  "$(scenario neither  no  no)"
check "5 PARTIAL run (gallery dir, no marker) → still hard-stops" UNLOCKED "$(scenario partial no dir-only)"

# ── 6. REGRESSION (reviewer HIGH-b): a DIFFERENT file deriving the same slug must NOT
#      inherit the gallery's approval. build accepts a PRD by content shape, not filename,
#      so `demo.md` derives slug `demo` exactly as `prd-demo.md` does.
check "6 slug collision does not inherit" UNLOCKED "$(scenario collide no yes demo.md)"

# ── 7. REGRESSION (reviewer MED): the gate must resolve from ANY cwd. The old mirror took a
#      $root argument, which made it structurally unable to catch a cwd bug in the real gate.
check "7 gallery marker resolves from a subdir" "LOCKED (gallery marker)" "$(scenario cwd no yes prd-demo.md sub/deep)"
check "7 prd marker resolves from a subdir"     "LOCKED (prd marker)"     "$(scenario cwd2 yes no prd-demo.md sub/deep)"

echo "lock-resolution: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
