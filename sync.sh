#!/bin/bash
# sync.sh — Commit and push updated learnings + config after /reflect or /retro
# Usage: ./sync.sh
# Tracks: memory/ (lessons-learned, patterns) AND config/ (CLAUDE.md, settings.json, skills, hooks, agents)
# Run this from any machine after /reflect, after editing a skill/hook, or before switching machines.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "Syncing Claude learning + config data..."
echo ""

# Stage tracked dirs
git add memory/ config/

if git diff --cached --quiet; then
  echo "No new learning or config data to sync."
  exit 0
fi

echo "Changes detected:"
git diff --cached --name-only | sed 's/^/  /'
echo ""

# Commit with date
DATE=$(date +%Y-%m-%d)
git commit -m "sync: update learnings + config $DATE"

echo ""
echo "✓ Committed. Pushing to remote..."
git push

echo ""
echo "✓ Synced! Other machines can run 'git pull' to get latest."
