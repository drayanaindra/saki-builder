#!/bin/bash
# get.sh — One-line installer for claude-config
#
# Usage (after forking this repo):
#   curl -fsSL https://gitlab.com/YOUR_USER/claude-config/-/raw/main/get.sh | bash
#
# Or pass your repo URL directly:
#   curl -fsSL .../get.sh | REPO_URL=git@gitlab.com:you/claude-config.git bash
#   curl -fsSL .../get.sh | bash -s -- git@gitlab.com:you/claude-config.git

set -e

INSTALL_DIR="$HOME/claude-config"

# Determine repo URL: argument > env var > auto-detect from existing install > error
REPO_URL="${1:-${REPO_URL:-}}"

if [ -z "$REPO_URL" ] && [ -d "$INSTALL_DIR/.git" ]; then
  REPO_URL="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
fi

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
err()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }
hdr()  { echo -e "\n${BOLD}$*${NC}"; }

hdr "claude-config installer"
echo "  Structured workflow, skills, and learning sync for Claude Code"
echo ""

if [ -z "$REPO_URL" ]; then
  echo -e "  ${RED}No repo URL provided.${NC}"
  echo ""
  echo "  Fork this repo, then run:"
  echo "    curl -fsSL <raw-url-to-get.sh> | REPO_URL=git@gitlab.com:YOU/claude-config.git bash"
  echo ""
  echo "  Or clone manually and run install.sh:"
  echo "    git clone git@gitlab.com:YOU/claude-config.git ~/claude-config"
  echo "    ~/claude-config/install.sh"
  exit 1
fi

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
  git clone "$REPO_URL" "$INSTALL_DIR" || err "Clone failed. Check your repo URL and SSH/HTTPS access."
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
