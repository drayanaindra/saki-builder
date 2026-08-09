#!/usr/bin/env bash
# test-init-env-engines.sh — verify /init-env scaffolds for BOTH host engines, and that the
# opencode-facing artifacts it depends on actually exist and are wired.
#
# The failure this guards against: init-env silently reverting to Claude-only. opencode reads
# CLAUDE.md as a compat fallback but never expands @import, so a Claude-only scaffold *looks*
# successful under opencode while loading no rules, no hooks and no agents.
#
# Run: bash test/test-init-env-engines.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$REPO/config/skills/init-env/SKILL.md"
BRIDGED="$REPO/opencode/commands/init-env.md"
TEMPLATE="$REPO/config/docs/templates/opencode-quality-hooks.ts"

fail() { echo "FAIL: $1"; exit 1; }
# grep -c on a FILE (never a pipe) — piped counts are decorated/inflated by the rtk wrapper.
has()  { [ "$(grep -cF -- "$2" "$1" || true)" -gt 0 ]; }

# ── 1. the source skill covers both engines ─────────────────────────────────────
[ -f "$SKILL" ] || fail "source skill missing: $SKILL"

# Engine detection must be positive on BOTH sides — an absence test misfires when opencode is
# launched from a Claude Code shell (it inherits CLAUDECODE).
has "$SKILL" 'OPENCODE'   || fail "no OPENCODE detection signal in the skill"
has "$SKILL" 'CLAUDECODE' || fail "no CLAUDECODE detection signal in the skill"

# The opencode artifact set. Each entry is a file opencode actually reads; dropping any one of
# them is the regression this test exists to catch.
for token in \
  'AGENTS.md' \
  'opencode.json' \
  'instructions' \
  '.opencode/agent/' \
  '.opencode/plugin/' \
  '.opencode/skill/' \
  'mode: subagent' \
  '.opencode/.env-init.json'
do
  has "$SKILL" "$token" || fail "skill does not scaffold '$token' for opencode"
done

# The Claude artifact set must survive the port.
for token in 'CLAUDE.md' '.claude/settings.json' '.claude/agents/' '.claude/.env-init.json'; do
  has "$SKILL" "$token" || fail "skill lost the Claude artifact '$token'"
done

# Roots must be resolved, not hardcoded: no bare ~/.claude hook or doc paths may remain, because
# neither resolves in an opencode-only install.
has "$SKILL" 'SAKI_DOCS'  || fail "skill does not resolve SAKI_DOCS"
has "$SKILL" 'SAKI_HOOKS' || fail "skill does not resolve SAKI_HOOKS"
[ "$(grep -cF -- '~/.claude/hooks/' "$SKILL" || true)" -eq 0 ] \
  || fail "skill still hardcodes ~/.claude/hooks/ (unresolvable under opencode) — use \$SAKI_HOOKS"
[ "$(grep -cF -- '${CLAUDE_PLUGIN_ROOT}/config/docs' "$SKILL" || true)" -eq 0 ] \
  || fail "skill still hardcodes \${CLAUDE_PLUGIN_ROOT}/config/docs — use \$SAKI_DOCS"

# opencode never expands @import, so the opencode branch must say so explicitly.
has "$SKILL" 'does not expand' || fail "skill does not warn that opencode ignores @import"

# ── 2. the referenced plugin template exists and is real TypeScript ─────────────
[ -f "$TEMPLATE" ] || fail "plugin template missing: $TEMPLATE (Step 4b copies it)"
has "$TEMPLATE" 'tool.execute.before' || fail "template has no PreToolUse analogue"
has "$TEMPLATE" 'tool.execute.after'  || fail "template has no PostToolUse analogue"
has "$TEMPLATE" 'throw new Error'     || fail "template cannot block — throw is opencode's only deny"

# The template must be inside the typecheck surface, or it will rot out of compiling.
grep -qF 'config/docs/templates/*.ts' "$REPO/tsconfig.json" \
  || fail "tsconfig include does not cover config/docs/templates/*.ts"

# It must compile. Pre-existing errors elsewhere in the project are tolerated; errors in the
# TEMPLATE are not.
TC_OUT="$(cd "$REPO" && npx tsc --noEmit -p tsconfig.json 2>&1 || true)"
if printf '%s' "$TC_OUT" | grep -q 'opencode-quality-hooks'; then
  echo "$TC_OUT" | grep 'opencode-quality-hooks'
  fail "plugin template does not typecheck"
fi

# ── 3. the bridged opencode copy is regenerated from the source ─────────────────
[ -f "$BRIDGED" ] || fail "bridged command missing: $BRIDGED"
for token in 'AGENTS.md' '.opencode/plugin/' 'SAKI_DOCS'; do
  has "$BRIDGED" "$token" || fail "bridged copy is stale — missing '$token' (run build-opencode.sh)"
done
# opencode registers our skills under BARE names; a namespaced ref there points at nothing.
[ "$(grep -cF -- 'saki-builder:' "$BRIDGED" || true)" -eq 0 ] \
  || fail "bridged copy still carries saki-builder: refs (run bin/namespace-refs.js --reverse)"

# ── 4. directory spellings the skill tells you to use are the ones opencode reads ─
# Only assertable when opencode is installed; skipped (not failed) otherwise.
if command -v opencode >/dev/null 2>&1; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/.opencode/agent"
  printf -- '---\nmode: subagent\ndescription: init-env scaffold probe\n---\nbody\n' \
    > "$T/.opencode/agent/initenv-probe.md"
  # opencode resolves project scope from the GIT ROOT — without a repo, .opencode/ is ignored
  # entirely. That is a real constraint on the scaffold, so the probe reproduces it faithfully.
  git -C "$T" init -q .
  # Write to a file, then grep the FILE. Piping into `grep -q` makes grep exit on first match,
  # SIGPIPEs opencode, and `set -o pipefail` then reports a failure the probe never had.
  (cd "$T" && opencode agent list --pure >"$T/agents.txt" 2>/dev/null) || true
  grep -q 'initenv-probe' "$T/agents.txt" \
    || fail "opencode does not discover .opencode/agent/ — the skill's Step 7 path is wrong"
  echo "  ✓ opencode $(opencode --version) discovers .opencode/agent/"
else
  echo "  ~ opencode not installed — skipped the live discovery probe"
fi

echo "init-env engines OK (claude + opencode)"
