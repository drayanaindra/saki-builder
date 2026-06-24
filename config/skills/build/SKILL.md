---
name: build
description: Autonomously execute a finished PRD end-to-end. Reads the PRD's vertical slices and runs /rplan → (/rplan-review if needed) → /approved → /qa → /reviewer on each, looping until every slice is done with no outstanding issues. Always runs the e2e suite before declaring the goal complete. No confirmation prompts. Usage — /build <prd-file.md>.
---

# Autonomous PRD Executor

You are operating in **TRUST MODE** — fully autonomous execution. The PRD has already
been written and reviewed (via `/prd`) and the user has pre-authorized this flow. Your
single goal: **ship every vertical slice in the PRD, fully tested, with no outstanding
issues.** Do not stop until that is true.

This command is the one-shot equivalent of running, by hand, for each slice:

```
/rplan  →  /rplan-review (only if needed)  →  /approved  →  /qa  →  /reviewer
```

…then verifying the whole thing end-to-end.

---

## CRITICAL: No Confirmation Prompts — Ever

You are in TRUST MODE. This means:
- **NEVER ask "Do you want to proceed?"** or any variation. Make the call, log it, continue.
- **Do NOT wait for plan approval.** `/rplan` normally stops for a human; here you
  auto-approve any plan that clears the confidence bar and proceed to `/approved` yourself.
- Agent-based sub-skills that are part of this flow (`/rplan-review`, `/reviewer`) are
  permitted — they are how slices get reviewed. Just never pause for user confirmation
  around them.
- The **only** hard stops are: a missing/unreadable PRD file (Gate 1), an unresolved `before
  slice N` open question (Per-Slice Loop, step 0), an ABSOLUTE NO-GO (below), or a slice that
  cannot be made green after repeated honest attempts.

---

## Run to completion — never yield early

A skill cannot switch on Claude Code's built-in `/goal` engine (only the user can type
`/goal`). So this skill enforces its **own** persistence — behave as if a goal were set:

- **Completion signal.** You are done ONLY when every slice in the PRD is green
  (`/qa` passes **and** `/reviewer` is clean) **and** the e2e suite passes. At that point,
  and only then, print `PRD_BUILD_COMPLETE`. Never print it early.
- **Do not hand control back** until you either print `PRD_BUILD_COMPLETE` or hit a real
  hard stop (missing PRD, NO-GO, honestly-blocked slice). If a turn runs long, keep going —
  start the next slice rather than stopping to ask "should I continue?"
- **Progress scratchpad.** Maintain `tasks/.build-<prd-slug>-progress.md` with the slice
  checklist (done / in-progress / remaining), updated after every slice. If context is
  cleared mid-build, re-read it on start and **skip already-green slices** to resume.
- **Loop guard.** If the same slice fails the same way ~3 times, stop hammering it: write
  the reason to the scratchpad, output `BLOCKED: slice <N> — <reason>`, then move on to any
  independent remaining slices before reporting.

### For guaranteed cross-turn autonomy, launch under /goal

Because a skill can't self-activate `/goal`, the most autonomous way to start is for the
**user** to type the wrapper (the engine is `/goal`, the orchestration is `/build`):

```
/goal /build tasks/prd-<feature>.md — done when every slice passes /qa and /reviewer and the e2e suite is green
```

Plain `/build tasks/prd-<feature>.md` still runs and self-iterates per the rules above; the
`/goal` wrapper just makes the cross-turn persistence bulletproof.

---

## Input

Usage: `/build <prd-file.md>` (filler words are fine, e.g. `/build start build prd-wave-2.md`).

Extract the PRD path from the arguments: take the token ending in `.md` (or matching
`prd-*`). Locate the file by checking, in order: `tasks/<name>`, `./<name>`, the path as
given. The `/prd` skill saves to `tasks/prd-<feature>.md`, so `tasks/` is the common case.

---

## GATE 1: Load the PRD (hard stop if missing)

Read the PRD file. If it cannot be found or read, **STOP** and output:
```
HARD STOP — PRD NOT FOUND
Looked for: tasks/<name>, ./<name>, <name>
Pass a valid PRD path: /build <prd-file.md>
```
Do NOT invent a PRD or ask the user to paste one — this is the one input the command requires.

From the PRD, extract (match sections by **heading title**, not number — PRD section numbers shift
as sections are added):
- **Vertical Slices** — the ordered, numbered list. Slices are forward-dependency-only, so
  **PRD order is execution order**. This is your work list.
- **Acceptance Criteria per Slice** — these become each slice's `/qa` success criteria.
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
  beta | before GA` deadlines — those are rollout decisions, outside `/build`'s scope.

Print the extracted slice list (numbered titles) and any **unresolved** `before slice N` gates so
the run is auditable, then begin.

### Optional: reuse a `/proto` preview if one exists

If `tasks/proto-<prd-slug>-notes.md` exists (the user ran `/proto` first), read it. It records the
**real design-system components + token references** chosen per screen, already validated visually.
When implementing a user-facing slice, **promote** those presentational components (mock data →
real data + state + tests + backend wiring) instead of re-picking from scratch — the look is
already approved. As part of the slice that promotes a `proto-preview/<slice>` preview, **delete
that throwaway preview route/story and revert any `/proto-preview` middleware bypass** (neither may
ship). If no proto notes exist, build the UI normally.

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
Forbidden in /build mode. Resolve manually with explicit human approval.
```
Then continue with the remaining independent slices.

---

## The Per-Slice Loop

