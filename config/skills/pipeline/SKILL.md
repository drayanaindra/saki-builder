---
name: pipeline
description: Fully-automated product pipeline — chains /saki-builder:prd ↔ /saki-builder:prd-review (loop to SHIP·READY) → [PRD APPROVAL GATE] → /saki-builder:proto → [PROTO APPROVAL GATE] → /saki-builder:build into one self-surviving run. Autonomous on every stage EXCEPT two hard human gates: PRD approval (only reached once the review is green — SHIP and READY) and proto approval (the build never starts until you approve the prototype). If the review can't reach green it stops as BLOCKED for a human — it never ships a red PRD forward and never loops forever. Maintains a state+metrics file and resumes across context clears. Survives to completion (front half via the pipeline-completion Stop gate, build half via the build-completion Stop gate). Usage — /saki-builder:pipeline <feature intent>  |  /saki-builder:pipeline --approve-prd <slug>  |  /saki-builder:pipeline --approve-proto <slug>  |  /saki-builder:pipeline <prd-file.md> (skip /saki-builder:prd).
---

# Autonomous Product Pipeline (two human gates: PRD approval · proto approval)

You run a feature from a one-line intent all the way to shipped, tested code with **two** human
checkpoints. The chain:

```
/saki-builder:prd  ↔  /saki-builder:prd-review (loop until SHIP·READY)  →  ⛔ HUMAN APPROVES PRD ⛔  →  /saki-builder:proto  →  ⛔ HUMAN APPROVES PROTO ⛔  →  /saki-builder:build
```

Everything is autonomous **except the two gates**. The review loops (fix → re-review) until the PRD is
**green — `SHIP` AND `READY`** — then pauses for the human to approve the spec; only after that does proto
render, and the build never starts until the human approves the prototype too. Each gate is a *resumable
pause*, not a confirmation prompt — you emit a gate sentinel, end the turn, and the user resumes with
`/saki-builder:pipeline --approve-prd <slug>` (past the PRD gate) or `--approve-proto <slug>` (past the proto
gate). If the review CANNOT reach green — a load-bearing unknown, an unbuilt dependency, an unaccepted bet,
or it stops converging — the run stops as `BLOCKED` and hands to the human. It never ships a red PRD forward
and never loops forever.

You do not re-implement `/saki-builder:prd`, `/saki-builder:prd-review`, `/saki-builder:proto`, or `/saki-builder:build` — you **invoke** them (Skill
tool) and thread their outputs. Your job is orchestration, the state+metrics file, and the two gates.

---

## Input & slug

Usage:
- `/saki-builder:pipeline <feature intent>` — start fresh from an intent (runs `/saki-builder:prd` first).
- `/saki-builder:pipeline <prd-file.md>` — start from an existing PRD (skips `/saki-builder:prd`).
- `/saki-builder:pipeline --approve-prd <slug>` — **resume past the PRD-approval gate** into `/saki-builder:proto`
  (the user has approved the spec). Only honored once the review reached `SHIP · READY`.
- `/saki-builder:pipeline --approve-proto <slug>` — **resume past the proto gate** into `/saki-builder:build` (the user has
  approved). This is the ONLY way the build starts.
- `/saki-builder:pipeline --status <slug>` — print the metrics dashboard for an in-flight or finished run.

