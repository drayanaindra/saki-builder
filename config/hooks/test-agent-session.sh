#!/usr/bin/env bash
# test-agent-session.sh — agent-session.js lifecycle state machine (plan I8 step 5, criterion S2).
#
# Covers the 11 cases the plan pins, including the two traps:
#   - a prose line mentioning "BLOCKED:" mid-sentence must NOT be parsed as a result (line-anchor)
#   - SessionEnd must never overwrite an already-terminal status

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$DIR/agent-session.js"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

fresh() { # fresh -> a clean cwd for one scenario
	local d
	d="$(mktemp -d "$TMP/case.XXXXXX")"
	echo "$d"
}

fire() { # fire <cwd> <json payload> [extra env assignments...]
	local cwd="$1" payload="$2"
	shift 2
	printf '%s' "$payload" | env SAKI_AGENT_MODE=1 "$@" node "$HOOK" 2>/dev/null
}

latest() { # latest <cwd> <jq-ish key path via node> -> value or MISSING
	local f="$1/tasks/.saki/latest.json"
	[ -f "$f" ] || {
		echo MISSING
		return
	}
	node -e '
    const fs=require("fs");
    try{const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
        const v=process.argv[2].split(".").reduce((a,k)=>a==null?a:a[k],d);
        process.stdout.write(v===undefined||v===null?"NULL":String(v));
    }catch(e){process.stdout.write("BADJSON")}' "$f" "$2"
}

payload() { # payload <event> <cwd> [extra json fields, no braces]
	local ev="$1" cwd="$2" extra="${3:-}"
	printf '{"hook_event_name":"%s","session_id":"s-abc","cwd":"%s"%s}' \
		"$ev" "$cwd" "${extra:+,$extra}"
}

# ── 1. agent mode OFF → no file at all ────────────────────────────────────────
d="$(fresh)"
printf '%s' "$(payload SessionStart "$d")" | env -u SAKI_AGENT_MODE node "$HOOK" >/dev/null 2>&1
check "1 off: no state file" MISSING "$(latest "$d" status)"

# ── 2. SessionStart → RUNNING with started_at ─────────────────────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
check "2 SessionStart status" RUNNING "$(latest "$d" status)"
check "2 SessionStart schema" 1 "$(latest "$d" schema)"
[ "$(latest "$d" started_at)" != NULL ] && check "2 started_at set" ok ok || check "2 started_at set" ok missing

# ── 3. two PostToolBatch beyond the throttle → turns==2, heartbeat advances ────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
fire "$d" "$(payload PostToolBatch "$d")" SAKI_HEARTBEAT_MS=0 >/dev/null
hb1="$(latest "$d" heartbeat_ts)"
sleep 1
fire "$d" "$(payload PostToolBatch "$d")" SAKI_HEARTBEAT_MS=0 >/dev/null
hb2="$(latest "$d" heartbeat_ts)"
check "3 turns after 2 batches" 2 "$(latest "$d" turns)"
[ "$hb2" \> "$hb1" ] && check "3 heartbeat advanced" ok ok || check "3 heartbeat advanced" ok "$hb1 -> $hb2"

# ── 4. two PostToolBatch INSIDE the throttle → debounced to 1 ──────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
fire "$d" "$(payload PostToolBatch "$d")" SAKI_HEARTBEAT_MS=60000 >/dev/null
fire "$d" "$(payload PostToolBatch "$d")" SAKI_HEARTBEAT_MS=60000 >/dev/null
check "4 throttle debounces" 1 "$(latest "$d" turns)"

# ── 5. Stop with a real sentinel → DONE + artifacts ───────────────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
MSG='All set.\nSAKI-RESULT: {\"status\":\"DONE\",\"task\":\"t\",\"artifacts\":[\"a.md\",\"b.go\"],\"blocked_on\":null,\"auto_resolved\":[],\"next\":null}'
fire "$d" "$(payload Stop "$d" "\"last_assistant_message\":\"$MSG\",\"stopped_by\":\"model_stop_reason\"")" >/dev/null
check "5 Stop status" DONE "$(latest "$d" status)"
check "5 Stop artifacts[1]" b.go "$(latest "$d" artifacts.1)"
[ "$(latest "$d" ended_at)" != NULL ] && check "5 ended_at set" ok ok || check "5 ended_at set" ok missing

# ── 6. Stop without any sentinel → UNKNOWN ────────────────────────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
fire "$d" "$(payload Stop "$d" '"last_assistant_message":"I finished the work.","stopped_by":"model_stop_reason"')" >/dev/null
check "6 no sentinel -> UNKNOWN" UNKNOWN "$(latest "$d" status)"

# ── 7. TRAP: prose mentioning the marker mid-sentence must NOT classify ───────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
PROSE='the step is BLOCKED: on an API, so I would emit SAKI-RESULT: {\"status\":\"BLOCKED\"} normally'
fire "$d" "$(payload Stop "$d" "\"last_assistant_message\":\"$PROSE\",\"stopped_by\":\"model_stop_reason\"")" >/dev/null
check "7 mid-sentence marker ignored" UNKNOWN "$(latest "$d" status)"

# ── 8. turn_limit → NEEDS_INPUT ───────────────────────────────────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
fire "$d" "$(payload Stop "$d" '"last_assistant_message":"...","stopped_by":"turn_limit"')" >/dev/null
check "8 turn_limit -> NEEDS_INPUT" NEEDS_INPUT "$(latest "$d" status)"

# ── 9. SessionEnd while RUNNING → closed out (never a stale RUNNING) ──────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
fire "$d" "$(payload SessionEnd "$d" '"exit_reason":"other"')" >/dev/null
check "9 SessionEnd closes RUNNING" UNKNOWN "$(latest "$d" status)"

# ── 10. SessionEnd AFTER a terminal Stop → terminal preserved ─────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
fire "$d" "$(payload Stop "$d" "\"last_assistant_message\":\"$MSG\",\"stopped_by\":\"model_stop_reason\"")" >/dev/null
fire "$d" "$(payload SessionEnd "$d" '"exit_reason":"other"')" >/dev/null
check "10 terminal not overwritten" DONE "$(latest "$d" status)"

# ── 11. subagent stop (agent_id present) → no write ───────────────────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d" '"agent_id":"sub-1","agent_type":"Explore"')" >/dev/null
check "11 subagent no write" MISSING "$(latest "$d" status)"

# ── 12. two sessions → per-session files + latest = last writer ───────────────
d="$(fresh)"
fire "$d" "$(payload SessionStart "$d")" >/dev/null
printf '%s' "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"s-xyz\",\"cwd\":\"$d\"}" |
	env SAKI_AGENT_MODE=1 node "$HOOK" >/dev/null 2>&1
[ -f "$d/tasks/.saki/s-abc.json" ] && [ -f "$d/tasks/.saki/s-xyz.json" ] &&
	check "12 per-session files" ok ok || check "12 per-session files" ok missing
check "12 latest = last writer" s-xyz "$(latest "$d" session_id)"

# ── 13. never blocks: empty stdout, exit 0, even on garbage ───────────────────
d="$(fresh)"
out="$(fire "$d" 'not json at all')"
check "13 garbage exit code" 0 "$?"
check "13 garbage stdout empty" "" "$out"
out="$(fire "$d" "$(payload Stop "$d" "\"last_assistant_message\":\"$MSG\"")")"
check "13 stop stdout empty (never blocks)" "" "$out"

echo "agent-session: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
