---
name: build
description: Autonomously execute a finished PRD end-to-end. Reads the PRD's vertical slices and runs /saketek:rplan → (/saketek:rplan-review if needed) → /saketek:approved → /saketek:qa → /saketek:reviewer → (security audit on security-relevant slices) on each, looping until every slice is done with no outstanding issues. Always runs the e2e suite before declaring the goal complete. No confirmation prompts. Usage — /saketek:build <prd-file.md>.
---

# Autonomous PRD Executor

You are operating in **TRUST MODE** — fully autonomous execution. The PRD has already
been written, reviewed (via `/saketek:prd` → `/saketek:prd-review`), and **Locked** (via
`/saketek:proto`, Gate 1.5), and the user has pre-authorized this flow. Your single goal: **ship every
vertical slice in the PRD, fully tested, with no outstanding issues.** Do not stop until that is true.

This command is the one-shot equivalent of running, by hand, for each slice:

```
/saketek:rplan  →  /saketek:rplan-review (only if needed)  →  /saketek:approved  →  /saketek:qa  →  /saketek:reviewer  →  security audit (security-relevant slices only)
```

…then verifying the whole thing end-to-end.

---

## CRITICAL: No Confirmation Prompts — Ever

You are in TRUST MODE. This means:
- **NEVER ask "Do you want to proceed?"** or any variation. Make the call, log it, continue.
- **Do NOT wait for plan approval.** `/saketek:rplan` normally stops for a human; here you
  auto-approve any plan that clears the confidence bar and proceed to `/saketek:approved` yourself.
- Agent-based sub-skills that are part of this flow (`/saketek:rplan-review`, `/saketek:reviewer`,
  and the `security-review` audit) are permitted — they are how slices get reviewed. Just never pause
  for user confirmation around them.
- The **only** hard stops are: a missing/unreadable PRD file (Gate 1), an ABSOLUTE NO-GO (below),
  or a slice that cannot be made green after repeated honest attempts. An unresolved `before slice
  N` open question is **not** a stop — `/saketek:build` auto-resolves it (Per-Slice Loop, step 0) and
  proceeds. **Exception:** a fork the PRD author tagged `[human]` is a deliberate, human-only
  decision — pause for it via the `NEEDS_DECISION:` gate (step 0a). That is a *resumable pause*, not
  a confirmation prompt: you emit the gate and end the turn; the studio collects the answer and
  re-drives you. It is the one sanctioned way to defer a decision to the operator.

---

## Run to completion — never yield early

A skill cannot switch on Claude Code's built-in `/goal` engine (only the user can type
`/goal`). So this skill enforces its **own** persistence — behave as if a goal were set:

- **Completion signal.** You are done ONLY when every slice in the PRD is green
  (`/saketek:qa` passes, `/saketek:reviewer` is clean, **and** any security audit a
  security-relevant slice required is clean) **and** the e2e suite passes. At that point,
  and only then, print `PRD_BUILD_COMPLETE`. Never print it early.
- **Do not hand control back** until you either print `PRD_BUILD_COMPLETE` or hit a real
  hard stop (missing PRD, NO-GO, honestly-blocked slice). If a turn runs long, keep going —
  start the next slice rather than stopping to ask "should I continue?"
- **Progress scratchpad (human log).** Maintain `tasks/.build-<prd-slug>-progress.md` with the
  slice checklist (done / in-progress / remaining), updated after every slice. If context is
  cleared mid-build, re-read it on start and **skip already-green slices** to resume.
