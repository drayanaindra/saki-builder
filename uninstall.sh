#!/bin/bash
# uninstall.sh — Remove symlinks and restore from backup (if available)
# Usage: ./uninstall.sh

set -e

CLAUDE_DIR="$HOME/.claude"

echo "Uninstalling Claude Code config symlinks..."
echo ""

# Remove symlinks
for item in CLAUDE.md RTK.md settings.json docs skills hooks memory; do
  target="$CLAUDE_DIR/$item"
  if [ -L "$target" ]; then
    rm "$target"
    echo "  Removed symlink: ~/.claude/$item"
  fi
done

echo ""

# Restore from most recent backup if available
LATEST_BACKUP=$(ls -td "$CLAUDE_DIR"/backup-* 2>/dev/null | head -1)

if [ -n "$LATEST_BACKUP" ]; then
  echo "Restoring from backup: $LATEST_BACKUP"
  for item in "$LATEST_BACKUP"/*; do
    name=$(basename "$item")
    mv "$item" "$CLAUDE_DIR/$name"
    echo "  Restored: ~/.claude/$name"
  done
  rmdir "$LATEST_BACKUP" 2>/dev/null || true
  echo ""
  echo "✓ Restored from backup."
else
  echo "No backup found. ~/.claude/ is now empty of config files."
fi

echo ""
echo "✓ Uninstall complete."
