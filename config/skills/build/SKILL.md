---
name: build
model_requirement: frontier
description: Autonomously execute a finished PRD (PRD-track) OR a single plan-track item (Improvement/Bug) end-to-end. PRD mode reads the PRD's vertical slices and runs /saki-builder:rplan → (/saki-builder:rplan-review if needed) → /saki-builder:approved → /saki-builder:qa → /saki-builder:reviewer → (security audit on security-relevant slices) on each slice; PLAN mode runs the same chain ONCE over one plan-track item — the hands-off equivalent of running /saki-builder:rplan → /saki-builder:rplan-review → /saki-builder:approved → /saki-builder:qa → /saki-builder:reviewer → /saki-builder:wrap by hand. Always runs the e2e suite and converges to clean before declaring done. No confirmation prompts. Usage — /saki-builder:build <E<n>|F<n>|prd-file.md | I<n>|B<n>|plan-file.md>.
---

# Autonomous PRD Executor

You are operating in **TRUST MODE** — fully autonomous execution. The PRD has already
been written, reviewed (via `/saki-builder:prd` → `/saki-builder:prd-review`), and **Locked** (via
`/saki-builder:proto`, Gate 1.5), and the user has pre-authorized this flow. Your single goal: **ship every
vertical slice in the PRD, fully tested, with no outstanding issues.** Do not stop until that is true.

This command is the one-shot equivalent of running, by hand, for each slice:

```
/saki-builder:rplan  →  /saki-builder:rplan-review (only if needed)  →  /saki-builder:approved  →  /saki-builder:qa  →  /saki-builder:reviewer  →  security audit (security-relevant slices only)
```

…then verifying the whole thing end-to-end and converging to clean (`/saki-builder:wrap --heal`).

---

## CRITICAL: No Confirmation Prompts — Ever

You are in TRUST MODE. This means:
- **NEVER ask "Do you want to proceed?"** or any variation. Make the call, log it, continue.
- **Do NOT wait for plan approval.** `/saki-builder:rplan` normally stops for a human; here you
  auto-approve any plan whose **Blocking Set is empty** and proceed to `/saki-builder:approved` yourself.
- Agent-based sub-skills that are part of this flow (`/saki-builder:rplan-review`, `/saki-builder:reviewer`,
  and the `security-review` audit) are permitted — they are how slices get reviewed. Just never pause
  for user confirmation around them.
- The **only** hard stops are: a missing/unreadable PRD file (Gate 1), an ABSOLUTE NO-GO (below),
  or a slice that cannot be made green after repeated honest attempts. An unresolved `before slice
  N` open question is **not** a stop — `/saki-builder:build` auto-resolves it (Per-Slice Loop, step 0) and
  proceeds. **Exception:** a fork the PRD author tagged `[human]` is a deliberate, human-only
  decision — pause for it via the `NEEDS_DECISION:` gate (step 0a). That is a *resumable pause*, not
  a confirmation prompt: you emit the gate and end the turn; the studio collects the answer and
  re-drives you. It is the one sanctioned way to defer a decision to the operator.

---

## Run to completion — never yield early

A skill cannot switch on Claude Code's built-in `/goal` engine (only the user can type
`/goal`). So this skill enforces its **own** persistence — behave as if a goal were set:

- **Completion signal.** You are done ONLY when every slice in the PRD is green — **or, in PLAN mode, the
  single plan-track item is green** — (`/saki-builder:qa` passes, `/saki-builder:reviewer` is clean, **and**
  any security audit a security-relevant slice/item required is clean), the e2e suite passes, **and** FINAL
  GATE 2 (`/saki-builder:wrap --heal`) has converged the tree to a clean `main`. At that point, and only
  then, print `PRD_BUILD_COMPLETE` (PRD mode) / `PLAN_BUILD_COMPLETE` (PLAN mode). Never print it early.
- **Do not hand control back** until you either print the completion sentinel or hit a real
  hard stop (missing PRD / unresolvable id, NO-GO, honestly-blocked slice/item). If a turn runs long, keep
  going — start the next slice rather than stopping to ask "should I continue?"
- **Progress scratchpad (human log).** Maintain `tasks/.build-<prd-slug>-progress.md` with the
  slice checklist (done / in-progress / remaining), updated after every slice. If context is
  cleared mid-build, re-read it on start and **skip already-green slices** to resume.
- **State manifest (machine resume state).** Also maintain `tasks/.build-<prd-slug>-state.json` —
  the studio reads + verifies this to resume an interrupted build at the exact step. Update it
  **after every step** (rplan / approved / qa / reviewer), not just every slice:
  ```json
  { "prd": "<path>", "branch": "<branch>", "commitPolicy": "per-step",
    "slices": [ { "n": 1, "title": "…", "status": "not-started|in-progress|done|blocked",
      "steps": { "rplan":    { "status": "done", "artifact": "tasks/<prd-slug>-slice1-plan.md" },
                 "approved": { "status": "done", "commit": "<sha>" },
                 "qa":       { "status": "done" },
                 "reviewer": { "status": "done" },
                 "security": { "status": "done|n/a" } } } ] }
  ```
  Rules: set `artifact` = the slice's plan file when rplan finishes; `commit` = the step's commit
  SHA when approved commits (use `commitPolicy:"none"` if this build does not commit per step — the
  studio then uses slice-level resume). The `security` step is `"n/a"` on a slice with no security
  surface; set `slices[n].status:"done"` only at step 6 (qa green + reviewer clean + the security
  audit clean-or-`n/a`). **Best-effort + safe:** a missing/partial manifest must degrade to a normal full
  run — never block on it. The studio trusts a step only when its artifact verifies (plan file
  exists / commit resolves), so an inaccurate manifest costs at worst a redo, never a skipped step.
  **PLAN mode** reuses this exact shape with a `"mode":"plan"` discriminator, an `"item":"<id>"` field,
  and a **single-element** `slices` array (`n:1`, `title` = the item/plan title) whose `steps` add
  `rplan` (the plan-creation step, done when the plan file exists). The resume logic (GATE 2) is unchanged —
  a 1-element array is just the degenerate case of the slice loop. In PLAN mode `<slug>` (in the
  `tasks/.build-<slug>-{state.json,progress.md}` names) derives from the item id lowercased (e.g. `b7`) for an
  id launch, or the plan filename minus `-plan.md` for a plan-file launch — there is no `<prd-slug>`.
- **Loop guard.** If the same slice fails the same way ~3 times, stop hammering it: write
  the reason to the scratchpad, output `BLOCKED: slice <N> — <reason>`, then move on to any
  independent remaining slices before reporting.

### For guaranteed cross-turn autonomy, launch under /goal

Because a skill can't self-activate `/goal`, the most autonomous way to start is for the
**user** to type the wrapper (the engine is `/goal`, the orchestration is `/saki-builder:build`):

