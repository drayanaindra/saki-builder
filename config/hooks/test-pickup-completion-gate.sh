#!/usr/bin/env bash
# Regression tests for pickup-completion-gate.sh. Locks the phase-driven behavior:
# front-half phases {prd, review} BLOCK; proto-ready (PRD green — the human runs /proto) and
# blocked/unknown ALLOW.
# Run: bash config/hooks/test-pickup-completion-gate.sh
set -u
GATE="$(cd "$(dirname "$0")" && pwd)/pickup-completion-gate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

# run <name> <expect block|allow> <cwd> <session> [env assignments...]
run() {
	local name="$1" expect="$2" cwd="$3" sess="$4"
	shift 4
	local out
	out="$(echo "{\"cwd\":\"$cwd\",\"session_id\":\"$sess\"}" | env "$@" "$GATE" 2>/dev/null)"
	local got="allow"
	echo "$out" | grep -q '"decision": "block"' && got="block"
	if [ "$got" = "$expect" ]; then
		PASS=$((PASS + 1))
		printf '  ok   %-52s (%s)\n' "$name" "$got"
	else
		FAIL=$((FAIL + 1))
		printf '  FAIL %-52s expected %s got %s\n' "$name" "$expect" "$got"
	fi
}
mkcwd() {
	local d="$TMP/$1"
	mkdir -p "$d/tasks"
	echo "$d"
}
state() { printf '%s' "$2" >"$1/tasks/.pickup-x-state.json"; } # fresh mtime

echo "pickup-completion-gate regression tests"

# ── front-half phases must BLOCK (keep the loop going) ─────────────────────────
for p in "prd" "review"; do
	c="$(mkcwd front_$p)"
	state "$c" "{\"slug\":\"x\",\"phase\":\"$p\",\"review\":{\"rounds\":0}}"
	run "phase '$p' → block" block "$c" "se$RANDOM"
done

# ── terminal success: proto-ready must ALLOW (PRD green — the human runs /proto) ─
c="$(mkcwd protoready)"
state "$c" '{"slug":"x","phase":"proto-ready","review":{"rounds":2,"verdict":"SHIP","readiness":"READY"}}'
run "proto-ready → allow (ready for /proto)" allow "$c" "s$RANDOM"

# ── terminal phases ALLOW ──────────────────────────────────────────────────────
c="$(mkcwd term_blocked)"
state "$c" '{"slug":"x","phase":"blocked","review":{"rounds":3}}'
run "phase 'blocked' → allow (terminal)" allow "$c" "s$RANDOM"

# ── unknown/empty phase ALLOWS (never trap; a gate must release) ───────────────
c="$(mkcwd unknown)"
state "$c" '{"slug":"x","phase":"frobnicate","review":{"rounds":0}}'
run "unknown phase → allow (never trap)" allow "$c" "s$RANDOM"
c="$(mkcwd emptyphase)"
state "$c" '{"slug":"x","phase":"","review":{"rounds":0}}'
run "empty phase → allow" allow "$c" "s$RANDOM"

# ── no state file / unparseable → fail-open ALLOW ──────────────────────────────
c="$(mkcwd nofile)"
run "no state file → allow" allow "$c" "s$RANDOM"
c="$(mkcwd garbage)"
printf 'not json{{{' >"$c/tasks/.pickup-x-state.json"
run "unparseable state → allow" allow "$c" "s$RANDOM"

# ── subagent stop → ALLOW (never trap a subagent) ─────────────────────────────
c="$(mkcwd subagent)"
state "$c" '{"slug":"x","phase":"review","review":{"rounds":0}}'
out="$(echo "{\"cwd\":\"$c\",\"session_id\":\"s1\",\"agent_id\":\"a1\"}" | "$GATE" 2>/dev/null)"
if echo "$out" | grep -q '"decision": "block"'; then FAIL=$((FAIL+1)); printf '  FAIL %-52s\n' "subagent stop → allow"; else PASS=$((PASS+1)); printf '  ok   %-52s (allow)\n' "subagent stop → allow"; fi

# ── session ownership: a DIFFERENT session is not trapped by an owned run ──────
c="$(mkcwd owned)"
state "$c" '{"slug":"x","phase":"review","review":{"rounds":0}}'
printf '{"session":"owner-A","score":0,"no_progress":0}' >"$c/tasks/.pickup-x-state.json.gate.json"
run "owned by A, B stops → allow (not trapped)" allow "$c" "owner-B"
run "owned by A, A stops → block (enforced)"    block "$c" "owner-A"

# ── progress-aware breaker: after MAX_BLOCKS no-progress stops → ALLOW ─────────
c="$(mkcwd breaker)"
state "$c" '{"slug":"x","phase":"review","review":{"rounds":0}}'
# 1 block allowed each call; drive no_progress past cap of 1 (score stays flat: review+0 rounds)
run "breaker call1 (np=1) → block" block "$c" "stuck" PICKUP_GATE_MAX_BLOCKS=1
run "breaker call2 (np=2>cap) → allow (stuck, report)" allow "$c" "stuck" PICKUP_GATE_MAX_BLOCKS=1

# ── stale run (older than window) → ALLOW ─────────────────────────────────────
c="$(mkcwd stale)"
state "$c" '{"slug":"x","phase":"review","review":{"rounds":0}}'
touch -t 202001010000 "$c/tasks/.pickup-x-state.json"
run "stale run (mtime > window) → allow" allow "$c" "s$RANDOM"

echo "─────────────────────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
