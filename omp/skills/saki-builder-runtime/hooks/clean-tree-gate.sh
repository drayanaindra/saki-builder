#!/usr/bin/env bash
# clean-tree-gate.sh — Auto-solving clean-tree gate. Runs as PreToolUse:Bash hook.
#
# Goal: keep the working tree from entangling across branch switches, and flag
# uncommitted state before a production build. AUTO-SOLVES — never blocks, never
# asks a human (exit 0 always). Safe for solo AND team use.
#
# Triggers & behaviour:
#   git switch <branch>            -> auto-stash current dirt (leave old branch clean),
#                                     then let the switch proceed against a clean tree
#   git switch -c / checkout -b    -> advisory only (carrying WIP into a FRESH branch is fine)
#   *build commands (npm/yarn/pnpm/go/vite/next/turbo build)
#                                  -> advisory only if dirty. NOT stashed: stashing would
#                                     build stale code (your changes would vanish from the tree)
#
# Why stash (not commit)? Non-destructive, local-only (never pushed), fully recoverable,
# and it sidesteps the `git add -A` shared-repo trap (a stash is restorable; a bad commit
# entangles history). Each stash is tagged `auto:<branch>:<epoch>` so it is easy to find.
#
#   Disable entirely:      export CLEAN_TREE_GATE=0
#   Downgrade to advisory: export CLEAN_TREE_GATE_STASH=0   (warn instead of stash)

COMMAND="${CLAUDE_TOOL_INPUT_COMMAND:-}"
[ -z "$COMMAND" ] && exit 0
[ "${CLEAN_TREE_GATE:-1}" = "0" ] && exit 0

# ─── Fast path: bail before touching git unless this is a command we care about ──
BUILD_RE='(npm[[:space:]]+run[[:space:]]+build|yarn[[:space:]]+build|pnpm[[:space:]]+(run[[:space:]]+)?build|go[[:space:]]+build|next[[:space:]]+build|vite[[:space:]]+build|turbo[[:space:]]+run[[:space:]]+build)'
echo "$COMMAND" | grep -qE "\bgit[[:space:]]+switch\b|\bgit[[:space:]]+checkout[[:space:]]+-b\b|\b${BUILD_RE}\b" || exit 0

# Must be inside a git work tree
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

dirty()  { [ -n "$(git status --porcelain 2>/dev/null)" ]; }
branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null; }

# ─── Branch CREATE (git switch -c / git checkout -b) → advisory only ───────────
if echo "$COMMAND" | grep -qE '\bgit[[:space:]]+(switch[[:space:]]+(-c|-C|--create)|checkout[[:space:]]+-b)\b'; then
  if dirty; then
    echo "clean-tree-gate: new branch created with uncommitted changes — git carries them onto the new branch (expected). No stash taken."
  fi
  exit 0
fi

# ─── Branch SWITCH to another branch (git switch <branch>) → auto-stash ────────
if echo "$COMMAND" | grep -qE '\bgit[[:space:]]+switch\b'; then
  dirty || exit 0
  cur="$(branch)"
  if [ "${CLEAN_TREE_GATE_STASH:-1}" = "0" ]; then
    echo "clean-tree-gate: WARNING — uncommitted changes on '${cur}'. Switching may carry them onto the target branch. (auto-stash disabled)"
    exit 0
  fi
  msg="auto:${cur}:$(date +%s)"
  if git stash push -u -m "$msg" >/dev/null 2>&1; then
    echo "clean-tree-gate: auto-stashed uncommitted work on '${cur}' → \"${msg}\" (nothing lost; switch now runs clean)."
    echo "  Restore later:  git switch ${cur} && git stash pop"
    echo "  Find it:        git stash list | grep '${msg}'"
  else
    echo "clean-tree-gate: WARNING — auto-stash on '${cur}' failed; leaving tree unchanged."
  fi
  exit 0
fi

# ─── Production BUILD → advisory only if dirty (never stash: would build stale code) ──
if echo "$COMMAND" | grep -qE "\b${BUILD_RE}\b"; then
  if dirty; then
    n="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    echo "clean-tree-gate: note — ${n} uncommitted file(s) on '$(branch)'. Build runs against the working tree; commit first to checkpoint a clean build point. (not stashed — that would build stale code)"
  fi
  exit 0
fi

exit 0
