#!/usr/bin/env bash
# test-detect.sh — fixture test for detect.sh (the arch-check metric emitter).
# Builds a synthetic Stage-2 repo whose modules independently exercise each
# Stage 2->3 trigger, runs detect.sh, and asserts the per-module classification.
# The LOC-only and imports-only modules pin each OR-branch of stage3_fired so a
# regression that drops one branch is caught. Exit 0 on pass, 1 on any mismatch.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$HERE/detect.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$DETECT" ] || fail "detect.sh not found at $DETECT"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

# make_module <dir> <total_loc> <sibling_imports>
# Writes <dir>/service.py with exactly <total_loc> lines, the first N being distinct
# `from modules.<sibling>` imports (sibling != this module's own name), the rest filler.
make_module() {
  local dir="$1" loc="$2" want="$3" self added=0 i body
  self="$(basename "$dir")"
  local pool=(payments catalog auth users inventory shipping billing search reviews notify)
  mkdir -p "$dir"
  {
    for ((i=0; i<${#pool[@]} && added<want; i++)); do
      [ "${pool[$i]}" = "$self" ] && continue
      echo "from modules.${pool[$i]} import X"
      added=$((added + 1))
    done
    body=$((loc - added))
    for ((i=1; i<=body; i++)); do echo "# line $i"; done
  } > "$dir/service.py"
}

BE="$FIX/backend/src/modules"
mkdir -p "$FIX/frontend/src"
make_module "$BE/orders"     600 6   # over on BOTH (600>500, 6>=5)
make_module "$BE/catalog"    200 2   # clear on BOTH (200<=500, 2<5)
make_module "$BE/bigsvc"     600 2   # fires on LOC branch ONLY
make_module "$BE/hicoupling" 200 6   # fires on IMPORTS branch ONLY

OUT="$(bash "$DETECT" "$FIX" 2>&1)" || fail "detect.sh exited non-zero:\n$OUT"

echo "$OUT" | grep -qiE '^Detected layout:' || fail "no 'Detected layout:' line:\n$OUT"

# module_line <name> -> the emitted MODULE line
module_line() { echo "$OUT" | grep -E "^MODULE $1 "; }

assert_fired() {
  local name="$1" want="$2" line
  line="$(module_line "$name")"
  [ -n "$line" ] || fail "no MODULE $name line:\n$OUT"
  echo "$line" | grep -q "stage3_fired=$want" || fail "$name: expected stage3_fired=$want, got: $line"
}

assert_metric() {
  local name="$1" kv="$2" line
  line="$(module_line "$name")"
  echo "$line" | grep -q "$kv" || fail "$name: expected '$kv', got: $line"
}

# per-module firing verdicts
assert_fired orders     yes
assert_fired catalog    no
assert_fired bigsvc     yes   # kills a regression that drops the LOC branch
assert_fired hicoupling yes   # kills a regression that drops the imports branch

# pin the counting math (not just the verdict)
assert_metric orders     "service_loc=600"
assert_metric orders     "sibling_imports=6"
assert_metric catalog    "sibling_imports=2"
assert_metric hicoupling "service_loc=200"
assert_metric hicoupling "sibling_imports=6"

echo "PASS: both triggers pinned independently (orders/bigsvc/hicoupling fire, catalog clear)"
exit 0
