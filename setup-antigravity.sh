#!/bin/bash
# setup-antigravity.sh — Install GEMINI.md global configuration & global/local workflows
# Usage: ./setup-antigravity.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GEMINI_DIR="$HOME/.gemini"

# Define all possible global paths
GLOBAL_PATH_1="$GEMINI_DIR/antigravity/global_workflows"
GLOBAL_PATH_2="$GEMINI_DIR/antigravity/workflows"
GLOBAL_PATH_3="$GEMINI_DIR/antigravity-cli/global_workflows"
GLOBAL_PATH_4="$GEMINI_DIR/antigravity-cli/workflows"

# Define all possible local paths (current workspace directory)
LOCAL_PATH_1=".agent/workflows"
LOCAL_PATH_2=".agents/workflows"

echo "Installing Antigravity global config from: $REPO_DIR"
echo "Target: $GEMINI_DIR"
echo ""

# Ensure all global directories exist
mkdir -p "$GEMINI_DIR"
mkdir -p "$GLOBAL_PATH_1"
mkdir -p "$GLOBAL_PATH_2"
mkdir -p "$GLOBAL_PATH_3"
mkdir -p "$GLOBAL_PATH_4"

# Ensure local directories exist if we are in a project folder
mkdir -p "$LOCAL_PATH_1"
mkdir -p "$LOCAL_PATH_2"

# 1. Symlink Global GEMINI.md
TARGET_FILE="$GEMINI_DIR/GEMINI.md"
if [ -e "$TARGET_FILE" ] && [ ! -L "$TARGET_FILE" ]; then
    BACKUP="$GEMINI_DIR/GEMINI.md.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$TARGET_FILE" "$BACKUP"
    echo "  Backed up existing configuration: ~/.gemini/GEMINI.md → $BACKUP"
fi

[ -L "$TARGET_FILE" ] && rm "$TARGET_FILE"
ln -s "$REPO_DIR/config/GEMINI.md" "$TARGET_FILE"
echo "  ✓ Symlinked ~/.gemini/GEMINI.md"

# 2. Symlink Skills to all global and local targets
echo ""
echo "Installing Custom Slash Commands into all Antigravity workflow paths..."

link_workflow() {
    local skill_name="$1"
    local skill_source="$REPO_DIR/config/antigravity-skills/$skill_name.md"

    if [ -f "$skill_source" ]; then
        for path in "$GLOBAL_PATH_1" "$GLOBAL_PATH_2" "$GLOBAL_PATH_3" "$GLOBAL_PATH_4" "$LOCAL_PATH_1" "$LOCAL_PATH_2"; do
            local dest="$path/$skill_name.md"
            [ -L "$dest" ] && rm "$dest"
            [ -f "$dest" ] && rm "$dest"
            ln -s "$skill_source" "$dest"
        done
        echo "  ✓ Registered /$skill_name"
    else
        echo "  ~ Skill '$skill_name' not found at config/antigravity-skills/$skill_name.md, skipping"
    fi
}

# Register the standard list of interactive workflows
link_workflow "rplan"
link_workflow "rplan-review"
link_workflow "qa"
link_workflow "reviewer"
link_workflow "retro"
link_workflow "reflect"
link_workflow "prompt"
link_workflow "sync"
link_workflow "rupdate"
link_workflow "init-env"

echo ""
echo "✓ Done! Antigravity config setup completed."
echo "Please restart your Antigravity session (exit and restart) to verify custom commands."
echo ""
