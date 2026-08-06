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

# The gate, verbatim in behaviour.
resolve() { # resolve <root> <prd-path> -> LOCKED|UNLOCKED
	local root="$1" prd="$2" slug
	slug="$(basename "$prd" .md | sed 's/^prd-//')"
	if grep -qE '^<!-- prd-locked:' "$prd" 2>/dev/null; then echo LOCKED
	elif [ -f "$root/tasks/proto-$slug/.prd-locked" ]; then echo LOCKED
	else echo UNLOCKED; fi
}

scenario() { # scenario <name> <prd-marker yes|no> <gallery yes|no|dir-only>
	local d; d="$(mktemp -d "$TMP/$1.XXXX")"; mkdir -p "$d/tasks"
	local prd="$d/tasks/prd-demo.md"
	{ [ "$2" = yes ] && printf '<!-- prd-locked: @me · 2026-08-06 · ui:tasks/proto-demo/ -->\n'; \
	  printf '# PRD\n## Vertical Slices\n'; } > "$prd"
	case "$3" in
		yes)      mkdir -p "$d/tasks/proto-demo"; printf '@me · 2026-08-06 · ui:tasks/proto-demo/\n' > "$d/tasks/proto-demo/.prd-locked" ;;
		dir-only) mkdir -p "$d/tasks/proto-demo"; printf 'notes\n' > "$d/tasks/proto-demo/notes.md" ;;
	esac
	resolve "$d" "$prd"
}

check "1 prd marker only"                LOCKED   "$(scenario prdonly  yes no)"
check "2 gallery marker only"            LOCKED   "$(scenario gallonly no  yes)"
check "3 both markers"                   LOCKED   "$(scenario both     yes yes)"
check "4 neither → still hard-stops"     UNLOCKED "$(scenario neither  no  no)"
check "5 PARTIAL run (gallery dir, no marker) → still hard-stops" UNLOCKED "$(scenario partial no dir-only)"

echo "lock-resolution: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