For **each slice, in PRD order**, run the full chain. Do not advance to slice N+1 until
slice N is green and reviewed.

### 0. Open-question gate — hard-stop on an unresolved architectural fork
Before planning slice N, check the Open Questions (the PRD's *Rabbit Holes & Open Questions*
section) extracted in Gate 1. If any question gated `before slice N` (or an earlier slice) is
**not** marked `✅ RESOLVED`, do **not** plan or implement the slice — that decision is
load-bearing and `/build` must never guess it (guessing is how an autonomous run bakes a wrong
architecture into every dependent slice). Stop and output:
```
BLOCKED: slice N — unresolved open question: <question> (owner: <owner>)
Resolve it in the PRD (prefix the entry `✅ RESOLVED — <decision>`), then re-run /build.
```
This is a legitimate hard stop, not a confirmation prompt — an unresolved architectural fork *is*
the "honestly-blocked slice" the TRUST-MODE rules already permit. Then move on to any independent
later slice whose own gates are resolved; report the blocked slice at the end.

### 1. `/rplan` — plan the slice
Invoke the `rplan` skill (Skill tool, `skill: rplan`) scoped to **this slice only**: its
description plus its acceptance criteria, **and the Business Rules & Invariants in scope for it**
(the rules its criteria link to, plus any `🔒 INVARIANT` the slice's writes could violate). The
plan must be built to uphold them — call out each in-scope invariant so the implementation and its
tests account for it. `/rplan` will research, build the plan, and score confidence. **Do not wait
for approval** — read the resulting plan and its confidence score yourself.

### 2. `/rplan-review` — *only if needed*
Run the `rplan-review` skill when any of these hold; otherwise skip straight to step 3:
- `/rplan` confidence is below its 96% bar, **or**
- the slice is HIGH risk (auth, DB migration, deletes, money, security boundary), **or**
- the slice spans >2 modules or has >3 acceptance criteria.

`/rplan-review` hardens the plan (criteria → test commands, domain-expert pass). After it,
re-read the plan.

### 3. `/approved` — implement
Invoke the `approved` skill to implement the slice under XP discipline (TDD Red→Green→Refactor,
commit-per-step, YAGNI). You are the approver here — invoke it without waiting for the user.

### 4. `/qa` — test against acceptance criteria + in-scope invariants
Invoke the `qa` skill. It runs **this slice's** acceptance criteria as real tests; every
criterion must pass. **Also verify each in-scope Business Rule** — and for a `🔒 INVARIANT`,
assert it holds under concurrency / partial failure where the stack allows (e.g. a race or
double-fire test), not just the happy path, since a passing acceptance criterion does not prove an
invariant holds. If any criterion or invariant check fails → fix in place and re-run `/qa`. Do not
proceed while red.

### 5. `/reviewer` — fresh-context review
Invoke the `reviewer` skill on the slice's diff. If it reports **blocking** issues
(correctness, security, data-loss, **or a violated `🔒 INVARIANT`**): fix them, then re-run `/qa`
and `/reviewer` until the review is clean. Non-blocking nits: fix if cheap, otherwise log and move on.

### 6. Mark done, advance
Log `SLICE [N] ✓ — <title>` with a one-line note (commits, files, test result), then move
to the next slice.

**Loop until issue-free:** a slice is "done" only when `/qa` is fully green **and**
`/reviewer` has no blocking findings. If you cannot get a slice green after repeated honest
attempts, stop and report exactly what's blocking — do not fake completion or weaken tests
to pass.

---

## FINAL GATE: End-to-end verification (always)

Before declaring the goal complete, **run the full e2e suite** — the goal is not done until
e2e is green. Detect and run whichever applies (check `package.json` scripts / config files):
- `npm run test:e2e` / `pnpm test:e2e` / `yarn e2e`
- Playwright (`playwright.config.*` → `npx playwright test`)
- Cypress (`cypress.config.*` → `npx cypress run`)
- the project's own e2e command if defined elsewhere

If e2e fails → treat it as a blocking issue: trace it to the offending slice, fix, re-run
`/qa` for that slice, then re-run e2e. Repeat until green.

If **no e2e suite exists**, do NOT silently pass. Report:
`⚠ NO E2E SUITE FOUND — slice-level /qa passed, but no end-to-end coverage exists.`

---

## Completion Output

When every slice is green, reviewed, and e2e passes, output:

```
--- /build COMPLETE ---
PRD: <prd-file>
Branch: feature/<name>
Slices: [N/N] done
  1. <title> ✓  (qa: pass, review: clean)
  2. <title> ✓  ...
E2E: <pass | no suite found>

Next actions:
> Review the branch diff and open a PR
> [anything logged as a non-blocking nit]
```

---

## Rules

- **No questions.** The only hard stops are: missing PRD (Gate 1), an unresolved `before slice N`
  open question (Per-Slice Loop, step 0), an ABSOLUTE NO-GO, or a slice that genuinely cannot be
  made green.
- **PRD is the source of truth.** Scope = its slices; success = its acceptance criteria;
  boundaries = its non-goals. Never re-elicit scope from the user.
- **One slice at a time, in order.** Forward dependencies only — finish N before N+1.
- **Single source of truth for behavior.** Invoke `rplan` / `rplan-review` / `approved` /
  `qa` / `reviewer`; do not re-implement their logic here.
- **Never fake green.** Don't weaken or delete tests to pass `/qa` or e2e. A blocked slice
  is reported honestly.
- **E2E before done, always.**
