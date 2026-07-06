#!/usr/bin/env bash
# pickup-completion-gate.sh — Stop hook. Keep a /pickup run alive through its FRONT half
# (prd -> prd-review, looping to green) until the PRD is ready for proto, instead of ending the
# session early. /pickup's terminal success is phase "proto-ready" (PRD green = SHIP·READY); the
# single human gate is at proto (running /proto is the approval), so this gate RELEASES the moment
# /pickup reaches proto-ready or blocked. The BUILD half is owned by build-completion-gate.sh.
#
# Why: /pickup's "loop to green" is prose the model can drift from over a long context. This is the
# deterministic harness-level backstop for the front half. It reads tasks/.pickup-<slug>-state.json
# (the state file /pickup maintains) and blocks an early Stop while the run is mid-front-half,
# feeding the model a "continue" reason.
#
# DESIGN (mirrors build-completion-gate.sh's hardening):
#   - PHASE-DRIVEN: BLOCK only while phase ∈ {prd, review}. ALLOW for proto-ready (PRD green — the
#     human's turn to run /proto), blocked (terminal — a human decides), or any unknown/empty phase.
#     An unknown/empty/typo'd phase ALLOWS — the safe direction here is to NOT trap, because a gate
#     must always be able to release; the build-gate is the strict backstop downstream.
#   - PROGRESS-AWARE circuit breaker: per-manifest sidecar tracks a score (phase ordinal + review
#     rounds). no_progress resets when the score rises; gives up after PICKUP_GATE_MAX_BLOCKS
#     no-progress stops (genuinely stuck) so a wedged front half can still report.
#   - SESSION-OWNED: sidecar records the owning session_id; never trap a different session.
#   - FAIL-OPEN everywhere: missing/stale/unparseable state, can't-persist sidecar, no python3 →
#     allow. SubagentStop-safe (agent_id present → no-op). Stale runs ignored (mtime > window).
#
# Tunables (env): PICKUP_GATE_ACTIVE_MINUTES (default 45), PICKUP_GATE_MAX_BLOCKS (default 5),
#   PICKUP_GATE_DISABLE=1 (off).
# Block signal: prints {"decision":"block","reason":"..."} to stdout. Always exits 0.

set -u
[ "${PICKUP_GATE_DISABLE:-0}" = "1" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0 # can't parse safely → allow

STDIN_JSON="$(cat 2>/dev/null)"
[ -z "$STDIN_JSON" ] && exit 0

printf '%s' "$STDIN_JSON" | PICKUP_GATE_ACTIVE_MINUTES="${PICKUP_GATE_ACTIVE_MINUTES:-45}" \
	PICKUP_GATE_MAX_BLOCKS="${PICKUP_GATE_MAX_BLOCKS:-5}" python3 -c '
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
window_min = float(os.environ.get("PICKUP_GATE_ACTIVE_MINUTES", "45"))
max_np = int(os.environ.get("PICKUP_GATE_MAX_BLOCKS", "5"))

def norm(v):
    return re.sub(r"[\s_]+", "-", str(v).strip().lower())

# Phases that mean "front half still working" → keep going.
ACTIVE = ("prd", "review")
# Everything else releases the stop: proto-ready (PRD green — the human runs /proto), blocked
# (terminal), unknown/empty (never trap — a gate must release).

def pickup_score(state):
    # Progress = phase advancing (prd -> review) or review rounds incrementing.
    ordinal = {"prd": 1, "review": 2}.get(norm(state.get("phase", "")), 0)
    rounds = 0
    rv = state.get("review")
    if isinstance(rv, dict):
        try:
            rounds = int(rv.get("rounds", 0))
        except Exception:
            rounds = 0
    return ordinal + rounds

def sanitize(txt, n=70):
    t = re.sub(r"\s+", " ", str(txt)).strip()
    for tok in ("PICKUP_READY", "PICKUP_BLOCKED", "decision"):
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

# ── Find active (recently-written) pickup state files in an ACTIVE phase ─────────
cands = []
for path in glob.glob(os.path.join(cwd, "tasks", ".pickup-*-state.json")):
    try:
        age_min = (time.time() - os.path.getmtime(path)) / 60.0
    except OSError:
        continue
    if age_min <= window_min:
        cands.append((os.path.getmtime(path), path))
if not cands:
    out_allow()                          # no active pickup → normal session
cands.sort(reverse=True)                 # newest first

# ── Choose a state file to enforce: prefer one OWNED by this session; else unclaimed
#    and in an ACTIVE phase. Never enforce another session''s run. ──
chosen = None
for _, path in cands:
    state = load(path)
    if not state:
        continue
    phase = norm(state.get("phase", ""))
    if phase not in ACTIVE:
        # proto-ready / blocked / unknown → not blocked.
        if phase in ("proto-ready", "blocked"):
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
score = pickup_score(state)
last = side.get("score")
np = 0 if (isinstance(last, int) and score > last) else int(side.get("no_progress", 0)) + 1
try:
    with open(sidecar(path), "w") as f:
        json.dump({"session": session, "score": score, "no_progress": np}, f)
except OSError:
    sys.stderr.write("pickup-completion-gate: cannot persist gate state — allowing stop (fail open)\n")
    out_allow()

if np > max_np:
    sys.stderr.write("pickup-completion-gate: %d stops with no progress — allowing stop so the "
                     "pickup can report.\n" % np)
    out_allow()

# ── Block the stop and tell the model to continue the front half ───────────────
slug = sanitize(state.get("slug", "the run"))
nextmap = {
    "prd":    "run /prd (seeded by the item), then advance to /prd-review",
    "review": "run /prd-review and loop until green (verdict SHIP AND readiness READY), then set "
              "phase to proto-ready and emit the PICKUP_READY sentinel — do NOT run /proto yet "
              "(running /proto is the human''s approval), and never mark the item Shipped from here",
}
reason = (
    "PICKUP INCOMPLETE — do not stop yet. The /pickup state file (%s) is in the \"%s\" phase. "
    "Per /pickup, continue the front half: %s. Update tasks/.pickup-%s-state.json after the stage "
    "transition. The sanctioned end of the front half is phase \"proto-ready\" (the PRD is green, "
    "SHIP·READY, and the human runs /proto next) or \"blocked\" (the review can''t reach green); set "
    "the right one and this gate will release. Never run /proto before the user asks — running it is "
    "their approval."
    % (os.path.relpath(path, cwd), phase, nextmap.get(phase, "continue the current stage"), slug)
)
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
'
exit 0