```
/goal /saki-builder:build tasks/prd-<feature>.md — done when every slice passes /saki-builder:qa and /saki-builder:reviewer and the e2e suite is green
```

Plain `/saki-builder:build tasks/prd-<feature>.md` still runs and self-iterates per the rules above; the
`/goal` wrapper just makes the cross-turn persistence bulletproof.

---

## Input

Usage: `/saki-builder:build <E<n>|F<n> | prd-file.md | I<n>|B<n> | plan-file.md>` (filler words are fine, e.g. `/saki-builder:build start build prd-wave-2.md`).

`/saki-builder:build` runs in one of **two modes**, decided by the argument (see *Mode detection* below):
**PRD mode** (Epic/Feature — a PRD with vertical slices, today's behavior) or **PLAN mode** (Improvement/Bug —
a single plan-track item or plan file, new). Resolve the argument by its shape:

**PRD-track item id (`E<n>` or `F<n>`) — the disciplined path:** if the argument is an item id, read
`tasks/roadmap.md`, find `### <id>`, and resolve its `**Child PRD:**` link to `tasks/prd-<slug>.md`. If
`<id>` has no Child PRD yet (its value is `—`), **STOP**: `<id> has no PRD yet — run /saki-builder:pickup <id> first`.
Remember the `<id>` so the Completion Output can flip its roadmap status to `Shipped`.

> **Note — PRD-path launches still flip the item.** The studio board (and a hand-typed
> `/saki-builder:build tasks/prd-<slug>.md`) invokes this skill with the **PRD path**, not `<id>`. Do NOT
> assume "no id argument ⇒ no item to flip": the Completion Output reverse-maps the built PRD back to
> its item via the roadmap's `**Child PRD:**` field, so the `Shipped` flip fires on either launch path.

Otherwise extract the PRD path from the arguments: take the token ending in `.md` (or matching
`prd-*`). Locate the file by checking, in order: `tasks/<name>`, `./<name>`, the path as
given. The `/saki-builder:prd` skill saves to `tasks/prd-<feature>.md`, so `tasks/` is the common case.

