#!/usr/bin/env bash
# test-coverage-gate.sh — unit tests for coverage-gate.sh's pure helpers
# (report parsers + threshold compare + push-to-main trigger). No git/network needed.

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./coverage-gate.sh
source "$DIR/coverage-gate.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

check() {
	local label="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf '  ✗ %s\n      expected: [%s]\n      actual:   [%s]\n' "$label" "$expected" "$actual"
	fi
}

# ok LABEL CMD... → assert CMD succeeds (exit 0)
ok() {
	local label="$1"; shift
	if "$@"; then pass=$((pass + 1)); else
		fail=$((fail + 1)); printf '  ✗ %s (expected success)\n' "$label"
	fi
}

# no LABEL CMD... → assert CMD fails (exit != 0)
no() {
	local label="$1"; shift
	if "$@"; then
		fail=$((fail + 1)); printf '  ✗ %s (expected failure)\n' "$label"
	else pass=$((pass + 1)); fi
}

echo "is_push_to_main:"
ok "push origin main"        is_push_to_main 'git push origin main'
ok "push origin master"      is_push_to_main 'git push origin master'
ok "push -u origin main"     is_push_to_main 'git push -u origin main'
no "push feature branch"     is_push_to_main 'git push origin feat/x'
no "not a push"              is_push_to_main 'git status main'
no "empty"                   is_push_to_main ''

echo "compare_gt (strict):"
ok "85 > 80"                 compare_gt 85 80
no "80 not > 80 (floor)"     compare_gt 80 80
ok "80.01 > 80"              compare_gt 80.01 80
no "79.99 > 80"              compare_gt 79.99 80
no "0 > 80"                  compare_gt 0 80

echo "parse_json_summary:"
printf '{"total":{"lines":{"total":200,"covered":170,"skipped":0,"pct":85}}}' > "$TMP/coverage-summary.json"
check "jest json-summary pct" "85" "$(parse_json_summary "$TMP/coverage-summary.json")"
check "missing file → empty"  ""   "$(parse_json_summary "$TMP/nope.json")"

echo "parse_cobertura:"
printf '%s\n' '<?xml version="1.0"?>' \
	'<coverage line-rate="0.857" branch-rate="0.5" version="1.9">' \
	'  <packages><package line-rate="0.9"></package></packages>' \
	'</coverage>' > "$TMP/coverage.xml"
check "cobertura line-rate ×100" "85.70" "$(parse_cobertura "$TMP/coverage.xml")"

echo "parse_lcov:"
printf '%s\n' 'SF:a.js' 'LF:100' 'LH:90' 'end_of_record' \
	'SF:b.js' 'LF:100' 'LH:70' 'end_of_record' > "$TMP/lcov.info"
# (90 + 70) / (100 + 100) * 100 = 80.00
check "lcov sum LH/LF ×100" "80.00" "$(parse_lcov "$TMP/lcov.info")"

echo "parse_go_out:"
if command -v go >/dev/null 2>&1; then
	# `go tool cover -func` resolves packages against module context, so build a
	# real minimal module and generate a genuine coverprofile (stdlib only, offline).
	MOD="$TMP/gomod"
	mkdir -p "$MOD"
	printf 'module example.com/covtest\n\ngo 1.20\n' > "$MOD/go.mod"
	printf 'package covtest\n\nfunc Add(a, b int) int { return a + b }\n' > "$MOD/f.go"
	printf 'package covtest\n\nimport "testing"\n\nfunc TestAdd(t *testing.T) {\n\tif Add(1, 2) != 3 {\n\t\tt.Fatal("bad")\n\t}\n}\n' > "$MOD/f_test.go"
	( cd "$MOD" && go test -coverprofile=coverage.out . >/dev/null 2>&1 )
	if [ -f "$MOD/coverage.out" ]; then
		check "go coverprofile total" "100.0" "$(cd "$MOD" && parse_go_out coverage.out)"
	else
		echo "  (skipped — go test could not produce a coverprofile here)"
	fi
else
	echo "  (skipped — go not installed)"
fi

echo ""
if [ "$fail" -eq 0 ]; then
	echo "✓ all $pass assertions passed"
	exit 0
fi
echo "✗ $fail failed, $pass passed"
exit 1
