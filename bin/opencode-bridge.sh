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

# ── 0. Back up anything we are about to overwrite ──────────────────────────────
# build-opencode.sh writes AGENTS.md / opencode.json / agent/ / commands/ with truncating
# redirects. If the user already has an opencode setup, those are THEIR files — a model pin, MCP
# servers, a theme, hand-written rules. Overwriting them silently is data loss, so take a timestamped
# backup first and tell them where it went. Nothing here is destructive without a copy on disk.
BACKUP=""
for f in AGENTS.md opencode.json; do
	if [[ -e "$DEST/$f" && ! -L "$DEST/$f" ]]; then
		if [[ -z "$BACKUP" ]]; then
			BACKUP="$DEST/.saki-backup-$(date +%Y%m%d-%H%M%S)"
			run mkdir -p "$BACKUP"
		fi
		run cp -R "$DEST/$f" "$BACKUP/$f"
	fi
done
for d in agent commands; do
	if [[ -d "$DEST/$d" ]] && [[ -n "$(ls -A "$DEST/$d" 2>/dev/null)" ]]; then
		if [[ -z "$BACKUP" ]]; then
			BACKUP="$DEST/.saki-backup-$(date +%Y%m%d-%H%M%S)"
			run mkdir -p "$BACKUP"
		fi
		run cp -R "$DEST/$d" "$BACKUP/$d"
	fi
done
[[ -n "$BACKUP" ]] && ok "existing config backed up → $BACKUP"

# ── 1. Skills → opencode's native skills dir ───────────────────────────────────
# opencode also scans ~/.claude/skills, but that is the user's OWN skills dir and may already hold
# unrelated entries — writing into opencode's own dir keeps the two from colliding.
# Bridged skills are written as real COPIES, not symlinks, because step 3 rewrites them in place —
# rewriting through a symlink would edit the plugin's own source. Only names that exist in the plugin
# are touched; a user's own skills in this dir are left completely alone.
n=0
SAKI_NAMES=()
for d in "$ROOT/config/skills"/*/; do
	[[ -f "$d/SKILL.md" ]] || continue
	name="$(basename "$d")"
	SAKI_NAMES+=("$name")
	if [[ "$DRY" == "1" ]]; then
		printf '  [dry] install skill %s\n' "$name"
	else
		rm -rf "$DEST/skills/$name"
		cp -R "${d%/}" "$DEST/skills/$name" || {
			warn "could not install skill $name — skipping"
			continue
		}
	fi
	n=$((n + 1))
done
ok "skills installed ($n)"

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
# The rewrite runs unconditionally over the copies made above. The previous guard was
# `... --dry | grep -qvE ' 0 refs '`, which is the house "never gate on piped grep -q" anti-pattern —
# it was always true (the dry-run prints a blank line), and the check it guarded was always false
# anyway because the stage held symlinks and `Dirent.isDirectory()` is false for those. Two bugs that
# cancelled. Copies + an unconditional rewrite is simply correct, and `commands/` needs it too:
# build-opencode.sh emits ~56 command files that carry the same namespaced refs.
if [[ "$DRY" != "1" ]]; then
	for stage in "$DEST/skills" "$DEST/commands"; do
		[[ -d "$stage" ]] || continue
		node "$ROOT/bin/namespace-refs.js" --reverse --dir "$stage" >/dev/null 2>&1 ||
			warn "de-namespace pass failed for $stage — refs may still read /saki-builder:x"
	done
	ok "skill + command refs de-namespaced (/saki-builder:x → /x)"
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
