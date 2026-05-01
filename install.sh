#!/bin/bash
# install.sh — Install claude-config into ~/.claude/
# Usage: ./install.sh
# Run this on any machine after cloning the repo.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing Claude Code config from: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Backup existing real files (not symlinks)
BACKUP="$CLAUDE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
backed_up=false

for item in CLAUDE.md settings.json docs skills hooks memory; do
	target="$CLAUDE_DIR/$item"
	if [ -e "$target" ] && [ ! -L "$target" ]; then
		if [ "$backed_up" = false ]; then
			mkdir -p "$BACKUP"
			backed_up=true
		fi
		mv "$target" "$BACKUP/$item"
		echo "  Backed up: ~/.claude/$item → $BACKUP/$item"
	fi
done

if [ "$backed_up" = true ]; then
	echo ""
	echo "Existing files backed up to: $BACKUP"
	echo ""
fi

# Create symlinks for shared config
link() {
	local src="$1"
	local dst="$2"
	[ -L "$dst" ] && rm "$dst"
	ln -s "$src" "$dst"
	echo "  ✓ ~/.claude/$(basename "$dst") → $src"
}

echo "Creating symlinks:"
link "$REPO_DIR/config/settings.json" "$CLAUDE_DIR/settings.json"
link "$REPO_DIR/config/docs" "$CLAUDE_DIR/docs"
link "$REPO_DIR/config/skills" "$CLAUDE_DIR/skills"
link "$REPO_DIR/config/hooks" "$CLAUDE_DIR/hooks"
link "$REPO_DIR/memory" "$CLAUDE_DIR/memory"

# CLAUDE.md is a LOCAL wrapper file (not a symlink) so each user can
# add personal @imports (RTK, project-specific tools) without touching
# the shared config. Skipped if already exists.
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ ! -f "$CLAUDE_MD" ] || [ -L "$CLAUDE_MD" ]; then
	# Remove old symlink if present
	[ -L "$CLAUDE_MD" ] && rm "$CLAUDE_MD"
	cat >"$CLAUDE_MD" <<EOF
# My Claude Code Config
# This file is LOCAL — not synced to the shared repo.
# Add personal @imports below (RTK, etc.)

@$REPO_DIR/config/CLAUDE.md

# Personal extensions (uncomment and customize):
# @$REPO_DIR/personal/RTK.md
EOF
	echo "  ✓ ~/.claude/CLAUDE.md (local wrapper — add personal @imports here)"
else
	echo "  ~ ~/.claude/CLAUDE.md already exists, skipping (add @$REPO_DIR/config/CLAUDE.md if needed)"
fi

# Register @playwright/mcp at user scope (skipped if already configured
# or if `claude` CLI is not on PATH). Safe to re-run — idempotent.
echo ""
echo "Configuring MCP servers:"
if ! command -v claude >/dev/null 2>&1; then
	echo "  ~ 'claude' CLI not on PATH — skipping MCP install"
	echo "    Re-run this script after installing Claude Code CLI."
elif claude mcp get playwright 2>&1 | grep -q "^No MCP server found"; then
	if claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest >/dev/null 2>&1; then
		echo "  ✓ @playwright/mcp registered (user scope)"
	else
		echo "  ⚠ Failed to register @playwright/mcp — run manually:"
		echo "    claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest"
	fi
else
	echo "  ~ playwright MCP already configured, skipping"
fi

echo ""
echo "✓ Done! Claude Code config installed."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (claude) to pick up new config"
echo "     (MCP: /qa will now use @playwright/mcp automatically)"
echo "  2. Edit ~/.claude/CLAUDE.md to uncomment personal @imports (RTK, etc.)"
echo "  3. After /reflect runs, use sync.sh to commit updated learnings"
echo "  4. On other machines: git pull && ./install.sh"
