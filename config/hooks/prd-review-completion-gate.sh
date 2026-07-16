#!/usr/bin/env bash
# prd-review-completion-gate.sh — Stop hook. Keep an autonomous /prd-review run alive through its
# loop-to-green (review -> apply the prescribed fixes -> re-review) until the PRD is green
# (SHIP·READY) or a hard blocker, instead of ending the session early. /prd-review's terminal
# success is phase "green"; a non-convergent / discovery-first PRD ends "blocked". This gate
# RELEASES the moment /prd-review reaches green or blocked.
#
# Why: /prd-review's "loop to green" is prose the model can drift from over a long context. This is
# the deterministic harness-level backstop for the autonomous loop. It reads
# tasks/.prd-review-<slug>-state.json (the state file /prd-review maintains) and blocks an early
# Stop while phase is "reviewing", feeding the model a "continue" reason.
#
# DESIGN (mirrors pickup-completion-gate.sh / build-completion-gate.sh hardening):
#   - PHASE-DRIVEN: BLOCK only while phase == "reviewing". ALLOW for green (PRD reached SHIP·READY),
#     blocked (terminal — a human decides), or any unknown/empty phase. An unknown/empty/typo'd
#     phase ALLOWS — the safe direction here is to NOT trap, because a gate must always be able to
#     release.
#   - PROGRESS-AWARE circuit breaker: per-manifest sidecar tracks a score (phase ordinal + review
#     rounds). no_progress resets when the score rises; gives up after PRD_REVIEW_GATE_MAX_BLOCKS
#     no-progress stops (genuinely stuck) so a wedged loop can still report.
#   - SESSION-OWNED: sidecar records the owning session_id; never trap a different session.
#   - FAIL-OPEN everywhere: missing/stale/unparseable state, can't-persist sidecar, no python3 →
#     allow. SubagentStop-safe (agent_id present → no-op). Stale runs ignored (mtime > window).
#
# Tunables (env): PRD_REVIEW_GATE_ACTIVE_MINUTES (default 45), PRD_REVIEW_GATE_MAX_BLOCKS (default 5),
#   PRD_REVIEW_GATE_DISABLE=1 (off).
# Block signal: prints {"decision":"block","reason":"..."} to stdout. Always exits 0.