- **State manifest (machine resume state).** Also maintain `tasks/.build-<prd-slug>-state.json` —
  the studio reads + verifies this to resume an interrupted build at the exact step. Update it
  **after every step** (rplan / approved / qa / reviewer), not just every slice:
  ```json
  { "prd": "<path>", "branch": "<branch>", "commitPolicy": "per-step",
    "slices": [ { "n": 1, "title": "…", "status": "not-started|in-progress|done|blocked",
      "steps": { "rplan":    { "status": "done", "artifact": "tasks/<...>-slice1-plan.md" },
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
- **Loop guard.** If the same slice fails the same way ~3 times, stop hammering it: write
  the reason to the scratchpad, output `BLOCKED: slice <N> — <reason>`, then move on to any
  independent remaining slices before reporting.

### For guaranteed cross-turn autonomy, launch under /goal

Because a skill can't self-activate `/goal`, the most autonomous way to start is for the
**user** to type the wrapper (the engine is `/goal`, the orchestration is `/saketek:build`):

```
/goal /saketek:build tasks/prd-<feature>.md — done when every slice passes /saketek:qa and /saketek:reviewer and the e2e suite is green
```

Plain `/saketek:build tasks/prd-<feature>.md` still runs and self-iterates per the rules above; the
`/goal` wrapper just makes the cross-turn persistence bulletproof.

---

## Input

Usage: `/saketek:build <E<n> | prd-file.md>` (filler words are fine, e.g. `/saketek:build start build prd-wave-2.md`).

**Epic id (`E<n>`) — the disciplined path:** if the argument is an epic id, read `tasks/roadmap.md`, find
`### E<n>`, and resolve its `**Child PRD:**` link to `tasks/prd-<slug>.md`. If `E<n>` has no Child PRD yet
(its value is `—`), **STOP**: `E<n> has no PRD yet — run /saketek:pickup E<n> first`. Remember the `E<n>`
so the Completion Output can flip its roadmap status to `Shipped`.

> **Note — PRD-path launches still flip the epic.** The studio board (and a hand-typed
> `/saketek:build tasks/prd-<slug>.md`) invokes this skill with the **PRD path**, not `E<n>`. Do NOT
> assume "no `E<n>` argument ⇒ no epic to flip": the Completion Output reverse-maps the built PRD back to
> its epic via the roadmap's `**Child PRD:**` field, so the `Shipped` flip fires on either launch path.

Otherwise extract the PRD path from the arguments: take the token ending in `.md` (or matching
`prd-*`). Locate the file by checking, in order: `tasks/<name>`, `./<name>`, the path as
given. The `/saketek:prd` skill saves to `tasks/prd-<feature>.md`, so `tasks/` is the common case.

---

## GATE 1: Load the PRD (hard stop if missing)

Read the PRD file. If it cannot be found or read, **STOP** and output:
```
HARD STOP — PRD NOT FOUND
Looked for: tasks/<name>, ./<name>, <name>
Pass a valid PRD path: /saketek:build <prd-file.md>
```
Do NOT invent a PRD or ask the user to paste one — this is the one input the command requires.

From the PRD, extract (match sections by **heading title**, not number — PRD section numbers shift
as sections are added):
- **Vertical Slices** — the ordered, numbered list. Slices are forward-dependency-only, so
  **PRD order is execution order**. This is your work list.
- **Acceptance Criteria per Slice** — these become each slice's `/saketek:qa` success criteria.
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
  beta | before GA` deadlines — those are rollout decisions, outside `/saketek:build`'s scope.

Print the extracted slice list (numbered titles) and any **unresolved** `before slice N` gates so
the run is auditable — these will be **auto-resolved** in the loop (step 0), not blocked on — then
begin.

### Optional: reuse a `/saketek:proto` preview if one exists

If `tasks/proto-<prd-slug>-notes.md` exists (the user ran `/saketek:proto` first), read it. It records the
**real design-system components + token references** chosen per screen, already validated visually.
When implementing a user-facing slice, **promote** those presentational components (mock data →
real data + state + tests + backend wiring) instead of re-picking from scratch — the look is
already approved. As part of the slice that promotes a `proto-preview/<slice>` preview, **delete
that throwaway preview route/story and revert any `/proto-preview` middleware bypass** (neither may
ship). If no proto notes exist, build the UI normally.

---

## GATE 1.5: Lock check — requirements must be frozen (hard stop if unlocked)

`/saketek:build` runs only against a **Locked** PRD — the requirements are frozen before any slice
reaches `/saketek:rplan`. Grep the PRD (loaded in Gate 1) for the lock marker:

```bash
grep -qE '^<!-- prd-locked:' "<prd-path>" && echo LOCKED || echo UNLOCKED
```

If the marker is **absent**, **STOP** — do not plan, do not touch code:
```
HARD STOP — PRD NOT LOCKED
Requirements aren't frozen; /saketek:build won't hand unfrozen scope to /saketek:rplan.
Lock it first:  /saketek:proto <E<n> | prd-file.md>
  — designs + approves the UI, then writes Status: Locked (a no-UI PRD is frozen there too).
