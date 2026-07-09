#!/usr/bin/env bash
# test-detect.sh — fixture test for detect.sh (the arch-check metric emitter).
# Builds a synthetic Stage-2 repo in a temp dir where module `orders` crosses the
# Stage 2->3 thresholds and `catalog` does not, runs detect.sh, and asserts the
# per-module classification. Exit 0 on pass, 1 on any mismatch.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$HERE/detect.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$DETECT" ] || fail "detect.sh not found at $DETECT"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

# --- build a Stage-2 fixture: backend/ + frontend/ split, two backend modules ---
mkdir -p "$FIX/backend/src/modules/orders" "$FIX/backend/src/modules/catalog" "$FIX/frontend/src"

# orders: OVER threshold — service.py 600 lines + 6 distinct sibling-module imports
{
  echo "from modules.payments import Payment"
  echo "from modules.catalog import Product"
  echo "from modules.auth import User"
  echo "from modules.users import Profile"
  echo "from modules.inventory import Stock"
  echo "from modules.shipping import Label"
  for i in $(seq 1 594); do echo "# business logic line $i"; done
} > "$FIX/backend/src/modules/orders/service.py"

# catalog: UNDER threshold — service.py 200 lines + 2 sibling imports
{
  echo "from modules.auth import User"
  echo "from modules.inventory import Stock"
  for i in $(seq 1 198); do echo "# line $i"; done
} > "$FIX/backend/src/modules/catalog/service.py"

# --- run the detector ---
OUT="$(bash "$DETECT" "$FIX" 2>&1)" || fail "detect.sh exited non-zero:\n$OUT"

# --- assertions ---
echo "$OUT" | grep -qiE '^Detected layout:' || fail "no 'Detected layout:' line in output:\n$OUT"

orders_line="$(echo "$OUT" | grep -E '^MODULE orders ')"
catalog_line="$(echo "$OUT" | grep -E '^MODULE catalog ')"

[ -n "$orders_line" ]  || fail "no MODULE orders line:\n$OUT"
[ -n "$catalog_line" ] || fail "no MODULE catalog line:\n$OUT"

echo "$orders_line"  | grep -q 'stage3_fired=yes' || fail "orders should be stage3_fired=yes, got: $orders_line"
echo "$catalog_line" | grep -q 'stage3_fired=no'  || fail "catalog should be stage3_fired=no, got: $catalog_line"

echo "PASS: orders FIRED, catalog clear"
exit 0
