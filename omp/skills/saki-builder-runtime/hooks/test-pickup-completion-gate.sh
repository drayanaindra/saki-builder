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

# ══ Cluster 5 (redesign): discriminating multi-call tests ══════════════════════
# gate_decision <cwd> <sess> [env…] → prints "block"|"allow" for one gate call.
gate_decision() {
	local cwd="$1" sess="$2"
	shift 2
	local out
	out="$(echo "{\"cwd\":\"$cwd\",\"session_id\":\"$sess\"}" | env "$@" "$GATE" 2>/dev/null)"
	echo "$out" | grep -q '"decision": "block"' && echo block || echo allow
}
pstate() { printf '%s' "$2" >"$1/tasks/.pickup-x-state.json"; }         # fresh mtime
psib() { printf '%s' "$2" >"$1/tasks/.prd-review-x-state.json"; }       # fresh sibling
phases_json() { python3 -c "import json,sys; print(json.dumps([{'id':'F%d'%i,'role':'x'} for i in range(int(sys.argv[1]))]))" "$1"; }
chk() { # chk <name> <expect> <got>
	if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); printf '  ok   %-52s (%s)\n' "$1" "$3"
	else FAIL=$((FAIL + 1)); printf '  FAIL %-52s expected %s got %s\n' "$1" "$2" "$3"; fi
}
PS_REVIEW='{"slug":"x","phase":"review","review":{"rounds":0}}'

# 5.2 — delegated fold: rising sibling rounds keep pickup blocking past max_np (discriminating).
c="$(mkcwd delegfold)"; S="delegfold"; got=block
for r in 0 0 1 1 2 2; do
	pstate "$c" "$PS_REVIEW"; psib "$c" "{\"slug\":\"x\",\"phase\":\"reviewing\",\"review\":{\"rounds\":$r}}"
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=allow
done
chk "test_delegated_progress_outlasts_maxnp" block "$got"
# 5.2 negative control — frozen sibling → releases at cap.
c="$(mkcwd delegfrozen)"; S="delegfrozen"; got=allow_never
for r in 0 0 0 0 0 0; do
	pstate "$c" "$PS_REVIEW"; psib "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":0}}'
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=released
done
chk "test_frozen_delegation_releases" released "$got"

# 5.6 — sidecar-delete gives fresh budget (minimal NO-recut state, score≈1 ≤ seed 5).
NRS='{"slug":"x","phase":"prd","review":{"rounds":0}}'
c="$(mkcwd repointdel)"; S="repointdel"; pstate "$c" "$NRS"
printf '{"session":"%s","score":5,"no_progress":2}' "$S" >"$c/tasks/.pickup-x-state.json.gate.json"
rm -f "$c/tasks/.pickup-x-state.json.gate.json" # simulate 4.6 delete-in-place
chk "test_repoint_sidecar_delete_fresh_budget" block "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)"
c="$(mkcwd repointkeep)"; S="repointkeep"; pstate "$c" "$NRS"
printf '{"session":"%s","score":5,"no_progress":2}' "$S" >"$c/tasks/.pickup-x-state.json.gate.json"
chk "test_repoint_without_delete_releases" allow "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)"

# 5.6b — recut_progress credits each /add (phases[] grows) → block all (discriminating).
c="$(mkcwd p2bmulti)"; S="p2bmulti"; got=block
for n in 0 1 2 3; do
	pstate "$c" "{\"slug\":\"x\",\"phase\":\"review\",\"review\":{\"rounds\":0},\"recut\":{\"stage\":\"registering\",\"phases\":$(phases_json "$n")}}"
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=allow
done
chk "test_phase2b_multiadd_survives" block "$got"
c="$(mkcwd p2bfrozen)"; S="p2bfrozen"; got=allow_never
for i in 1 2 3 4; do
	pstate "$c" '{"slug":"x","phase":"review","review":{"rounds":0},"recut":{"stage":"registering","phases":[]}}'
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=released
done
chk "test_phase2b_frozen_registered_releases" released "$got"
# 5.6b BK-1 — runaway phases plateau at cap(5) → still escapes.
c="$(mkcwd p2brunaway)"; S="p2brunaway"; got=wedged
for n in 1 2 3 4 5 6 7 8; do
	pstate "$c" "{\"slug\":\"x\",\"phase\":\"review\",\"review\":{\"rounds\":0},\"recut\":{\"stage\":\"registering\",\"phases\":$(phases_json "$n")}}"
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=escaped
done
chk "test_recut_progress_runaway_still_escapes" escaped "$got"

# 5.5 / 5.6c — fail-safe + security branches (all fold 0, no crash, stay blocking).
c="$(mkcwd unparsesib)"; pstate "$c" "$PS_REVIEW"; printf 'not json{{{' >"$c/tasks/.prd-review-x-state.json"
chk "test_delegated_sibling_unparseable_folds_zero" block "$(gate_decision "$c" "u$RANDOM")"
c="$(mkcwd noreviewkey)"; pstate "$c" "$PS_REVIEW"; psib "$c" '{"slug":"x","phase":"reviewing"}'
chk "test_delegated_sibling_no_review_key_folds_zero" block "$(gate_decision "$c" "k$RANDOM")"
c="$(mkcwd traversal)"; pstate "$c" '{"slug":"../../../etc/x","phase":"review","review":{"rounds":0}}'
chk "test_delegated_slug_traversal_folds_zero" block "$(gate_decision "$c" "t$RANDOM")"
c="$(mkcwd allpunct)"; pstate "$c" '{"slug":"///","phase":"review","review":{"rounds":0}}'
chk "test_delegated_slug_allpunct_folds_zero" block "$(gate_decision "$c" "a$RANDOM")"
c="$(mkcwd negrounds)"; pstate "$c" "$PS_REVIEW"; psib "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":-3}}'
chk "test_delegated_negative_rounds_clamped" block "$(gate_decision "$c" "n$RANDOM")"
c="$(mkcwd malrecut)"; pstate "$c" '{"slug":"x","phase":"review","review":{"rounds":0},"recut":"notadict"}'
chk "test_malformed_recut_folds_zero" block "$(gate_decision "$c" "m$RANDOM")"

# 5.4 — true wedge still releases (breaker not disabled), incl. a stale sibling present.
c="$(mkcwd truewedge)"; S="truewedge"; got=wedged
for i in 1 2 3 4; do
	pstate "$c" "$PS_REVIEW"
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=released
done
chk "test_true_wedge_still_fires" released "$got"
c="$(mkcwd twstale)"; S="twstale"; got=wedged
for i in 1 2 3 4; do
	pstate "$c" "$PS_REVIEW"; psib "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":5}}'
	touch -t 202001010000 "$c/tasks/.prd-review-x-state.json"
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=released
done
chk "test_true_wedge_stale_sibling_still_fires" released "$got"

# 5.5 — stale sibling not folded (guards the mtime window; invariant guard).
c="$(mkcwd stalesib)"; S="stalesib"; got=wedged
for i in 1 2 3 4; do
	pstate "$c" "$PS_REVIEW"; psib "$c" '{"slug":"x","phase":"reviewing","review":{"rounds":9}}'
	touch -t 202001010000 "$c/tasks/.prd-review-x-state.json"
	[ "$(gate_decision "$c" "$S" PICKUP_GATE_MAX_BLOCKS=2)" = allow ] && got=released
done
chk "test_stale_sibling_not_folded" released "$got"

echo "─────────────────────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