Then re-run /saketek:build.
```

This is the gate that enforces **"lock Product Requirement before hand off to rplan."** It is **not** a
confirmation prompt (TRUST MODE holds) — it is a *precondition*: the lock is written by a human-gated step
(`/saketek:proto`) **before** build, so build itself never pauses to ask. A Locked PRD is by definition
Approved + review-green (the lock is the last gate of the PRD phase), so no separate approval check is needed
here. `--slice` PARTIAL proto runs do not lock, so a build after one still correctly hard-stops until a full
`/saketek:proto` locks the whole journey.

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
Forbidden in /saketek:build mode. Resolve manually with explicit human approval.
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
  re-drives `/saketek:build`, which then reads it like any resolved question. This is a pause, not a block:
  no `BLOCKED:`, no give-up — the build resumes the moment the human answers.

**0b. Everything else — resolve it yourself and proceed** (the default; untagged forks). The goal is
to ship the expectation, so a missing decision is something `/saketek:build` *makes*, not something it waits
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

Carry the decision into step 1 (`/saketek:rplan`) as a stated assumption so the plan and its tests are
built on it.

### 1. `/saketek:rplan` — plan the slice
Invoke the `rplan` skill (Skill tool, `skill: rplan`) scoped to **this slice only**: its
description plus its acceptance criteria, **and the Business Rules & Invariants in scope for it**
(the rules its criteria link to, plus any `🔒 INVARIANT` the slice's writes could violate). The
plan must be built to uphold them — call out each in-scope invariant so the implementation and its
tests account for it. `/saketek:rplan` will research, build the plan, and score confidence. **Do not wait
for approval** — read the resulting plan and its confidence score yourself.

### 2. `/saketek:rplan-review` — *only if needed*
Run the `rplan-review` skill when any of these hold; otherwise skip straight to step 3:
- `/saketek:rplan` confidence is below its 96% bar, **or**
- the slice is HIGH risk (auth, DB migration, deletes, money, security boundary), **or**
- the slice spans >2 modules or has >3 acceptance criteria.

`/saketek:rplan-review` hardens the plan (criteria → test commands, domain-expert pass). After it,
re-read the plan.

### 3. `/saketek:approved` — implement
**First load the `clean-code` skill** (Skill tool, `skill: clean-code`) so the slice is written to
the SonarQube clean-code standard — the Pre-merge Gate grades the diff (Clean as You Code), so
writing clean now avoids a gate failure later. Then invoke the `approved` skill to implement the
slice under XP discipline (TDD Red→Green→Refactor, commit-per-step, YAGNI). You are the approver
here — invoke both without waiting for the user. (Re-load `clean-code` every slice; this keeps it in
context even if a context clear happened between slices.)

### 4. `/saketek:qa` — test against acceptance criteria + in-scope invariants
Invoke the `qa` skill. It runs **this slice's** acceptance criteria as real tests; every
criterion must pass. **Also verify each in-scope Business Rule** — and for a `🔒 INVARIANT`,
assert it holds under concurrency / partial failure where the stack allows (e.g. a race or
double-fire test), not just the happy path, since a passing acceptance criterion does not prove an
invariant holds. If any criterion or invariant check fails → fix in place and re-run `/saketek:qa`. Do not
proceed while red.

### 5. `/saketek:reviewer` — fresh-context review
Invoke the `reviewer` skill on the slice's diff. If it reports **blocking** issues
(correctness, security, data-loss, **or a violated `🔒 INVARIANT`**): fix them, then re-run `/saketek:qa`
and `/saketek:reviewer` until the review is clean. Non-blocking nits: fix if cheap, otherwise log and move on.

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
   hardcoded secret, missing ownership / tenant check in a handler): fix via `/saketek:approved`
   under TDD — add a failing test that *reproduces the hole* first, then close it. Re-enter at step 4.
2. **Design-level** (the flaw is in the plan, not the code — no tenant-isolation model, wrong auth
   boundary, a data model that structurally leaks): a point-fix won't hold — **re-plan the slice from
   step 1 `/saketek:rplan`**, carrying the finding in as an explicit requirement/assumption, then
   `/saketek:rplan-review` (the slice is now HIGH-risk) → `/saketek:approved`.
   **If the fix reshapes the UI** (changes a screen, field, or flow the user sees — e.g. drops a
   leaking field, inserts a step-up-auth / confirm screen), the approved proto for that screen is now
   stale: re-render it autonomously with `/saketek:proto --slice=N`, update
   `tasks/proto-<slug>-notes.md`, and annotate the changed requirement in the PRD in place
   (`✅ RESOLVED (auto, security) — <what changed> — <why>`). Do NOT pause for human UI sign-off
   (TRUST MODE) and do NOT unlock the PRD — it stays Locked; you're amending one screen under the same
   auto-decision rule as step 0b. Record it in the Completion Output's auto-resolved block for
   post-hoc human review.
3. **Dependency-CVE**: bump / replace the dependency in-slice; if it can't be resolved in-slice, log
   it — the SonarQube `sonar-dependency-risks` gate at the Pre-merge Gate is the hard backstop before push.

After any route, **re-run the tail** — `/saketek:qa` → `/saketek:reviewer` → this audit —
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

**Loop until issue-free:** a slice is "done" only when `/saketek:qa` is fully green, **and**
`/saketek:reviewer` has no blocking findings, **and** — if the slice was security-relevant — the
step-5.5 security audit is clean. If you cannot get a slice green after repeated honest
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
`/saketek:qa` for that slice, then re-run e2e. Repeat until green.

If **no e2e suite exists**, do NOT silently pass. Report:
`⚠ NO E2E SUITE FOUND — slice-level /saketek:qa passed, but no end-to-end coverage exists.`

---

## Completion Output

When every slice is green, reviewed, and e2e passes, **flip the built PRD's epic to `Shipped` in
`tasks/roadmap.md`** (if one exists). Identify the epic by **either** launch path:
- **Epic-id launch** — the remembered `E<n>` from the Input step.
- **PRD-path launch** (the studio board and hand-typed `/saketek:build tasks/prd-<slug>.md`) — reverse-map:
  scan `tasks/roadmap.md` for the `### E<n>` block whose `**Child PRD:**` **basename** matches the built
  PRD's basename (compare filenames only — roadmap stores a bare `prd-<slug>.md`, the build arg may be an
  absolute or `tasks/`-relative path).

