#!/usr/bin/env bash
# test-namespace-refs.sh — namespace-refs.js --reverse must strip the plugin namespace for opencode
# without touching path contexts or external commands (plan I8 step 8, criterion S5).

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/namespace-refs.js"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
	if [ "$2" = "$3" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"
	fi
}

mkdir -p "$TMP/skills/demo"
cat >"$TMP/skills/demo/SKILL.md" <<'EOF'
Run /saki-builder:prd to write the spec.
Then /saki-builder:prd-review until it is green.
Path context must survive: skills/saki-builder:rplan and ./saki-builder:qa
External commands stay bare: /code-review and /security-review.
A bare /rplan is already un-namespaced and must not double up.
Sentence-final form must strip too: then run /saki-builder:build.
Longer name must win over its prefix: /saki-builder:prd-review, not prd.
A real path suffix stays put: /saki-builder:rplan/template.md
EOF
ORIG="$(cat "$TMP/skills/demo/SKILL.md")"

# 1. --dry reports the right count and writes nothing.
OUT="$(node "$SCRIPT" --reverse --dir "$TMP" --dry 2>&1)"
check "1 dry-run hit count" 4 "$(printf '%s' "$OUT" | grep -oE '[0-9]+ refs' | grep -oE '^[0-9]+')"
check "1 dry-run writes nothing" "$ORIG" "$(cat "$TMP/skills/demo/SKILL.md")"

# 2. apply → the two real refs are stripped.
node "$SCRIPT" --reverse --dir "$TMP" >/dev/null 2>&1
BODY="$(cat "$TMP/skills/demo/SKILL.md")"
check "2 /saki-builder:prd stripped" 1 "$(printf '%s' "$BODY" | grep -cE '^Run /prd to write')"
check "2 /saki-builder:prd-review stripped" 1 "$(printf '%s' "$BODY" | grep -cE '^Then /prd-review until')"

# 3. path contexts untouched (the lookbehind guard).
check "3 skills/ path untouched" 1 "$(printf '%s' "$BODY" | grep -c 'skills/saki-builder:rplan')"
check "3 ./ path untouched" 1 "$(printf '%s' "$BODY" | grep -c './saki-builder:qa')"

# 4. external commands untouched.
check "4 /code-review untouched" 1 "$(printf '%s' "$BODY" | grep -c '/code-review')"

# 4b. sentence-final refs strip (the case that silently left 18 refs namespaced), and a real
#     path suffix does not.
check "4b sentence-final stripped" 1 "$(printf '%s' "$BODY" | grep -c 'then run /build\.')"
check "4b longest-name wins" 1 "$(printf '%s' "$BODY" | grep -c '/prd-review, not prd')"
check "4b path suffix untouched" 1 "$(printf '%s' "$BODY" | grep -c 'saki-builder:rplan/template.md')"

# 5. the ONLY surviving `saki-builder:` occurrences are the 2 path contexts (count occurrences,
#    not lines — both live on the same line, and grep -c would report 1).
check "5 only path contexts survive" 3 \
	"$(python3 -c "import sys;print(sys.stdin.read().count('saki-builder:'))" <<<"$BODY")"

# 6. idempotent — a second pass finds nothing.
OUT2="$(node "$SCRIPT" --reverse --dir "$TMP" --dry 2>&1)"
check "6 idempotent" 0 "$(printf '%s' "$OUT2" | grep -oE '[0-9]+ refs' | grep -oE '^[0-9]+')"

# 7. forward mode still works — exercised in a SANDBOX, never against the repo.
#    (An earlier version of this test ran forward mode with no --dir; before --dir existed the flag
#    was ignored and it rewrote 79 refs across 11 real skill files. A test must never be able to
#    mutate the source tree, so this asserts on a fixture and only dry-runs the repo default.)
mkdir -p "$TMP/fwd/skills/demo"
printf 'Run /prd then /prd-review, but not /code-review or skills/rplan.\n' \
	>"$TMP/fwd/skills/demo/SKILL.md"
node "$SCRIPT" --dir "$TMP/fwd" >/dev/null 2>&1
FWD="$(cat "$TMP/fwd/skills/demo/SKILL.md")"
check "7 forward namespaces /prd" 1 "$(printf '%s' "$FWD" | grep -c 'Run /saki-builder:prd then')"
check "7 forward keeps /code-review bare" 1 "$(printf '%s' "$FWD" | grep -c '/code-review')"
check "7 forward leaves path context" 1 "$(printf '%s' "$FWD" | grep -c 'skills/rplan')"

# 8. --dir MUST be honoured, in both directions. This is the exact bug that caused the incident:
#    when --dir was silently ignored the tool fell back to the repo and rewrote 79 real refs. A
#    scoped run reports the FIXTURE's count, never the repo's — if these ever match the repo total
#    again, --dir has stopped working.
mkdir -p "$TMP/scoped/skills/demo"
printf 'One ref only: /prd\n' >"$TMP/scoped/skills/demo/SKILL.md"
check "8 --dir scopes forward" 1 \
	"$(node "$SCRIPT" --dir "$TMP/scoped" --dry 2>&1 | grep -oE '[0-9]+ refs' | grep -oE '^[0-9]+')"
printf 'One ref only: /saki-builder:prd\n' >"$TMP/scoped/skills/demo/SKILL.md"
check "8 --dir scopes reverse" 1 \
	"$(node "$SCRIPT" --reverse --dir "$TMP/scoped" --dry 2>&1 | grep -oE '[0-9]+ refs' | grep -oE '^[0-9]+')"

echo "namespace-refs: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
