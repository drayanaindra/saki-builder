#!/usr/bin/env bash
# build-completion-gate.sh — Stop hook. Keep an autonomous /build running until its
# OWN state manifest says every slice is finished, instead of ending the session early.
#
# Why: /build's "run to completion" is prose the model can drift from over a long context.
# This is the deterministic harness-level backstop. It reads tasks/.build-<slug>-state.json
# (the machine-resume manifest /build maintains) and blocks the Stop while actionable slices
# remain, feeding the model a "continue" reason.
#
# DESIGN (hardened after an adversarial pressure-test — see test-build-completion-gate.sh):
#   - FAIL-SAFE classification: a slice counts as finished ONLY when its (normalized) status is
#     "done" or "blocked" — and a "done" slice must also have steps.qa + steps.reviewer done when
#     a `steps` block is present. EVERY other/unknown/typo'd/empty status counts as REMAINING.
#     (Drift like "in_progress"/"In Progress"/"todo" can no longer silently end a build.)
#   - PROGRESS-AWARE circuit breaker: per-manifest sidecar tracks a progress score
#     (done-slices + done-steps). The no-progress counter resets whenever the score rises, so a
#     long healthy build is never falsely abandoned; it only gives up after BUILD_GATE_MAX_BLOCKS
#     stops that make NO progress (genuinely stuck) — then it allows the stop so /build can report.
#   - SESSION-OWNED: the sidecar records the owning session_id. A different session that stops in
#     the same repo is never trapped by this build's manifest (and concurrent builds each enforce
#     only their own manifest).
#   - FAIL-OPEN everywhere: missing/stale/unparseable manifest, can't-persist sidecar, missing
#     python3 → allow the stop. An uncapped block is the dangerous direction, so ambiguity → allow.
#   - SubagentStop-safe (agent_id present → no-op). Stale builds ignored (mtime > active window).
#
# Tunables (env): BUILD_GATE_ACTIVE_MINUTES (default 45), BUILD_GATE_MAX_BLOCKS (no-progress cap,
#   default 5), BUILD_GATE_DISABLE=1 (off).
# Block signal: prints {"decision":"block","reason":"..."} to stdout. Always exits 0.