set -u
[ "${PRD_REVIEW_GATE_DISABLE:-0}" = "1" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0 # can't parse safely → allow

STDIN_JSON="$(cat 2>/dev/null)"
[ -z "$STDIN_JSON" ] && exit 0

printf '%s' "$STDIN_JSON" | PRD_REVIEW_GATE_ACTIVE_MINUTES="${PRD_REVIEW_GATE_ACTIVE_MINUTES:-45}" \
	PRD_REVIEW_GATE_MAX_BLOCKS="${PRD_REVIEW_GATE_MAX_BLOCKS:-5}" \
	PRD_REVIEW_GATE_HARD_CAP="${PRD_REVIEW_GATE_HARD_CAP:-4}" python3 -c '
import json, sys, os, glob, time, re

def out_allow():            # allow the stop: no stdout, exit 0
    sys.exit(0)

try:
    payload = json.load(sys.stdin)
except Exception:
    out_allow()

# Never trap a subagent stop.
if payload.get("agent_id") or payload.get("agent_type"):
    out_allow()

cwd = payload.get("cwd") or os.getcwd()
session = str(payload.get("session_id", "")) or "nosession"
window_min = float(os.environ.get("PRD_REVIEW_GATE_ACTIVE_MINUTES", "45"))
max_np = int(os.environ.get("PRD_REVIEW_GATE_MAX_BLOCKS", "5"))
hard_cap = int(os.environ.get("PRD_REVIEW_GATE_HARD_CAP", "4"))  # 1 over the prose 3-round cap

def norm(v):
    return re.sub(r"[\s_]+", "-", str(v).strip().lower())

# The one phase that means "loop still working" → keep going.
ACTIVE = ("reviewing",)
# Everything else releases the stop: green (PRD reached SHIP·READY), blocked (terminal),
# unknown/empty (never trap — a gate must release).

def review_score(state):
    # Progress = review rounds incrementing (phase is single-active, so the ordinal is a constant
    # floor; rounds are the real signal that a pass completed). CLAMP rounds at hard_cap so the score
    # PLATEAUS once past the cap: a model that keeps looping past the cap (rounds 5,6,7…) then stops
    # raising the score → no_progress climbs → the breaker deterministically releases (instead of the
    # score rising every stop and resetting no_progress → wedged forever).
    ordinal = {"reviewing": 1}.get(norm(state.get("phase", "")), 0)
    rounds = 0
    rv = state.get("review")
    if isinstance(rv, dict):
        try:
            rounds = int(rv.get("rounds", 0))
        except Exception:
            rounds = 0
    return ordinal + min(rounds, hard_cap)

def sanitize(txt, n=70):
    t = re.sub(r"\s+", " ", str(txt)).strip()
    for tok in ("PRD_REVIEW_GREEN", "PRD_REVIEW_BLOCKED", "decision"):
        t = re.sub(re.escape(tok), "[redacted]", t, flags=re.I)
    return t[:n]

def load(path):
    try:
        with open(path, encoding="utf-8-sig", errors="replace") as f:
            return json.load(f)
    except Exception:
        return None

def sidecar(path):
    return path + ".gate.json"

def read_side(path):
    try:
        with open(sidecar(path)) as f:
            return json.load(f)
    except Exception:
        return None

# ── Find active (recently-written) prd-review state files in the ACTIVE phase ────
cands = []
for path in glob.glob(os.path.join(cwd, "tasks", ".prd-review-*-state.json")):
    try:
        age_min = (time.time() - os.path.getmtime(path)) / 60.0
    except OSError:
        continue
    if age_min <= window_min:
        cands.append((os.path.getmtime(path), path))
if not cands:
    out_allow()                          # no active review loop → normal session
cands.sort(reverse=True)                 # newest first

# ── Choose a state file to enforce: prefer one OWNED by this session; else unclaimed
#    and in the ACTIVE phase. Never enforce another session''s run. ──
chosen = None
for _, path in cands:
    state = load(path)
    if not state:
        continue
    phase = norm(state.get("phase", ""))
    if phase not in ACTIVE:
        # green / blocked / unknown → not blocked.
        if phase in ("green", "blocked"):
            try: os.remove(sidecar(path))    # finished → clear gate state
            except OSError: pass
        continue
    side = read_side(path)
    owner = (side or {}).get("session")
    if owner == session:
        chosen = (path, state, phase); break          # ours → enforce
    if owner is None and chosen is None:
        chosen = (path, state, phase)                 # unclaimed → claim+enforce
    # owner is a DIFFERENT session → skip
if chosen is None:
    out_allow()

path, state, phase = chosen

# ── Progress-aware circuit breaker (per-manifest sidecar) ──────────────────────
side = read_side(path) or {}
score = review_score(state)
last = side.get("score")
np = 0 if (isinstance(last, int) and score > last) else int(side.get("no_progress", 0)) + 1
try:
    with open(sidecar(path), "w") as f:
        json.dump({"session": session, "score": score, "no_progress": np}, f)
except OSError:
    sys.stderr.write("prd-review-completion-gate: cannot persist gate state — allowing stop (fail open)\n")
    out_allow()

if np > max_np:
    sys.stderr.write("prd-review-completion-gate: %d stops with no progress — allowing stop so the "
                     "review can report.\n" % np)
    out_allow()

# ── Block the stop and tell the model to continue the loop-to-green ─────────────
# Extract RAW rounds (un-clamped) for the hard-cap trigger — read from state, not review_score.
raw_rounds = 0
_rv = state.get("review")
if isinstance(_rv, dict):
    try:
        raw_rounds = int(_rv.get("rounds", 0))
    except Exception:
        raw_rounds = 0

if raw_rounds >= hard_cap:
    # Hit the round cap still not green → STOP looping. Constant reason (no state echo); the unique
    # token "round cap" is ABSENT from the generic reason below, so a test can discriminate on it.
    reason = (
        "PRD-REVIEW ROUND CAP REACHED — you have hit the round cap and the PRD is not green. STOP "
        "looping: do NOT run another review round. Set phase to \"blocked\", tag it non-convergence, "
        "and emit the PRD_REVIEW_BLOCKED sentinel now — this gate will release then."
    )
else:
    slug = sanitize(state.get("slug", "the run"))
    reason = (
        "PRD-REVIEW INCOMPLETE — do not stop yet. The autonomous /prd-review state file (%s) is in the "
        "\"reviewing\" phase. Continue the loop-to-green: run the review core, and if the PRD is not green "
        "(Verdict SHIP AND Readiness READY), apply the prescribed fixes to the PRD and re-review — until "
        "green or a hard blocker (DISCOVERY-FIRST / structural NOT READY / non-convergence). Cap at 3 "
        "rounds; never fabricate grounding. Update tasks/.prd-review-%s-state.json after the transition and "
        "set phase to \"green\" (SHIP·READY) or \"blocked\" — this gate will release then."
        % (os.path.relpath(path, cwd), slug)
    )
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
'
exit 0
