#!/usr/bin/env bash
# test-opencode-install.sh — verify bin/saki-install.mjs against a scratch target.
# Run: bash test/test-opencode-install.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TARGET="$TMP/cfg"

bash "$REPO/bin/build-npm-bundle.sh" >/dev/null
node "$REPO/bin/saki-install.mjs" --target "$TARGET" --bundle "$REPO/dist/opencode-bundle" >/dev/null

# ── managed files/dirs land ────────────────────────────────────────────────
[ -f "$TARGET/AGENTS.md" ] || { echo "FAIL: AGENTS.md missing"; exit 1; }
[ -d "$TARGET/skills" ] && [ -n "$(ls "$TARGET/skills")" ] || { echo "FAIL: skills empty"; exit 1; }
[ -d "$TARGET/commands" ] && [ -n "$(ls "$TARGET/commands")" ] || { echo "FAIL: commands empty"; exit 1; }
[ -d "$TARGET/agent" ] && [ "$(ls "$TARGET/agent" | wc -l | tr -d ' ')" -ge 3 ] || { echo "FAIL: agent < 3 files"; exit 1; }

# ── AGENTS.md docs refs are repointed to the package's absolute path ────────
TOTAL="$(grep -c "config/docs/" "$TARGET/AGENTS.md" || true)"
ABS="$(grep -c "$REPO/config/docs/" "$TARGET/AGENTS.md" || true)"
[ "$TOTAL" = "$ABS" ] && [ "$TOTAL" -gt 0 ] || { echo "FAIL: bare config/docs refs remain in AGENTS.md"; exit 1; }

# ── .saki-env pins the package root ─────────────────────────────────────────
grep -q "SAKI_PLUGIN_ROOT=$REPO" "$TARGET/.saki-env" || { echo "FAIL: .saki-env missing/bad"; exit 1; }

# ── idempotent: a second run must not change anything or create a backup ───
BEFORE="$(find "$TARGET" -type f | sort)"
node "$REPO/bin/saki-install.mjs" --target "$TARGET" --bundle "$REPO/dist/opencode-bundle" >/dev/null
AFTER="$(find "$TARGET" -type f | sort)"
[ "$BEFORE" = "$AFTER" ] || { echo "FAIL: second run changed files"; exit 1; }
[ -z "$(ls -d "$TARGET"/.saki-backup-* 2>/dev/null || true)" ] || { echo "FAIL: second run created a backup (not idempotent)"; exit 1; }

echo "opencode-install OK (target: $TARGET)"