**Plan-track item id (`I<n>` or `B<n>`) — the PLAN-mode path:** if the argument is a plan-track id, read
`tasks/roadmap.md`, find `### <id>`, and **confirm `**Track:** Plan`** (the roadmap Track field is the
authority; an `E<n>`/`F<n>` id belongs to PRD mode above). Resolve its plan file, in order:
(1) its `**Child plan:**` link (written by `/saki-builder:rplan` Step 0.6 when it's set — the clean primary);
(2) fallback — grep `tasks/*-plan.md` headers for `**Item:** <id>` (the stamp `/saki-builder:rplan` always
writes); if more than one file matches, take the **newest** (most-recently-modified). If **neither** resolves
(the item has no plan yet, `Child plan: —` and no stamped plan — including a legacy plan predating the
`**Item:**` stamp, for which the fix is to pass the plan file path directly), do **NOT**
stop — **PLAN mode runs `/saki-builder:rplan` itself** to create the plan (see The Single-Plan Loop, step
P1). This differs from the PRD `no-PRD` stop on purpose: the roadmap **item** (created by `/saki-builder:add`)
is the pre-existing scope unit here — the analogue of the PRD — and plan-track has no human lock gate, so a
missing plan is something `/saki-builder:build` *creates*, exactly as PRD mode runs `/saki-builder:rplan`
per-slice. Remember the `<id>` so Completion Output flips its roadmap status to `Shipped`.

**Plan file path (`*-plan.md`) — the PLAN-mode path:** a plan file passed directly resolves to itself; skip
`/saki-builder:rplan` (the plan already exists — resume from review/approved). If the plan header carries
`**Item:** <id>`, remember it for the `Shipped` flip; if not, it's a standalone plan (no roadmap flip).

### Mode detection

Set an internal `MODE ∈ {PRD, PLAN}` from the argument, then follow the rest of this skill accordingly —
**PRD mode is unchanged; PLAN mode diverges only at the points that say so.**

| Argument | MODE | Authority |
|----------|------|-----------|
| `E<n>` / `F<n>` id | **PRD** | id prefix + roadmap `**Track:** PRD` |
| `prd-*.md`, or a `.md` containing `## Vertical Slices` / `<!-- prd-locked` | **PRD** | file shape |
| `I<n>` / `B<n>` id | **PLAN** | id prefix + roadmap `**Track:** Plan` (Track field wins if they ever disagree) |
| `*-plan.md`, or a `.md` containing an `Evidence Ledger` / rplan Steps table | **PLAN** | file shape |
| id not found on `tasks/roadmap.md` | — | **STOP**: `<id> not found on roadmap — /saki-builder:add it, or run /saki-builder:rplan on a plan file` |

**Precedence when a file matches more than one row** (e.g. `prd-foo-plan.md`, or a `.md` carrying both a
`## Vertical Slices` heading and an `Evidence Ledger`): the **content** shape wins over the **filename**, and
the **plan** shape wins the tie — an `Evidence Ledger` / rplan Steps table ⇒ **PLAN**, regardless of filename.
A `.md` matching **neither** shape (no slices, no Evidence Ledger) is ambiguous — **STOP** and ask
`is <file> a PRD or a plan? (couldn't infer)` rather than defaulting to PRD and hard-stopping later at the lock gate.

**PLAN mode changes exactly these things vs PRD mode, nothing else:** it **skips GATE 1.5** (PRD-lock — a
plan-track item is never locked), runs **The Single-Plan Loop** instead of The Per-Slice Loop (one unit, no
slice iteration, no open-question/fork gate, no step-3.5 proto-fidelity gate), and uses the **PLAN-mode
Completion Output**. GATE 0 (branch safety), GATE 2 (resume), the FINAL GATE (e2e), and FINAL GATE 2
(`/saki-builder:wrap --heal`) run **identically** in both modes.

---

## GATE 1: Load the PRD / plan (hard stop if missing)

> **PLAN mode:** skip the PRD-slice extraction below. Load the resolved plan file (if it exists) and
> extract its **Success Criteria** (→ the `/saki-builder:qa` targets) and the files/screens it touches
> (its Frontend checklist + any `tasks/<slug>-flow.md`). If the item has **no plan yet**, there is nothing
> to load here — The Single-Plan Loop step P1 creates it via `/saki-builder:rplan`. Then go straight to
> GATE 0 → GATE 2 → **The Single-Plan Loop** (GATE 1.5 does not apply). The rest of this gate is PRD mode.

Read the PRD file. If it cannot be found or read, **STOP** and output:
```
HARD STOP — PRD NOT FOUND
Looked for: tasks/<name>, ./<name>, <name>
Pass a valid PRD path: /saki-builder:build <prd-file.md>
```
Do NOT invent a PRD or ask the user to paste one — this is the one input the command requires.

From the PRD, extract (match sections by **heading title**, not number — PRD section numbers shift
as sections are added):
- **Vertical Slices** — the ordered, numbered list. Slices are forward-dependency-only, so
  **PRD order is execution order**. This is your work list.
- **Acceptance Criteria per Slice** — these become each slice's `/saki-builder:qa` success criteria.
- **Business Rules & Invariants** (the *Business Rules & Invariants* section, if present) — the
  domain rules every slice must uphold. If it reads "none beyond CRUD", skip the rule checks in the
  loop below. Otherwise: each rule links to an acceptance criterion, and a criterion may cite
  `enforces rule N.x` — use that linkage to find the rules in scope for a given slice. Rules tagged
  `🔒 INVARIANT` (money / stock / tenant isolation) must hold **under concurrency and partial
  failure** — a stronger bar than a happy-path criterion.
- **Non-Goals** — treat as hard out-of-scope. Never expand a slice past them.
- **Open Questions** (the *Rabbit Holes & Open Questions* section) — each question with a
  `before slice N` deadline, and whether it carries a `✅ RESOLVED` marker. These are architectural
  forks that gate specific slices (see the Per-Slice Loop, step 0). Ignore `before launch | before
  beta | before GA` deadlines — those are rollout decisions, outside `/saki-builder:build`'s scope.

Print the extracted slice list (numbered titles) and any **unresolved** `before slice N` gates so
the run is auditable — these will be **auto-resolved** in the loop (step 0), not blocked on — then
begin.

### Reuse the `/saki-builder:proto` preview when one exists (verified at step 3.5)

If `tasks/proto-<slug>/notes.md` exists (the user ran `/saki-builder:proto` first), read it. It records the
**real design-system components + token references** chosen per screen, already validated visually.
When implementing a user-facing slice, **promote** those presentational components (mock data →
real data + state + tests + backend wiring) — the look is already approved. **This is not discretionary
when the notes exist:** promoting the named components (rather than re-picking UI from scratch) is
**required and verified by the step-3.5 Proto-fidelity gate** (the inverse of proto's 5d) — a shipped
slice that re-invents a promoted component is a blocking finding. As part of the slice that promotes a
`proto-preview/<slice>` preview, **delete that throwaway preview route/story and revert any
`/proto-preview` middleware bypass** (neither may ship). If **no** proto notes exist, build the UI
normally (step 3.5 skips).

---

## GATE 1.5: Lock check — requirements must be frozen (hard stop if unlocked)

> **PLAN mode: this gate does not apply — SKIP it** and log `LOCK: n/a (plan-track)`. Plan-track items are
> never locked (there is no `/saki-builder:proto` freeze for Improvement/Bug — that's the whole reason
> plan-track skips proto). Proceed to GATE 0 → GATE 2 → The Single-Plan Loop. The rest of this gate is PRD mode.

`/saki-builder:build` runs only against a **Locked** PRD — the requirements are frozen before any slice
reaches `/saki-builder:rplan`. The approval is written by `/saki-builder:proto` into **two** artifacts —
the PRD's `<!-- prd-locked: … -->` marker and the gallery's `tasks/proto-<slug>/.prd-locked`. Either one
proves it (the gallery marker is the one that also exists when proto ran before the PRD did):

```bash
# LOCKED if the approval is provable from EITHER artifact. The PRD marker stays the primary for every
# PRD-first run; the gallery marker is the one that also exists when proto ran before the PRD existed.
PRD="<prd-path>"; ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SLUG="$(basename "$PRD" .md | sed 's/^prd-//')"
MARK="$ROOT/tasks/proto-$SLUG/.prd-locked"
if grep -qE '^<!-- prd-locked:' "$PRD" 2>/dev/null; then
  echo "LOCKED (prd marker)"
# The gallery marker must name the PRD it froze — otherwise any file deriving the same slug
# (build accepts a PRD by content shape, not filename) would inherit another PRD's approval.
elif [ -f "$MARK" ] && grep -qF "prd:$(basename "$PRD")" "$MARK"; then
  echo "LOCKED (gallery marker)"
else
  echo UNLOCKED
fi
```

If **neither** marker is present, **STOP** — do not plan, do not touch code:
```
HARD STOP — PRD NOT LOCKED
Requirements aren't frozen — no approval found in the PRD (<!-- prd-locked: … -->) or in the
gallery (tasks/proto-<slug>/.prd-locked).
/saki-builder:build won't hand unfrozen scope to /saki-builder:rplan.
Lock it first:  /saki-builder:proto <E<n>|F<n> | prd-file.md>
  — designs + approves the UI, then writes tasks/proto-<slug>/.prd-locked (always) and
    Status: Locked + <!-- prd-locked --> in the PRD (a no-UI PRD is frozen there too).
Then re-run /saki-builder:build.
```

This is the gate that enforces **"lock Product Requirement before hand off to rplan."** It is **not** a
confirmation prompt (TRUST MODE holds) — it is a *precondition*: the lock is written by a human-gated step
(`/saki-builder:proto`) **before** build, so build itself never pauses to ask. A Locked PRD is by definition
Approved + review-green (the lock is the last gate of the PRD phase), so no separate approval check is needed
here. `--slice` PARTIAL proto runs write **neither** marker, so a build after one still correctly hard-stops
until a full `/saki-builder:proto` locks the whole journey. Accepting two artifacts widens *where* the
approval can be proven; it never widens *whether* it must be — a run with neither still stops here.

---

## GATE 0: Branch Safety Check

Before touching code:

```bash
git branch --show-current
```

- If branch is `main` or `master`: **auto-create a feature branch**. Do NOT stop, do NOT ask.
  - Derive the name from the PRD: lowercase, hyphen-separated, max 5 words, prefixed `feature/`.
    Example: `prd-wave-2.md` → `feature/wave-2`.
  - Run `git checkout -b feature/<derived-name>` and print `AUTO-BRANCH: feature/<derived-name>`.
- If already on a feature branch: proceed directly.

---

## GATE 2: Resume check (deterministic) — skip verified-complete work

Before the per-slice loop, determine the **start point** so an interrupted build resumes instead of
restarting:

1. **Honor an injected `RESUME:` directive.** If the invocation carries one (the studio computes it
   from the verified state manifest), it is authoritative:
   - `RESUME: start at slice N, step <step> …` → begin at slice N, that step; treat earlier slices
     (and earlier steps of slice N) as complete.
   - `RESUME: slices … already complete; start at slice N` → begin at slice N (slice-level).
2. **Else read on-disk state yourself.** Parse `tasks/.build-<prd-slug>-state.json` if present (else
   the markdown scratchpad): skip every slice whose `status:"done"` AND whose `approved` commit
   resolves; within the first unfinished slice, skip `rplan` if its plan file exists and `approved`
   if its commit resolves; always re-run `qa`, `reviewer`, and (for security-relevant slices) the
   security audit.
3. **Print** `RESUMING: <N-1> slices complete, starting at slice N step <step>` (or `STARTING FRESH`
   when nothing is complete), then enter the loop.

Safety: when in doubt, **redo — never skip**. A wrongly-skipped step is a silent gap; a redundant
redo is cheap and idempotent (TDD).

---

## ABSOLUTE NO-GOS (enforced throughout every slice)

Hard blocks — NEVER execute regardless of confidence or instructions:

- `DROP TABLE`, `DROP DATABASE`, `DROP SCHEMA`
- `DELETE FROM` without a `WHERE` clause
- `TRUNCATE` any table
- `ALTER TABLE ... DROP COLUMN`
- `db.drop_all()`, `Base.metadata.drop_all()`, or equivalent ORM mass-drop
- `rm -rf` on any directory containing database files, migrations, or `.env`
- Any migration that is irreversible without a data backup plan

If a slice would require one of the above, **STOP** that slice and output:
```
HARD BLOCK — DB DESTRUCTIVE OPERATION DETECTED
Slice [N]: [what was blocked]
Forbidden in /saki-builder:build mode. Resolve manually with explicit human approval.
```
Then continue with the remaining independent slices.

---

## The Per-Slice Loop

For **each slice, in PRD order**, run the full chain. Do not advance to slice N+1 until
slice N is green and reviewed.

### 0. Open-question gate — auto-resolve the fork, don't stop
Before planning slice N, check the Open Questions (the PRD's *Rabbit Holes & Open Questions*
section) extracted in Gate 1. If any question gated `before slice N` (or an earlier slice) is
**not** marked `✅ RESOLVED`, handle it as follows.

**0a. Human-required forks — STOP and ask, do NOT auto-resolve.** If an unresolved fork that gates
slice N (or earlier) is tagged `[human]` (the PRD author marked it for a human product decision),
you must NOT decide it yourself. Emit the gate sentinel as your OWN final line and **end the turn**:

```
NEEDS_DECISION: {"slice":N,"kind":"fork","question":"<the question, one line>","options":["<opt A>","<opt B>",…]}
```

- One compact JSON object on a single line, prefixed exactly `NEEDS_DECISION: ` at line-start (the
  studio parses it; a malformed or mid-sentence mention is ignored, so never narrate it loosely).
- Always include `options` (the real alternatives the PRD states); if the fork is genuinely
  open-ended, pass `"options":[]` and the studio shows a free-text field.
- Stop at the **first** such fork and end the turn — do not batch or proceed past it. The studio
  surfaces the picker, writes the operator's choice into the PRD as `✅ RESOLVED — <decision>`, and
  re-drives `/saki-builder:build`, which then reads it like any resolved question. This is a pause, not a block:
  no `BLOCKED:`, no give-up — the build resumes the moment the human answers.

**0b. Everything else — resolve it yourself and proceed** (the default; untagged forks). The goal is
to ship the expectation, so a missing decision is something `/saki-builder:build` *makes*, not something it waits
on. Resolve it with the first rule that applies:

1. **Take the PRD's lean.** If the entry states a recommendation, default, or "leaning X" — use it.
2. **Serve the slice's criteria.** Else pick the option that best satisfies *this slice's*
   acceptance criteria + its JTBD / outcomes.
3. **YAGNI + reversibility.** Else pick the simplest, most reversible option — the one cheapest to
   change later if it turns out wrong. Reversibility is the safety net that replaces the old hard
   stop: a wrong-but-reversible call costs a refactor, not a baked-in architecture.
4. **Never cross a guardrail.** A resolution may never violate a **Non-Goal** or a `🔒 INVARIANT`,
   and may never require an **ABSOLUTE NO-GO**. If the *only* way to satisfy the slice is one of
   those, that — not the open question — is the genuine block: output
   `BLOCKED: slice N — <reason>`, then move on to independent later slices.

Then **record the decision** so it is auditable and a human can override it later:
- Annotate the PRD entry in place: prefix it `✅ RESOLVED (auto) — <decision> — <one-line why>`.
- Write it to the progress scratchpad and emit the marker line:
  `AUTO-RESOLVED: slice N — <question> → <decision>`.

Carry the decision into step 1 (`/saki-builder:rplan`) as a stated assumption so the plan and its tests are
built on it.

### 1. `/saki-builder:rplan` — plan the slice
Invoke the `rplan` skill (Skill tool, `skill: rplan`) scoped to **this slice only**: its
description plus its acceptance criteria, **and the Business Rules & Invariants in scope for it**
(the rules its criteria link to, plus any `🔒 INVARIANT` the slice's writes could violate). The
plan must be built to uphold them — call out each in-scope invariant so the implementation and its
tests account for it. **Tell `/saki-builder:rplan` to name the plan `<prd-slug>-slice<N>`** so it writes a
slice-distinct `tasks/<prd-slug>-slice<N>-plan.md` (a multi-slice build keeps several plans in `tasks/`;
newest-wins selection would otherwise let a later step bind to the wrong slice's plan). `/saki-builder:rplan`
will research, build the plan, and populate its Evidence Ledger. Record that exact plan path in the state
manifest's `artifact` and **pass it explicitly to `/saki-builder:rplan-review` (step 2), `/saki-builder:approved` (step 3), and
`/saki-builder:qa` (step 4)**. **Do not wait for approval** — read the resulting plan and its Blocking Set yourself.

### 2. `/saki-builder:rplan-review` — *only if needed*
Run the `rplan-review` skill when any of these hold; otherwise skip straight to step 3:
- `/saki-builder:rplan` leaves any blocking item unresolved (Blocking Set non-empty), **or**
- the slice is HIGH risk (auth, DB migration, deletes, money, security boundary), **or**
- the slice spans >2 modules or has >3 acceptance criteria.

Invoke it **passing this slice's plan path from step 1** so it reviews *this* slice's plan, not the newest
`*-plan.md`. `/saki-builder:rplan-review` hardens the plan (criteria → test commands, domain-expert pass).
After it, re-read the plan.

### 3. `/saki-builder:approved` — implement
**First load the `clean-code` skill** (Skill tool, `skill: clean-code`) so the slice is written to
the SonarQube clean-code standard — the Pre-merge Gate grades the diff (Clean as You Code), so
writing clean now avoids a gate failure later. Then invoke the `approved` skill to implement the
slice under XP discipline (TDD Red→Green→Refactor, commit-per-step, YAGNI) — **pass it this slice's plan path
from step 1** so it implements *this* slice's plan, not the newest `*-plan.md`. You are the approver
here — invoke both without waiting for the user. (Re-load `clean-code` every slice; this keeps it in
context even if a context clear happened between slices.)

### 3.5. Proto-fidelity gate — promote the real components, don't re-invent (user-facing slice + proto handoff only)
**Gate this step:** run it **only when** `tasks/proto-<slug>/notes.md` exists AND this slice ships a
user-facing surface. Otherwise **skip**, log `PROTO-FIDELITY: slice N — skipped (no proto notes | backend slice)`,
and go to step 4.

This is the **inverse of proto's Step 5d provenance check**. Proto proved its *preview* imported the real
components; this proves the *shipped* slice did too — closing the seam where build silently re-picks UI from
scratch and drifts from the approved look (the failure proto's own grounding gate prevents on its side).

Mechanical — for each real component the notes name for this slice's screen(s) (the promoted presentational
components + the design-system components proto codified/used), confirm the slice's **real implementation**
imports it by its recorded path (where the notes give only a name, resolve its design-system path):
```bash
# for each component the notes promote for this slice's screens:
grep -Rl "<recorded-import-path>" <slice's real route/component dir> 2>/dev/null
# empty ⇒ the shipped slice did NOT import proto's component ⇒ it re-invented ⇒ blocking
```
If a component the notes said to **promote** is absent from the shipped slice (its path isn't imported; the
slice hand-rolled its own version), that is a **blocking finding — same bar as a `/saki-builder:reviewer`
correctness block**: fix in place (import/promote the named component), then re-run this gate. Do NOT advance
to step 4 while a promoted component was re-invented. This is blocking-but-**recoverable** (fix + re-run),
never an abort of the whole build.

**Legitimate deviation (not a block):** proto's approved look was intentionally changed this slice — e.g. the
step-5.5 security reshape, which already re-proto's and updates `tasks/proto-<slug>/notes.md`, so the grep
matches the current components. The notes are the source of truth; a deviation that did NOT update the notes
is drift → reconcile (re-proto the screen, or import the named component). Log one line:
`PROTO-FIDELITY: slice N — <K promoted components verified | re-invented X → fixed>`.

### 4. `/saki-builder:qa` — test against acceptance criteria + in-scope invariants
Invoke the `qa` skill, **passing this slice's plan path from step 1** so it tests *this* slice's criteria
(not the newest `*-plan.md`). It runs **this slice's** acceptance criteria as real tests; every
criterion must pass. **Also verify each in-scope Business Rule** — and for a `🔒 INVARIANT`,
assert it holds under concurrency / partial failure where the stack allows (e.g. a race or
double-fire test), not just the happy path, since a passing acceptance criterion does not prove an
invariant holds. If any criterion or invariant check fails → fix in place and re-run `/saki-builder:qa`. Do not
proceed while red.

### 5. `/saki-builder:reviewer` — fresh-context review
**First confirm the slice actually committed** — `git diff BASE..HEAD` must be non-empty. An empty committed
diff (e.g. `/saki-builder:approved` had nothing committable, or left work uncommitted) means both
`/saki-builder:reviewer` and the step-5.5 security audit would review *nothing* and could report clean — a
false green. On a code-bearing slice an empty diff is a **gate failure**: commit the slice's work (or fix why
`/saki-builder:approved` didn't) and re-run — never accept a clean review of an empty diff.
Invoke the `reviewer` skill on the slice's diff. If it reports **blocking** issues
(correctness, security, data-loss, **or a violated `🔒 INVARIANT`**): fix them, then re-run `/saki-builder:qa`
and `/saki-builder:reviewer` until the review is clean. Non-blocking nits: fix if cheap, otherwise log and move on.

### 5.5. Security audit — *security-relevant slices only*
Gate this step: run it **only when the slice touches a security surface** — auth / session, money /
payment, PII, a new public or external-facing endpoint, file upload, crypto, raw SQL / shell, or any
untrusted external input. For a pure-UI, copy, or internal-refactor slice, **skip** it, log
`SECURITY: slice N — skipped (no security surface)`, and go to step 6. (Skipping keeps the audit off
the ~80% of slices where it is dead weight.)

When it applies, audit the **same pinned committed diff** the reviewer used (`git diff BASE..HEAD`,
never the working tree):
- **Primary** — invoke the global `security-review` skill (Skill tool, `skill: security-review`) on
  that diff. It hunts the classes a generic review under-weights: broken authz / IDOR, missing
  tenant isolation, a missing auth guard on the new route, mass-assignment, hardcoded secrets,
  injection, SSRF.
- **Fallback** (if `security-review` isn't installed in this project) — do NOT hard-stop: run a
  fresh-context Agent pass over the diff using the reviewer's Security checklist, and lean on the
  SonarQube security gate (hotspots + `sonar-dependency-risks` for CVEs) that already runs at the
  Pre-merge Gate before push.

A security **HIGH is blocking** — same bar as a violated `🔒 INVARIANT`. **Auto-resolve it, no human
touch** (TRUST MODE holds for security too — never emit `NEEDS_DECISION` for a finding; that gate is
only for `[human]`-tagged forks). Classify each blocking finding by depth and route it to the
**shallowest** skill that closes it (cheapest fix first, escalate only when the shallow fix can't hold):

1. **Implementation-level** (default — missing auth guard, unvalidated input, string-concat SQL,
   hardcoded secret, missing ownership / tenant check in a handler): fix via `/saki-builder:approved`
   under TDD — add a failing test that *reproduces the hole* first, then close it. Re-enter at step 4.
2. **Design-level** (the flaw is in the plan, not the code — no tenant-isolation model, wrong auth
   boundary, a data model that structurally leaks): a point-fix won't hold — **re-plan the slice from
   step 1 `/saki-builder:rplan`**, carrying the finding in as an explicit requirement/assumption, then
   `/saki-builder:rplan-review` (the slice is now HIGH-risk) → `/saki-builder:approved`.
   **If the fix reshapes the UI** (changes a screen, field, or flow the user sees — e.g. drops a
   leaking field, inserts a step-up-auth / confirm screen), the approved proto for that screen is now
   stale: re-render it autonomously with `/saki-builder:proto --slice=N`, update
   `tasks/proto-<slug>/notes.md`, and annotate the changed requirement in the PRD in place
   (`✅ RESOLVED (auto, security) — <what changed> — <why>`). Do NOT pause for human UI sign-off
   (TRUST MODE) and do NOT unlock the PRD — it stays Locked; you're amending one screen under the same
   auto-decision rule as step 0b. Record it in the Completion Output's auto-resolved block for
   post-hoc human review.
3. **Dependency-CVE**: bump / replace the dependency in-slice; if it can't be resolved in-slice, log
   it — the SonarQube `sonar-dependency-risks` gate at the Pre-merge Gate is the hard backstop before push.

After any route, **re-run the tail** — `/saki-builder:qa` → `/saki-builder:reviewer` → this audit —
and loop until all three are clean. A fix may never cross a **Non-Goal**, a `🔒 INVARIANT`, or an
**ABSOLUTE NO-GO** (the step-0b guardrails still bind); if the only way to close the finding is one of
those, that — not the finding — is the genuine block. MED / LOW: fix if cheap, else log and move on.

**Honest backstop (never fake-green).** If a HIGH survives ~3 same-failure fix rounds (the loop
guard), do NOT weaken the test, suppress the finding, or mark the slice done — output
`BLOCKED: slice N — <security finding>` and move to independent later slices. A security hole is the
one thing that must never be silenced to pass. **Stay terse:** log each route as ONE line —
`SECURITY: slice N — <finding> → <approved|rplan|dep-bump>` — not a narration, and re-run the audit to
*actual* clean before step 6, never assert it.

### 6. Mark done, advance
Log `SLICE [N] ✓ — <title>` with a one-line note (commits, files, test result), then move
to the next slice.

**Loop until issue-free:** a slice is "done" only when `/saki-builder:qa` is fully green, **and**
`/saki-builder:reviewer` has no blocking findings, **and** — if the slice was security-relevant — the
step-5.5 security audit is clean, **and** — if the slice had a `/saki-builder:proto` handoff — the
step-3.5 Proto-fidelity gate passed (promoted components imported, not re-invented). If you cannot get a slice green after repeated honest
attempts, stop and report exactly what's blocking — do not fake completion or weaken tests
to pass.

---

## The Single-Plan Loop (PLAN mode)

**Run this instead of The Per-Slice Loop when `MODE == PLAN`.** A plan-track item is **one unit of work**,
not a slice list — so this is the per-slice chain run **once**, with the slice-specific gates removed. It
invokes the **same** skills (`rplan` / `rplan-review` / `approved` / `qa` / `reviewer` / `security-review`) —
it does not re-implement any of them (the "single source of truth for behavior" rule). What's dropped vs the
Per-Slice Loop: **no** slice iteration, **no** open-question/fork gate (step 0/0a/0b — a plan has no *Rabbit
Holes & Open Questions* section), and **no** step-3.5 proto-fidelity gate (plan-track has no
`/saki-builder:proto` handoff). The ABSOLUTE NO-GOS and the loop guard (~3 same-failure strikes → `BLOCKED:`)
still apply.

### P0. Flip the item In-progress
If launched by an `I<n>`/`B<n>` id (or a plan carrying `**Item:** <id>`) and the item is still `Planned`,
flip it `Planned → In-progress` in `tasks/roadmap.md` (`**Status:**` + `**Updated:**` via `date +%F`) — the
PLAN-mode analogue of what `/saki-builder:pickup` does on the PRD side. Build owns the terminal `Shipped`
flip (P6 / Completion Output), never here.

### P1. `/saki-builder:rplan` — plan the item (only if no plan yet)
If GATE 1 resolved an existing plan file, **skip this step** (resume). Otherwise invoke the `rplan` skill
(Skill tool, `skill: rplan`) seeded from the roadmap item — pass the `<id>` so rplan reads its **What** /
**Repro / Context** and stamps `**Item:** <id>` in the plan header. **Tell rplan the invocation is
build-driven (`/saki-builder:build` owns the resume state)** so it skips its own manual-chain state seed
(rplan Step 7 honors any build-driven invocation, PRD slice or PLAN item). `/saki-builder:rplan` normally
stops for a human; here — TRUST MODE — **auto-approve any
plan whose Blocking Set is empty** and proceed. Record the plan path in the state manifest's `artifact` and
**pass it explicitly to every step below.**

### P1.5. UI-escalation decision (auto-picked)
Read the plan's Frontend checklist + any `tasks/<slug>-flow.md` and classify the visual surface:
- **Non-UI plan** (backend-only — the plan header says so, or no Frontend files touched) → skip all UI
  handling; log `UI: none`. Go to P2.
- **UI plan** → the design-system-reuse check (P5) is **always** on. **Additionally**, if the plan touches
  **>1 user-facing screen OR introduces a new visible state** (a new route/page, or a Gherkin scenario for a
  state the screen didn't render before), mark this run **`UI-ESCALATED`** — a screenshot glance of those
  screen(s) runs after `/saki-builder:approved` (P3.5). Otherwise (single screen, no new state) the reuse
  check alone suffices; log `UI: reuse-check only`.

### P2. `/saki-builder:rplan-review` — only if needed
Same triggers as PRD mode: run the `rplan-review` skill when the plan's Blocking Set is non-empty, **or** the
item is HIGH risk (auth, DB migration, deletes, money, security boundary), **or** it spans >2 modules or has
>3 acceptance criteria. Otherwise skip to P3. Pass this plan's path. Re-read the plan after.

### P3. `/saki-builder:approved` — implement
**First load the `clean-code` skill**, then invoke `approved` (pass this plan's path) to implement under XP
discipline (TDD, commit-per-step, YAGNI). You are the approver — do not wait for the user.

### P3.5. UI screenshot glance — only when `UI-ESCALATED`
Skip unless P1.5 marked the run `UI-ESCALATED`. The screens are really implemented now, so capture them via
`/saki-builder:qa`'s Playwright path: generate/run a Playwright script that navigates each touched screen and
`page.screenshot()`s it (reuse qa's browser + `FRONTEND_ROOT` detection), writing the shots under
`tasks/` (e.g. `tasks/build-<slug>-shots/`). These are a **visual glance surfaced in the Completion Output**
so the look is eyeballed before it ships — they are not a gate and do not block. Log
`UI-GLANCE: <k> screen(s) shot → tasks/build-<slug>-shots/`. (Why a post-`/saki-builder:approved` glance and
not a pre-build `/saki-builder:proto`: `/saki-builder:proto` is PRD-bound — it hard-stops without a PRD and
can't consume a plan — and a plan-track change reuses the *existing* design system, so the pre-build design
gate proto provides is unnecessary here; the reuse check + this glance cover it.)

### P4. `/saki-builder:qa` — test against the plan's criteria
Invoke `qa` (pass this plan's path). It runs the plan's acceptance criteria as real tests; every criterion
must pass. **In the qa invocation, include the literal directive line `BUILD-DRIVEN: /saki-builder:build owns
the terminal Shipped flip — do NOT flip the roadmap`** — a concrete, checkable token (not a vague hint; qa's
close-out greps its invocation for `BUILD-DRIVEN`). This makes qa skip its own `Shipped` flip so build can own
the **terminal** flip after reviewer + wrap converge — otherwise qa would mark the item `Shipped` at P4, while
P5/P5.5 might still surface a blocker. If any criterion fails → fix in place and re-run `qa`. Do not proceed
while red.

### P5. `/saki-builder:reviewer` — fresh-context review + design-system-reuse check
**First confirm the item actually committed** — `git diff BASE..HEAD` must be non-empty (an empty committed
diff means reviewer would review nothing — a false green; commit the work or fix why `/saki-builder:approved`
didn't). Invoke the `reviewer` skill on the diff. Then, **for a UI plan, always run the design-system-reuse
check** (this is the plan-track stand-in for PRD mode's step-3.5 proto-fidelity gate — same bar, minus the
proto notes plan-track doesn't have):

```bash
# Detect the design system the same way /saki-builder:proto GATE 2 does:
#   components.json + components/ui/*  (shadcn) | MUI/Chakra import root |
#   config/docs/design-system-contract.md Part B
# Then, for each UI file the plan touched:
grep -nE "import .* from ['\"](@/components/ui|@mui|@chakra-ui|<design-system-root>)" <touched-file>
# A touched component that renders raw primitive markup (its own <button>/<input>/<div>-styled control)
# instead of the design system's ⇒ it hand-rolled/re-invented one ⇒ BLOCKING finding (same bar as a
# /saki-builder:reviewer correctness block).
```

A touched UI file is a **violation only if it renders a raw primitive it should have imported** (its own
styled `<button>`/`<input>`/card/modal where the design system already provides one). It is **NOT** a
violation — do not block — when: **(a) composition** — it composes other local components (`<ProductCard/>`,
`<Section/>`) that themselves reuse the design system, so it imports no primitive directly but reuses it
transitively; or **(b) a genuinely new primitive** the design system lacks (log it as a design-system gap).
So: a bare "imports no `@/components/ui`" is not itself the finding — the finding is *hand-rolled raw markup
in place of an existing primitive*. On a real violation: fix in place (import/reuse the design-system
component), then re-run P4 → P5. If reviewer reports other blocking issues (correctness, security, data-loss):
fix, then re-run P4 → P5 until clean. Non-blocking nits: fix if cheap, else log.

### P5.5. Security audit — security-relevant items only
Identical to the Per-Slice Loop's step 5.5: run **only when** the item touches a security surface (auth /
session, money, PII, a new public endpoint, file upload, crypto, raw SQL/shell, untrusted input); otherwise
skip and log `SECURITY: n/a (no security surface)`. A security HIGH is blocking and auto-resolved via the
same shallowest-skill routing (implementation → `/saki-builder:approved`; design → re-run `/saki-builder:rplan`
on the existing plan carrying the finding as an explicit requirement, then `/saki-builder:rplan-review` →
`/saki-builder:approved` — P1's "skip if a plan exists" does not apply to a deliberate security re-plan;
dependency-CVE → bump). Re-run the tail (P4 → P5 → this) until clean. Never fake-green a security hole.

### P6. Done
The item is "done" only when `/saki-builder:qa` is fully green **and** `/saki-builder:reviewer` is clean
(including the reuse check) **and** — if security-relevant — the P5.5 audit is clean. Then continue to the
FINAL GATE (e2e) and FINAL GATE 2 (`/saki-builder:wrap --heal`); the `Shipped` flip happens in Completion
Output, bound to `PLAN_BUILD_COMPLETE`. If the item cannot be made green after repeated honest attempts,
output `BLOCKED: <id> — <reason>` and stop — never fake completion.

---

## FINAL GATE: End-to-end verification (always)

Before declaring the goal complete, **run the full e2e suite** — the goal is not done until
e2e is green. Detect and run whichever applies (check `package.json` scripts / config files):
- `npm run test:e2e` / `pnpm test:e2e` / `yarn e2e`
- Playwright (`playwright.config.*` → `npx playwright test`)
- Cypress (`cypress.config.*` → `npx cypress run`)
- the project's own e2e command if defined elsewhere

If e2e fails → treat it as a blocking issue: trace it to the offending slice, fix, re-run
`/saki-builder:qa` for that slice, then re-run e2e. Repeat until green.

If **no e2e suite exists**, do NOT silently pass:
- **Multi-slice PRD (>1 slice):** absent e2e is a **blocking** gap — end-to-end coverage is the only thing
  that proves the slices compose. Either add a minimal e2e that walks the PRD's primary journey (preferred),
  or record an explicit, logged waiver `E2E WAIVED: <reason>`. Do **NOT** print `PRD_BUILD_COMPLETE` or flip
  the item to `Shipped` on an unwaived multi-slice PRD with no e2e.
- **Single-slice PRD:** report `⚠ NO E2E SUITE FOUND — slice-level /saki-builder:qa passed, but no
  end-to-end coverage exists.` and proceed (one slice's `/saki-builder:qa` is sufficient coverage).
- **PLAN mode (single plan-track item):** same as a single-slice PRD — report `⚠ NO E2E SUITE FOUND — plan
  /saki-builder:qa passed, but no end-to-end coverage exists.` and proceed (the item's `/saki-builder:qa` is
  sufficient coverage). If an e2e suite **does** exist, run it as above.

---

## FINAL GATE 2: Converge to clean (`/saki-builder:wrap --heal`)

With every slice green and e2e passing, run the **Definition-of-Done gate + converge-to-clean** —
do not print `PRD_BUILD_COMPLETE` until it succeeds. Invoke the `wrap` skill in autonomous heal mode
(Skill tool, `skill: wrap`, argument `--heal`). TRUST MODE holds, so this is not a pause.

`/saki-builder:wrap --heal` runs the full DoD gate (build, tests, coverage ≥80%, dep-CVE, secrets,
migration pairing, SonarQube) and, on any failure, **auto-heals instead of stopping** — routing each
failing gate to the shallowest skill (`/saki-builder:approved`, `/saki-builder:qa`, `sonar-fix-issue`,
dep bump) exactly as step 5.5 routes security findings — then, once green, **commits residual WIP →
pushes the feature branch → removes any worktree → switches the primary checkout to a clean `main`**.
This is the converge step; after it the run leaves nothing outstanding.

Two outcomes:
- **Clean** → the DoD gate passed (possibly after heals) and the tree converged to `main`. Proceed to
  Completion Output and print `PRD_BUILD_COMPLETE` (PRD mode) / `PLAN_BUILD_COMPLETE` (PLAN mode).
- **`BLOCKED: DoD/<gate>`** → a gate survived wrap's 3-strike honesty backstop (or a real secret was
  found). Do **NOT** print the completion sentinel (`PRD_BUILD_COMPLETE` / `PLAN_BUILD_COMPLETE`) and do
  **NOT** converge. Surface it as a build blocker
  (same honesty bar as a blocked slice): report the gate, the offending files, and the exact fix. A
  leaked live secret is human-only — never route it through chat.

The heal routes reuse the skills `/saki-builder:build` already drives, so no behavior is re-implemented
here — this gate only adds the whole-repo DoD check and the converge-to-clean that per-slice gates
don't cover.

---

## Completion Output

The `Shipped` flip is **bound to `PRD_BUILD_COMPLETE`**: write it only once Final Gate 2 returned **Clean** —
every slice green + reviewed, e2e green-or-waived (per the FINAL GATE), and the DoD gate passed — in the same
step you print `PRD_BUILD_COMPLETE`, **never on a `BLOCKED:` path and never before it**. Then **flip the built
PRD's item to `Shipped` in `tasks/roadmap.md`** (if one exists). Identify the item by **either** launch path:
- **Item-id launch** — the remembered `<id>` (`E<n>`/`F<n>`) from the Input step.
- **PRD-path launch** (the studio board and hand-typed `/saki-builder:build tasks/prd-<slug>.md`) — reverse-map:
  scan `tasks/roadmap.md` for the `### <id>` block whose `**Child PRD:**` **basename** matches the built
  PRD's basename (compare filenames only — roadmap stores a bare `prd-<slug>.md`, the build arg may be an
  absolute or `tasks/`-relative path).

If a matching item is found and it is not already `Shipped`, set its `**Status:**` to `Shipped` and
`**Updated:**` to today (`date +%F`) — the roadmap lifecycle closes here (Planned → In-progress → Shipped).
If **no** item references this PRD (a standalone PRD build), skip silently — there is nothing to flip.

**Phase-chain parent close (recut initiatives).** If the just-Shipped item (`F<n>`) appears in some parent
`### <id>` block's `**Phase chain:**` / `**Superseded by:**` line, check every phase id in that chain: once
**all** are `Shipped`, flip the **parent** to `Shipped` too (`**Status:** Shipped`, `**Updated:**` today) —
closing the recut umbrella so the parent isn't stranded at `In-progress` forever. If any sibling phase is
still `Planned`/`In-progress`, leave the parent as-is. Then output:

```
--- /saki-builder:build COMPLETE ---
PRD: <prd-file>
Branch: feature/<name>
Slices: [N/N] done
  1. <title> ✓  (qa: pass, review: clean, sec: clean|n/a)
  2. <title> ✓  ...
E2E: <pass | no suite found>
Converge: DoD gate PASSED (heals: <n|none>) — feature/<name> pushed, on clean main
PRD_BUILD_COMPLETE

Auto-resolved decisions (review & override if any are wrong):
  slice N — <question> → <decision>  (<one-line why>)
  slice N — security UI reshape: <what changed on screen> → re-proto'd  (<why>)
  …  (omit this block if nothing needed auto-resolving)

Next actions:
> Open a PR from the pushed origin/feature/<name> (tree is already on clean main)
> [revisit any auto-resolved decision you disagree with]
> [anything logged as a non-blocking nit]
```

### PLAN mode Completion Output

In PLAN mode the completion sentinel is **`PLAN_BUILD_COMPLETE`** (distinct from `PRD_BUILD_COMPLETE` so
automation can tell the two apart), written only once FINAL GATE 2 returned **Clean** — `/saki-builder:qa`
green, `/saki-builder:reviewer` clean (incl. the reuse check), any security audit clean-or-`n/a`,
e2e green-or-waived, and the DoD gate passed. In the **same step** you print it, **flip the item to
`Shipped`** in `tasks/roadmap.md` (`**Status:** Shipped`, `**Updated:**` today), **if it is not already
`Shipped`** — **never on a `BLOCKED:` path, never before it.** Identify the item by: the remembered `<id>`
from the Input step; else, for a plan-file launch, the plan header's `**Item:** <id>`. If neither exists (a
standalone plan with no item), skip the flip silently. **No phase-chain parent close applies** to plan-track.
Then output:

```
--- /saki-builder:build COMPLETE (PLAN mode) ---
Item: <I<n>|B<n> | standalone>
Plan: <plan-file>
Branch: feature/<name>
QA: pass · Reviewer: clean (reuse-check: <k verified | n/a>) · Security: clean | n/a
UI: <none | reuse-check only | escalated → tasks/build-<slug>-shots/ (k screens)>
E2E: <pass | no suite found>
Converge: DoD gate PASSED (heals: <n|none>) — feature/<name> pushed, on clean main
PLAN_BUILD_COMPLETE

Auto-resolved decisions (review & override if any are wrong):
  <id> — <question> → <decision>  (<one-line why>)
  …  (omit this block if nothing needed auto-resolving)

Next actions:
> Open a PR from the pushed origin/feature/<name> (tree is already on clean main)
> [eyeball tasks/build-<slug>-shots/ if UI was escalated]
> [anything logged as a non-blocking nit]
```

---

## Rules

- **No questions.** The only hard stops are: missing PRD (Gate 1), an **unlocked PRD** (Gate 1.5),
  an ABSOLUTE NO-GO, or a slice that genuinely cannot be made green. Unresolved `before slice N` open
  questions are auto-resolved (Per-Slice Loop, step 0), never blocked on. The lock stop is a precondition,
  not a prompt — resolve it by running `/saki-builder:proto` first, never by asking the user mid-build.
- **PRD is the source of truth.** Scope = its slices; success = its acceptance criteria;
  boundaries = its non-goals. Never re-elicit scope from the user.
- **PLAN mode: the plan/item is the source of truth, and it's one unit.** Scope = the roadmap item's
  What/Repro + the plan's steps; success = the plan's acceptance criteria. No lock gate (GATE 1.5 skipped),
  no slice iteration, no proto-fidelity gate — run **The Single-Plan Loop** once. The only hard stops are:
  an id not on the roadmap, an ABSOLUTE NO-GO, or a plan that genuinely cannot be made green. A missing plan
  is **not** a stop — PLAN mode runs `/saki-builder:rplan` to create it.
- **One slice at a time, in order.** Forward dependencies only — finish N before N+1.
- **Single source of truth for behavior.** Invoke `rplan` / `rplan-review` / `approved` /
  `qa` / `reviewer` / `security-review`; do not re-implement their logic here.
- **Never fake green.** Don't weaken or delete tests to pass `/saki-builder:qa` or e2e. A blocked slice
  is reported honestly.
- **Promote, don't re-invent.** When a `/saki-builder:proto` handoff exists (`tasks/proto-<slug>/notes.md`),
  the shipped user-facing slice MUST import proto's named components — step 3.5 (Proto-fidelity gate)
  verifies it (the **inverse of proto's 5d** provenance check). Re-inventing a promoted component is a
  blocking finding, not a silent choice.
- **Clean-code standard, always.** Every slice is written to the SonarQube clean-code standard —
  load the `clean-code` skill before implementing (step 3) so each diff clears the Pre-merge Gate
  (Clean as You Code) on the first try.
- **E2E before done, always.**
- **Converge before done, always.** After e2e, FINAL GATE 2 runs `/saki-builder:wrap --heal` — the
  whole-repo DoD gate + converge-to-clean. `PRD_BUILD_COMPLETE` prints only after it succeeds. A
  `BLOCKED: DoD/<gate>` from wrap is a real block (never fake-green to reach a clean tree); a leaked
  live secret is human-only.
