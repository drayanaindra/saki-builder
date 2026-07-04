#!/usr/bin/env bash
# test-design-engine-setup.sh — round-trip + detection tests for
# design-engine-setup.sh. Uses temp dirs; no Figma MCP / network needed.

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/design-engine-setup.sh"

pass=0
fail=0
tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

check() {
	local label="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf '  ✗ %s\n      expected: [%s]\n      actual:   [%s]\n' "$label" "$expected" "$actual"
	fi
}

# field FILE-OF-DETECT-OUTPUT KEY → the value after "KEY: "
field() { grep -E "^$2: " <<<"$1" | head -1 | sed -E "s/^$2: //"; }

echo "empty dir → NONE:"
p1="$tmproot/empty"; mkdir -p "$p1"
out=$(bash "$SCRIPT" detect --path "$p1")
check "status NONE" "NONE" "$(field "$out" status)"
check "engine -"    "-"    "$(field "$out" engine)"
check "frontend no" "no"   "$(field "$out" frontend)"

echo "frontend detection:"
p2="$tmproot/fe"; mkdir -p "$p2"
printf '{ "dependencies": { "next": "14.0.0", "react": "18" } }\n' >"$p2/package.json"
out=$(bash "$SCRIPT" detect --path "$p2")
check "frontend yes" "yes" "$(field "$out" frontend)"

echo "record native → detect:"
p3="$tmproot/native"; mkdir -p "$p3"
bash "$SCRIPT" record --engine native --path "$p3" >/dev/null
out=$(bash "$SCRIPT" detect --path "$p3")
check "status RECORDED" "RECORDED" "$(field "$out" status)"
check "engine native"   "native"   "$(field "$out" engine)"
check "figma_source -"  "-"        "$(field "$out" figma_source)"

echo "record figma → detect echoes fields:"
p4="$tmproot/figma"; mkdir -p "$p4"
bash "$SCRIPT" record --engine figma --path "$p4" \
	--seat view --capability read \
	--source "https://www.figma.com/file/ABC123/App" --handle "M Asep Indrayana" >/dev/null
out=$(bash "$SCRIPT" detect --path "$p4")
check "engine figma"       "figma"                                  "$(field "$out" engine)"
check "figma_seat view"    "view"                                   "$(field "$out" figma_seat)"
check "figma_capability"   "read"                                   "$(field "$out" figma_capability)"
check "figma_source url"   "https://www.figma.com/file/ABC123/App"  "$(field "$out" figma_source)"

echo "bad engine → non-zero exit:"
if bash "$SCRIPT" record --engine bogus --path "$tmproot/x" >/dev/null 2>&1; then
	fail=$((fail + 1)); echo "  ✗ bad engine should have failed"
else
	pass=$((pass + 1))
fi

echo "record is valid JSON:"
if command -v jq >/dev/null 2>&1; then
	if jq -e . "$p4/.claude/design-engine.json" >/dev/null 2>&1; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1)); echo "  ✗ record is not valid JSON"
	fi
else
	echo "  ~ jq absent — skipped JSON validation"
fi

echo ""
if [ "$fail" -eq 0 ]; then
	echo "✓ all $pass assertions passed"
	exit 0
fi
echo "✗ $fail failed, $pass passed"
exit 1
