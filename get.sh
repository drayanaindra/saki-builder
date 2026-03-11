#!/bin/bash
# get.sh — One-line installer for claude-config
# Usage: curl -fsSL https://gitlab.com/drayanaindra/claude-config/-/raw/main/get.sh | bash

set -e

REPO_URL="git@gitlab.com:drayanaindra/claude-config.git"
REPO_HTTPS="https://gitlab.com/drayanaindra/claude-config.git"
INSTALL_DIR="$HOME/claude-config"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
err()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }
hdr()  { echo -e "\n${BOLD}$*${NC}"; }

hdr "claude-config installer"
echo "  Personal Claude Code config with skills, protocols, and learning sync"
echo ""

# ── Prerequisites ────────────────────────────────────────────────────────────
hdr "Checking prerequisites..."

command -v git >/dev/null 2>&1 || err "git is required but not installed."
ok "git $(git --version | awk '{print $3}')"

command -v claude >/dev/null 2>&1 && ok "claude CLI found" || warn "claude CLI not found — install from https://claude.ai/code before using"

# ── Clone or update ──────────────────────────────────────────────────────────
hdr "Setting up repository..."

if [ -d "$INSTALL_DIR/.git" ]; then
  warn "Already installed at $INSTALL_DIR — pulling latest..."
  git -C "$INSTALL_DIR" pull --ff-only
  ok "Updated to latest"
else
  # Try SSH first, fall back to HTTPS
  if ssh -T git@gitlab.com 2>&1 | grep -q "Welcome"; then
    git clone "$REPO_URL" "$INSTALL_DIR"
  else
    warn "SSH not configured, using HTTPS..."
    git clone "$REPO_HTTPS" "$INSTALL_DIR"
  fi
  ok "Cloned to $INSTALL_DIR"
fi

# ── Install ──────────────────────────────────────────────────────────────────
hdr "Installing..."

chmod +x "$INSTALL_DIR/install.sh" "$INSTALL_DIR/sync.sh" "$INSTALL_DIR/uninstall.sh"
bash "$INSTALL_DIR/install.sh"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}All done!${NC}"
echo ""
echo "  Start Claude Code:   claude"
echo "  Sync learnings:      cd ~/claude-config && ./sync.sh"
echo "  Update config:       cd ~/claude-config && git pull"
echo "  Uninstall:           cd ~/claude-config && ./uninstall.sh"
echo ""
