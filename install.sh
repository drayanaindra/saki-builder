#!/bin/bash
# install.sh — Symlink claude-config into ~/.claude/
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

for item in CLAUDE.md RTK.md settings.json docs skills hooks memory; do
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

# Create symlinks
link() {
  local src="$1"
  local dst="$2"
  # Remove existing symlink if present
  [ -L "$dst" ] && rm "$dst"
  ln -s "$src" "$dst"
  echo "  ✓ ~/.claude/$(basename "$dst") → $src"
}

echo "Creating symlinks:"
link "$REPO_DIR/config/CLAUDE.md"     "$CLAUDE_DIR/CLAUDE.md"
link "$REPO_DIR/config/RTK.md"        "$CLAUDE_DIR/RTK.md"
link "$REPO_DIR/config/settings.json" "$CLAUDE_DIR/settings.json"
link "$REPO_DIR/config/docs"          "$CLAUDE_DIR/docs"
link "$REPO_DIR/config/skills"        "$CLAUDE_DIR/skills"
link "$REPO_DIR/config/hooks"         "$CLAUDE_DIR/hooks"
link "$REPO_DIR/memory"               "$CLAUDE_DIR/memory"

echo ""
echo "✓ Done! Claude Code config installed."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (claude) to pick up new config"
echo "  2. After /reflect runs, use sync.sh to commit updated learnings"
echo "  3. On other machines: git pull && ./install.sh"
