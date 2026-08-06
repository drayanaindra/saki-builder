#!/usr/bin/env bash
# test-inject-core.sh — inject-core.js must stay inert by default and layer the agent-mode
# overlay ONLY when SAKI_AGENT_MODE=1 (plan I8 step 2, criterion S1).

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
HOOK="$DIR/inject-core.js"

pass=0
fail=0

check() { # check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"
	fi
}

PAYLOAD='{"session_id":"t1","cwd":"'"$ROOT"'","hook_event_name":"SessionStart","source":"startup"}'

run() { # run <SAKI_AGENT_MODE value or empty> -> stdout
	if [ -n "${1:-}" ]; then
		printf '%s' "$PAYLOAD" | SAKI_AGENT_MODE="$1" CLAUDE_PLUGIN_ROOT="$ROOT" node "$HOOK" 2>/dev/null
	else
		printf '%s' "$PAYLOAD" | env -u SAKI_AGENT_MODE CLAUDE_PLUGIN_ROOT="$ROOT" node "$HOOK" 2>/dev/null
	fi
}

has() { # has <haystack> <needle> -> yes|no
	case "$1" in
	*"$2"*) echo yes ;;
	*) echo no ;;
	esac
}

# 1–2. Default (agent mode OFF): core present, overlay absent.
OFF="$(run '')"
check "off: core injected" yes "$(has "$OFF" 'saki-builder — always-on core')"
check "off: overlay NOT injected" no "$(has "$OFF" 'agent mode (autonomous runner)')"

# 3–4. Agent mode ON: both present.
ON="$(run 1)"
check "on: core injected" yes "$(has "$ON" 'saki-builder — always-on core')"
check "on: overlay injected" yes "$(has "$ON" 'agent mode (autonomous runner)')"

# 5. The overlay must come AFTER the core so it wins by position.
core_at=$(printf '%s' "$ON" | grep -bo 'saki-builder — always-on core' | head -1 | cut -d: -f1)
ovl_at=$(printf '%s' "$ON" | grep -bo 'agent mode (autonomous runner)' | head -1 | cut -d: -f1)
if [ -n "$core_at" ] && [ -n "$ovl_at" ] && [ "$ovl_at" -gt "$core_at" ]; then
	check "on: overlay after core" ok ok
else
	check "on: overlay after core" ok "core@${core_at:-?} overlay@${ovl_at:-?}"
fi

# 6. Output is valid SessionStart hook JSON in both modes.
check "on: valid hook JSON" SessionStart \
	"$(printf '%s' "$ON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).hookSpecificOutput.hookEventName)}catch(e){process.stdout.write("INVALID")}})')"

# 7. Anything other than exactly "1" is OFF (no truthy-string surprises).
check "SAKI_AGENT_MODE=true is OFF" no "$(has "$(run true)" 'agent mode (autonomous runner)')"

# 8. Fail-open: exit 0 even on garbage stdin.
printf 'not json' | SAKI_AGENT_MODE=1 CLAUDE_PLUGIN_ROOT="$ROOT" node "$HOOK" >/dev/null 2>&1
check "fail-open exit code" 0 "$?"

echo "inject-core: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