set -u
[ "${BUILD_GATE_DISABLE:-0}" = "1" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0 # can't parse safely → allow

STDIN_JSON="$(cat 2>/dev/null)"
[ -z "$STDIN_JSON" ] && exit 0

printf '%s' "$STDIN_JSON" | BUILD_GATE_ACTIVE_MINUTES="${BUILD_GATE_ACTIVE_MINUTES:-45}" \
	BUILD_GATE_MAX_BLOCKS="${BUILD_GATE_MAX_BLOCKS:-5}" python3 -c '
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
window_min = float(os.environ.get("BUILD_GATE_ACTIVE_MINUTES", "45"))
max_np = int(os.environ.get("BUILD_GATE_MAX_BLOCKS", "5"))

def norm(v):
    return re.sub(r"[\s_]+", "-", str(v).strip().lower())

TERMINAL = ("done", "blocked")

def step_status(steps, key):
    st = steps.get(key, {})
    return norm(st.get("status", "")) if isinstance(st, dict) else norm(st)

def slice_finished(s):
    if not isinstance(s, dict):
        return False
    status = norm(s.get("status", ""))
    if status == "blocked":
        return True                      # terminal — cannot proceed, let it report
    if status != "done":
        return False                     # not-started / in-progress / unknown / empty → remaining
    steps = s.get("steps")               # status=="done": defend against premature marking
    if isinstance(steps, dict) and steps:
        for key in ("qa", "reviewer"):
            if key in steps and step_status(steps, key) != "done":
                return False             # marked done but qa/reviewer not actually green → remaining
    return True

def get_slices(state):
    sl = state.get("slices")
    if isinstance(sl, list):
        return sl
    if isinstance(sl, dict):
        return list(sl.values())
    return []

def progress_score(slices):
    done_slices = sum(1 for s in slices if isinstance(s, dict) and norm(s.get("status", "")) == "done")
    done_steps = 0
    for s in slices:
        steps = s.get("steps") if isinstance(s, dict) else None
        if isinstance(steps, dict):
            for v in steps.values():
                stat = v.get("status", "") if isinstance(v, dict) else v
                if norm(stat) == "done":
                    done_steps += 1
    return done_slices * 100 + done_steps

def sanitize(txt, n=70):
    t = re.sub(r"\s+", " ", str(txt)).strip()
    for tok in ("PRD_BUILD_COMPLETE", "BLOCKED:", "decision"):  # scrub the gate''s own control tokens
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

# ── Find active (recently-written) build manifests with remaining work ─────────
cands = []
for path in glob.glob(os.path.join(cwd, "tasks", ".build-*-state.json")):
    try:
        age_min = (time.time() - os.path.getmtime(path)) / 60.0
    except OSError:
        continue
    if age_min <= window_min:
        cands.append((os.path.getmtime(path), path))
if not cands:
    out_allow()                          # no active build → normal session
cands.sort(reverse=True)                 # newest first

# ── Choose the manifest to enforce: prefer one OWNED by this session; else an
#    unclaimed one with remaining work. Never enforce a manifest owned by another session. ──
chosen = None
for _, path in cands:
    state = load(path)
    if not state:
        continue
    slices = get_slices(state)
    if not slices:
        continue
    remaining = [s for s in slices if not slice_finished(s)]
    if not remaining:
        try: os.remove(sidecar(path))    # this build is complete → clear its gate state
        except OSError: pass
        continue
    side = read_side(path)
    owner = (side or {}).get("session")
    if owner == session:
        chosen = (path, state, slices, remaining); break          # ours → enforce
    if owner is None and chosen is None:
        chosen = (path, state, slices, remaining)                 # unclaimed → claim+enforce
    # owner is a DIFFERENT session → skip (do not trap a stranger / other build)
if chosen is None:
    out_allow()

path, state, slices, remaining = chosen

# ── Progress-aware circuit breaker (per-manifest sidecar) ──────────────────────
side = read_side(path) or {}
score = progress_score(slices)
last = side.get("score")
np = 0 if (isinstance(last, int) and score > last) else int(side.get("no_progress", 0)) + 1
try:
    with open(sidecar(path), "w") as f:
        json.dump({"session": session, "score": score, "no_progress": np}, f)
except OSError:
    sys.stderr.write("build-completion-gate: cannot persist gate state — allowing stop (fail open)\n")
    out_allow()                          # can''t cap → must fail open (never block uncapped)

if np > max_np:
    # Hard give-up: keep the sidecar (np stays > cap) so we KEEP allowing once judged stuck,
    # rather than oscillating block/allow. Real progress later resets np to 0 and re-enables it.
    sys.stderr.write("build-completion-gate: %d stops with no progress — allowing stop so the "
                     "build can report.\n" % np)
    out_allow()

# ── Block the stop and tell the model to continue ──────────────────────────────
todo = "; ".join(sanitize("slice %s: %s" % (s.get("n", "?"), s.get("title", "")), 60)
                 for s in remaining[:8])
prd = sanitize(state.get("prd", "the PRD"))
reason = (
    "BUILD INCOMPLETE — do not stop yet. The /saki-builder:build state manifest (%s) still has unfinished "
    "slices: %s. Per /saki-builder:build, run to completion: take the next unfinished slice through "
    "/saki-builder:rplan -> /saki-builder:approved -> /saki-builder:qa -> /saki-builder:reviewer until "
    "/saki-builder:qa is green and /saki-builder:reviewer is clean, update the "
    "state manifest (set the slice status to \"done\" only after /saki-builder:qa AND "
    "/saki-builder:reviewer pass), then "
    "continue. Only stop when every slice is done, e2e passes, and you have emitted the build-"
    "complete sentinel. If a slice genuinely cannot be made green, set its status to \"blocked\" "
    "in the manifest and report it; this gate will then let you stop. (Manifest: %s)"
    % (prd, todo, os.path.relpath(path, cwd))
)
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
'
exit 0