Derive `<slug>` the same way `/saki-builder:prd` does: `slugify(feature)`. When starting from a PRD file,
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
  "phase": "prd|review|awaiting-prd-approval|proto|awaiting-approval|build|done|blocked",
  "started_at": 1730000000,
  "human_gates": 0,
  "stages": {
    "prd":    { "status": "pending|in-progress|done", "started": 0, "ended": 0,
                "slices": 0, "criteria": 0, "approved": false },
    "review": { "status": "pending|in-progress|done", "started": 0, "ended": 0,
                "verdict": "SHIP|REVISE|DISCOVERY-FIRST", "readiness": "READY|NOT READY",
                "phase1": "PASSED|FAILED", "rounds": 0, "blockers_fixed": 0 },
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
- `awaiting-prd-approval` → the PRD is green (`SHIP · READY`), waiting for the human to approve the
  spec → the Stop gate **releases**. Set `phase:"awaiting-prd-approval"` and `human_gates += 1` here.
- `awaiting-approval` → proto rendered, waiting for the human → the Stop gate **releases** (the
  human's turn). Set `stages.proto.status:"awaiting-approval"` and `human_gates += 1` here.
- `build` → `/saki-builder:build` owns survival now (its own `build-completion-gate.sh` Stop hook) → the
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
| `awaiting-prd-approval` | If invoked **without** `--approve-prd` → re-show the PRD gate (still waiting). If invoked **with** `--approve-prd <slug>` → write the approval flag into the PRD, go to Phase 3 (proto). |
| `awaiting-approval` | If invoked **without** `--approve-proto` → re-show the gate (still waiting). If invoked **with** `--approve-proto <slug>` → record approval, go to Phase 4 (build). |
| `build` | Hand to `/saki-builder:build` (it resumes itself via its own state manifest). |
| `done` / `blocked` | Print the dashboard; nothing to do. |

`--approve-prd <slug>` is ONLY honored when `phase == awaiting-prd-approval`; `--approve-proto <slug>`
ONLY when `phase == awaiting-approval`. If the relevant stage isn't at its gate yet, say so and continue
the current stage — never skip a gate.

---

## Phase 1 — `/saki-builder:prd`  (skip if a PRD file was passed)

Init the state file (`phase:"prd"`, stamp `started_at` and `stages.prd.started`). Invoke the `prd`
skill with the intent. When it finishes:
- Record `prd = tasks/prd-<slug>.md`, `stages.prd.slices` = count of §8 Vertical Slices,
  `stages.prd.criteria` = total §9 Acceptance Criteria, `stages.prd.status:"done"`, `ended`.
- Set `phase:"review"`.

`/saki-builder:prd`'s Step 0.5 shape phase runs **autonomously** under the pipeline — it takes its
autonomous fallback (auto-selects the recommended shape, derives appetite from the intent's scope,
states the defaults) and adds **no** human gate. The single human gate stays at proto. (To shape a
feature interactively, run `/saki-builder:prd <intent>` first, then hand the PRD file to the pipeline.)

Do **not** pause for approval — the PRD is reviewed in Phase 2.

---

## Phase 2 — `/saki-builder:prd-review`  (loop until green = SHIP · READY)

Set `phase:"review"`, `stages.review.started`. Invoke the `prd-review` skill on the PRD. It emits
`Phase 1 (Structural): PASSED/FAILED`, `Verdict: SHIP | REVISE | DISCOVERY-FIRST`, and
`Readiness: READY | NOT READY`. **Green = `Verdict: SHIP` AND `Readiness: READY`** — both axes. A
`SHIP · NOT READY` PRD is sound but not buildable-now (an unbuilt dep, a slice-1-blocking open Q, an
unaccepted bet); it is NOT green and does NOT advance.

Loop (autonomous — you are the author here, fix the PRD yourself). Record `verdict` + `readiness` each round:
- **Phase 1 FAILED, or Verdict REVISE, or Readiness NOT READY on a FIXABLE blocker** → apply the review's
  prescribed fixes to the PRD (rewrite vague criteria, add the prescribed failure/edge criteria, fix orphan
  slices, add kill criteria, resolve a §12 open Q, close a fixable readiness blocker), bump
  `stages.review.rounds`, add fixes to `blockers_fixed`, and re-run `prd-review`. Cap at **3 rounds**.
- **Escape to the human as BLOCKED** — do NOT loop forever, do NOT fabricate grounding — when the review
  can't be authored to green:
  - **Verdict DISCOVERY-FIRST** (a load-bearing unknown needs discovery), OR
  - **Readiness NOT READY on a STRUCTURAL blocker** you can't author away — an unbuilt / `TBD` §14
    dependency, or an unaccepted bet / unresolved DISCOVERY-RISK, OR
  - **Non-convergence** — round-2 carries the same blocker volume/level as round-1, or the 3-round cap is
    hit still not green (see `patterns.md` — score-trajectory convergence signal; recut, don't loop again).

  Record it, set `phase:"blocked"`, `stages.build.status:"blocked"`, emit
  `PIPELINE_BLOCKED: <slug> — <DISCOVERY-FIRST | readiness: blocker>: <reason>`, and end. A human decides.
- **Green — Verdict SHIP AND Readiness READY** → record `verdict:"SHIP"`, `readiness:"READY"`,
  `stages.review.status:"done"`, `ended`. Set `phase:"awaiting-prd-approval"` and go to **Phase 2.5**
  (the PRD approval gate). Never jump straight to proto — the human approves the spec first.

---

## Phase 2.5 — ⛔ PRD APPROVAL GATE ⛔  (first human gate — only reached on a green PRD)

The review is green (`SHIP · READY`). Before any proto/design work, the human approves the spec. This is a
*resumable pause*, exactly like the proto gate — never a confirmation prompt.

1. Ensure `phase:"awaiting-prd-approval"`, `human_gates += 1`, and the state file is written.
2. **Emit the gate sentinel on its own line and END THE TURN:**

```
PIPELINE_PRD_GATE: {"slug":"<slug>","prd":"tasks/prd-<slug>.md","verdict":"SHIP","readiness":"READY","rounds":N,"blockers_fixed":B}
```

Then print the human-readable handoff:

```
⛔ PRD APPROVAL GATE — proto/design will NOT start until you approve the spec.

PRD ready & green: tasks/prd-<slug>.md   (review SHIP · READY · R rounds · B blockers fixed)
Review record:     tasks/prd-<slug>-review.md
Read the spec, then:
  • Approve  →  /saki-builder:pipeline --approve-prd <slug>      (proceeds to /saki-builder:proto)
  • Revise   →  tell me what to change; I fix the PRD, re-run the review to green, and re-gate
```

**Do not proceed to Phase 3 until the user runs `--approve-prd`.** On that resume:
- Write the approval flag into the PRD header: advance `**Status:** … Approved` and add
  `<!-- prd-approved: <@approver | pipeline> · <YYYY-MM-DD> -->` below the machine-readable header.
- Set `stages.prd.approved:true`, `phase:"proto"`, then run Phase 3.

(The `pipeline-completion-gate.sh` Stop hook ALLOWS the stop at `phase:"awaiting-prd-approval"` — ending the
turn here is correct and expected, same as the proto gate.)

---

## Phase 3 — `/saki-builder:proto`  →  ⛔ PROTO APPROVAL GATE ⛔

Set `phase:"proto"`, `stages.proto.started`. Invoke the `proto` skill on the PRD
(`/saki-builder:proto tasks/prd-<slug>.md`). `/saki-builder:proto` renders the full journey gallery and has its own internal
checkpoints (Step 2.5 component specs, Step 7 approval). **Honor them** — they ARE the human gate;
never auto-approve them the way `/saki-builder:build` auto-approves a plan.

`/saki-builder:proto` GATE 2 needs a real design system. If `/saki-builder:proto` stops with **NO DESIGN SYSTEM FOUND**, do
not fabricate one: record `stages.proto.status:"blocked"`, set `phase:"blocked"`, emit
`PIPELINE_BLOCKED: <slug> — no design system for /saki-builder:proto (scaffold one, then resume)`, and end.

When `/saki-builder:proto` has produced the gallery (`tasks/proto-<slug>/preview.html`) and reached its Step 7
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
  • Approve  →  /saki-builder:pipeline --approve-proto <slug>      (proceeds to autonomous /saki-builder:build)
  • Revise   →  tell me what to change; I re-render proto and re-gate
```

**Do not proceed to Phase 4 under any circumstance until the user runs `--approve-proto`.** This is
the one non-negotiable human gate. (The `pipeline-completion-gate.sh` Stop hook is configured to
ALLOW the stop at `phase:"awaiting-approval"`, so ending the turn here is correct and expected.)

---

## Phase 4 — `/saki-builder:build`  (only after `--approve-proto`)

Entered ONLY via `/saki-builder:pipeline --approve-proto <slug>` when `phase == awaiting-approval`. First:
- Record `stages.proto.approved:true`, `stages.proto.status:"done"`.
- Set `phase:"build"`, `stages.build.started`, `stages.build.slices_total` = `stages.prd.slices`.

Then invoke the `build` skill on the PRD (`/saki-builder:build tasks/prd-<slug>.md`). `/saki-builder:build` is fully
autonomous and survives to completion on its own (`build-completion-gate.sh` Stop hook + its own
`.build-<slug>-state.json`). It will **reuse the approved proto** (it reads
`tasks/proto-<slug>-notes.md` and promotes those components — see `/saki-builder:build`'s "reuse a /saki-builder:proto
preview"). Let it run to `PRD_BUILD_COMPLETE`.

While `/saki-builder:build` runs, mirror its progress into the pipeline state file at each slice boundary
(`stages.build.slices_done`, `qa`, `reviewer`, `commits`, any `blocked`). If `/saki-builder:build`'s Stop gate
re-drove it after an early stop, increment `autonomy.stop_gate_recoveries`. If `/saki-builder:build`
auto-resolved an open-question fork (`AUTO-RESOLVED:` line), increment `autonomy.auto_resolved_forks`.

On `/saki-builder:build` completion: record `stages.build.e2e`, `stages.build.status:"done"`, `ended`. Set
`phase:"done"`. Go to Phase 5.

If `/saki-builder:build` reports `NEEDS_DECISION:` (a `[human]` fork) or `BLOCKED:` — surface it verbatim and end
the turn; that is `/saki-builder:build`'s own resumable pause, not a pipeline failure.

---

## Phase 5 — Metrics dashboard

When `phase:"done"` (or on `--status`), compute durations from the timestamps and print:

```
═══════════════════════════════════════════════════════════════
PIPELINE COMPLETE — <slug>
═══════════════════════════════════════════════════════════════
Stage      Status   Duration   Key result
  /saki-builder:prd       ✓       Xm Ys     N slices · C acceptance criteria · APPROVED
  /review    ✓       Xm Ys     verdict SHIP · READY · R rounds · B blockers fixed
  /saki-builder:proto     ✓       Xm Ys     S screens · T states · K components added · APPROVED
  /saki-builder:build     ✓       Xm Ys     N/N slices · qa pass · reviewer clean · e2e <result>
  ─────────────────────────────────────────────────────────────
  TOTAL              Xm Ys

Quality gates:   prd-review SHIP·READY ✓ · /saki-builder:qa N/N ✓ · /saki-builder:reviewer clean ✓ · e2e <result> · sonar <if run>
Autonomy:        human gates: 2 (prd, proto)  ·  stop-gate recoveries: X  ·  auto-resolved forks: Y
Scope:           N slices · C criteria · S proto screens/T states · K components · M commits · Z blocked
═══════════════════════════════════════════════════════════════
PIPELINE_COMPLETE
```

`PIPELINE_COMPLETE` (own line) is the terminal sentinel — print it only when `phase:"done"`.

---

## Survival & rules

- **Run to completion.** Do not hand control back mid-stage. The front half is kept alive by the
  `pipeline-completion-gate.sh` Stop hook (it blocks an early stop while `phase` ∈ {prd, review,
  proto} and not at a gate). The build half is kept alive by `build-completion-gate.sh`.
  The two never fight: the pipeline gate releases the moment `phase` becomes `awaiting-prd-approval`,
  `awaiting-approval`, or `build`.
- **Two gates, both sacred.** PRD approval (only reachable on a green `SHIP · READY` PRD) and proto
  approval. Never auto-approve either: proto never starts without `--approve-prd`, and `/saki-builder:build`
  never starts without `--approve-proto`.
- **No confirmation prompts elsewhere.** PRD fixes, the review loop, and the build are autonomous. The
  only stops are: the two approval gates; missing input (no intent and no PRD); a review that can't reach
  green (`DISCOVERY-FIRST`, an unbuilt dep / unaccepted bet, or non-convergence — reported `BLOCKED`);
  `NO DESIGN SYSTEM`; a `[human]` fork inside `/saki-builder:build`; or a genuinely-blocked slice.
- **Single source of truth for behavior.** Invoke `prd` / `prd-review` / `proto` / `build`; do not
  re-implement them. The PRD is the source of scope; the proto is the source of look; success =
  every slice green + e2e.
- **Always persist state before ending a turn** so any resume (`--approve-proto`, a context clear,
  or the Stop gate re-driving you) lands on the right phase.
