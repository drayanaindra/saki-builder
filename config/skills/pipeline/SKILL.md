---
name: pipeline
description: Fully-automated product pipeline — chains /prd → /prd-review → /proto → [PROTO APPROVAL GATE] → /build into one self-surviving run. Autonomous on every stage EXCEPT a single hard human gate at proto: the build never starts until you approve the prototype. Maintains a state+metrics file and resumes across context clears. Survives to completion (front half via the pipeline-completion Stop gate, build half via the build-completion Stop gate). Usage — /pipeline <feature intent>  |  /pipeline --approve-proto <slug>  |  /pipeline <prd-file.md> (skip /prd).
---

# Autonomous Product Pipeline (one human gate: proto)

You run a feature from a one-line intent all the way to shipped, tested code with a **single**
human checkpoint. The chain:

```
/prd  →  /prd-review (loop until SHIP)  →  /proto  →  ⛔ HUMAN APPROVES PROTO ⛔  →  /build
```

Everything is autonomous **except the proto gate**. The user's rule is absolute: **do not start
`/build` until the user has approved the prototype.** The proto approval is a *resumable pause*,
not a confirmation prompt — you emit a gate sentinel, end the turn, and the user resumes with
`/pipeline --approve-proto <slug>`.

You do not re-implement `/prd`, `/prd-review`, `/proto`, or `/build` — you **invoke** them (Skill
tool) and thread their outputs. Your job is orchestration, the state+metrics file, and the gate.

---

## Input & slug

Usage:
- `/pipeline <feature intent>` — start fresh from an intent (runs `/prd` first).
- `/pipeline <prd-file.md>` — start from an existing PRD (skips `/prd`).
- `/pipeline --approve-proto <slug>` — **resume past the proto gate** into `/build` (the user has
  approved). This is the ONLY way the build starts.
- `/pipeline --status <slug>` — print the metrics dashboard for an in-flight or finished run.

Derive `<slug>` the same way `/prd` does: `slugify(feature)`. When starting from a PRD file,
`<slug>` = the PRD filename minus `prd-` and `.md`. The state+metrics file is
`tasks/.pipeline-<slug>-state.json` — read it on every invocation to know where you are.

---

## State + metrics file (single source of truth)

Maintain `tasks/.pipeline-<slug>-state.json`. **Update it after every stage transition** (this is
what the `pipeline-completion-gate.sh` Stop hook reads to keep you running, and what `--status`
prints). Get timestamps with `date +%s` (Bash). Schema:

```json
{
  "slug": "task-tracker",
  "intent": "<the one-line intent>",
  "prd": "tasks/prd-task-tracker.md",
  "session": "<session_id if known, else omit>",
  "phase": "prd|review|proto|awaiting-approval|build|done|blocked",
  "started_at": 1730000000,
  "human_gates": 0,
  "stages": {
    "prd":    { "status": "pending|in-progress|done", "started": 0, "ended": 0,
                "slices": 0, "criteria": 0 },
    "review": { "status": "pending|in-progress|done", "started": 0, "ended": 0,
                "verdict": "SHIP|REVISE|DISCOVERY-FIRST", "phase1": "PASSED|FAILED",
                "rounds": 0, "blockers_fixed": 0 },
    "proto":  { "status": "pending|in-progress|awaiting-approval|done", "started": 0, "ended": 0,
                "screens": 0, "states": 0, "components_added": 0, "approved": false,
                "gallery": "tasks/proto-<slug>/preview.html" },
    "build":  { "status": "pending|in-progress|done|blocked", "started": 0, "ended": 0,
                "slices_done": 0, "slices_total": 0, "qa": "", "reviewer": "",
                "e2e": "pass|no-suite|fail", "commits": 0, "blocked": [] }
  },
  "autonomy": { "stop_gate_recoveries": 0, "auto_resolved_forks": 0 }
}
```

