#!/bin/bash
# sync.sh — Commit and push updated learnings after /reflect or /retro
# Usage: ./sync.sh
# Run this from any machine after /reflect updates patterns.md

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "Syncing Claude learning data..."
echo ""

# Check for changes in memory/
git add memory/

if git diff --cached --quiet; then
  echo "No new learning data to sync."
  exit 0
fi

echo "Changes detected in memory/:"
git diff --cached --name-only | sed 's/^/  /'
echo ""

# Commit with date
DATE=$(date +%Y-%m-%d)
git commit -m "sync: update learnings $DATE"

echo ""
echo "✓ Committed. Pushing to remote..."
git push -u origin main

echo ""
echo "✓ Synced! Other machines can run 'git pull' to get latest learnings."
