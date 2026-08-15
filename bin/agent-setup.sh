#!/usr/bin/env bash
# agent-setup.sh — provision saki-builder on a headless box, non-interactively.
#
# For an agent runner (Hermes Agent, OpenClaw, CI) that needs the plugin installed before it can
# spawn `claude -p`. Idempotent: safe to re-run, every step is guarded. No TTY required.
#
# Usage:
#   bash bin/agent-setup.sh                 # install + enable, then print the spawn command
#   bash bin/agent-setup.sh --check         # report state only, change nothing
#
# Env: MARKETPLACE_URL (default: the saketek marketplace)

set -u

MARKETPLACE_NAME="saketek"
MARKETPLACE_URL="${MARKETPLACE_URL:-https://github.com/drayanaindra/saki-builder.git}"
PLUGIN="saki-builder@${MARKETPLACE_NAME}"
CHECK_ONLY=0
for a in "$@"; do [ "$a" = "--check" ] && CHECK_ONLY=1; done

say() { printf '%s\n' "$*"; }
ok() { printf '  ✓ %s\n' "$*"; }
skip() { printf '  ~ %s\n' "$*"; }
warn() { printf '  ⚠ %s\n' "$*" >&2; }

# ── 0. Preconditions ──────────────────────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
	warn "'claude' is not on PATH — install Claude Code first:"
	warn "  https://code.claude.com/docs/en/quickstart"
	exit 1
fi
ok "claude CLI: $(command -v claude)"

command -v node >/dev/null 2>&1 || {
	warn "'node' is not on PATH — the lifecycle hook needs it"
	exit 1
}
ok "node: $(node --version)"

plugin_installed() { claude plugin list 2>/dev/null | grep -q "saki-builder"; }

if [ "$CHECK_ONLY" = "1" ]; then
	plugin_installed && ok "$PLUGIN installed" || skip "$PLUGIN NOT installed"
	exit 0
fi

# ── 1. Marketplace (idempotent — a re-add is a harmless no-op) ─────────────────
say ""
say "Marketplace:"
if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
	skip "$MARKETPLACE_NAME already known"
else
	if claude plugin marketplace add "$MARKETPLACE_URL" >/dev/null 2>&1; then
		ok "added $MARKETPLACE_NAME"
	else
		warn "could not add $MARKETPLACE_NAME — continuing (it may already be registered)"
	fi
fi

# ── 2. Install + enable ───────────────────────────────────────────────────────
say ""
say "Plugin:"
if plugin_installed; then
	skip "$PLUGIN already installed"
else
	if claude plugin install "$PLUGIN" >/dev/null 2>&1; then
		ok "installed $PLUGIN"
	else
		warn "install failed — run manually: claude plugin install $PLUGIN"
		exit 1
	fi
fi

claude plugin enable "$PLUGIN" >/dev/null 2>&1 && ok "enabled" || skip "already enabled"

# ── 3. Verify the lifecycle hook is wired and behaves ─────────────────────────
# Drives the installed hook directly with a SessionStart payload: the only check that proves the
# state file a supervisor will poll actually gets written on this box.
say ""
say "Verification:"
HOOK="$(claude plugin list --json 2>/dev/null |
	node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{
    const j=JSON.parse(s), f=(Array.isArray(j)?j:Object.values(j).flat())
      .find(p=>String(p.name||p.id||"").includes("saki-builder"));
    process.stdout.write(f&&f.installPath?f.installPath+"/config/hooks/agent-session.js":"")
  }catch(e){process.stdout.write("")}})' 2>/dev/null)"
[ -f "${HOOK:-}" ] || HOOK="$(cd "$(dirname "$0")/.." && pwd)/config/hooks/agent-session.js"

if [ -f "$HOOK" ]; then
	PROBE="$(mktemp -d)"
	trap 'rm -rf "$PROBE"' EXIT
	printf '{"hook_event_name":"SessionStart","session_id":"probe","cwd":"%s"}' "$PROBE" |
		SAKI_AGENT_MODE=1 node "$HOOK" >/dev/null 2>&1
	if [ -f "$PROBE/tasks/.saki/latest.json" ]; then
		ok "lifecycle hook writes state (probe → tasks/.saki/latest.json)"
	else
		warn "lifecycle hook did not write state — runs will be invisible to the supervisor"
	fi
else
	skip "lifecycle hook not resolvable from here — it resolves at session time"
fi

# ── 4. Print the spawn contract ───────────────────────────────────────────────
cat <<'EOF'

Ready. Spawn a supervised run with:

  SAKI_AGENT_MODE=1 SAKI_TASK_ID="<label>" \
  claude -p "<task or /saki-builder:build I7>" \
    --permission-mode acceptEdits \
    --output-format stream-json --verbose \
    </dev/null

Then poll <cwd>/tasks/.saki/latest.json:

  absent .......................... never started
  status RUNNING, heartbeat_ts advancing ... alive
  status RUNNING, heartbeat_ts stale ....... hung (kill it)
  status DONE|BLOCKED|NEEDS_INPUT|UNKNOWN .. finished

Full contract, supervisor loop, and opencode setup: docs/AGENT-RUNNERS.md
EOF