If a matching epic is found and it is not already `Shipped`, set its `**Status:**` to `Shipped` and
`**Updated:**` to today (`date +%F`) — the roadmap lifecycle closes here (Planned → In-progress → Shipped).
If **no** epic references this PRD (a standalone PRD build), skip silently — there is nothing to flip. Then output:

```
--- /saketek:build COMPLETE ---
PRD: <prd-file>
Branch: feature/<name>
Slices: [N/N] done
  1. <title> ✓  (qa: pass, review: clean, sec: clean|n/a)
  2. <title> ✓  ...
E2E: <pass | no suite found>
PRD_BUILD_COMPLETE

Auto-resolved decisions (review & override if any are wrong):
  slice N — <question> → <decision>  (<one-line why>)
  slice N — security UI reshape: <what changed on screen> → re-proto'd  (<why>)
  …  (omit this block if nothing needed auto-resolving)

Next actions:
> Review the branch diff and open a PR
> [revisit any auto-resolved decision you disagree with]
> [anything logged as a non-blocking nit]
```

---

## Rules

- **No questions.** The only hard stops are: missing PRD (Gate 1), an **unlocked PRD** (Gate 1.5),
  an ABSOLUTE NO-GO, or a slice that genuinely cannot be made green. Unresolved `before slice N` open
  questions are auto-resolved (Per-Slice Loop, step 0), never blocked on. The lock stop is a precondition,
  not a prompt — resolve it by running `/saketek:proto` first, never by asking the user mid-build.
- **PRD is the source of truth.** Scope = its slices; success = its acceptance criteria;
  boundaries = its non-goals. Never re-elicit scope from the user.
- **One slice at a time, in order.** Forward dependencies only — finish N before N+1.
- **Single source of truth for behavior.** Invoke `rplan` / `rplan-review` / `approved` /
  `qa` / `reviewer` / `security-review`; do not re-implement their logic here.
- **Never fake green.** Don't weaken or delete tests to pass `/saketek:qa` or e2e. A blocked slice
  is reported honestly.
- **Clean-code standard, always.** Every slice is written to the SonarQube clean-code standard —
  load the `clean-code` skill before implementing (step 3) so each diff clears the Pre-merge Gate
  (Clean as You Code) on the first try.
- **E2E before done, always.**
