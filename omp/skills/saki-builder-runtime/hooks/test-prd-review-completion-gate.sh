#!/usr/bin/env bash
# Regression tests for prd-review-completion-gate.sh. Locks the phase-driven behavior:
# the active phase {reviewing} BLOCKS (keep the loop-to-green going); terminal green (PRD
# reached SHIP·READY) and blocked/unknown ALLOW.
# Run: bash config/hooks/test-prd-review-completion-gate.sh
set -u
GATE="$(cd "$(dirname "$0")" && pwd)/prd-review-completion-gate.sh"
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
state() { printf '%s' "$2" >"$1/tasks/.prd-review-x-state.json"; } # fresh mtime

echo "prd-review-completion-gate regression tests"

# ── active phase must BLOCK (keep the loop-to-green going) ──────────────────────
c="$(mkcwd active_reviewing)"
state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":0}}'
run "phase 'reviewing' → block" block "$c" "se$RANDOM"

# ── terminal success: green must ALLOW (PRD reached SHIP·READY) ─────────────────
c="$(mkcwd green)"
state "$c" '{"slug":"x","phase":"green","review":{"rounds":2,"verdict":"SHIP","readiness":"READY"}}'
run "green → allow (SHIP·READY, terminal)" allow "$c" "s$RANDOM"

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
printf 'not json{{{' >"$c/tasks/.prd-review-x-state.json"
run "unparseable state → allow" allow "$c" "s$RANDOM"

# ── subagent stop → ALLOW (never trap a subagent) ─────────────────────────────
c="$(mkcwd subagent)"
state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":0}}'
out="$(echo "{\"cwd\":\"$c\",\"session_id\":\"s1\",\"agent_id\":\"a1\"}" | "$GATE" 2>/dev/null)"
if echo "$out" | grep -q '"decision": "block"'; then FAIL=$((FAIL+1)); printf '  FAIL %-52s\n' "subagent stop → allow"; else PASS=$((PASS+1)); printf '  ok   %-52s (allow)\n' "subagent stop → allow"; fi

# ── session ownership: a DIFFERENT session is not trapped by an owned run ──────
c="$(mkcwd owned)"
state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":0}}'
printf '{"session":"owner-A","score":0,"no_progress":0}' >"$c/tasks/.prd-review-x-state.json.gate.json"
run "owned by A, B stops → allow (not trapped)" allow "$c" "owner-B"
run "owned by A, A stops → block (enforced)"    block "$c" "owner-A"

# ── progress-aware breaker: after MAX_BLOCKS no-progress stops → ALLOW ─────────
c="$(mkcwd breaker)"
state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":0}}'
# 1 block allowed each call; drive no_progress past cap of 1 (score stays flat: reviewing+0 rounds)
run "breaker call1 (np=1) → block" block "$c" "stuck" PRD_REVIEW_GATE_MAX_BLOCKS=1
run "breaker call2 (np=2>cap) → allow (stuck, report)" allow "$c" "stuck" PRD_REVIEW_GATE_MAX_BLOCKS=1

# ── stale run (older than window) → ALLOW ─────────────────────────────────────
c="$(mkcwd stale)"
state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":0}}'
touch -t 202001010000 "$c/tasks/.prd-review-x-state.json"
run "stale run (mtime > window) → allow" allow "$c" "s$RANDOM"

# ══ Cluster 5 (5.7): hard-cap enforcement + deterministic escape ═══════════════
# reason_has <cwd> <sess> <needle> [env…] → yes|no  (captures the block reason, not just block/allow)
reason_has() {
	local cwd="$1" sess="$2" needle="$3"; shift 3
	echo "{\"cwd\":\"$cwd\",\"session_id\":\"$sess\"}" | env "$@" "$GATE" 2>/dev/null | grep -q "$needle" && echo yes || echo no
}
decision() {
	local cwd="$1" sess="$2"; shift 2
	echo "{\"cwd\":\"$cwd\",\"session_id\":\"$sess\"}" | env "$@" "$GATE" 2>/dev/null | grep -q '"decision": "block"' && echo block || echo allow
}
chk() { if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); printf '  ok   %-52s (%s)\n' "$1" "$3"; else FAIL=$((FAIL + 1)); printf '  FAIL %-52s expected %s got %s\n' "$1" "$2" "$3"; fi; }

# test_hardcap_forces_terminal: rounds ≥ hard_cap, phase reviewing → block, reason contains "round cap".
# (each sub-assertion uses its OWN fresh cwd so the first-call is unclaimed — no ownership skip.)
c="$(mkcwd hardcapA)"; state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":4}}'
chk "test_hardcap_forces_terminal (block)" block "$(decision "$c" "hcA" PRD_REVIEW_GATE_HARD_CAP=4)"
c="$(mkcwd hardcapB)"; state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":4}}'
chk "test_hardcap_forces_terminal (reason=round cap)" yes "$(reason_has "$c" "hcB" 'round cap' PRD_REVIEW_GATE_HARD_CAP=4)"
# test_hardcap_grace_round_normal_reason: rounds = cap-1 → normal reason, must NOT contain "round cap".
c="$(mkcwd grace)"; state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":3}}'
chk "test_hardcap_grace_round_normal_reason (no 'round cap')" no "$(reason_has "$c" "gr" 'round cap' PRD_REVIEW_GATE_HARD_CAP=4)"
# test_hardcap_breaker_escape: rounds pinned at cap, flat score → releases within MAX_BLOCKS+1 calls.
c="$(mkcwd hcescape)"; S="hcescape"; got=wedged
for i in 1 2 3; do  # MAX_BLOCKS=2 → release on 3rd
	state "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":4}}'
	[ "$(decision "$c" "$S" PRD_REVIEW_GATE_HARD_CAP=4 PRD_REVIEW_GATE_MAX_BLOCKS=2)" = allow ] && got=escaped
done
chk "test_hardcap_breaker_escape" escaped "$got"
# test_hardcap_runaway_rounds_still_escapes (BR-2): rounds RISE 4→8 past cap, clamped score plateaus → escape.
c="$(mkcwd hcrunaway)"; S="hcrunaway"; got=wedged
for r in 4 5 6 7 8; do
	state "$c" "{\"slug\":\"x\",\"phase\":\"reviewing\",\"review\":{\"rounds\":$r}}"
	[ "$(decision "$c" "$S" PRD_REVIEW_GATE_HARD_CAP=4 PRD_REVIEW_GATE_MAX_BLOCKS=2)" = allow ] && got=escaped
done
chk "test_hardcap_runaway_rounds_still_escapes" escaped "$got"

echo "─────────────────────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
