#!/usr/bin/env bash
# opencode-bridge.sh — make saki-builder work under opencode, from the INSTALLED plugin.
#
# opencode does not understand Claude Code plugin manifests, marketplaces, or hooks.json. It DOES
# read Agent Skills from a fixed set of directories and load TS/JS plugins from its own plugin dir.
# This bridges the two, so a teammate does not have to clone this repo to use saki-builder there:
#
#   config/skills/<n>/SKILL.md  →  ~/.config/opencode/skills/<n>/     (symlinked, then de-namespaced)
#   instructions/core.md        →  ~/.config/opencode/AGENTS.md       (generated, machine-portable)
#   config/agents/*.md          →  ~/.config/opencode/agent/*.md      (mode: subagent injected)
#   opencode/plugins/*.ts       →  ~/.config/opencode/plugins/        (safety gates + lifecycle state)
#
# Usage:
#   bash bin/opencode-bridge.sh              # install
#   SAKI_AGENT_MODE=1 bash bin/opencode-bridge.sh   # also bake in the autonomous overlay
#   bash bin/opencode-bridge.sh --dry        # show what would happen
#
# Idempotent: re-running relinks and regenerates in place.

set -euo pipefail

# Resolve the plugin root: the installed plugin dir when the loader exported it, else this checkout.
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEST="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
DRY=0
for a in "$@"; do [[ "$a" == "--dry" ]] && DRY=1; done

say() { printf '%s\n' "$*"; }
ok() { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ⚠ %s\n' "$*" >&2; }
run() { if [[ "$DRY" == "1" ]]; then printf '  [dry] %s\n' "$*"; else "$@"; fi; }

say "▸ plugin root : $ROOT"
say "▸ opencode    : $DEST"
[[ -d "$ROOT/config/skills" ]] || {
	warn "no config/skills under $ROOT — is CLAUDE_PLUGIN_ROOT correct?"
	exit 1
}

run mkdir -p "$DEST/skills" "$DEST/plugins" "$DEST/agent"

# ── 1. Skills → opencode's native skills dir ───────────────────────────────────
# opencode also scans ~/.claude/skills, but that is the user's OWN skills dir and may already hold
# unrelated entries — writing into opencode's own dir keeps the two from colliding.
n=0
for d in "$ROOT/config/skills"/*/; do
	[[ -f "$d/SKILL.md" ]] || continue
	name="$(basename "$d")"
	run ln -sfn "${d%/}" "$DEST/skills/$name"
	n=$((n + 1))
done
ok "skills linked ($n)"

# ── 2. Rules + config + agents (portable — never the owner's personal ~/.claude) ─
if [[ -x "$ROOT/build-opencode.sh" ]] || [[ -f "$ROOT/build-opencode.sh" ]]; then
	if [[ "$DRY" == "1" ]]; then
		say "  [dry] SAKI_PLUGIN_ROOT=$ROOT OPENCODE_OUT=$DEST bash $ROOT/build-opencode.sh --from-plugin"
	else
		SAKI_PLUGIN_ROOT="$ROOT" OPENCODE_OUT="$DEST" \
			bash "$ROOT/build-opencode.sh" --from-plugin >/dev/null
		ok "AGENTS.md + opencode.json + agent/ generated"
		[[ "${SAKI_AGENT_MODE:-}" == "1" ]] && ok "agent-mode overlay baked in"
	fi
else
	warn "build-opencode.sh not found — skipping rules/config generation"
fi

# ── 3. Strip the plugin namespace from the BRIDGED skills ─────────────────────
# Our skill bodies say `/saki-builder:rplan` (correct for Claude Code). opencode registers the same
# skills under their bare name, so the namespaced form points at a command that does not exist there.
# The symlinks above point at the plugin's real files, so rewrite through them onto real copies.
if [[ "$DRY" != "1" ]]; then
	STAGE="$DEST/skills"
	# Replace symlinks with real copies only if a rewrite is actually needed, so an already-bare
	# install stays a cheap set of symlinks.
	if node "$ROOT/bin/namespace-refs.js" --reverse --dir "$STAGE" --dry 2>/dev/null | grep -qvE ' 0 refs '; then
		for l in "$STAGE"/*; do
			[[ -L "$l" ]] || continue
			tgt="$(readlink "$l")"
			rm "$l"
			cp -R "$tgt" "$l"
		done
		node "$ROOT/bin/namespace-refs.js" --reverse --dir "$STAGE" >/dev/null
		ok "skill refs de-namespaced (/saki-builder:x → /x)"
	else
		ok "skill refs already bare"
	fi
fi

# ── 4. Plugins (safety gates + lifecycle state) ───────────────────────────────
p=0
for f in "$ROOT/opencode/plugins"/*.ts; do
	[[ -e "$f" ]] || continue
	run ln -sfn "$f" "$DEST/plugins/$(basename "$f")"
	p=$((p + 1))
done
ok "plugins linked ($p)"

# ── 5. Pin the plugin root for the TS plugin ──────────────────────────────────
# safety-hooks.ts resolves the bash gate scripts relative to itself, which only works from a repo
# clone. Persist the real root so it works from the installed plugin too.
if [[ "$DRY" != "1" ]]; then
	printf 'SAKI_PLUGIN_ROOT=%s\n' "$ROOT" >"$DEST/.saki-env"
	ok "SAKI_PLUGIN_ROOT pinned in $DEST/.saki-env"
fi

cat <<EOF

Done. In opencode:
  • skills are invoked bare — /rplan, /prd, /build (no saki-builder: prefix)
  • rules load from $DEST/AGENTS.md
  • safety gates + lifecycle state run from $DEST/plugins/

Export SAKI_PLUGIN_ROOT so the TS plugin finds the gate scripts:
  export \$(cat $DEST/.saki-env)

Runner contract (same tasks/.saki/latest.json as headless Claude): docs/AGENT-RUNNERS.md
EOF
