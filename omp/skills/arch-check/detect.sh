#!/usr/bin/env bash
# detect.sh — read-only architecture-tier metric emitter for /saki-builder:arch-check.
#
# Measures the MECHANICAL transition triggers from skill://saki-builder-runtime/docs/modular-architecture.md
# against a repo and emits structured KEY=VALUE lines for the skill to classify.
# It NEVER edits code, moves files, or runs a migration — measurement only (writes to
# stdout exclusively). Judgment/external triggers (business-rule count, aggregate
# boundaries, dev count, team ownership, merge frequency) are NOT measured here — the
# skill surfaces them as candidates.
#
# Usage: bash detect.sh [repo-root]   (default: current directory)
set -u

ROOT="${1:-.}"

# --- Thresholds (from modular-architecture.md §Transition Triggers) ------------------
readonly SERVICE_LOC_MAX=500      # Stage 2->3: module service.* over this fires
readonly SIBLING_IMPORTS_MIN=5    # Stage 2->3: imports this many+ sibling modules fires
readonly MODEL_COUNT_MAX=15       # Stage 1->2
readonly COMPONENT_COUNT_MAX=20   # Stage 1->2
readonly PY_LOC_MAX=300           # Stage 1->2: any backend .py over this
readonly TSX_LOC_MAX=500          # Stage 1->2: any frontend .tsx over this

# find with node_modules/.git pruned; args after are appended to the expression
prune_find() {
  find "$ROOT" -type d \( -name node_modules -o -name .git \) -prune -o "$@"
}

# largest LOC among files matching a glob under a dir (echoes 0 if none)
max_loc() {
  local dir="$1" pattern="$2" max=0 f lines
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    [ -n "$lines" ] && [ "$lines" -gt "$max" ] && max=$lines
  done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null)
  echo "$max"
}

# distinct sibling modules a module imports (Python `from modules.X`, TS `@/features/X`)
count_sibling_imports() {
  local module_dir="$1" self_name="$2"
  grep -rhoE "(from modules\.[A-Za-z_][A-Za-z0-9_]*|@/features/[A-Za-z_][A-Za-z0-9_-]*)" \
      "$module_dir" 2>/dev/null \
    | sed -E 's#.*(modules\.|@/features/)##' \
    | grep -Fvx "$self_name" \
    | sort -u | grep -c .
}

# emit one MODULE line: service LOC + sibling imports + stage3 verdict
emit_module() {
  local module_dir="$1" name loc imports fired="no"
  name="$(basename "$module_dir")"
  loc="$(max_loc "$module_dir" 'service.*')"
  imports="$(count_sibling_imports "$module_dir" "$name")"
  { [ "$loc" -gt "$SERVICE_LOC_MAX" ] || [ "$imports" -ge "$SIBLING_IMPORTS_MIN" ]; } && fired="yes"
  echo "MODULE $name service_loc=$loc sibling_imports=$imports stage3_fired=$fired"
}

# collect module directories = immediate subdirs of any modules/ or features/ dir
list_module_dirs() {
  local parent
  while IFS= read -r parent; do
    [ -d "$parent" ] || continue
    find "$parent" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  done < <(prune_find -type d \( -name modules -o -name features \) -print | sort -u)
}

# --- App-level Stage 1->2 metrics (context; honest n/a when a stack doesn't match) ----
emit_app_stage1() {
  local models components largest_py largest_tsx fired="no"
  models=$(prune_find -type f -name '*.py' -path '*models*' -print 2>/dev/null | grep -c .)
  components=$(prune_find -type f -name '*.tsx' -path '*components*' -print 2>/dev/null | grep -c .)
  largest_py=$(prune_find -type f -name '*.py' -print 2>/dev/null | xargs wc -l 2>/dev/null \
                 | awk '$2!="total"{if($1>m)m=$1}END{print m+0}')
  largest_tsx=$(prune_find -type f -name '*.tsx' -print 2>/dev/null | xargs wc -l 2>/dev/null \
                 | awk '$2!="total"{if($1>m)m=$1}END{print m+0}')
  [ "$models" = "0" ] && models="n/a"
  [ "$components" = "0" ] && components="n/a"
  { [ "$models" != "n/a" ] && [ "$models" -gt "$MODEL_COUNT_MAX" ]; } && fired="yes"
  { [ "$components" != "n/a" ] && [ "$components" -gt "$COMPONENT_COUNT_MAX" ]; } && fired="yes"
  { [ "$largest_py" -gt "$PY_LOC_MAX" ] || [ "$largest_tsx" -gt "$TSX_LOC_MAX" ]; } && fired="yes"
  echo "APP model_count=$models component_count=$components largest_py=$largest_py largest_tsx=$largest_tsx stage2_fired=$fired"
}

# --- main -----------------------------------------------------------------------------
main() {
  [ -d "$ROOT" ] || { echo "Detected layout: error — '$ROOT' is not a directory"; exit 0; }

  local split="no"
  [ -d "$ROOT/backend" ] && [ -d "$ROOT/frontend" ] && split="yes"

  # portable array fill (bash 3.2 has no mapfile)
  local modules=() line
  while IFS= read -r line; do
    [ -n "$line" ] && modules+=("$line")
  done < <(list_module_dirs)

  if [ "${#modules[@]}" -gt 0 ]; then
    echo "Detected layout: Stage 2 (Modular Monolith) · backend+frontend split=$split · modules=${#modules[@]}"
    local m
    for m in "${modules[@]}"; do emit_module "$m"; done
    echo "APP stage1->2: N/A (already Stage 2)"
  else
    echo "Detected layout: flat / N/A (Stage 1) · backend+frontend split=$split · no modules/ or features/ dir"
    emit_app_stage1
  fi
}

main
