#!/usr/bin/env bash
# pipeline-completion-gate.sh — Stop hook. Keep an autonomous /pipeline run alive through its
# FRONT half (prd -> prd-review -> proto) until it reaches the proto approval gate, instead of
# ending the session early. The BUILD half is owned by build-completion-gate.sh; this gate hands
# off to it (releases) the moment the pipeline enters the build phase.
#
# Why: /pipeline's "run to completion" is prose the model can drift from over a long context.
# This is the deterministic harness-level backstop for the front half. It reads
# tasks/.pipeline-<slug>-state.json (the state+metrics file /pipeline maintains) and blocks an
# early Stop while the run is mid-front-half, feeding the model a "continue" reason.
#
# THE ONE HUMAN GATE: when phase == "awaiting-approval", this gate ALLOWS the stop — that is the
# proto approval checkpoint, the user's turn. It is NOT an early exit; it is the designed pause.
#
# DESIGN (mirrors build-completion-gate.sh's hardening):
#   - PHASE-DRIVEN: BLOCK only while phase ∈ {prd, review, proto}. ALLOW for awaiting-approval
#     (human gate), build (build-gate owns it), done, blocked (terminal), or any unknown phase.
#     An unknown/empty/typo'd phase ALLOWS — the safe direction here is to NOT trap, because the
#     proto gate must always be able to release; the build-gate is the strict backstop downstream.
#   - PROGRESS-AWARE circuit breaker: per-manifest sidecar tracks a score (count of done stages).
#     no_progress resets when the score rises; gives up after PIPELINE_GATE_MAX_BLOCKS no-progress
#     stops (genuinely stuck) so a wedged front half can still report.
#   - SESSION-OWNED: sidecar records the owning session_id; never trap a different session.
#   - FAIL-OPEN everywhere: missing/stale/unparseable state, can't-persist sidecar, no python3 →
#     allow. SubagentStop-safe (agent_id present → no-op). Stale runs ignored (mtime > window).
#
# Tunables (env): PIPELINE_GATE_ACTIVE_MINUTES (default 45), PIPELINE_GATE_MAX_BLOCKS (default 5),
#   PIPELINE_GATE_DISABLE=1 (off).
# Block signal: prints {"decision":"block","reason":"..."} to stdout. Always exits 0.

set -u
[ "${PIPELINE_GATE_DISABLE:-0}" = "1" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0 # can't parse safely → allow

STDIN_JSON="$(cat 2>/dev/null)"
[ -z "$STDIN_JSON" ] && exit 0

printf '%s' "$STDIN_JSON" | PIPELINE_GATE_ACTIVE_MINUTES="${PIPELINE_GATE_ACTIVE_MINUTES:-45}" \
	PIPELINE_GATE_MAX_BLOCKS="${PIPELINE_GATE_MAX_BLOCKS:-5}" python3 -c '
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
window_min = float(os.environ.get("PIPELINE_GATE_ACTIVE_MINUTES", "45"))
max_np = int(os.environ.get("PIPELINE_GATE_MAX_BLOCKS", "5"))

def norm(v):
    return re.sub(r"[\s_]+", "-", str(v).strip().lower())

# Phases that mean "front half still working" → keep going.
ACTIVE = ("prd", "review", "proto")
# Everything else releases the stop: awaiting-approval (human gate), build (build-gate owns),
# done/blocked (terminal), unknown/empty (never trap — the proto gate must be able to release).

def done_stage_count(state):
    stages = state.get("stages")
    if not isinstance(stages, dict):
        return 0
    n = 0
    for v in stages.values():
        st = v.get("status", "") if isinstance(v, dict) else v
        if norm(st) == "done":
            n += 1
    return n

def sanitize(txt, n=70):
    t = re.sub(r"\s+", " ", str(txt)).strip()
    for tok in ("PIPELINE_COMPLETE", "PIPELINE_PROTO_GATE", "PIPELINE_BLOCKED", "decision"):
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

# ── Find active (recently-written) pipeline state files in an ACTIVE phase ─────────
cands = []
for path in glob.glob(os.path.join(cwd, "tasks", ".pipeline-*-state.json")):
    try:
        age_min = (time.time() - os.path.getmtime(path)) / 60.0
    except OSError:
        continue
    if age_min <= window_min:
        cands.append((os.path.getmtime(path), path))
if not cands:
    out_allow()                          # no active pipeline → normal session
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
        # awaiting-approval / build / done / blocked / unknown → this gate does not block it.
        if phase in ("done",):
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
score = done_stage_count(state)
last = side.get("score")
np = 0 if (isinstance(last, int) and score > last) else int(side.get("no_progress", 0)) + 1
try:
    with open(sidecar(path), "w") as f:
        json.dump({"session": session, "score": score, "no_progress": np}, f)
except OSError:
    sys.stderr.write("pipeline-completion-gate: cannot persist gate state — allowing stop (fail open)\n")
    out_allow()

if np > max_np:
    sys.stderr.write("pipeline-completion-gate: %d stops with no progress — allowing stop so the "
                     "pipeline can report.\n" % np)
    out_allow()

# ── Block the stop and tell the model to continue the front half ───────────────
slug = sanitize(state.get("slug", "the run"))
nextmap = {
    "prd":    "run /prd, then advance to /prd-review",
    "review": "run /prd-review and loop until the verdict is SHIP, then advance to /proto",
    "proto":  "run /proto to render the gallery, then set phase to awaiting-approval and emit the "
              "PROTO_GATE sentinel (do NOT start /build — that needs the human approval)",
}
reason = (
    "PIPELINE INCOMPLETE — do not stop yet. The /pipeline state file (%s) is in the \"%s\" phase. "
    "Per /pipeline, continue the front half: %s. Update tasks/.pipeline-%s-state.json after the "
    "stage transition. The ONLY sanctioned pause in the front half is the proto approval gate "
    "(phase \"awaiting-approval\"); set that and this gate will release. Never start /build before "
    "the user approves the proto."
    % (os.path.relpath(path, cwd), phase, nextmap.get(phase, "continue the current stage"), slug)
)
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
'
exit 0