`phase` is the master cursor the Stop gate keys off. Set it precisely:
- `prd|review|proto` → front-half work in progress → the Stop gate **keeps you running**.
- `awaiting-approval` → proto rendered, waiting for the human → the Stop gate **releases** (the
  human's turn). Set `stages.proto.status:"awaiting-approval"` and `human_gates += 1` here.
- `build` → `/build` owns survival now (its own `build-completion-gate.sh` Stop hook) → the
  pipeline gate releases.
- `done` → everything green. `blocked` → a hard stop you reported.

**Best-effort + safe:** a missing/partial state file degrades to a normal manual run — never block
on it. Always write the file before ending a turn so resume works.

---

## GATE 0 — Resume check (deterministic)

On every invocation, read `tasks/.pipeline-<slug>-state.json` if it exists and branch on `phase`:

| `phase` on entry | Action |
|------------------|--------|
| (no file) | Fresh start → Phase 1 (or Phase 3 if a PRD file was passed). |
| `prd` / `review` / `proto` | Resume that stage where it left off (re-run the current stage's skill; earlier stages are done). |
| `awaiting-approval` | If invoked **without** `--approve-proto` → re-show the gate (still waiting). If invoked **with** `--approve-proto <slug>` → record approval, go to Phase 4 (build). |
| `build` | Hand to `/build` (it resumes itself via its own state manifest). |
| `done` / `blocked` | Print the dashboard; nothing to do. |

`--approve-proto <slug>` is ONLY honored when `phase == awaiting-approval`. If the proto isn't
rendered yet, say so and continue the current stage — never skip the gate.

---

## Phase 1 — `/prd`  (skip if a PRD file was passed)

Init the state file (`phase:"prd"`, stamp `started_at` and `stages.prd.started`). Invoke the `prd`
skill with the intent. When it finishes:
- Record `prd = tasks/prd-<slug>.md`, `stages.prd.slices` = count of §8 Vertical Slices,
  `stages.prd.criteria` = total §9 Acceptance Criteria, `stages.prd.status:"done"`, `ended`.
- Set `phase:"review"`.

Do **not** pause for approval — the PRD is reviewed in Phase 2.

---

## Phase 2 — `/prd-review`  (loop until SHIP)

Set `phase:"review"`, `stages.review.started`. Invoke the `prd-review` skill on the PRD. It emits
`Phase 1 (Structural): PASSED/FAILED` and `Verdict: SHIP | REVISE | DISCOVERY-FIRST`.

Loop (autonomous — you are the author here, fix the PRD yourself):
- **Phase 1 FAILED or Verdict REVISE** → apply the review's prescribed fixes to the PRD file
  (rewrite vague criteria, add the missing failure/edge criteria it prescribes, fix orphan slices,
  add kill criteria), bump `stages.review.rounds`, add fixes to `blockers_fixed`, and re-run
  `prd-review`. Cap at **3 rounds**.
- **Verdict DISCOVERY-FIRST** → the PRD has a load-bearing unknown the review says needs discovery
  before building. Do NOT loop forever: record it, set `phase:"blocked"`,
  `stages.build.status:"blocked"`, emit `PIPELINE_BLOCKED: <slug> — PRD needs discovery: <reason>`,
  and end. (A human decides whether to proceed.)
- **Verdict SHIP** (or rounds exhausted with only non-blocking nits) → record `verdict`,
  `stages.review.status:"done"`, `ended`. Set `phase:"proto"`.

Track the trajectory: if round-2 has the same blocker volume as round-1, recut rather than loop a
3rd time (see `patterns.md` — score-trajectory convergence signal).

---

## Phase 3 — `/proto`  →  ⛔ PROTO APPROVAL GATE ⛔

Set `phase:"proto"`, `stages.proto.started`. Invoke the `proto` skill on the PRD
(`/proto tasks/prd-<slug>.md`). `/proto` renders the full journey gallery and has its own internal
checkpoints (Step 2.5 component specs, Step 7 approval). **Honor them** — they ARE the human gate;
never auto-approve them the way `/build` auto-approves a plan.

`/proto` GATE 2 needs a real design system. If `/proto` stops with **NO DESIGN SYSTEM FOUND**, do
not fabricate one: record `stages.proto.status:"blocked"`, set `phase:"blocked"`, emit
`PIPELINE_BLOCKED: <slug> — no design system for /proto (scaffold one, then resume)`, and end.

When `/proto` has produced the gallery (`tasks/proto-<slug>/preview.html`) and reached its Step 7
approval question:
1. Record scope counts: `stages.proto.screens`, `.states`, `.components_added` (from the Step 2.5
   gap analysis), `.gallery`.
2. Set `stages.proto.status:"awaiting-approval"`, `phase:"awaiting-approval"`, `human_gates += 1`,
   `stages.proto.ended`.
3. **Emit the gate sentinel on its own line and END THE TURN:**

```
PIPELINE_PROTO_GATE: {"slug":"<slug>","gallery":"tasks/proto-<slug>/preview.html","screens":N,"states":M,"components_added":K}
```

Then print the human-readable handoff:

```
⛔ PROTO APPROVAL GATE — build will NOT start until you approve.

Prototype ready: tasks/proto-<slug>/preview.html  (N screens · M states · K new components)
Review the gallery, then:
  • Approve  →  /pipeline --approve-proto <slug>      (proceeds to autonomous /build)
  • Revise   →  tell me what to change; I re-render proto and re-gate
```

**Do not proceed to Phase 4 under any circumstance until the user runs `--approve-proto`.** This is
the one non-negotiable human gate. (The `pipeline-completion-gate.sh` Stop hook is configured to
ALLOW the stop at `phase:"awaiting-approval"`, so ending the turn here is correct and expected.)

---

## Phase 4 — `/build`  (only after `--approve-proto`)

Entered ONLY via `/pipeline --approve-proto <slug>` when `phase == awaiting-approval`. First:
- Record `stages.proto.approved:true`, `stages.proto.status:"done"`.
- Set `phase:"build"`, `stages.build.started`, `stages.build.slices_total` = `stages.prd.slices`.

Then invoke the `build` skill on the PRD (`/build tasks/prd-<slug>.md`). `/build` is fully
autonomous and survives to completion on its own (`build-completion-gate.sh` Stop hook + its own
`.build-<slug>-state.json`). It will **reuse the approved proto** (it reads
`tasks/proto-<slug>-notes.md` and promotes those components — see `/build`'s "reuse a /proto
preview"). Let it run to `PRD_BUILD_COMPLETE`.

While `/build` runs, mirror its progress into the pipeline state file at each slice boundary
(`stages.build.slices_done`, `qa`, `reviewer`, `commits`, any `blocked`). If `/build`'s Stop gate
re-drove it after an early stop, increment `autonomy.stop_gate_recoveries`. If `/build`
auto-resolved an open-question fork (`AUTO-RESOLVED:` line), increment `autonomy.auto_resolved_forks`.

On `/build` completion: record `stages.build.e2e`, `stages.build.status:"done"`, `ended`. Set
`phase:"done"`. Go to Phase 5.

If `/build` reports `NEEDS_DECISION:` (a `[human]` fork) or `BLOCKED:` — surface it verbatim and end
the turn; that is `/build`'s own resumable pause, not a pipeline failure.

---

## Phase 5 — Metrics dashboard

When `phase:"done"` (or on `--status`), compute durations from the timestamps and print:

```
═══════════════════════════════════════════════════════════════
PIPELINE COMPLETE — <slug>
═══════════════════════════════════════════════════════════════
Stage      Status   Duration   Key result
  /prd       ✓       Xm Ys     N slices · C acceptance criteria
  /review    ✓       Xm Ys     verdict SHIP · R rounds · B blockers fixed
  /proto     ✓       Xm Ys     S screens · T states · K components added · APPROVED
  /build     ✓       Xm Ys     N/N slices · qa pass · reviewer clean · e2e <result>
  ─────────────────────────────────────────────────────────────
  TOTAL              Xm Ys

Quality gates:   prd-review SHIP ✓ · /qa N/N ✓ · /reviewer clean ✓ · e2e <result> · sonar <if run>
Autonomy:        human gates: 1 (proto)  ·  stop-gate recoveries: X  ·  auto-resolved forks: Y
Scope:           N slices · C criteria · S proto screens/T states · K components · M commits · Z blocked
═══════════════════════════════════════════════════════════════
PIPELINE_COMPLETE
```

`PIPELINE_COMPLETE` (own line) is the terminal sentinel — print it only when `phase:"done"`.

---

## Survival & rules

- **Run to completion.** Do not hand control back mid-stage. The front half is kept alive by the
  `pipeline-completion-gate.sh` Stop hook (it blocks an early stop while `phase` ∈ {prd, review,
  proto} and not awaiting approval). The build half is kept alive by `build-completion-gate.sh`.
  The two never fight: the pipeline gate releases the moment `phase` becomes `awaiting-approval` or
  `build`.
- **The proto gate is sacred.** Exactly one human gate. Never auto-approve proto. Never start
  `/build` without `--approve-proto`.
- **No confirmation prompts elsewhere.** PRD fixes, review loop, and the build are autonomous. The
  only stops are: missing input (no intent and no PRD), `DISCOVERY-FIRST`, `NO DESIGN SYSTEM`, a
  `[human]` fork inside `/build`, or a genuinely-blocked slice.
- **Single source of truth for behavior.** Invoke `prd` / `prd-review` / `proto` / `build`; do not
  re-implement them. The PRD is the source of scope; the proto is the source of look; success =
  every slice green + e2e.
- **Always persist state before ending a turn** so any resume (`--approve-proto`, a context clear,
  or the Stop gate re-driving you) lands on the right phase.
