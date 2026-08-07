#!/usr/bin/env bash
# build-npm-bundle.sh — build the self-contained opencode bundle shipped inside the npm package.
#
# Produces dist/opencode-bundle/ from the canonical Claude Code sources, reusing the SAME generators
# the repo-clone bridge uses (build-opencode.sh --from-plugin + namespace-refs.js --reverse), so the
# npm package and a clone never drift:
#
#   AGENTS.md   — flattened instructions/core.md, portable (plugin defaults, no personal settings)
#   agent/      — opencode agents (mode: subagent injected)
#   commands/   — opencode slash commands generated from config/skills
#   skills/     — copies of config/skills, de-namespaced for opencode (bare /rplan, not /saki-builder:rplan)
#
# DELIBERATELY NOT produced: opencode.json. Plugin registration is the installer's job (step 5 /
# `opencode plugin @saketek/saki-builder`), not a generated config that would clobber a user's file.
#
# config/docs and config/hooks are NOT copied into the bundle: they ship at the package root and are
# referenced from the installed AGENTS.md via absolute path (repointed by bin/saki-install.mjs).
#
# Usage:
#   bash bin/build-npm-bundle.sh     # generate ./dist/opencode-bundle
#   npm pack                         # runs this via the prepack script
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${OPENCODE_OUT:-$REPO/dist/opencode-bundle}"

rm -rf "$OUT"
echo "▸ bundle out : $OUT"

# 1. Flatten rules + generate agents + commands from the plugin defaults (not the owner's ~/.claude).
OPENCODE_OUT="$OUT" bash "$REPO/build-opencode.sh" --from-plugin >/dev/null

# 2. Drop the generated opencode.json — registration is the installer's job, never a config clobber.
rm -f "$OUT/opencode.json"

# 3. Skills: copies (not symlinks — the de-namespace pass rewrites them in place), then strip the
#    saki-builder: namespace. The repo-clone bridge stops at skills+commands+AGENTS.md (leaving
#    agent/* namespaced); the npm bundle de-namespaces agents too — a strict improvement with the
#    same guard (only known skill names, only .md).
cp -R "$REPO/config/skills" "$OUT/skills"
for stage in "$OUT/skills" "$OUT/commands" "$OUT/AGENTS.md" "$OUT/agent"; do
  node "$REPO/bin/namespace-refs.js" --reverse --dir "$stage" >/dev/null
done

echo "✓ opencode-bundle built:"
echo "  $(find "$OUT" -type f | wc -l | tr -d ' ') files"
for d in AGENTS.md agent commands skills; do
  printf '  %-9s %s\n' "$d" "$(find "$OUT/$d" -type f 2>/dev/null | wc -l | tr -d ' ') files"
done
